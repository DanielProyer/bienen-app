# Erkenner-Vergleich — Implementierungsplan

> **Für agentische Ausführung:** ERFORDERLICHE SUB-SKILL: `superpowers:subagent-driven-development`
> (empfohlen) oder `superpowers:executing-plans`. Schritte nutzen Kästchen (`- [ ]`) zur Nachverfolgung.

**Ziel:** Belastbar messen, welcher Erkennungsdienst die Imkerei-Fachsprache dieses Betriebs am besten
versteht — **bevor** eine Zeile des Tonmitschnitts gebaut wird.

**Architektur:** Eine Edge Function kapselt beliebig viele Anbieter hinter *einer* Schnittstelle. Eine
eigenständige Vergleichsseite nimmt auf, schickt dieselbe Aufnahme an alle Anbieter und stellt die
Transkripte nebeneinander. Die Auswertung misst zuerst **Vollständigkeit**, dann **Fachbegriff-Treffer**.

**Tech-Stack:** Supabase Edge Function (Deno/TypeScript), statische Testseite (HTML/JS) unter `web/`,
Anbieter ElevenLabs Scribe v2 und AssemblyAI Universal-3.5 Pro.

---

## Warum dieser Plan vor dem Bau kommt

Aus der Marktrecherche (`assets/recherche/31_Spracherkennung_Marktvergleich.md`) und den Entscheiden
D-99 bis D-99e ergeben sich drei Gründe:

1. **Für Deutsch existiert bei keinem Anbieter eine unabhängige Fehlerrate.** Alle vergleichbaren
   Messungen sind englischsprachig. Die eigene Messung ist die beste verfügbare Datenquelle.
2. **Die Wirksamkeit der Fachwortlisten ist für keine Sprache quantifiziert.** Dass eine Liste
   existiert, ist belegt; dass sie „Weiselzellen" rettet, ist Annahme.
3. **Vollständigkeit ist nicht selbstverständlich.** Die OpenAI-4o-Modelle schneiden nach acht bis neun
   Minuten still ab. Ein Modell, das nach neun Minuten aufhört, braucht man auf Genauigkeit nicht zu
   messen — deshalb steht dieser Test **vor** allen anderen.

**Was dieser Plan NICHT tut:** Er baut nichts an der App. Keine Migration, keine Tabelle, kein UI in der
Durchsicht. Alles davon hängt vom Ergebnis ab.

---

## Voraussetzung, die nur der Betreiber erfüllen kann

Vor Task 2 müssen zwei Schlüssel als Supabase-Secrets gesetzt sein. **Der Betreiber setzt sie selbst;
sie erscheinen nie im Chat, nie im Repo, nie im Client.**

```bash
supabase secrets set ELEVENLABS_API_KEY=... --project-ref dcdcohktxbhdxnxjvcyp
```

```bash
supabase secrets set ASSEMBLYAI_API_KEY=... --project-ref dcdcohktxbhdxnxjvcyp
```

```bash
supabase secrets set TRANSKRIPTION_TESTWORT=... --project-ref dcdcohktxbhdxnxjvcyp
```

Das dritte Geheimnis ist ein frei gewähltes Wort. Es schützt die Function davor, dass Fremde sie über
die öffentliche Pages-URL auf Kosten des Betreibers benutzen — die Testseite hat keinen Login.

Beide Anbieter haben Startguthaben: AssemblyAI 50 USD ohne Kreditkarte, ElevenLabs ein kostenloses
Kontingent. Der gesamte Test kostet weniger als einen Franken.

---

## Dateien

| Datei | Verantwortung |
|---|---|
| `supabase/functions/transkription/index.ts` | HTTP-Eingang, Testwort-Prüfung, Anbieterauswahl |
| `supabase/functions/transkription/anbieter.ts` | Ein Anbieter = eine Funktion mit gleicher Signatur |
| `supabase/functions/transkription/fachwoerter.ts` | Die Wortliste, an einer Stelle gepflegt |
| `web/erkennervergleich.html` | Aufnahme, Versand, Gegenüberstellung, Auswertung |
| `test/sprache/fachwort_treffer_test.dart` | Auswertungslogik als reine Dart-Funktion |
| `lib/features/durchsicht/sprache/domain/fachwort_treffer.dart` | dieselbe Logik, später in der App wiederverwendbar |

**Warum die Auswertung in Dart und nicht nur im Browser:** Die Trefferzählung wird später in der App
gebraucht, um zu erkennen, welche Begriffe wiederholt danebenliegen. Sie hier als reine, getestete
Funktion zu schreiben, spart den zweiten Bau — und macht sie testbar, was im HTML nicht der Fall wäre.

---

## Task 1: Fachwortliste als reine Datei

**Dateien:**
- Erstellen: `supabase/functions/transkription/fachwoerter.ts`

- [ ] **Schritt 1: Datei anlegen**

