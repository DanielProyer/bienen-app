import {
  assemblyaiStand,
  assemblyaiStarten,
  elevenlabsTranskribieren,
  infomaniakStand,
  infomaniakStarten,
} from './anbieter.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { waehleServiceKey } from './schluessel.ts';

// Der Service-Key wird nur zum PRUEFEN des Nutzer-JWT gebraucht, nie zum
// Lesen von Daten.
//
// WIEDERVERWENDET statt nachgebaut, und zwar nach einem Fehlschlag: Die erste
// Fassung las SUPABASE_SECRET_KEYS als Komma-Liste. Die Variable ist aber ein
// JSON-OBJEKT ({"default": "sb_secret_..."}) — der rohe JSON-Text ging als
// Schluessel weiter, getUser scheiterte, und jeder App-Aufruf bekam 401.
// Genau das steht seit dem 27.07. in schluessel.ts beschrieben.
function serviceKey(): string {
  return waehleServiceKey(
    Deno.env.get('SUPABASE_SECRET_KEYS'),
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY'),
  );
}

// Anbieter mit Auftragsnummer. Beide Routen sind von Haus aus asynchron; die
// Seite startet sie und fragt danach in kurzen Aufrufen den Stand ab.
const MIT_AUFTRAG = {
  assemblyai: { starten: assemblyaiStarten, stand: assemblyaiStand },
  infomaniak: { starten: infomaniakStarten, stand: infomaniakStand },
} as const;

type MitAuftrag = keyof typeof MIT_AUFTRAG;

// Die Testseite liegt oeffentlich auf GitHub Pages und hat keinen Login.
// Ohne diese Huerde koennte jeder Fremde auf Kosten des Betreibers
// transkribieren lassen. Das Testwort steht als Supabase-Secret.
function testwortStimmt(anfrage: Request): boolean {
  const erwartet = Deno.env.get('TRANSKRIPTION_TESTWORT');
  if (!erwartet) return false; // ohne gesetztes Geheimnis bleibt zu
  return anfrage.headers.get('x-testwort') === erwartet;
}

/// Zweiter Eingang: ein eingeloggter Nutzer der App.
///
/// Die oeffentliche Testseite hat keinen Login und weist sich mit dem Testwort
/// aus; die App hat einen und schickt ihr JWT. Beide Wege muessen nebeneinander
/// bestehen, solange die Testseite existiert.
///
/// Geprueft wird NUR, ob das JWT gueltig ist — welchem Betrieb der Nutzer
/// angehoert, spielt hier keine Rolle: Die Function liest nichts aus der
/// Datenbank, sie reicht Audio an die Erkenner weiter und gibt Text zurueck.
async function nutzerIstEingeloggt(anfrage: Request): Promise<boolean> {
  const kopf = anfrage.headers.get('Authorization') ?? '';
  const jwt = kopf.startsWith('Bearer ') ? kopf.slice(7) : '';
  if (!jwt) return false;
  const schluessel = serviceKey();
  if (!schluessel) return false;
  try {
    const admin = createClient(Deno.env.get('SUPABASE_URL')!, schluessel);
    const { data, error } = await admin.auth.getUser(jwt);
    return !error && !!data.user;
  } catch {
    return false;
  }
}

// `authorization` und `apikey` muessen freigegeben sein: supabase_flutter
// haengt sie beim invoke() an, und der Browser weist die Anfrage sonst schon
// im Preflight ab — BEVOR die Function ueberhaupt laeuft (Falle aus D-86).
const KOPF = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type, x-testwort, x-client-info, apikey',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Content-Type': 'application/json',
};

function antwort(koerper: unknown, status = 200): Response {
  return new Response(JSON.stringify(koerper), { status, headers: KOPF });
}

// --- Durchreiche-Bucket (U01) -----------------------------------------------
//
// Die Tonaufnahme geht NICHT mehr im Koerper der Anfrage hierher. Gemessen:
// 9,65 MB ueber eine langsame Leitung -> 504 nach 165 s, ohne dass ein
// Erkenner angefangen haette; dieselbe Anfrage mit 120 KB -> Antwort nach
// 0,28 s. Die 150-Sekunden-Grenze umfasst den UPLOAD, nicht erst die
// Bearbeitung — und bei drei Anbietern ging die Datei dreimal ueber die
// Leitung.
//
// Neuer Weg: Der Browser laedt EINMAL in den Bucket (signierte Upload-Adresse,
// gilt fuer genau einen Pfad), danach bekommt die Function nur den Pfad und
// holt die Datei im Rechenzentrum ab.
const EINGANG = 'transkription-eingang';

