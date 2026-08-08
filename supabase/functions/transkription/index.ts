import { assemblyaiStand, assemblyaiStarten, elevenlabsTranskribieren } from './anbieter.ts';

// Die Testseite liegt oeffentlich auf GitHub Pages und hat keinen Login.
// Ohne diese Huerde koennte jeder Fremde auf Kosten des Betreibers
// transkribieren lassen. Das Testwort steht als Supabase-Secret.
function testwortStimmt(anfrage: Request): boolean {
  const erwartet = Deno.env.get('TRANSKRIPTION_TESTWORT');
  if (!erwartet) return false; // ohne gesetztes Geheimnis bleibt zu
  return anfrage.headers.get('x-testwort') === erwartet;
}

const KOPF = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'content-type, x-testwort',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Content-Type': 'application/json',
};

function antwort(koerper: unknown, status = 200): Response {
  return new Response(JSON.stringify(koerper), { status, headers: KOPF });
}

Deno.serve(async (anfrage) => {
  if (anfrage.method === 'OPTIONS') return new Response('ok', { headers: KOPF });

  if (!testwortStimmt(anfrage)) {
    return antwort({ fehler: 'Testwort fehlt oder stimmt nicht' }, 401);
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
      },
      elevenlabsModell: Deno.env.get('ELEVENLABS_MODELL') ?? 'scribe_v2',
    });
  }

  // --- Stand eines laufenden AssemblyAI-Auftrags ----------------------------
  //
  // Steht VOR dem Auslesen des Formulars: dieser Aufruf traegt kein Audio.
  if (aktion === 'assemblyai-stand') {
    const id = url.searchParams.get('id');
    if (!id) return antwort({ fehler: 'Parameter "id" fehlt' }, 400);
    return antwort(await assemblyaiStand(id));
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

  switch (aktion) {
    // Synchron, weil ElevenLabs keine Auftragsnummer kennt. Steht bewusst in
    // einem EIGENEN Aufruf: laeuft er in den 150-s-Timeout, ist der bereits
    // gestartete AssemblyAI-Auftrag davon unberuehrt.
    case 'elevenlabs':
      return antwort({
        mitWortliste,
        groesseBytes: audio.size,
        dateiname: audio.name,
        ergebnis: await elevenlabsTranskribieren(audio, mitWortliste),
      });

    case 'assemblyai-start': {
      const gestartet = await assemblyaiStarten(audio, mitWortliste);
      return antwort({ mitWortliste, groesseBytes: audio.size, ...gestartet });
    }

    default:
      return antwort({ fehler: `Unbekannte Aktion "${aktion}"` }, 400);
  }
});