```typescript
// Fachvokabular der Imkerei, das Standardmodelle verhoeren.
//
// Zwei Begriffsgruppen fehlen hier BEWUSST (Entscheid D-99d):
//
//  * Seuchen (Faulbrut, Sauerbrut, Amerikanische Faulbrut, Nosema): Wortlisten
//    koennen Begriffe EINFUEGEN, die nie gesagt wurden. Ein halluzinierter
//    Seuchenbefund im vorbefuellten Formular waere gravierender als ein
//    fehlender. Diese Begriffe loest die Sprachmodell-Stufe aus dem Kontext.
//
//  * Alltagswoerter mit imkerlicher Sonderbedeutung (Beute, Windel, Stifte,
//    Schied, Rahmen): regulaere deutsche Woerter. Sie zu boosten erzeugt
//    Uebererkennung im uebrigen Text.
//
// Die Liste ist bewusst kurz. Die Anbieter empfehlen 20-50 Begriffe; mehr
// verschlechtert laut Google die Erkennung der NICHT geboosteten Woerter.
export const FACHWOERTER: string[] = [
  'Varroa',
  'Varroamilbe',
  'Milben',
  'Weiselzellen',
  'Weiselrichtigkeit',
  'weiselrichtig',
  'weisellos',
  'Drohnenbrut',
  'Drohnenrahmen',
  'Schwarmtrieb',
  'Schwarmzellen',
  'Ableger',
  'Kunstschwarm',
  'Dadant',
  'Zander',
  'Mittelwand',
  'Absperrgitter',
  'Honigraum',
  'Brutraum',
  'Wabengasse',
  'Gemüll',
  'Ameisensäure',
  'Oxalsäure',
  'Sublimation',
  'Trachtende',
  'Räuberei',
  'Kalkbrut',
  'Buckfast',
  'Bienenflucht',
  'Futterteig',
];

/// Die Begriffe, an denen der Feldtest gescheitert ist. Sie werden in der
/// Auswertung eigens ausgewiesen, weil an ihnen der Nutzen des Verfahrens
/// haengt — nicht an der Gesamtfehlerrate.
export const PRUEFBEGRIFFE: string[] = [
  'Weiselzellen',
  'Milben',
  'Schwarmtrieb',
  'Drohnenbrut',
  'Varroa',
  'Ableger',
];
```

- [ ] **Schritt 2: Committen**

```bash
git add supabase/functions/transkription/fachwoerter.ts
git commit -m "Erkenner-Vergleich: Fachwortliste, ohne Seuchen- und Alltagsbegriffe"
```

---

## Task 2: Anbieter-Modul mit einheitlicher Signatur

**Dateien:**
- Erstellen: `supabase/functions/transkription/anbieter.ts`

Beide Anbieter nehmen `webm/opus` direkt an — das ist verifiziert und der Grund, warum genau diese
beiden im Test stehen. Es wird also nichts umgewandelt.

- [ ] **Schritt 1: Datei anlegen**

```typescript
import { FACHWOERTER } from './fachwoerter.ts';

/// Was jeder Anbieter zurueckgeben muss. Bewusst schmal: alles, was die
/// Auswertung braucht, und nichts darueber hinaus.
export interface Transkript {
  anbieter: string;
  modell: string;
  text: string;
  dauerMs: number;      // wie lange der Dienst gebraucht hat
  fehler?: string;      // gesetzt, wenn der Aufruf misslang
}

export type Erkenner = (audio: Blob, mitWortliste: boolean) => Promise<Transkript>;

// --- ElevenLabs Scribe v2 ---------------------------------------------------
//
// Nimmt audio/webm und audio/opus ausdruecklich an (Formatliste geprueft).
// Keyterms kosten 20 % Aufschlag; genau dieser Aufschlag steht hier zur
// Messung: bringt die Liste mehr, als sie kostet?
export const elevenlabs: Erkenner = async (audio, mitWortliste) => {
  const start = Date.now();
  const schluessel = Deno.env.get('ELEVENLABS_API_KEY');
  if (!schluessel) {
    return { anbieter: 'elevenlabs', modell: '—', text: '', dauerMs: 0,
             fehler: 'ELEVENLABS_API_KEY ist nicht gesetzt' };
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
      return { anbieter: 'elevenlabs', modell: 'scribe_v2', text: '',
               dauerMs: Date.now() - start, fehler: `HTTP ${antwort.status}: ${roh.slice(0, 300)}` };
    }
    const daten = JSON.parse(roh);
    return { anbieter: 'elevenlabs', modell: 'scribe_v2', text: daten.text ?? '',
             dauerMs: Date.now() - start };
  } catch (e) {
    return { anbieter: 'elevenlabs', modell: 'scribe_v2', text: '',
             dauerMs: Date.now() - start, fehler: String(e) };
  }
};

// --- AssemblyAI Universal-3.5 Pro -------------------------------------------
//
// Zwei Schritte: Datei hochladen, dann Auftrag anlegen und pollen.
//
// DREI FALLEN, die die Gegenpruefung der Recherche zutage gefoerdert hat:
//  1. language_code hat den Standardwert 'en_us'. Wer ihn weglaesst, laesst
//     deutsches Audio als ENGLISCH transkribieren.
//  2. speech_models muss explizit gesetzt werden. Der Standard ist ein anderes
//     Modell als das hier gemeinte, und er unterscheidet sich zwischen
//     Gratis- und Bezahlkonto.
//  3. Der Authorization-Header traegt KEIN 'Bearer' — laut Anbieter der
//     haeufigste Fehler ueberhaupt.
export const assemblyai: Erkenner = async (audio, mitWortliste) => {
  const start = Date.now();
  const schluessel = Deno.env.get('ASSEMBLYAI_API_KEY');
  if (!schluessel) {
    return { anbieter: 'assemblyai', modell: '—', text: '', dauerMs: 0,
             fehler: 'ASSEMBLYAI_API_KEY ist nicht gesetzt' };
  }
  const kopf = { 'Authorization': schluessel };   // ohne 'Bearer'

  try {
    // Der Upload verlangt den rohen Datenstrom, kein JSON.
    const hoch = await fetch('https://api.eu.assemblyai.com/v2/upload', {
      method: 'POST', headers: kopf, body: audio,
    });
    if (!hoch.ok) {
      return { anbieter: 'assemblyai', modell: 'universal-3-5-pro', text: '',
               dauerMs: Date.now() - start, fehler: `Upload HTTP ${hoch.status}` };
    }
    const { upload_url } = await hoch.json();

    const auftragKoerper: Record<string, unknown> = {
      audio_url: upload_url,
      language_code: 'de',                          // Falle 1
      speech_models: ['universal-3-5-pro', 'universal-2'],   // Falle 2
      speaker_labels: true,
    };
    if (mitWortliste) auftragKoerper.keyterms_prompt = FACHWOERTER;

    const auftrag = await fetch('https://api.eu.assemblyai.com/v2/transcript', {
      method: 'POST', headers: { ...kopf, 'Content-Type': 'application/json' },
      body: JSON.stringify(auftragKoerper),
    });
    const roh = await auftrag.text();
    if (!auftrag.ok) {
      return { anbieter: 'assemblyai', modell: 'universal-3-5-pro', text: '',
               dauerMs: Date.now() - start, fehler: `Auftrag HTTP ${auftrag.status}: ${roh.slice(0, 300)}` };
    }
    const { id } = JSON.parse(roh);

    // Pollen, hoechstens zwei Minuten. Fuer den Test genuegt das; im Produktivbau
    // kommt ein Webhook an diese Stelle.
    for (let i = 0; i < 60; i++) {
      await new Promise((f) => setTimeout(f, 2000));
      const stand = await fetch(`https://api.eu.assemblyai.com/v2/transcript/${id}`, { headers: kopf });
      const d = await stand.json();
      if (d.status === 'completed') {
        return { anbieter: 'assemblyai', modell: d.speech_model_used ?? 'universal-3-5-pro',
                 text: d.text ?? '', dauerMs: Date.now() - start };
      }
      if (d.status === 'error') {
        return { anbieter: 'assemblyai', modell: 'universal-3-5-pro', text: '',
                 dauerMs: Date.now() - start, fehler: d.error ?? 'unbekannt' };
      }
    }
    return { anbieter: 'assemblyai', modell: 'universal-3-5-pro', text: '',
             dauerMs: Date.now() - start, fehler: 'Zeitüberschreitung nach 2 Minuten' };
  } catch (e) {
    return { anbieter: 'assemblyai', modell: 'universal-3-5-pro', text: '',
             dauerMs: Date.now() - start, fehler: String(e) };
  }
};

