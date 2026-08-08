import { FACHWOERTER } from './fachwoerter.ts';

/// Was jeder Anbieter zurueckgeben muss. Bewusst schmal: alles, was die
/// Auswertung braucht, und nichts darueber hinaus.
export interface Transkript {
  anbieter: string;
  modell: string;
  text: string;
  dauerMs: number; // wie lange der Dienst gebraucht hat
  fehler?: string; // gesetzt, wenn der Aufruf misslang
}

// --- Warum zwei Phasen statt eines Aufrufs ----------------------------------
//
// Supabase bricht eine Edge Function nach 150 s mit 504 ab, wenn bis dahin
// keine Antwort steht (Antwort-Timeout, gilt auch im Pro-Tarif; nur die Wall
// clock ist dort groesser). Der urspruengliche Entwurf pollte AssemblyAI bis
// zu 120 s INNERHALB des Aufrufs und wartete zugleich auf ElevenLabs — bei der
// Zwoelf-Minuten-Aufnahme, die das Vollstaendigkeitsurteil ueberhaupt erst
// moeglich macht, laeuft das in die Grenze.
//
// Deshalb: AssemblyAI wird nur GESTARTET (Upload + Auftrag, wenige Sekunden)
// und gibt seine Auftragsnummer heraus; die Seite fragt den Stand danach in
// eigenen, kurzen Aufrufen ab. Zustand haelt AssemblyAI selbst — es braucht
// dafuer weder Tabelle noch Migration.
//
// ElevenLabs bleibt synchron, weil es keine Auftragsnummer kennt. Der Aufruf
// steht deshalb FUER SICH: faellt er in die Zeitgrenze, laeuft AssemblyAI
// trotzdem weiter. Genau dafuer sind die Aufrufe getrennt.

// --- ElevenLabs Scribe ------------------------------------------------------
//
// Nimmt audio/webm und audio/opus ausdruecklich an (Formatliste geprueft) —
// der MediaRecorder-Ausgang geht ohne Umwandlung hinein. Die Aufnahmen der
// Natel-Sprachmemo (m4a/aac) ebenso; deshalb wird der ECHTE Dateiname
// weitergereicht und nicht mehr 'durchsicht.webm' behauptet. Ein falscher
// Name kann den Dienst auf das falsche Format schliessen lassen.
//
// Keyterms kosten 20 % Aufschlag. Genau dieser Aufschlag steht hier zur
// Messung: bringt die Liste mehr, als sie kostet?
//
// Die Modellkennung ist ueberschreibbar (Secret ELEVENLABS_MODELL). Grund:
// Kennungen aendern sich mit neuen Generationen, und ein Tippfehler darin
// waere sonst nur mit einem neuen Deploy zu heilen — mitten im Feldtest der
// falsche Moment.
export async function elevenlabsTranskribieren(
  audio: File,
  mitWortliste: boolean,
): Promise<Transkript> {
  const start = Date.now();
  const modell = Deno.env.get('ELEVENLABS_MODELL') ?? 'scribe_v2';
  const schluessel = Deno.env.get('ELEVENLABS_API_KEY');
  if (!schluessel) {
    return {
      anbieter: 'elevenlabs',
      modell: '—',
      text: '',
      dauerMs: 0,
      fehler: 'ELEVENLABS_API_KEY ist nicht gesetzt',
    };
  }

  // Ein Versuch, mit oder ohne Fachwortliste.
  //
  // Die Liste geht als WIEDERHOLTES Feld hinein, ein Eintrag je Begriff. Der
  // erste Anlauf schickte sie als einen JSON-String — ElevenLabs las das als
  // EIN Stichwort von rund 400 Zeichen und antwortete:
  // "All keywords must be less than 50 characters." In multipart/form-data
  // ist das wiederholte Feld die uebliche Schreibweise fuer eine Liste.
  const versuch = async (mitListe: boolean) => {
    const form = new FormData();
    form.append('file', audio, audio.name || 'durchsicht.webm');
    form.append('model_id', modell);
    form.append('language_code', 'de');
    form.append('diarize', 'true');
    if (mitListe) {
      for (const begriff of FACHWOERTER) form.append('keyterms', begriff);
    }
    const antwort = await fetch('https://api.elevenlabs.io/v1/speech-to-text', {
      method: 'POST',
      headers: { 'xi-api-key': schluessel },
      body: form,
    });
    return { ok: antwort.ok, status: antwort.status, roh: await antwort.text() };
  };

  try {
    let a = await versuch(mitWortliste);

    // Rueckfallebene: Weist der Dienst die Wortliste zurueck, wird OHNE sie
    // erneut versucht. Die Liste ist eine Verbesserung, keine Voraussetzung —
    // ein Transkript ohne Boost ist unendlich viel besser als keines. Genau
    // dieser Fall hat den ersten Feldversuch blockiert.
    if (!a.ok && mitWortliste && a.status === 400 && a.roh.includes('keyword')) {
      a = await versuch(false);
      if (a.ok) {
        const daten = JSON.parse(a.roh);
        return {
          anbieter: 'elevenlabs',
          // Im Modellnamen sichtbar machen, dass ohne Liste gemessen wurde —
          // sonst vergleicht man spaeter Ergebnisse, die nicht vergleichbar sind.
          modell: `${modell} (ohne Wortliste)`,
          text: daten.text ?? '',
          dauerMs: Date.now() - start,
        };
      }
    }

    if (!a.ok) {
      return {
        anbieter: 'elevenlabs',
        modell,
        text: '',
        dauerMs: Date.now() - start,
        fehler: `HTTP ${a.status}: ${a.roh.slice(0, 300)}`,
      };
    }
    const daten = JSON.parse(a.roh);
    return {
      anbieter: 'elevenlabs',
      modell,
      text: daten.text ?? '',
      dauerMs: Date.now() - start,
    };
  } catch (e) {
    return {
      anbieter: 'elevenlabs',
      modell,
      text: '',
      dauerMs: Date.now() - start,
      fehler: String(e),
    };
  }
}

