import {
  assemblyaiStand,
  assemblyaiStarten,
  elevenlabsTranskribieren,
  infomaniakStand,
  infomaniakStarten,
} from './anbieter.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// Der Service-Key wird nur zum PRUEFEN des Nutzer-JWT gebraucht, nie zum
// Lesen von Daten. Moderne Schluessel zuerst (D-87: die Legacy-Keys sind
// deaktiviert), Fallback fuer den Fall, dass nur der alte Name gesetzt ist.
function serviceKey(): string {
  const modern = Deno.env.get('SUPABASE_SECRET_KEYS');
  if (modern) return modern.split(',')[0].trim();
  return Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
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
    });
  }

  // --- Stand eines laufenden Auftrags ---------------------------------------
  //
  // Steht VOR dem Auslesen des Formulars: dieser Aufruf traegt kein Audio.
  const standVon = aktion.endsWith('-stand') ? aktion.slice(0, -6) : null;
  if (standVon) {
    if (!(standVon in MIT_AUFTRAG)) {
      return antwort({ fehler: `Unbekannter Anbieter "${standVon}"` }, 400);
    }
    const id = url.searchParams.get('id');
    if (!id) return antwort({ fehler: 'Parameter "id" fehlt' }, 400);
    return antwort(await MIT_AUFTRAG[standVon as MitAuftrag].stand(id));
  }

  let form: FormData;
  try {
    form = await anfrage.formData();
  } catch (e) {
    return antwort({ fehler: `Formulardaten unlesbar: ${e}` }, 400);
  }

  const audio = form.get('audio');
  if (!(audio instanceof File)) return antwort({ fehler: 'Feld "audio" fehlt' }, 400);
  if (audio.size === 0) return antwort({ fehler: 'Die Aufnahme ist leer (0 Bytes)' }, 400);

  const mitWortliste = form.get('wortliste') === 'ja';

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