export const ERKENNER: Record<string, Erkenner> = { elevenlabs, assemblyai };
```

- [ ] **Schritt 2: Committen**

```bash
git add supabase/functions/transkription/anbieter.ts
git commit -m "Erkenner-Vergleich: zwei Anbieter hinter einer Signatur"
```

---

## Task 3: Edge Function als Eingang

**Dateien:**
- Erstellen: `supabase/functions/transkription/index.ts`

- [ ] **Schritt 1: Datei anlegen**

```typescript
import { ERKENNER, Transkript } from './anbieter.ts';

// Die Testseite liegt oeffentlich auf GitHub Pages und hat keinen Login.
// Ohne diese Huerde koennte jeder Fremde auf Kosten des Betreibers
// transkribieren lassen. Das Testwort steht als Supabase-Secret.
function testwortStimmt(anfrage: Request): boolean {
  const erwartet = Deno.env.get('TRANSKRIPTION_TESTWORT');
  if (!erwartet) return false;   // ohne gesetztes Geheimnis bleibt zu
  return anfrage.headers.get('x-testwort') === erwartet;
}

const KOPF = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'content-type, x-testwort',
  'Content-Type': 'application/json',
};

Deno.serve(async (anfrage) => {
  if (anfrage.method === 'OPTIONS') return new Response('ok', { headers: KOPF });

  if (!testwortStimmt(anfrage)) {
    return new Response(JSON.stringify({ fehler: 'Testwort fehlt oder stimmt nicht' }),
      { status: 401, headers: KOPF });
  }

  const form = await anfrage.formData();
  const audio = form.get('audio');
  if (!(audio instanceof File)) {
    return new Response(JSON.stringify({ fehler: 'Feld "audio" fehlt' }),
      { status: 400, headers: KOPF });
  }
  const mitWortliste = form.get('wortliste') === 'ja';
  const gewuenscht = String(form.get('anbieter') ?? '').split(',').filter(Boolean);
  const namen = gewuenscht.length ? gewuenscht : Object.keys(ERKENNER);

  // Alle Anbieter gleichzeitig — sonst wartet der Nutzer doppelt so lang.
  const ergebnisse: Transkript[] = await Promise.all(
    namen.map((n) =>
      ERKENNER[n]
        ? ERKENNER[n](audio, mitWortliste)
        : Promise.resolve({ anbieter: n, modell: '—', text: '', dauerMs: 0,
                            fehler: 'unbekannter Anbieter' })
    )
  );

  return new Response(JSON.stringify({
    mitWortliste,
    groesseBytes: audio.size,
    ergebnisse,
  }), { headers: KOPF });
});
```

- [ ] **Schritt 2: Ausrollen**

```bash
supabase functions deploy transkription --project-ref dcdcohktxbhdxnxjvcyp
```

- [ ] **Schritt 3: Absicherung prüfen — ohne Testwort muss sie zumachen**

```bash
curl -s -o /dev/null -w "%{http_code}\n" -X POST "https://dcdcohktxbhdxnxjvcyp.supabase.co/functions/v1/transkription"
```

Erwartet: `401`

- [ ] **Schritt 4: Committen**

```bash
git add supabase/functions/transkription/index.ts
git commit -m "Erkenner-Vergleich: Edge Function mit Testwort-Schutz"
```

---

## Task 4: Trefferzählung als reine Dart-Funktion (TDD)

**Dateien:**
- Erstellen: `lib/features/durchsicht/sprache/domain/fachwort_treffer.dart`
- Test: `test/sprache/fachwort_treffer_test.dart`

Diese Funktion beantwortet die eigentliche Frage des Tests: **Wie viele der erwarteten Fachbegriffe
stehen im Transkript?** Sie wird später in der App wiederverwendet, um wiederholte Verhörer zu erkennen.

- [ ] **Schritt 1: Fehlschlagenden Test schreiben**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/durchsicht/sprache/domain/fachwort_treffer.dart';

void main() {
  test('findet Begriffe unabhängig von Gross- und Kleinschreibung', () {
    final t = zaehleTreffer(
      transkript: 'die weiselzellen sind offen, fünf Milben gefunden',
      erwartet: ['Weiselzellen', 'Milben', 'Schwarmtrieb'],
    );
    expect(t.gefunden, ['Weiselzellen', 'Milben']);
    expect(t.fehlend, ['Schwarmtrieb']);
    expect(t.quote, closeTo(2 / 3, 0.001));
  });

  test('findet Begriffe auch als Teil eines zusammengesetzten Wortes', () {
    // "Varroamilben" enthaelt "Varroa" — das zaehlt als Treffer, denn der
    // Imker hat den Begriff gesagt.
    final t = zaehleTreffer(transkript: 'Varroamilben auf der Windel', erwartet: ['Varroa']);
    expect(t.gefunden, ['Varroa']);
  });

  test('zählt einen Begriff nur einmal, auch bei Mehrfachnennung', () {
    final t = zaehleTreffer(transkript: 'Milben Milben Milben', erwartet: ['Milben']);
    expect(t.gefunden, ['Milben']);
    expect(t.quote, 1.0);
  });

  test('leeres Transkript ergibt Quote null statt Division durch null', () {
    final t = zaehleTreffer(transkript: '', erwartet: ['Milben']);
    expect(t.gefunden, isEmpty);
    expect(t.quote, 0.0);
  });

  test('leere Erwartungsliste ergibt Quote null und stürzt nicht ab', () {
    final t = zaehleTreffer(transkript: 'irgendetwas', erwartet: []);
    expect(t.quote, 0.0);
  });

  test('ignoriert Satzzeichen am Wortrand', () {
    final t = zaehleTreffer(transkript: 'kein Schwarmtrieb, alles ruhig.', erwartet: ['Schwarmtrieb']);
    expect(t.gefunden, ['Schwarmtrieb']);
  });
}
```