// --- AssemblyAI Universal-3.5 Pro -------------------------------------------
//
// DREI FALLEN, die die Gegenpruefung der Marktrecherche zutage gefoerdert hat.
// Alle drei sind still — sie werfen keinen Fehler, sie liefern ein falsches
// Ergebnis:
//
//  1. language_code hat den Standardwert 'en_us'. Wer ihn weglaesst, laesst
//     deutsches Audio als ENGLISCH transkribieren.
//  2. speech_models muss explizit gesetzt werden. Der Standard ist ein anderes
//     Modell als das hier gemeinte, und er unterscheidet sich zwischen Gratis-
//     und Bezahlkonto. Das Antwortfeld speech_model_used sagt, was wirklich lief.
//  3. Der Authorization-Header traegt KEIN 'Bearer' — laut Anbieter der
//     haeufigste Fehler ueberhaupt.
//
// Der EU-Endpunkt kostet dasselbe wie der amerikanische und braucht keine
// Freischaltung; deshalb steht er hier von Anfang an.
const AAI = 'https://api.eu.assemblyai.com/v2';

function aaiKopf(): Record<string, string> | null {
  const schluessel = Deno.env.get('ASSEMBLYAI_API_KEY');
  if (!schluessel) return null;
  return { 'Authorization': schluessel }; // Falle 3: ohne 'Bearer'
}