function adminClient() {
  const k = serviceKey();
  if (!k) return null;
  return createClient(Deno.env.get('SUPABASE_URL')!, k);
}

/// Macht aus einem Dateinamen einen brauchbaren Storage-Schluessel.
/// Leerzeichen und Sonderzeichen im Namen sind der haeufigste Grund fuer
/// Pfade, die beim Signieren noch gehen und beim Abrufen nicht mehr.
function saeubern(name: string): string {
  const s = name.replace(/[^\p{L}\p{N}._-]+/gu, '_').replace(/^_+|_+$/g, '');
  return (s.length > 80 ? s.slice(-80) : s) || 'aufnahme';
}

/// Besorgt das Audio — aus dem Bucket (Regelfall) oder aus dem Koerper
/// (Altweg, weiterhin brauchbar fuer kurze Aufnahmen wie den Drill).
async function audioBesorgen(
  anfrage: Request,
): Promise<{ audio: File; mitWortliste: boolean } | { fehler: string; status: number }> {
  const typ = anfrage.headers.get('content-type') ?? '';

  if (typ.includes('application/json')) {
    let koerper: Record<string, unknown>;
    try {
      koerper = await anfrage.json();
    } catch (e) {
      return { fehler: `Koerper unlesbar: ${e}`, status: 400 };
    }
    const pfad = String(koerper.pfad ?? '');
    if (!pfad) return { fehler: 'Feld "pfad" fehlt', status: 400 };

    const admin = adminClient();
    if (!admin) return { fehler: 'Kein Service-Key gesetzt', status: 500 };
    const { data, error } = await admin.storage.from(EINGANG).download(pfad);
    if (error || !data) {
      return { fehler: `Aufnahme nicht abrufbar: ${error?.message ?? 'unbekannt'}`, status: 404 };
    }
    if (data.size === 0) return { fehler: 'Die Aufnahme ist leer (0 Bytes)', status: 400 };

    return {
      audio: new File([data], pfad.split('/').pop() ?? 'durchsicht.webm', {
        type: data.type || 'audio/webm',
      }),
      mitWortliste: koerper.wortliste === 'ja',
    };
  }

  let form: FormData;
  try {
    form = await anfrage.formData();
  } catch (e) {
    return { fehler: `Formulardaten unlesbar: ${e}`, status: 400 };
  }
  const audio = form.get('audio');
  if (!(audio instanceof File)) return { fehler: 'Feld "audio" fehlt', status: 400 };
  if (audio.size === 0) return { fehler: 'Die Aufnahme ist leer (0 Bytes)', status: 400 };
  return { audio, mitWortliste: form.get('wortliste') === 'ja' };
}