- [ ] **Schritt 2: Test laufen lassen, Fehlschlag bestätigen**

```bash
flutter test test/sprache/fachwort_treffer_test.dart
```

Erwartet: FEHLER — `Target of URI doesn't exist: fachwort_treffer.dart`

- [ ] **Schritt 3: Umsetzung schreiben**

```dart
/// Ergebnis einer Trefferzählung.
class Trefferbild {
  /// Begriffe aus der Erwartungsliste, die im Transkript vorkommen.
  final List<String> gefunden;

  /// Begriffe, die fehlen — das sind die Verhörer, um die es geht.
  final List<String> fehlend;

  /// Anteil gefundener Begriffe, 0.0 bis 1.0.
  final double quote;

  const Trefferbild({required this.gefunden, required this.fehlend, required this.quote});
}

/// Zählt, wie viele der erwarteten Fachbegriffe im Transkript stehen.
///
/// Bewusst **Teilstring**-Vergleich statt Wortgrenzen: Sagt der Imker
/// „Varroamilben", hat er „Varroa" gesagt — der Erkenner hat es richtig
/// verstanden, auch wenn kein eigenständiges Wort dasteht. Ein zu strenger
/// Vergleich würde den Dienst schlechter aussehen lassen, als er ist.
///
/// Gross-/Kleinschreibung wird ignoriert, weil die Anbieter unterschiedlich
/// normalisieren und das für die Frage „verstanden oder nicht" belanglos ist.
Trefferbild zaehleTreffer({
  required String transkript,
  required List<String> erwartet,
}) {
  final heuhaufen = transkript.toLowerCase();
  final gefunden = <String>[];
  final fehlend = <String>[];

  for (final begriff in erwartet) {
    if (heuhaufen.contains(begriff.toLowerCase())) {
      gefunden.add(begriff);
    } else {
      fehlend.add(begriff);
    }
  }

  return Trefferbild(
    gefunden: gefunden,
    fehlend: fehlend,
    quote: erwartet.isEmpty ? 0.0 : gefunden.length / erwartet.length,
  );
}
```

- [ ] **Schritt 4: Test laufen lassen, Erfolg bestätigen**

```bash
flutter test test/sprache/fachwort_treffer_test.dart
```

Erwartet: `All tests passed!` (6 Tests)

- [ ] **Schritt 5: Committen**

```bash
git add lib/features/durchsicht/sprache/domain/fachwort_treffer.dart test/sprache/fachwort_treffer_test.dart
git commit -m "Erkenner-Vergleich: Trefferzählung als reine Funktion, 6 Tests"
```

---

## Task 5: Vergleichsseite

**Dateien:**
- Erstellen: `web/erkennervergleich.html`

Die Aufnahmelogik ist die aus `web/tontest.html` — inklusive des stillen Dauertons, der den Tab
wachhält (D-98c). Neu sind: Versand an die Edge Function, Gegenüberstellung, Trefferzählung.

- [ ] **Schritt 1: Seite anlegen**