/// Laedt hoch und legt den Auftrag an. Gibt die Auftragsnummer heraus, ohne
/// auf das Ergebnis zu warten.
export async function assemblyaiStarten(
  audio: File,
  mitWortliste: boolean,
): Promise<{ id?: string; fehler?: string }> {
  const kopf = aaiKopf();
  if (!kopf) return { fehler: 'ASSEMBLYAI_API_KEY ist nicht gesetzt' };

  try {
    // Der Upload verlangt den rohen Datenstrom. Ein JSON-Koerper liefert eine
    // gueltige upload_url, scheitert aber spaeter mit 'Transcoding failed'.
    const hoch = await fetch(`${AAI}/upload`, {
      method: 'POST',
      headers: kopf,
      body: audio,
    });
    if (!hoch.ok) {
      return { fehler: `Upload HTTP ${hoch.status}: ${(await hoch.text()).slice(0, 300)}` };
    }
    const { upload_url } = await hoch.json();

    const koerper: Record<string, unknown> = {
      audio_url: upload_url,
      language_code: 'de', // Falle 1
      speech_models: ['universal-3-5-pro', 'universal-2'], // Falle 2
      speaker_labels: true,
    };
    if (mitWortliste) koerper.keyterms_prompt = FACHWOERTER;

    const auftrag = await fetch(`${AAI}/transcript`, {
      method: 'POST',
      headers: { ...kopf, 'Content-Type': 'application/json' },
      body: JSON.stringify(koerper),
    });
    const roh = await auftrag.text();
    if (!auftrag.ok) {
      return { fehler: `Auftrag HTTP ${auftrag.status}: ${roh.slice(0, 300)}` };
    }
    return { id: JSON.parse(roh).id };
  } catch (e) {
    return { fehler: String(e) };
  }
}

/// Fragt den Stand eines laufenden Auftrags ab. `fertig` sagt, ob weiter
/// gefragt werden muss — bei einem Fehler steht es ebenfalls auf true, sonst
/// fragte die Seite endlos nach.
export async function assemblyaiStand(
  id: string,
): Promise<Transkript & { fertig: boolean; status: string }> {
  const kopf = aaiKopf();
  const grund = {
    anbieter: 'assemblyai',
    modell: 'universal-3-5-pro',
    text: '',
    dauerMs: 0,
  };
  if (!kopf) {
    return { ...grund, fertig: true, status: 'error', fehler: 'ASSEMBLYAI_API_KEY ist nicht gesetzt' };
  }

  try {
    const stand = await fetch(`${AAI}/transcript/${id}`, { headers: kopf });
    if (!stand.ok) {
      return {
        ...grund,
        fertig: true,
        status: 'error',
        fehler: `Stand HTTP ${stand.status}: ${(await stand.text()).slice(0, 300)}`,
      };
    }
    const d = await stand.json();
    if (d.status === 'completed') {
      return {
        anbieter: 'assemblyai',
        // Was TATSAECHLICH lief — siehe Falle 2.
        modell: d.speech_model_used ?? 'universal-3-5-pro',
        text: d.text ?? '',
        dauerMs: 0, // die Seite misst die Wanduhr, hier gibt es keine
        fertig: true,
        status: 'completed',
      };
    }
    if (d.status === 'error') {
      return { ...grund, fertig: true, status: 'error', fehler: d.error ?? 'unbekannt' };
    }
    // queued | processing
    return { ...grund, fertig: false, status: d.status ?? 'unbekannt' };
  } catch (e) {
    return { ...grund, fertig: true, status: 'error', fehler: String(e) };
  }
}

// --- Infomaniak, Whisper in der Schweiz -------------------------------------
//
// Kam aus dem Schwesterprojekt (Heineken, ADR-0004 vom 31.07.2026), wo dieser
// Weg bereits produktiv laeuft. Im Marktvergleich dieses Projekts fehlte er:
// dort stand nur "Whisper selbst betrieben" — verworfen, weil es eigene Server
// braucht. Whisper BETRIEBEN VON einem Schweizer Anbieter war nie geprueft.
//
// Warum er hier antritt: Datenschutz war laut D-98a das eigentliche Kriterium
// (dafuer wurde damals Azure Switzerland North gewaehlt). Infomaniak liefert
// die Schweizer Verarbeitung ohne Azures Ballast — Inhalte werden nicht
// gespeichert, kein CLOUD Act, ISO 27001. Kosten CHF 0.006/min: bei den 20
// Jahresstunden aus D-98a rund sieben Franken im Jahr.
//
// ZWEI DINGE, die dieser Test eigens beantworten muss:
//
//  1. Whisper HALLUZINIERT BEI STILLE — im eigenen Marktvergleich vermerkt.
//     Eine Durchsicht ist genau der ungeeignete Fall: fuenfzehn Minuten mit
//     langen Arbeitspausen. Beim Nachlesen deshalb gezielt auf erfundene
//     Saetze in den Pausen achten, nicht nur auf Verhoerer.
//  2. Whisper kennt KEINE Sprechertrennung. ElevenLabs (diarize) und
//     AssemblyAI (speaker_labels) liefern sie; hier reden Daniel und Lorena
//     ohne Zuordnung in einem Fluss.
//
// Der Glossar-Parameter ist Whispers `prompt` — dieselbe Rolle wie keyterms
// bei den anderen beiden, aber auf 224 Token begrenzt. Die Fachwortliste
// bleibt darunter; sie enthaelt nach D-99d bewusst keine Seuchenbegriffe.
const GLOSSAR = 'Diktat einer Durchsicht am Bienenvolk (Imkerei). Fachbegriffe: '
  + FACHWOERTER.join(', ') + '.';