Deno.serve(async (anfrage) => {
  if (anfrage.method === 'OPTIONS') return new Response('ok', { headers: KOPF });

  // Reihenfolge mit Absicht: Das Testwort kostet einen Zeichenvergleich, die
  // JWT-Pruefung einen Netzaufruf. Wer das Testwort mitschickt, zahlt den
  // Aufruf nicht.
  if (!testwortStimmt(anfrage) && !(await nutzerIstEingeloggt(anfrage))) {
    return antwort({ fehler: 'Nicht berechtigt: weder gültiges Testwort noch Anmeldung' }, 401);
  }

  const url = new URL(anfrage.url);
  const aktion = url.searchParams.get('aktion') ?? 'elevenlabs';

  // --- Selbstauskunft -------------------------------------------------------
  //
  // Beantwortet vor dem Feldtest die Frage, an der sonst der ganze Tag haengt:
  // stimmt das Testwort, und sind die Schluessel ueberhaupt gesetzt? Gibt NUR
  // ja/nein heraus, nie einen Wert.
  if (aktion === 'ping') {
    return antwort({
      bereit: true,
      schluessel: {
        elevenlabs: Boolean(Deno.env.get('ELEVENLABS_API_KEY')),
        assemblyai: Boolean(Deno.env.get('ASSEMBLYAI_API_KEY')),
        infomaniak: Boolean(Deno.env.get('INFOMANIAK_API_KEY')),
      },
      elevenlabsModell: Deno.env.get('ELEVENLABS_MODELL') ?? 'scribe_v2',
      infomaniakProdukt: Deno.env.get('INFOMANIAK_PRODUKT_ID') ?? '110469',
      // Ohne diese Auskunft ist von aussen nicht erkennbar, ob der App-Weg
      // ueberhaupt funktionieren KANN: Faellt die Service-Key-Wahl aus, weist
      // die Function jeden angemeldeten Nutzer mit 401 ab — ununterscheidbar
      // von einem falschen Testwort. Genau daran ist der erste Anlauf
      // gescheitert. Nur ja/nein, nie ein Wert.
      appWegBereit: Boolean(serviceKey()),
    });
  }

  // --- Upload-Ziel ausstellen -----------------------------------------------
  //
  // Gibt eine signierte Adresse heraus, die fuer GENAU EINEN Pfad gilt und
  // ablaeuft. Damit kann eine Seite ohne Login hochladen, ohne dass der Bucket
  // fuer irgendjemanden sonst offen waere.
  if (aktion === 'upload-ziel') {
    const admin = adminClient();
    if (!admin) return antwort({ fehler: 'Kein Service-Key gesetzt' }, 500);
    const name = saeubern(url.searchParams.get('dateiname') ?? 'aufnahme');
    const pfad = `${crypto.randomUUID()}/${name}`;
    const { data, error } = await admin.storage.from(EINGANG).createSignedUploadUrl(pfad);
    if (error || !data) {
      return antwort({ fehler: `Upload-Ziel fehlgeschlagen: ${error?.message ?? 'unbekannt'}` }, 500);
    }
    return antwort({ pfad: data.path, signedUrl: data.signedUrl, token: data.token });
  }

  // --- Durchgereichte Datei wieder wegraeumen -------------------------------
  //
  // Der Bucket ist eine Durchreiche, kein Archiv: Was ausgewertet ist, gehoert
  // geloescht. Ohne diesen Weg sammeln sich Tondateien an, die niemand mehr
  // braucht und die niemand sieht.
  if (aktion === 'aufraeumen') {
    const admin = adminClient();
    if (!admin) return antwort({ fehler: 'Kein Service-Key gesetzt' }, 500);
    let pfad = '';
    try {
      pfad = String(((await anfrage.json()) as Record<string, unknown>).pfad ?? '');
    } catch { /* leerer Koerper -> unten abgefangen */ }
    if (!pfad) return antwort({ fehler: 'Feld "pfad" fehlt' }, 400);
    const { error } = await admin.storage.from(EINGANG).remove([pfad]);
    return antwort({ geloescht: !error, fehler: error?.message });
  }

  // --- Stand eines laufenden Auftrags ---------------------------------------
  //
  // Steht VOR dem Beschaffen des Audios: dieser Aufruf traegt keines.
  const standVon = aktion.endsWith('-stand') ? aktion.slice(0, -6) : null;
  if (standVon) {
    if (!(standVon in MIT_AUFTRAG)) {
      return antwort({ fehler: `Unbekannter Anbieter "${standVon}"` }, 400);
    }
    const id = url.searchParams.get('id');
    if (!id) return antwort({ fehler: 'Parameter "id" fehlt' }, 400);
    return antwort(await MIT_AUFTRAG[standVon as MitAuftrag].stand(id));
  }

  const beschafft = await audioBesorgen(anfrage);
  if ('fehler' in beschafft) return antwort({ fehler: beschafft.fehler }, beschafft.status);
  const { audio, mitWortliste } = beschafft;

  // Synchron, weil ElevenLabs keine Auftragsnummer kennt. Steht bewusst in
  // einem EIGENEN Aufruf: laeuft er in den 150-s-Timeout, sind die bereits
  // gestarteten Auftraege der anderen davon unberuehrt.
  if (aktion === 'elevenlabs') {
    return antwort({
      mitWortliste,
      groesseBytes: audio.size,
      dateiname: audio.name,
      ergebnis: await elevenlabsTranskribieren(audio, mitWortliste),
    });
  }

  const startVon = aktion.endsWith('-start') ? aktion.slice(0, -6) : null;
  if (startVon && startVon in MIT_AUFTRAG) {
    const gestartet = await MIT_AUFTRAG[startVon as MitAuftrag].starten(audio, mitWortliste);
    return antwort({ mitWortliste, groesseBytes: audio.size, ...gestartet });
  }

  return antwort({ fehler: `Unbekannte Aktion "${aktion}"` }, 400);
});