```html
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Erkenner-Vergleich</title>
<style>
  :root { --rand:#e2ddd4; --gut:#2e7d32; --warn:#b8860b; --schlecht:#c62828; }
  body { font-family: system-ui, sans-serif; margin:0; padding:16px; background:#faf8f4; color:#2b2b2b;
         max-width:820px; margin-inline:auto; }
  h1 { font-size:20px; margin:0 0 2px; }
  .unter { color:#6b665e; font-size:14px; margin:0 0 12px; line-height:1.45; }
  .haupt { width:100%; padding:18px; font-size:18px; font-weight:700; border:0; border-radius:12px;
           background:var(--gut); color:#fff; margin-bottom:10px; }
  .haupt.laeuft { background:var(--schlecht); }
  .haupt:disabled { background:#bbb; }
  input[type=text], input[type=password] { width:100%; padding:12px; font-size:16px; border:1px solid var(--rand);
           border-radius:10px; margin-bottom:8px; box-sizing:border-box; }
  .schalter { display:flex; gap:10px; align-items:flex-start; background:#fff; border:1px solid var(--rand);
              border-radius:10px; padding:10px; margin-bottom:8px; font-size:14px; line-height:1.4; }
  .schalter input { margin-top:3px; flex:none; width:20px; height:20px; }
  .karte { background:#fff; border:1px solid var(--rand); border-radius:10px; padding:12px; margin-bottom:10px; }
  .karte h3 { margin:0 0 4px; font-size:16px; }
  .zahl { font-variant-numeric:tabular-nums; font-weight:700; }
  .gut { color:var(--gut); } .schlecht { color:var(--schlecht); } .warn { color:var(--warn); }
  .txt { font-size:14px; line-height:1.5; white-space:pre-wrap; background:#faf8f4; padding:8px;
         border-radius:8px; max-height:220px; overflow-y:auto; margin-top:8px; }
  textarea { width:100%; height:110px; font-size:14px; padding:8px; border:1px solid var(--rand);
             border-radius:10px; box-sizing:border-box; }
  #verlauf { font-family:ui-monospace,monospace; font-size:12px; background:#fff; border:1px solid var(--rand);
             border-radius:10px; padding:8px; max-height:200px; overflow-y:auto; }
</style>

<h1>Erkenner-Vergleich</h1>
<p class="unter" id="fassungZeile"></p>
<p class="unter">
Dieselbe Aufnahme geht an alle Anbieter gleichzeitig. <b>Zuerst zählt die Vollständigkeit</b> — hört das
Transkript beim letzten gesprochenen Satz auf? Erst danach die Fachbegriffe.<br>
Sprich eine echte Durchsicht durch, mit den Fachwörtern, die dich interessieren. Fünf Minuten genügen
für einen Vergleich; für das Vollständigkeitsurteil brauchst du <b>mindestens zwölf Minuten</b>.</p>

<input type="password" id="testwort" placeholder="Testwort (einmalig, wird lokal gemerkt)">

<label class="schalter">
  <input type="checkbox" id="wortliste" checked>
  <span><b>Fachwortliste mitschicken</b> — <em>zum Vergleich denselben Text einmal mit und einmal ohne
  laufen lassen. Nur so ist zu sehen, ob die Liste etwas bringt.</em></span>
</label>

<button class="haupt" id="knopf">Aufnahme starten</button>
<button class="haupt" id="sendKnopf" style="background:#555" disabled>Aufnahme auswerten lassen</button>

<div id="ergebnisse"></div>

<div class="karte">
  <h3>Was du gesagt hast (für die Trefferzählung)</h3>
  <p class="unter" style="margin:0 0 6px">Trage hier die Fachbegriffe ein, die du tatsächlich gesagt hast —
  mit Komma getrennt. Nur diese werden gezählt.</p>
  <textarea id="erwartet">Weiselzellen, Milben, Schwarmtrieb, Drohnenbrut, Varroa, Ableger</textarea>
</div>

<div id="verlauf"></div>

<script>
const FASSUNG = 'V1';
const ZIEL = 'https://dcdcohktxbhdxnxjvcyp.supabase.co/functions/v1/transkription';
const HAEPPCHEN_MS = 5000;

const el = (id) => document.getElementById(id);
let strom = null, rec = null, laeuft = false, teile = [], tonCtx = null;
let start = 0, letztesHaeppchen = 0, luecke = 0, blob = null;

document.addEventListener('DOMContentLoaded', () => {
  el('fassungZeile').textContent = 'Fassung ' + FASSUNG
    + ' — steht hier eine ältere, lädt der Browser aus dem Zwischenspeicher.';
  el('testwort').value = localStorage.getItem('testwort') || '';
});

function log(text, art) {
  const d = document.createElement('div');
  d.className = art || '';
  d.textContent = new Date().toLocaleTimeString('de-CH') + '  ' + text;
  el('verlauf').appendChild(d);
  el('verlauf').scrollTop = el('verlauf').scrollHeight;
}

// Chrome friert untaetige Tabs ein — aber keinen, der Ton abspielt.
// Unhoerbar leise, 30 Hz. Echte Stille waere wirkungslos (Entscheid D-98c).
function stillenTonStarten() {
  try {
    const C = window.AudioContext || window.webkitAudioContext;
    tonCtx = new C();
    const o = tonCtx.createOscillator(), g = tonCtx.createGain();
    o.frequency.value = 30; g.gain.value = 0.003;
    o.connect(g); g.connect(tonCtx.destination); o.start();
  } catch (e) { log('Stiller Ton misslungen: ' + e, 'schlecht'); }
}

async function starten() {
  try {
    strom = await navigator.mediaDevices.getUserMedia({ audio: true });
  } catch (e) { log('Kein Mikrofon: ' + e, 'schlecht'); return; }
  teile = []; luecke = 0; blob = null;
  el('ergebnisse').innerHTML = '';
  let opt = {};
  if (MediaRecorder.isTypeSupported('audio/webm;codecs=opus')) {
    opt = { mimeType: 'audio/webm;codecs=opus', audioBitsPerSecond: 24000 };
  }
  rec = new MediaRecorder(strom, opt);
  rec.ondataavailable = (ev) => {
    if (!ev.data || !ev.data.size) return;
    teile.push(ev.data);
    const nun = Date.now();
    if (letztesHaeppchen && nun - letztesHaeppchen > HAEPPCHEN_MS * 2) {
      luecke = Math.max(luecke, nun - letztesHaeppchen);
    }
    letztesHaeppchen = nun;
  };
  start = Date.now(); letztesHaeppchen = start; laeuft = true;
  rec.start(HAEPPCHEN_MS);
  stillenTonStarten();
  el('knopf').textContent = 'Aufnahme beenden';
  el('knopf').classList.add('laeuft');
  el('sendKnopf').disabled = true;
  log('Aufnahme läuft — sprich deine Durchsicht', 'gut');
}

async function beenden() {
  laeuft = false;
  try { rec && rec.state !== 'inactive' && rec.stop(); } catch (e) {}
  if (strom) strom.getTracks().forEach((t) => t.stop());
  if (tonCtx) { try { tonCtx.close(); } catch (e) {} tonCtx = null; }
  await new Promise((f) => setTimeout(f, 400));
  blob = new Blob(teile, { type: rec.mimeType || 'audio/webm' });
  const min = (Date.now() - start) / 60000;
  el('knopf').textContent = 'Aufnahme starten';
  el('knopf').classList.remove('laeuft');
  el('sendKnopf').disabled = false;
  log('Beendet: ' + min.toFixed(1) + ' min, ' + (blob.size / 1048576).toFixed(2) + ' MB'
      + (luecke ? ', Lücke ' + Math.round(luecke / 1000) + ' s' : ', lückenlos'),
      luecke > 20000 ? 'schlecht' : 'gut');
}

el('knopf').onclick = () => (laeuft ? beenden() : starten());

// --- Trefferzählung, gleiche Regel wie fachwort_treffer.dart ----------------
function zaehleTreffer(transkript, erwartet) {
  const heu = (transkript || '').toLowerCase();
  const gefunden = [], fehlend = [];
  for (const b of erwartet) {
    (heu.includes(b.toLowerCase()) ? gefunden : fehlend).push(b);
  }
  return { gefunden, fehlend, quote: erwartet.length ? gefunden.length / erwartet.length : 0 };
}

el('sendKnopf').onclick = async () => {
  if (!blob) return;
  const wort = el('testwort').value.trim();
  if (!wort) { log('Testwort fehlt', 'schlecht'); return; }
  localStorage.setItem('testwort', wort);
  el('sendKnopf').disabled = true;
  el('sendKnopf').textContent = 'läuft … (kann zwei Minuten dauern)';
  log('Sende ' + (blob.size / 1048576).toFixed(2) + ' MB an alle Anbieter');

  const form = new FormData();
  form.append('audio', blob, 'durchsicht.webm');
  form.append('wortliste', el('wortliste').checked ? 'ja' : 'nein');

  try {
    const antwort = await fetch(ZIEL, { method: 'POST', headers: { 'x-testwort': wort }, body: form });
    const daten = await antwort.json();
    if (daten.fehler) { log('Fehler: ' + daten.fehler, 'schlecht'); return; }
    zeige(daten);
  } catch (e) {
    log('Versand misslungen: ' + e, 'schlecht');
  } finally {
    el('sendKnopf').disabled = false;
    el('sendKnopf').textContent = 'Aufnahme auswerten lassen';
  }
};

function zeige(daten) {
  const erwartet = el('erwartet').value.split(',').map((s) => s.trim()).filter(Boolean);
  const dauerMin = (Date.now() - start) / 60000;
  const ziel = el('ergebnisse');
  ziel.innerHTML = '<p class="unter">Fachwortliste war ' +
    (daten.mitWortliste ? '<b>an</b>' : '<b>aus</b>') + '. Aufnahme ' + dauerMin.toFixed(1) + ' min.</p>';

  for (const e of daten.ergebnisse) {
    const k = document.createElement('div');
    k.className = 'karte';
    if (e.fehler) {
      k.innerHTML = '<h3>' + e.anbieter + '</h3><p class="schlecht">Fehler: ' + e.fehler + '</p>';
      ziel.appendChild(k);
      continue;
    }
    const t = zaehleTreffer(e.text, erwartet);
    const woerter = e.text.trim().split(/\s+/).filter(Boolean).length;
    // Grobe Vollstaendigkeitsprobe: unter 90 Woertern je Minute ist verdaechtig
    // wenig fuer freie Rede — dann bitte das Textende von Hand pruefen.
    const proMin = dauerMin > 0.5 ? woerter / dauerMin : 0;
    const verdacht = proMin > 0 && proMin < 90;
    k.innerHTML =
      '<h3>' + e.anbieter + ' <span class="unter">(' + e.modell + ', '
        + (e.dauerMs / 1000).toFixed(1) + ' s)</span></h3>' +
      '<div>Fachbegriffe: <span class="zahl ' + (t.quote >= 0.8 ? 'gut' : t.quote >= 0.5 ? 'warn' : 'schlecht')
        + '">' + t.gefunden.length + '/' + erwartet.length + '</span>' +
        (t.fehlend.length ? ' &nbsp;— fehlt: <b class="schlecht">' + t.fehlend.join(', ') + '</b>' : '') +
      '</div>' +
      '<div>Länge: <span class="zahl">' + woerter + '</span> Wörter, ' +
        '<span class="' + (verdacht ? 'schlecht' : '') + '">' + Math.round(proMin) + ' je Minute</span>' +
        (verdacht ? ' &nbsp;⚠ <b>auf Abbruch prüfen — endet der Text beim letzten gesagten Satz?</b>' : '') +
      '</div>' +
      '<div class="txt">' + (e.text || '(leer)') + '</div>';
    ziel.appendChild(k);
  }
}
</script>
```

