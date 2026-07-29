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

/// Ein Anbieter ist eine Funktion mit dieser Signatur — mehr nicht.
///
/// Der Vergleich soll beliebig erweiterbar sein, ohne dass der Eingang etwas
/// von einzelnen Diensten weiss. Fehler werden NICHT geworfen, sondern im
/// Transkript zurueckgegeben: Faellt ein Anbieter aus, sollen die anderen
/// trotzdem ein Ergebnis liefern.
export type Erkenner = (audio: Blob, mitWortliste: boolean) => Promise<Transkript>;

// --- ElevenLabs Scribe v2 ---------------------------------------------------
//
// Nimmt audio/webm und audio/opus ausdruecklich an (Formatliste geprueft) —
// der MediaRecorder-Ausgang geht ohne Umwandlung hinein.
//
// Keyterms kosten 20 % Aufschlag. Genau dieser Aufschlag steht hier zur
// Messung: bringt die Liste mehr, als sie kostet?
export const elevenlabs: Erkenner = async (audio, mitWortliste) => {
  const start = Date.now();
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

  const form = new FormData();
  form.append('file', audio, 'durchsicht.webm');
  form.append('model_id', 'scribe_v2');
  form.append('language_code', 'de');
  form.append('diarize', 'true');
  if (mitWortliste) form.append('keyterms', JSON.stringify(FACHWOERTER));

  try {
    const antwort = await fetch('https://api.elevenlabs.io/v1/speech-to-text', {
      method: 'POST',
      headers: { 'xi-api-key': schluessel },
      body: form,
    });
    const roh = await antwort.text();
    if (!antwort.ok) {
      return {
        anbieter: 'elevenlabs',
        modell: 'scribe_v2',
        text: '',
        dauerMs: Date.now() - start,
        fehler: `HTTP ${antwort.status}: ${roh.slice(0, 300)}`,
      };
    }
    const daten = JSON.parse(roh);
    return {
      anbieter: 'elevenlabs',
      modell: 'scribe_v2',
      text: daten.text ?? '',
      dauerMs: Date.now() - start,
    };
  } catch (e) {
    return {
      anbieter: 'elevenlabs',
      modell: 'scribe_v2',
      text: '',
      dauerMs: Date.now() - start,
      fehler: String(e),
    };
  }
};

// --- AssemblyAI Universal-3.5 Pro -------------------------------------------
//
// Zwei Schritte: Datei hochladen, dann Auftrag anlegen und pollen.
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
export const assemblyai: Erkenner = async (audio, mitWortliste) => {
  const start = Date.now();
  const schluessel = Deno.env.get('ASSEMBLYAI_API_KEY');
  if (!schluessel) {
    return {
      anbieter: 'assemblyai',
      modell: '—',
      text: '',
      dauerMs: 0,
      fehler: 'ASSEMBLYAI_API_KEY ist nicht gesetzt',
    };
  }
  const kopf = { 'Authorization': schluessel }; // Falle 3: ohne 'Bearer'

  try {
    // Der Upload verlangt den rohen Datenstrom. Ein JSON-Koerper liefert eine
    // gueltige upload_url, scheitert aber spaeter mit 'Transcoding failed'.
    const hoch = await fetch('https://api.eu.assemblyai.com/v2/upload', {
      method: 'POST',
      headers: kopf,
      body: audio,
    });
    if (!hoch.ok) {
      return {
        anbieter: 'assemblyai',
        modell: 'universal-3-5-pro',
        text: '',
        dauerMs: Date.now() - start,
        fehler: `Upload HTTP ${hoch.status}`,
      };
    }
    const { upload_url } = await hoch.json();

    const auftragKoerper: Record<string, unknown> = {
      audio_url: upload_url,
      language_code: 'de', // Falle 1
      speech_models: ['universal-3-5-pro', 'universal-2'], // Falle 2
      speaker_labels: true,
    };
    if (mitWortliste) auftragKoerper.keyterms_prompt = FACHWOERTER;

    const auftrag = await fetch('https://api.eu.assemblyai.com/v2/transcript', {
      method: 'POST',
      headers: { ...kopf, 'Content-Type': 'application/json' },
      body: JSON.stringify(auftragKoerper),
    });
    const roh = await auftrag.text();
    if (!auftrag.ok) {
      return {
        anbieter: 'assemblyai',
        modell: 'universal-3-5-pro',
        text: '',
        dauerMs: Date.now() - start,
        fehler: `Auftrag HTTP ${auftrag.status}: ${roh.slice(0, 300)}`,
      };
    }
    const { id } = JSON.parse(roh);

    // Pollen, hoechstens zwei Minuten. Fuer den Test genuegt das; im
    // Produktivbau kommt an diese Stelle ein Webhook.
    for (let i = 0; i < 60; i++) {
      await new Promise((f) => setTimeout(f, 2000));
      const stand = await fetch(`https://api.eu.assemblyai.com/v2/transcript/${id}`, {
        headers: kopf,
      });
      const d = await stand.json();
      if (d.status === 'completed') {
        return {
          anbieter: 'assemblyai',
          // Was TATSAECHLICH lief — siehe Falle 2.
          modell: d.speech_model_used ?? 'universal-3-5-pro',
          text: d.text ?? '',
          dauerMs: Date.now() - start,
        };
      }
      if (d.status === 'error') {
        return {
          anbieter: 'assemblyai',
          modell: 'universal-3-5-pro',
          text: '',
          dauerMs: Date.now() - start,
          fehler: d.error ?? 'unbekannt',
        };
      }
    }
    return {
      anbieter: 'assemblyai',
      modell: 'universal-3-5-pro',
      text: '',
      dauerMs: Date.now() - start,
      fehler: 'Zeitüberschreitung nach 2 Minuten',
    };
  } catch (e) {
    return {
      anbieter: 'assemblyai',
      modell: 'universal-3-5-pro',
      text: '',
      dauerMs: Date.now() - start,
      fehler: String(e),
    };
  }
};

export const ERKENNER: Record<string, Erkenner> = { elevenlabs, assemblyai };
