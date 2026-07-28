# Sprachband für die Durchsicht — Design

**Stand:** 2026-07-28 · **Modul:** 4.3 Durchsicht (Spracheingabe, Ablösung von v1 und v2)
**Fachbezug:** `../../../../imkerei/02_Recherche/11_Imkerei_Grundlagen_Betriebsweisen.md` (Ablauf der Durchsicht)

## Warum neu

Die bisherige Spracheingabe setzt **ein Mikrofon je Feld**: antippen, einen Satz sagen, wieder antippen. Im Feldtest hat sich das als untauglich erwiesen — mit Handschuhen am offenen Volk kommt niemand dazu, für jede Angabe ein Symbol zu treffen. Drei Nachbesserungen an Filtern und Betriebsarten haben die Symptome verschoben, nicht die Ursache behoben: Das Bedienmodell passt nicht zur Arbeit.

Gewünscht ist stattdessen **ein Aufnahmeband für die ganze Durchsicht**, das laufend mithört, erkannte Angaben sofort in die Felder einträgt und dabei jederzeit zeigt, was es verstanden hat. Die Dauer der Durchsicht soll die App aus Start und Speichern selbst bestimmen.

## Was die Technik hergibt — und was nicht

Die Web Speech API ist **nicht für Dauerbetrieb gebaut**. Chrome beendet die Erkennung bei Stille nach wenigen Sekunden, im Dauermodus oft schon nach etwa einer Minute; nach rund fünf Minuten liefert sie häufig gar nichts mehr, obwohl das Mikrofon aktiv wirkt. Der verbreitete Ausweg — Neustart im `onend`-Ereignis — läuft bei zu schneller Wiederholung in eine Ratenbegrenzung, nach der Sitzungen sofort wieder enden.
Belege: [Web-Speech-API Issue #99](https://github.com/WebAudio/web-speech-api/issues/99), [Chromium-Diskussion zur 60-Sekunden-Grenze](https://groups.google.com/a/chromium.org/g/chromium-html5/c/s2XhT-Y5qAc), [Bericht über Aussetzer nach längerer Laufzeit](https://groups.google.com/a/chromium.org/g/chromium-html5/c/AQbwcktdQ3g/m/9gCk-48SBAAJ).

**Daraus folgen zwei Entwurfsentscheidungen:**

1. **Geplant erneuern statt reaktiv neu starten.** Die App beendet und startet die Erkennung selbst in ruhigem Takt (Vorgabe: alle 45 Sekunden), bevor Chrome sie kappt. Neustarts werden damit vorhersehbar statt zufällig, und die Zahl der Anmeldungen bleibt niedrig genug für die Ratenbegrenzung. Ein `onend` ausserhalb des Takts gilt weiterhin als Störung und wird gebremst behandelt.
2. **Ein Mitschnitt als Sicherheitsnetz.** Parallel läuft eine Tonaufnahme über `MediaRecorder`, die diese Grenzen nicht hat. Was die Live-Erkennung verpasst, ist dort nachhörbar und auf Wunsch nachträglich auswertbar.

## Bedienmodell

### Das Band

Ein Streifen am oberen Rand des Wizards, sichtbar auf allen drei Schritten:

- **Zustand** — hört zu / Pause / gestört, als Farbe und Wort. Ein stiller Ausfall ist der schlimmste Fehler dieser Funktion; der Zustand muss ohne Nachdenken ablesbar sein.
- **Laufzeit** der Aufnahme.
- **Zuletzt gehört** — der laufende Teiltext, damit man merkt, dass das Mikro etwas aufnimmt.
- **Ein Knopf** zum Starten und Anhalten. Das Band läuft über Seitenwechsel hinweg weiter.

### Das Protokoll

Direkt unter dem Band die letzten Einträge, neueste zuoberst:

```
14:32  Temperatur → 20 °C            [rückgängig]
14:32  Brutwaben → 6                 [rückgängig]
14:31  „also da hinten ist noch"     (nichts erkannt)
```

Erkanntes nennt Feld und Wert, damit ein Hörfehler sofort auffällt („Brutwaben → 16"). Nicht Erkanntes erscheint gedämpft — daran sieht man, dass das Mikro läuft, aber ein Feldwort fehlte. Rückgängig setzt das Feld auf den Wert davor zurück.

### Grammatik

**Alle Feldwörter gelten immer**, unabhängig vom Wizard-Schritt. Wer beim Abschluss noch „Temperatur zwanzig Grad" nachschiebt, setzt das Feld — das ist die Anforderung „einzelne Infos können erst am Schluss dazukommen".

Ausgenommen sind die **Wabenwörter** (`brut`, `pollen`, `nächste`, `zurück`, `schied` …). Sie gelten nur, solange der Wabenschritt geöffnet ist, weil sie sonst mit Feldwörtern kollidieren: „Futter" bezeichnet dort eine Wabeneigenschaft, hier ein Kilogramm-Feld.

**Neu: Freitextfelder.** `wetter`, `massnahme`/`massnahmen` und `notiz` nehmen alles auf, was nach dem Feldwort folgt, bis ein weiteres Feldwort erkannt wird oder der Satz endet:

- „**Wetter** schön und windstill" → Wetter = „schön und windstill"
- „**Notiz** Volk sitzt ruhig **Temperatur** achtzehn" → Notiz = „Volk sitzt ruhig", Temperatur = 18

Mehrfaches Sprechen desselben Freitextfelds **hängt an** (getrennt durch Leerzeichen); Zahl-, Auswahl- und Ja/Nein-Felder werden **überschrieben**. Begründung: Notizen wachsen im Lauf der Durchsicht, ein Messwert wird korrigiert.

Rückgängig entfernt bei Freitext genau den zuletzt angehängten Abschnitt, nicht das ganze Feld — deshalb speichert das Protokoll bei jedem Eintrag den vollständigen vorherigen Feldwert und stellt diesen wieder her.

### Dauer

Die Messung beginnt beim Öffnen des Wizards und endet beim Speichern. Das bestehende Dauer-Feld wird damit vorbelegt statt leer gelassen und bleibt mit den +/− Tasten korrigierbar. Bei einer Durchsicht, die beim Bearbeiten einer bestehenden geöffnet wird, bleibt der gespeicherte Wert stehen und wird nicht überschrieben.

## Bausteine

Neu oder geändert, in der Reihenfolge der Abhängigkeit:

| Baustein | Ort | Aufgabe |
|---|---|---|
| `SprachbandZustand` | `sprache/domain/` | Reine Zustandsmaschine: aus, hört, Pause, gestört — plus Laufzeit und Störungszähler. Ohne Browser prüfbar. |
| `feld_erkennung.dart` | `sprache/domain/` | Erweiterte Grammatik. Nimmt einen Satz und den aktuellen Schritt, liefert eine Liste von Feldsetzungen (Feld, Wert, Rohtext). Ersetzt `parseKommando`, übernimmt dessen Regeln und ergänzt Freitextfelder. |
| `SprachProtokoll` | `sprache/domain/` | Liste der Einträge mit Zeit, Feld, altem und neuem Wert — Grundlage für Anzeige und Rückgängig. |
| `TaktErneuerer` | `sprache/data/` | Erneuert die Erkennung im festen Takt; kapselt Timer und Übergabe, damit keine Lücke im Zuhören entsteht. |
| `TonMitschnitt` | `sprache/data/` | `MediaRecorder`-Kapsel: starten, stoppen, Bytes liefern. Web-spezifisch, mit Stub für Tests. |
| `SprachbandController` | `sprache/data/` | Führt die Teile zusammen: nimmt Erkennungsergebnisse, ruft die Grammatik, schreibt ins Protokoll, meldet Feldsetzungen an den Wizard. |
| `SprachbandLeiste` | `sprache/presentation/` | Band + Protokoll als Widget. |
| Wizard | `durchsicht/presentation/pages/` | Bindet das Band ein, nimmt Feldsetzungen entgegen, misst die Dauer. Die sechs Einzelmikros entfallen. |

Der bestehende `WebSpracheErkenner` bleibt die unterste Schicht (Web Speech API), verliert aber seinen selbstgesteuerten Neustart — den übernimmt der `TaktErneuerer`. Aus dem Bestand bleiben unverändert erhalten, weil sie ihre Berechtigung behalten und getestet sind:

- `ErgebnisAuswahl` — sortiert aus, was der Browser mehrfach liefert. Beim Takt-Wechsel beginnt der Ergebnistext von vorn; genau dafür ist der Textvergleich statt der Index-Zählung gebaut.
- `NeustartBremse` — greift jetzt nur noch bei Störungen ausserhalb des Takts, nicht mehr im Normalbetrieb.
- `KommandoPuffer` — führt weiterhin Satzstücke zusammen, wenn die Erkennung mitten im Satz abschliesst („Temperatur" … „zwanzig Grad"). Beim Dauerband tritt das häufiger auf als bisher, nicht seltener.

Ersatzlos entfallen `SprachMikro` (die sechs Einzelmikros) und der Einzelsatz-Modus im `SprachController` — beide waren Antworten auf das alte Bedienmodell.

## Datenfluss

```
Mikrofon
   ├─→ WebSpracheErkenner ──→ ErgebnisAuswahl ──→ SprachbandController
   │        ↑ TaktErneuerer                            │
   │                                                   ├─→ feld_erkennung ──→ Feldsetzung ──→ Wizard-Zustand
   │                                                   └─→ SprachProtokoll ──→ Anzeige
   └─→ TonMitschnitt ──────────────────────────────────────────────────────→ Storage (beim Speichern)
```

## Mitschnitt und Auswertung

**Aufnahme:** `MediaRecorder` mit Opus in WebM, eine Spur, niedrige Bitrate (Sprache, ~24 kbit/s ≈ 0,2 MB je Minute). Eine halbe Stunde kostet damit rund 6 MB — vertretbar für den Supabase-Speicher, auch über eine Saison mit acht Völkern.

**Ablage:** neuer Bucket `durchsicht-audio` nach dem Muster der bestehenden Foto-Buckets (privat, Pfad beginnt mit der `betrieb_id`, vier Richtlinien). An `durchsichten` kommt eine Spalte `audio_pfad text` dazu. Migration `S01`, freigabepflichtig wie jede Produktionsmigration.

**Abspielen:** In der Durchsicht-Detailansicht ein Abspieler mit signierter URL, wie bei den Fotos.

**Auswertung (Stufe C, siehe unten):** Beim Speichern ein Knopf „Aufnahme auswerten". Er schickt den Mitschnitt an einen Transkriptionsdienst, lässt die Grammatik über das Ergebnis laufen und zeigt die Funde als **Vorschlagsliste** — jeder Eintrag einzeln annehmbar oder verwerfbar, nichts wird automatisch gesetzt. Ohne diesen Knopf verlässt kein Ton das Gerät ausser über die Live-Erkennung.

**Offen und vor Stufe C zu entscheiden:** welcher Transkriptionsdienst. Kandidaten sind OpenAI Whisper (günstig, gute Deutsch-Erkennung, aber Mundart schwach) und ein europäischer Anbieter (Datenschutz, meist teurer). Die Entscheidung braucht einen eigenen Vergleich und Daniels Freigabe, weil Kosten je Minute und ein weiterer Datenempfänger daran hängen.

## Fehlerbehandlung

| Fall | Verhalten |
|---|---|
| Mikrofon nicht freigegeben | Band zeigt „gestört" mit Klartext; Tippen bleibt möglich. Kein Neustartversuch. |
| Erkennung liefert nichts mehr, Band läuft | Der Takterneuerer merkt, dass über zwei Takte kein Ergebnis kam, und meldet „gestört — bitte neu starten". Das ist der wichtigste Fall: stiller Ausfall wird sichtbar. |
| Ratenbegrenzung (Sitzungen enden sofort) | Nach mehreren Fehlschlägen in Folge Pause statt Weiterversuch, mit Hinweis. |
| Mitschnitt nicht möglich (kein `MediaRecorder`) | Live-Erkennung läuft trotzdem; Hinweis, dass kein Sicherheitsnetz besteht. |
| Hochladen des Mitschnitts scheitert | Durchsicht wird trotzdem gespeichert; der Mitschnitt bleibt lokal und kann erneut hochgeladen werden. Fachdaten haben Vorrang vor dem Beleg. |
| Browser ohne Web Speech API (Firefox, Safari) | Band erscheint nicht, alles bleibt tippbar — wie heute. |

## Tests

Reine Logik, ohne Browser prüfbar:

- **Grammatik**: jedes Feld einmal, Freitext bis zum nächsten Feldwort, Anhängen gegen Überschreiben, Wabenwörter nur im Wabenschritt, der gemeldete Fall „Wetter schön" und „Temperatur zwanzig Grad".
- **Zustandsmaschine**: Übergänge, Störungserkennung nach zwei stillen Takten.
- **Protokoll**: Rückgängig stellt den vorherigen Wert her, auch bei mehrfacher Setzung desselben Feldes.
- **Dauer**: Vorbelegung beim Speichern, kein Überschreiben beim Bearbeiten.

Mit Fake-Erkenner (vorhanden) im Controller-Test: Feldsetzung landet im Wizard, Protokoll wächst, Seitenwechsel unterbricht das Band nicht.

Was **nicht** automatisch prüfbar ist und im Feldtest bestätigt werden muss: ob das Band eine reale Durchsicht durchhält, und ob die Erkennung Mundart genug versteht. Dafür ist der Mitschnitt da.

## Staffelung

Drei Stufen, jede für sich nutzbar:

- **Stufe A — Live-Band.** Band, Protokoll, erweiterte Grammatik, Dauer-Messung, Wegfall der Einzelmikros. Danach ist die Durchsicht sprechbar erfassbar; kein Mitschnitt, keine Migration.
- **Stufe B — Mitschnitt.** `MediaRecorder`, Bucket, Migration `S01`, Abspieler in der Detailansicht.
- **Stufe C — Auswertung des Mitschnitts.** Transkriptionsdienst (Entscheidung offen), Vorschlagsliste beim Speichern.

Der Umsetzungsplan beginnt mit Stufe A. B und C bekommen eigene Pläne, wenn A im Feld getragen hat — sonst baut man das Sicherheitsnetz für ein Verfahren, das sich noch ändert.

## Nicht in diesem Entwurf

- Sprachausgabe der App (Vorlesen von Werten zur Kontrolle).
- Mundart-Wörterbuch über die vorhandenen Aliase hinaus — erst sammeln, was im Feld tatsächlich verschluckt wird.
- Spracheingabe in anderen Modulen (Behandlung, Fütterung). Erst hier bewähren.