- [ ] **Schritt 2: Trefferzählung im Browser gegen die Dart-Fassung prüfen**

Beide Fassungen müssen bei denselben Eingaben dasselbe liefern — sonst misst die Seite etwas anderes
als der spätere App-Code.

```bash
node -e "
const zaehle=(t,e)=>{const h=(t||'').toLowerCase();const g=[],f=[];for(const b of e){(h.includes(b.toLowerCase())?g:f).push(b)}return{g,f,q:e.length?g.length/e.length:0}};
const a=zaehle('die weiselzellen sind offen, fünf Milben gefunden',['Weiselzellen','Milben','Schwarmtrieb']);
console.log(JSON.stringify(a)==='{\"g\":[\"Weiselzellen\",\"Milben\"],\"f\":[\"Schwarmtrieb\"],\"q\":0.6666666666666666}'?'GLEICH':'ABWEICHUNG: '+JSON.stringify(a));
console.log('leer:', JSON.stringify(zaehle('',['Milben'])));
console.log('teilwort:', JSON.stringify(zaehle('Varroamilben',['Varroa'])));
"
```

Erwartet:
```
GLEICH
leer: {"g":[],"f":["Milben"],"q":0}
teilwort: {"g":["Varroa"],"f":[],"q":1}
```

- [ ] **Schritt 3: Version anheben, ausrollen**