function imKopf(): { token: string; basis: string } | null {
  const token = Deno.env.get('INFOMANIAK_API_KEY');
  if (!token) return null;
  // Die Produkt-ID gehoert zum Konto. Als Secret ueberschreibbar, damit ein
  // anderes Konto keinen Deploy erzwingt.
  const produkt = Deno.env.get('INFOMANIAK_PRODUKT_ID') ?? '110469';
  return { token, basis: `https://api.infomaniak.com/1/ai/${produkt}` };
}

/// Laedt hoch und legt den Auftrag an. Die Route ist von Haus aus asynchron
/// (Batch-ID), passt also ohne Umweg in das Zwei-Phasen-Muster.
export async function infomaniakStarten(
  audio: File,
  mitWortliste: boolean,
): Promise<{ id?: string; fehler?: string }> {
  const k = imKopf();
  if (!k) return { fehler: 'INFOMANIAK_API_KEY ist nicht gesetzt' };

  const form = new FormData();
  form.append('file', audio, audio.name || 'durchsicht.webm');
  form.append('model', 'whisper');
  form.append('language', 'de');
  if (mitWortliste) form.append('prompt', GLOSSAR);

  try {
    const start = await fetch(`${k.basis}/openai/audio/transcriptions`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${k.token}` },
      body: form,
    });
    const roh = await start.text();
    if (!start.ok) {
      return { fehler: `HTTP ${start.status}: ${roh.slice(0, 300)}` };
    }
    const { batch_id } = JSON.parse(roh);
    if (!batch_id) return { fehler: 'Keine Batch-ID erhalten' };
    return { id: String(batch_id) };
  } catch (e) {
    return { fehler: String(e) };
  }
}

/// Fragt den Stand ab. Das Ergebnis kommt als JSON-Zeichenkette im Feld `data`
/// — deshalb der zweite Auspackschritt.
export async function infomaniakStand(
  id: string,
): Promise<Transkript & { fertig: boolean; status: string }> {
  const k = imKopf();
  const grund = { anbieter: 'infomaniak', modell: 'whisper', text: '', dauerMs: 0 };
  if (!k) {
    return { ...grund, fertig: true, status: 'error', fehler: 'INFOMANIAK_API_KEY ist nicht gesetzt' };
  }

  try {
    const a = await fetch(`${k.basis}/results/${id}`, {
      headers: { Authorization: `Bearer ${k.token}` },
    });
    if (!a.ok) {
      return {
        ...grund,
        fertig: true,
        status: 'error',
        fehler: `Stand HTTP ${a.status}: ${(await a.text()).slice(0, 300)}`,
      };
    }
    const stand = await a.json();
    if (stand.status === 'success') {
      let text = '';
      try {
        text = (typeof stand.data === 'string' ? JSON.parse(stand.data) : stand.data)?.text ?? '';
      } catch {
        return { ...grund, fertig: true, status: 'error', fehler: 'Ergebnis unlesbar' };
      }
      return { ...grund, text: String(text).trim(), fertig: true, status: 'completed' };
    }
    if (stand.status === 'error' || stand.result === 'error') {
      return { ...grund, fertig: true, status: 'error', fehler: stand.message ?? 'Erkennung fehlgeschlagen' };
    }
    return { ...grund, fertig: false, status: stand.status ?? 'unbekannt' };
  } catch (e) {
    return { ...grund, fertig: true, status: 'error', fehler: String(e) };
  }
}