```bash
sed -i 's/^version: 1.70.0+104/version: 1.71.0+105/' pubspec.yaml && bash deploy.sh
```

- [ ] **Schritt 4: Ausgelieferte Fassung prüfen**

```bash
curl -s "https://danielproyer.github.io/bienen-app/erkennervergleich.html" | grep -c "FASSUNG = 'V1'"
```

Erwartet: `1`

- [ ] **Schritt 5: Committen**

```bash
git add web/erkennervergleich.html pubspec.yaml
git commit -m "Erkenner-Vergleich: Vergleichsseite, Vollständigkeit vor Genauigkeit"
```

---

## Task 6: Das Gold-Set aufnehmen

**Diese Aufgabe erledigt der Betreiber, nicht der Entwickler.** Sie ist die eigentliche Datenquelle.

- [ ] **Schritt 1: Lange Aufnahme für das Vollständigkeitsurteil**

Eine echte Durchsicht sprechen, **mindestens zwölf Minuten**, Handy in der Tasche, mit Wind. Beide
Personen sollen zu Wort kommen. Auswerten lassen, **Fachwortliste an**.

Prüffrage: **Endet jedes Transkript beim letzten gesagten Satz?** Bei der Warnung „auf Abbruch prüfen"
den Schluss von Hand vergleichen. Ein Anbieter, der abschneidet, scheidet aus — unabhängig von seiner
Trefferquote.

- [ ] **Schritt 2: Kurze Aufnahme, zweimal — mit und ohne Wortliste**

Denselben Text zweimal sprechen (rund drei Minuten), einmal mit Häkchen, einmal ohne. Das beantwortet
die Frage, die keine Recherche beantworten konnte: **Bringt die Fachwortliste überhaupt etwas?**

- [ ] **Schritt 3: Aufnahmeseite gegenprüfen**

Dieselben zwei Sätze dreimal: Handy in der Tasche · Handy auf der Nachbarbeute · Ansteckmikrofon am
Kragen, falls vorhanden. **Bluetooth-Headsets nicht verwenden** — deren Freisprechmodus schaltet auf
Schmalband und verschlechtert die Erkennung.

Dieser Schritt kostet fünf Minuten und schlägt womöglich jede Anbieterwahl.

- [ ] **Schritt 4: Ergebnisse festhalten**

Je Lauf notieren: Anbieter, Wortliste an/aus, Aufnahmesituation, Trefferquote, fehlende Begriffe,
Vollständigkeit ja/nein. Ohne diese Notizen ist der Vergleich Erinnerungssache.

---

## Task 7: Entscheiden und festschreiben

**Dateien:**
- Ändern: `docs/decision-log.md`
- Ändern: `docs/superpowers/specs/2026-07-28-durchsicht-tonmitschnitt-design.md`

- [ ] **Schritt 1: Nach diesen Regeln entscheiden, in dieser Reihenfolge**

1. **Vollständigkeit ist ein Ausschlusskriterium.** Wer abschneidet, fällt raus.
2. **Fachbegriff-Treffer ist das Hauptmass.** Ziel: mindestens 80 % der tatsächlich gesagten Begriffe.
3. **Kein falsch eingefügter Begriff.** Steht ein Fachwort im Transkript, das nie gesagt wurde, ist die
   Wortliste zu aggressiv — dann Liste kürzen und erneut messen.
4. Bei Gleichstand entscheidet die **EU-Verarbeitung** (D-99, Abschnitt 8 der Recherche).

- [ ] **Schritt 2: Ergebnis als Entscheid D-100 eintragen**

In `docs/decision-log.md` oberhalb des Abschnitts „2026-07-28 (nachts)" einfügen — mit den gemessenen
Zahlen, nicht mit Eindrücken. Die Vorlage:

```markdown
## 2026-07-2X — Erkenner gewählt nach eigener Messung (Feldtest)

- **D-100 · Gewählt: <Anbieter>.** Gemessen an <N> Aufnahmen aus <Situation>. Vollständigkeit: <ja/nein
  je Anbieter>. Fachbegriff-Treffer mit Wortliste: <x/y> gegen <x/y> ohne. Fehlende Begriffe:
  <Liste>. *Konsequenz:* <was daraus für den Bau folgt>.
- **D-100a · Wirkung der Fachwortliste: <gemessen>.** <Zahl mit gegen Zahl ohne.> *Konsequenz:*
  <Liste behalten / kürzen / verwerfen>.
- **D-100b · Aufnahmesituation:** <Tasche gegen Kragen, gemessen>. *Konsequenz:* <Empfehlung ans
  Material, ggf. Eintrag in die Imkerei-Schiene>.
```

- [ ] **Schritt 3: Die Spec auf den gemessenen Stand bringen**

Im Abschnitt „Erkennung: Kaskade statt Einzelanbieter" den Satz „Gewählter Erkenner: ElevenLabs
Scribe v2 … unter Vorbehalt der eigenen Messung" durch das Messergebnis ersetzen. Der Vorbehalt
entfällt damit — er war genau bis hierher gültig.

- [ ] **Schritt 4: Committen**

```bash
git add docs/decision-log.md docs/superpowers/specs/2026-07-28-durchsicht-tonmitschnitt-design.md
git commit -m "Erkenner nach eigener Messung gewählt (D-100)"
```

---

## Was danach kommt — und warum es hier noch nicht steht

Der Bau des Tonmitschnitts umfasst rund zwanzig weitere Aufgaben in sechs Blöcken:

| Block | Inhalt | hängt vom Messergebnis ab? |
|---|---|---|
| **A** | Migrationen S01–S04 (Aufnahmen, Bucket, Verhörer, Aufbewahrung) — **einzeln zur Freigabe** | nein |
| **B** | Domäne: `Aufnahme`-Modell, Gateway, Fake- und Supabase-Umsetzung | nein |
| **C** | Aufnahme im Browser: Dienst mit stillem Dauerton, Provider, Knopf im Wizard | nein |
| **D** | Erkennung: Edge Function produktiv, Feldextraktion mit JSON-Schema | **ja** |
| **E** | Korrektur: Vorbefüllung mit Herkunft, Verhörer lernen, Aufnahme abhören | **ja** |
| **F** | Einstellungen: Unterseite „Aufnahme & Sprache", Aufbewahrung, Löschpfad | teilweise |

**Warum jetzt nicht ausformuliert:** Die Blöcke D und E hängen unmittelbar am Messergebnis. Zeigt der
Test, dass die Fachbegriffe auch mit Wortliste unter 50 % bleiben, ändert sich der Zuschnitt
grundlegend — dann wird die Sprachmodell-Stufe zum Hauptträger und braucht ein anderes Schema, andere
Prüfungen und ein anderes Korrekturformular. Diesen Plan vorher zu schreiben hiesse, ihn zweimal zu
schreiben.

Die Blöcke A bis C sind vom Ergebnis **unabhängig** und könnten parallel laufen. Empfehlung: trotzdem
warten. Sie sind in zwei Sitzungen gebaut, und ein negatives Messergebnis würde die Datenmodell-Frage
neu stellen (etwa: braucht es überhaupt eine Transkript-Spalte, wenn nur die Aufnahme zählt?).

---

## Selbstprüfung dieses Plans

**Spec-Abdeckung.** Die Spec verlangt vor der Umsetzung drei Dinge (Abschnitt „Vor der Umsetzung zu
klären"): Anbieterpreise prüfen — durch die Recherche erledigt; Qualitätsvergleich mit denselben Sätzen
— Tasks 5–6; Löschpfad prüfen — gehört in Block F und ist dort vermerkt. Die Recherche verlangt
zusätzlich einen Prüfmassstab (Task 6/7), Vollständigkeit vor Genauigkeit (Tasks 5, 7) und das
Mitmessen der Aufnahmeseite (Task 6, Schritt 3). Alles abgedeckt.

**Platzhalter.** Keine. Jeder Codeschritt enthält vollständigen Code; jeder Prüfschritt einen Befehl
mit erwarteter Ausgabe. Die Entscheidungsvorlage in Task 7 enthält bewusst Lücken — das sind
Messwerte, die erst entstehen, keine unfertigen Anweisungen.

**Typ-Stimmigkeit.** `Transkript` (Task 2) wird in Task 3 importiert und in Task 5 als JSON-Feld
`ergebnisse` gelesen — Felder `anbieter`, `modell`, `text`, `dauerMs`, `fehler` stimmen überein.
`zaehleTreffer` liefert in Dart (Task 4) `gefunden`/`fehlend`/`quote` und in JS (Task 5)
`gefunden`/`fehlend`/`quote` — die Gleichheit prüft Task 5, Schritt 2 ausdrücklich nach.

**Eine bewusste Doppelung:** Die Trefferzählung existiert zweimal, in Dart und in JavaScript. Der
JS-Teil könnte den Dart-Teil nicht aufrufen, ohne die ganze Flutter-App auf die Testseite zu ziehen.
Die Doppelung ist mit einem Vergleichsschritt abgesichert und verschwindet, sobald die Auswertung in
die App wandert.
