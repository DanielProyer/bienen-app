# Spracherkennung für die Durchsicht — Marktvergleich

**Stand:** 28. Juli 2026 · **Umfang:** 16 Anbieter, 8 Querschnittsachsen, 6 adversariale Gegenprüfungen
**Anlass:** Die vorläufige Wahl (Azure Speech) beruhte auf zwei Websuchen. Diese Recherche prüft sie.

---

## Inhalt

1. [Das Wichtigste in Kürze](#1-das-wichtigste-in-kürze)
2. [Der Anwendungsfall als Massstab](#2-der-anwendungsfall-als-massstab)
3. [Vier Befunde, die die Frage verschieben](#3-vier-befunde-die-die-frage-verschieben)
4. [Beurteilungstabelle: alle 16 Kandidaten](#4-beurteilungstabelle-alle-16-kandidaten)
5. [Die Architektur entscheidet, nicht der Anbieter](#5-die-architektur-entscheidet-nicht-der-anbieter)
6. [Was andere Imkerei-Apps machen](#6-was-andere-imkerei-apps-machen)
7. [Empfehlung ohne Datenschutz-Gewichtung](#7-empfehlung-ohne-datenschutz-gewichtung)
8. [Empfehlung mit Datenschutz-Gewichtung](#8-empfehlung-mit-datenschutz-gewichtung)
9. [Warum Azure zurückfällt](#9-warum-azure-zurückfällt)
10. [Vor der Umsetzung zu klären](#10-vor-der-umsetzung-zu-klären)
11. [Methodik und Grenzen dieser Recherche](#11-methodik-und-grenzen-dieser-recherche)

---

## 1. Das Wichtigste in Kürze

**Die vorläufige Wahl war falsch begründet — aber nicht wegen Azure, sondern wegen der Frage.**
Azure wurde gewählt, weil es als einziger grosser Dienst eine echte `de-CH`-Locale *und* akustisches
Training anbietet. Beide Vorteile schrumpfen bei näherem Hinsehen erheblich, und vor allem: Sie lösen
ein Problem, das gar nicht besteht.

**Der Schweizer Akzent ist kein Problem.** Der eigene Feldtest hat ihn bereits bestanden — ein System,
das „Königin auf Wabe 8" und „Brut in allen Stadien" fehlerfrei liefert, hat kein Akzentproblem. Die
beunruhigenden Zahlen der Forschung (25–30 % Wortfehlerrate) betreffen **Dialekt**, nicht Hochdeutsch
mit Akzent. Ein Spezialmodell für Schweizerdeutsch wäre hier die falsche Investition: Es würde ein
nicht vorhandenes Problem lösen und bei Standarddeutsch schlechter abschneiden.

**Der einzige echte Engpass ist das Fachvokabular** — und der wird **nicht im Erkenner gelöst**,
sondern in der Stufe darüber. Alle drei Fehler aus dem Feldtest (Weiselzellen, Milben → „Minuten",
Schwarmtrieb) sind Vokabularfehler, und sie sind systematisch, also regelbar.

**Alle Kosten sind irrelevant.** Über sechzehn Anbieter hinweg liegt die Spanne für 20 Stunden Audio im
Jahr zwischen 2 und 20 Dollar. Wer diese Entscheidung mit dem Preis begründet, optimiert die falsche
Grösse.

**Die Empfehlung lautet deshalb nicht auf einen Anbieter, sondern auf eine Architektur:** eine Kaskade
aus einem austauschbaren Erkenner und einer LLM-Stufe, die aus fehlerhaftem Text die richtigen Felder
ableitet. Genau so bauen es die Wettbewerber, und genau dafür gibt es Messungen.

---

## 2. Der Anwendungsfall als Massstab

Jede Bewertung in diesem Dokument misst am selben Massstab:

| Randbedingung | Folge für die Auswahl |
|---|---|
| Handschuhe, Wabe in beiden Händen | Keine Bedienung während der Arbeit; Aufnahme läuft durch |
| 15 Minuten am Stück, ein Volk je Aufnahme | Batch statt Streaming; **Dauergrenzen sind ein Ausschlusskriterium** |
| `webm/opus` aus dem Browser-Recorder | Wer das Format nicht nimmt, kostet eine Umwandlungsstufe |
| Flutter Web + Supabase Edge Functions (Deno) | REST bevorzugt; 256 MB Speicher, 2 s Rechenzeit |
| Schlechtes Netz auf 1570 m | Upload wird nachgereicht — Verzögerung ist gratis |
| Aufnahme bleibt als Rückfall gespeichert | **Die Erkennung muss nützlich sein, nicht perfekt** |
| Deutschschweizer Sprecher, Hochdeutsch mit Akzent | Kein Dialekt-Problem (siehe Abschnitt 3.1) |
| Zwei Sprecher am Stand | Sprechertrennung wünschenswert |
| 20 Stunden Audio im Jahr, später ×100 | Preis praktisch bedeutungslos |
| Mandantenfähig, zur Vermarktung bestimmt | Wortlisten pro Mandant; kein Modell-Lock-in |

---

## 3. Vier Befunde, die die Frage verschieben

### 3.1 Schweizer Akzent — Entwarnung mit Belegen

Der Sprecher fällt in die Kategorie **Schweizer Hochdeutsch**, nicht in Dialekt. Das ist sprachtechnisch
ein völlig anderes Problem, und es ist gelöstes Terrain. Die alarmierenden Zahlen aus der Literatur
beschreiben durchgehend Mundart.

Daraus folgt eine unbequeme Erkenntnis: **Das `de-CH`-Etikett ist als Auswahlkriterium fast wertlos** —
und teilweise sogar eine Falle:

- **Google** führt `de-CH` nur mit Telefonie-Modellen (für 8-kHz-Telefonaudio gebaut). Wer es wählt,
  bekommt ein *schlechteres* Ergebnis als mit `de-DE`.
- **AssemblyAI** beschriftet `de_ch` als „Swiss German" — fachlich falsch, und nur auf dem älteren Modell.
- Brauchbar ist `de-CH` nur bei **Azure**, **Amazon** und **Deepgram**.

Faustregel: bei Google und AssemblyAI `de-DE` bzw. `de` wählen; bei Azure und Deepgram lohnt ein
A/B-Vergleich zwischen `de-CH` und `de-DE`.

**Eine Warnung bleibt:** Kippt ein Sprecher in echte Mundart, bricht die Erkennung ein — und zwar
tückisch, durch stille Umformulierung ins Hochdeutsche statt durch erkennbare Fehler. Für Kunden aus der
Deutschschweiz ist das eine reale Grenze, die in der Bedienung zu benennen ist.

### 3.2 Das Fachwort-Problem gehört in die LLM-Stufe

Dies ist die wichtigste technische Erkenntnis der ganzen Recherche.

**Kein einziger untersuchter Wettbewerber versucht, das Transkript perfekt zu machen.** Alle setzen ein
Sprachmodell mit Fachkontext dahinter, das aus fehlerhaftem Text die richtigen Feldwerte ableitet. Und
für diesen Weg gibt es Messungen, die es für den Erkenner-Weg nicht gibt:

- **28 % relative Fehlerreduktion** bei Fachterminologie durch nachgelagerte LLM-Korrektur (DeRAGEC)
- **+6 BLEU** bei — bemerkenswert einschlägig — **Schweizer Parlamentsdeutsch**, mit Whisper plus
  nachgelagertem Sprachmodell

Die Runtime-Wortliste beim Erkenner bleibt sinnvoll, ist aber die kleinere Hälfte. Sie kostet dreissig
Minuten Arbeit und ist bei allen Anbietern verfügbar.

**Nebenwirkung, die zu beachten ist:** Wortlisten können Begriffe *einfügen*, die nie gesagt wurden.
Bei meldepflichtigen Seuchen wäre ein halluzinierter Befund gravierender als ein fehlender.
**Faulbrut, Sauerbrut und verwandte Begriffe gehören nicht in die Boost-Liste** — sie gehören in die
LLM-Stufe, wo der Kontext sie auflöst. Dasselbe gilt für Alltagswörter mit imkerlicher Sonderbedeutung:
Beute, Windel, Stifte, Schied.

### 3.3 Die Lernfähigkeit fällt als Nebenprodukt an

Der Wunsch nach einem auf die eigene Stimme trainierten Modell ist verständlich — aber der Aufwand steht
in keinem Verhältnis, und die Wirkung ist bei modernen Modellen zweifelhaft.

Was echtes Training verlangt:

| Anbieter | Anforderung |
|---|---|
| Azure Custom Speech | Audioschnipsel von **maximal 40 Sekunden** mit wörtlichem Transkript; Modelle **verfallen nach 2 Jahren**; Hosting eines eigenen Endpunkts ≈ **471 USD/Jahr** |
| Google | **100 Audiostunden** Training plus 10 Stunden Validierung — bei 20 Stunden im Jahr wären das fünf Jahre |
| Amazon | Akustisches Training ausdrücklich **nicht unterstützt** |
| Whisper selbst betrieben | Technisch möglich (LoRA), verlangt aber eigene Server — Edge Functions können es nicht |

Die Annahme aus dem bisherigen Entwurf, die Trainingsdaten fielen „von selbst" an, ist **falsch**:
Korrigierte Formularfelder sind keine wörtlichen Transkripte von 40-Sekunden-Schnipseln.

**Was stattdessen funktioniert und sofort wirkt:** eine Verhörer-Tabelle pro Person und Mandant. Jede
Korrektur des Imkers ist ein Signal; nach einigen Treffern wandert der Begriff in die Mandantenliste,
die bei jedem Auftrag mitgeschickt wird. Das ist personalisiert, mandantenfähig, kostenlos, wirkt ab der
ersten Korrektur — und wandert bei einem Anbieterwechsel mit, statt in trainierten Gewichten
festzustecken.

### 3.4 Format und Dauer sind härtere Filter als Genauigkeit

Zwei technische Details schliessen Kandidaten aus, bevor die Genauigkeit überhaupt zur Sprache kommt.

**Dateiformat.** Der Browser nimmt `webm/opus` auf. Wer das nicht annimmt, erzwingt eine Umwandlung —
in einer Edge Function mit 2 Sekunden Rechenzeit ein ernstes Problem.

| Nimmt `webm` direkt | Nimmt `webm` **nicht** |
|---|---|
| OpenAI · Deepgram · AssemblyAI · Soniox · ElevenLabs · Amazon · Azure · Google | **Speechmatics** · **Gemini** · **Gladia** · alle Offline-Modelle im Browser |

Bei Speechmatics ist die Formatliste ausdrücklich als abschliessend bezeichnet. Der naheliegende
Ausweg — im Browser gleich als `audio/mp4` aufnehmen — ist ein **Codec-Wechsel von Opus auf AAC**, und
bei 24 kbit/s ist AAC hörbar schwächer. Bei Wind am offenen Bienenstand ist das genau an der falschen
Stelle gespart. Chrome kann kein `ogg` aufnehmen, also bliebe nur Umcontainern im Browser.

**Dauergrenze — der gefährlichste Einzelbefund der Recherche.** Die OpenAI-Modelle `gpt-4o-transcribe`
und `gpt-4o-mini-transcribe` haben eine Ausgabegrenze von **2000 Token**. Das Transkript *ist* die
Ausgabe. Nutzerberichte belegen: Das Transkript wird **nach acht bis neun Minuten stillschweigend
abgeschnitten** — ohne Fehlermeldung, mit plausibel aussehendem Ergebnis. Bei einer 15-Minuten-Durchsicht
fehlten zwei Drittel der Beobachtungen, und niemand würde es merken.

`whisper-1` ist davon nachweislich **nicht** betroffen. Für das im Juli 2026 erschienene `gpt-transcribe`
ist die Grenze **nicht dokumentiert** — also ungeklärt.

> **Regel für jeden Feldtest:** Zuerst die **Vollständigkeit** prüfen (hört das Transkript beim letzten
> gesprochenen Satz auf?), erst danach die Genauigkeit. Ein Modell, das nach neun Minuten abbricht,
> braucht man auf Fehlerrate gar nicht erst zu messen.

---

## 4. Beurteilungstabelle: alle 16 Kandidaten

Note von 1 (ungeeignet) bis 10 (ideal), **für diesen Anwendungsfall**, Datenschutz ausgeklammert.
Preis für 20 Stunden Audio im Jahr, Batch-Betrieb.

| # | Kandidat | Note | Preis/Jahr | `webm` | Fachwort-Hebel | Echtes Lernen | `de-CH` | Kernproblem |
|---|---|---|---|---|---|---|---|---|
| 1 | **Multimodale LLM** (Gemini 3.x Audio) | **9** | ~$7–16 | ✗ | freier Prompt, unbegrenzt | nein (sinnlos) | – | Format-Umwandlung nötig; Halluzination bei Pflichtdaten |
| 2 | **ElevenLabs Scribe v2** | **8** | $4.40 | ✓✓ | 1000 Keyterms (+20 %) | nein | – | Bester gemessener Wert — aber englisch gemessen |
| 2 | **AssemblyAI** Universal-3.5 Pro | **8** | $6.60 | ✓✓ | 1000 Keyterms + Prompt | nein (Strategie) | ⚠ irreführend | Starker API-Wandel; Standardsprache ist **Englisch** |
| 2 | **Soniox** v5 | **8** | **$2.17** | ✓ | Kontext, 8000 Token, inklusive | nein | ✗ | Sehr dünne unabhängige Beleglage |
| 2 | **Speechmatics** Enhanced | **8** | $10.00 | **✗** | Dictionary mit **Aussprache** | nein (Enterprise) | ✓ (Zusage) | Format-Blocker; keine deutsche Messung |
| 2 | **OpenAI** `gpt-transcribe` | **8→7** | $5.40 | ✓✓ | `keywords` (brandneu) | nein | ✗ | **Trunkierung** bei den 4o-Modellen |
| 2 | **Mistral Voxtral** | **8** | $3.60 | ✓ | 100 Begriffe (engl. optimiert) | nein (Self-Service) | ✗ | Fachwort-Hebel für Deutsch „experimentell"; Apache 2.0 |
| 8 | **Microsoft Azure** Speech | **7** | $7.20 | ✓ | 500 Phrasen + Aussprache | **ja**, teuer | ✓✓ | Siehe Abschnitt 9 |
| 8 | **Deepgram** Nova-3 | **7** | $9.24 | ✓✓ | 500 Token (kostet extra) | Enterprise | ✓ | Einziger, der für den Hebel zahlt und Wirkung nicht belegt |
| 8 | **Gladia** Solaria | **7** | $12.20 | **✗** | Nachbearbeitung am Text | nein | ✗ | Deutsch ist die schwächste Sprache |
| 8 | **Whisper** selbst betrieben | **7** | ~$3 | ✓ | 224 Token (knapp) | **ja**, LoRA | ✗ | Braucht eigene Server; halluziniert bei Stille |
| 12 | **Google** Chirp 3 | **6** | $19.20 / $3.60¹ | ✓ | 1000 Phrasen, gratis | Preview, unerreichbar | ⚠ Falle | Audio **nur** über Google-Cloud-Speicher |
| 13 | **Amazon Transcribe** | **5** | $7.20 | ✓✓ | Vokabular (Aussprache **abgekündigt**) | nein | ✓ | Audio nur über S3; Genauigkeit hinteres Mittelfeld |
| 13 | **NVIDIA** Parakeet/Canary | **5** | ~$1.80 | ✓ | nur im eigenen Container | **ja** | ✗ | Fachwort-Hebel auf dem bezahlbaren Weg nicht verfügbar |
| 15 | **Picovoice** Leopard | **3** | ~$6000² | – | sehr gut | nein | ✗ | Preismodell; Schlüssel im Browser lesbar |
| 15 | **Offline im Browser** (WASM) | **3** | $0 | **✗** | schwach | ja | ✗ | Auf dem Handy zu langsam; kein Präzedenzfall |

¹ Standardpreis bzw. mit verzögerter Sammelverarbeitung. ² Letzter veröffentlichter Einstiegspreis; kein Minutentarif mehr.

**Legende `webm`:** ✓✓ = ausdrücklich dokumentiert und empfohlen · ✓ = unterstützt · ✗ = nicht unterstützt

---

## 5. Die Architektur entscheidet, nicht der Anbieter

Die Auswertung aller Achsen führt zu einer zweistufigen Kaskade:

```
Aufnahme (webm/opus)
   │
   ├─► Stufe 1: Erkenner  ── Wortliste (global + pro Mandant)
   │                          → Transkript, wörtlich
   │
   └─► Stufe 2: Sprachmodell ── Fachglossar + JSON-Schema
                                → Formularfelder, mit Beleg-Zitat je Feld
   │
   └─► Imker prüft und korrigiert  ──► Korrektur wandert in die Wortliste
```

**Warum zweistufig und nicht ein Schritt:** Der Direktweg (Audio direkt ins Sprachmodell) ist real und
funktioniert, spart aber keinen Schritt — er tauscht die Erkennungsstufe gegen eine Umwandlungsstufe,
weil Gemini `webm` nicht annimmt. Zudem entsteht beim Direktweg kein Transkript als eigenständiges
Artefakt, und die App will es ohnehin anzeigen. Und die belegten Messungen zur Fachwortkorrektur
stammen sämtlich aus Kaskaden.

**Beide Stufen sind einzeln austauschbar und einzeln messbar.** Das ist bei einer Technologie, in der
2026 im Halbjahrestakt Modelle abgekündigt werden, kein Luxus.

**Zwingende Regeln für Stufe 2**, unabhängig vom Anbieter:

- Alle Felder dürfen leer bleiben; Regel im Prompt: **nicht gesagt → leer, nicht raten**
- Je befülltem Feld ein **wörtliches Beleg-Zitat** und ein Zeitstempel — damit der Imker im Audio
  nachhören kann, ohne zu suchen
- Alle Auswahlfelder als geschlossene Liste
- **Seuchenfelder werden nie maschinell gesetzt**, nur vorgeschlagen
- Jedes Feld trägt eine Herkunft: `maschinell` / `bestätigt` / `manuell`

Der letzte Punkt gehört ins Datenmodell und nicht in einen späteren Ausbau: Bei einem Bestandesbuch mit
amtlichem Charakter muss nachvollziehbar bleiben, was eine Maschine vorgeschlagen und was ein Mensch
bestätigt hat.

---

## 6. Was andere Imkerei-Apps machen

Untersucht wurden vierzehn Imkerei-Anwendungen im deutschsprachigen und englischsprachigen Raum.

**Das geplante Vorgehen ist fremdvalidiert.** Zwei Anbieter fahren exakt dasselbe Muster — Aufnahme,
nachgereichter Upload, Batch-Erkennung, Sprachmodell füllt die Felder, Originalaufnahme bleibt abrufbar.
Einer zeigt sogar Transkript und Aufnahme nebeneinander an.

**Die Web Speech API ist auch fremdseitig erledigt.** Der einzige Wettbewerber, der darauf setzt, räumt
auf der eigenen Seite ein, dass die Erkennung ohne aktive Verbindung nicht funktioniert. Zusammen mit
den eigenen Feldmessungen ist das eine doppelte Absage.

**Nachahmenswert:** Ein Anbieter erlaubt den **Import fremder Aufnahmen** — von Diktiergeräten oder der
Sprachmemo-App des Telefons. Billig zu bauen, erschliesst aber genau die Imker, die heute schon so
arbeiten. Und mehrere Anbieter empfehlen unabhängig voneinander dasselbe: ein **Ansteckmikrofon am
Kragen** statt des Telefons in der Tasche. Auf 1570 m mit Wind ist das vermutlich der wirksamste einzelne
Qualitätsgewinn — und er kostet fast nichts.

**Zur Erwartungshaltung, unbequem aber wichtig:** In 73 gesichteten Rezensionen der beiden etablierten
deutschsprachigen Apps verlangt **niemand** Spracheingabe. Wo sie existiert, wird sie begeistert
bewertet — von einer sehr kleinen Frühnutzergruppe. Spracheingabe ist also ein starker Unterschied im
Wettbewerb, aber kein nachgewiesener Marktzwang. Da die Aufnahme ohnehin als Rückfall bleibt, ist das
Risiko gut abgefedert.

**Das Zeitfenster ist real, aber es schliesst sich:** Vier deutschsprachige Sprachlösungen sind binnen
zwölf Monaten entstanden, alle noch klein. Verteidigbare Nischen: **Deutschschweizer Sprecher** (dort
hat nachweislich niemand Belege oder Nutzer), **echte Mandantenfähigkeit** (die Wettbewerber sind
Einzelbetriebs-Apps) und ein **schweizrechtskonformes Bestandesbuch**.

---

## 7. Empfehlung ohne Datenschutz-Gewichtung

> ### **ElevenLabs Scribe v2 als Erkenner, plus Sprachmodell-Stufe. Zweitkandidat im Test: AssemblyAI.**

**Begründung:**

Scribe v2 hat den **besten unabhängig gemessenen Wert des ganzen Feldes** (2,2 % Wortfehlerrate) und
gleichzeitig den saubersten Betriebsweg für genau diesen Aufbau: `audio/webm` **und** `audio/opus`
stehen ausdrücklich in der Formatliste, es gibt 1000 Keyterms, Sprechertrennung ohne Aufpreis, und —
in der Gegenprüfung gefunden — einen Parameter `source_url` samt Webhook. Damit lädt die App die Datei
in den Supabase-Speicher, die Edge Function übergibt nur eine signierte Adresse, und **es läuft nie ein
Audio-Byte durch die Function**. Die ganze Speicher- und Zeitlimit-Diskussion entfällt, statt umgangen
zu werden.

Kosten: 4.40 USD im Jahr, mit Fachwortliste 5.40.

**AssemblyAI** liegt praktisch gleichauf: `webm` nativ, 1000 Keyterms, 3,1 % gemessen, EU-Endpunkt zum
selben Preis, 50 USD Startguthaben ohne Kreditkarte. Beide gehören in denselben Feldtest.

**Warum nicht der Erstplatzierte (multimodale LLM, Note 9):** Der Direktweg ist der spannendste
Kandidat und gehört als A/B-Vergleich mitgemessen — aber nicht als Basis. Er erzwingt eine
Formatumwandlung, liefert kein eigenständiges Transkript, und die einzige einschlägige Fundstelle für
Schweizer Hochdeutsch bezieht sich auf eine Modellgeneration, die im Oktober 2026 abgeschaltet wird —
während dieselbe Recherche eine dokumentierte Verschlechterung des Nachfolgers bei Audio findet.

**Warum nicht Soniox** (mit 2.17 USD der günstigste): Technisch stimmig, Kontextfenster von 8000 Token
inklusive, `webm` unterstützt. Aber die unabhängige Beleglage ist die dünnste im ganzen Feld — der
einzige auffindbare Fachforums-Beitrag hat einen einzigen Kommentar, und der verlinkt auf die
Anbieterseite. Als drittes Los im Feldtest gerne, als Basis für ein Produkt zu früh.

---

## 8. Empfehlung mit Datenschutz-Gewichtung

> ### **AssemblyAI über den EU-Endpunkt — mit Mistral Voxtral als strategischem Ausweg.**

Sobald fremde Imkereien die App nutzen, laufen deren Aufnahmen durch den Dienst, und gesprochene
Notizen enthalten unvermeidlich Beiläufiges. Dann gilt das Schweizer Datenschutzgesetz, für EU-Kunden
die DSGVO.

**AssemblyAI** bietet `api.eu.assemblyai.com` mit Verarbeitung und Speicherung in der EU — **zum
gleichen Preis, ohne Freischaltung, ohne Aufpreis**. Damit fällt der Datenschutz-Aufschlag weg, den
andere Anbieter verlangen, und die Empfehlung aus Abschnitt 7 ändert sich nur um einen Hostnamen.

**Warum Voxtral als Ausweg:** Mistral ist ein europäischer Anbieter, und Voxtral steht unter
Apache-2.0-Lizenz — das Modell lässt sich **selbst betreiben**, falls ein Kunde volle Datenhoheit
verlangt. Diese Option hat kein anderer ernsthafter Kandidat. Der Fachwort-Hebel ist für Deutsch
allerdings ausdrücklich als „experimentell" gekennzeichnet; Voxtral ist der Notausgang, nicht der
Hauptweg.

**Was mit Datenschutz-Gewichtung ausscheidet:** ElevenLabs (keine EU-Verarbeitung dokumentiert),
Gemini und OpenAI auf dem Standardweg (USA; bei OpenAI ist die Europa-Region vertrieblich
freizuschalten, nicht selbst buchbar, mit 10 % Aufschlag).

**Und die Schweiz?** Azure hat zwar Rechenzentren in der Schweiz — aber genau dort ist der schnelle
Betriebsmodus **nicht verfügbar**. Schweizer Datenhaltung und der empfohlene Modus schliessen sich
derzeit gegenseitig aus. Ein Schweizer Spezialanbieter existiert, hat aber keine dokumentierte
Schnittstelle und liegt preislich ein bis zwei Grössenordnungen höher — bei Vermarktung entscheidet
das die Frage von allein.

---

## 9. Warum Azure zurückfällt

Azure bleibt ein guter Dienst und landet mit Note 7 im soliden Mittelfeld. Für diesen Anwendungsfall
sprechen aber sechs Befunde dagegen:

1. **Der `de-CH`-Vorteil löst ein Problem, das nicht besteht** (Abschnitt 3.1). Er war der tragende
   Grund der ursprünglichen Wahl.
2. **Die Fachwortliste ist im Sammelbetrieb nicht verfügbar** — nur im schnellen und im
   Echtzeit-Modus. Der Betriebsmodus muss also nach dem Fachwort-Hebel gewählt werden, nicht umgekehrt.
3. **Schweizer Rechenzentren können den schnellen Modus nicht.** Datenhaltung im Land und empfohlener
   Betrieb schliessen sich aus — das entwertet das zweite Argument der ursprünglichen Wahl.
4. **Microsoft räumt selbst ein**, dass bei Sprachen der zweiten Reihe unbekannte Fachwörter versagen,
   und empfiehlt die Wortliste nur *ergänzend* zu einem trainierten Modell. Ein Fehlerbericht dazu läuft
   seit Oktober 2023 mit Beschwerden bis Februar 2026.
5. **Das Training ist teurer und aufwendiger als angenommen:** 40-Sekunden-Schnipsel mit wörtlichem
   Transkript, Modellverfall nach zwei Jahren, rund 471 USD im Jahr allein für das Vorhalten.
6. **Hohe Umbau-Unruhe:** Schnittstellenversionen wurden im März 2026 hart abgeschaltet, ein neues
   Modell nach weniger als fünf Monaten abgekündigt, dazu mehrere Umbenennungen der Produktlinie.

**Azure bleibt der richtige Kandidat**, falls sich später herausstellt, dass akustisches Training doch
gebraucht wird — es ist der einzige grosse Anbieter, der es für Deutsch anbietet. Diese Tür bleibt offen,
weil die Kaskaden-Architektur den Erkenner austauschbar hält.

---

## 10. Vor der Umsetzung zu klären

In dieser Reihenfolge. Die ersten drei sind Entscheidungsblocker.

1. **Prüfmassstab festlegen, bevor verglichen wird.** 20 bis 30 Minuten echte Feldaufnahmen — mit Wind,
   Telefon in der Tasche, beiden Sprechern — von Hand wörtlich abgetippt, dazu die Soll-Formularwerte.
   Zielwerte benennen, etwa: Fachbegriffe zu mindestens 80 % erkannt, kein falsch eingefügter
   Seuchenbegriff, mindestens 60 % der Felder korrekt vorbefüllt. Ohne diese Zahlen ist der Vergleich
   Geschmackssache.
2. **Vollständigkeit vor Genauigkeit prüfen** (Abschnitt 3.4). Hört das Transkript beim letzten
   gesprochenen Satz auf?
3. **Die Aufnahmeseite mitmessen** — sie kostet fast nichts und schlägt womöglich jede Anbieterwahl:
   dieselbe Szene bei 24, 32 und 64 kbit/s, Telefon in der Tasche gegen Ansteckmikrofon am Kragen.
   **Bluetooth-Headsets ausdrücklich ausschliessen** — deren Freisprechmodus schaltet auf Schmalband.
4. **Mindestens zwei Dienste in denselben Test.** Kosten im Cent-Bereich, liefert aber die einzige
   belastbare Aussage für diese Stimme und dieses Vokabular.
5. **Die Extraktionsstufe als eigenes Stück spezifizieren** — Schema, Leerfeld-Regel,
   Negationsbehandlung, Konfidenz je Feld, Herkunftskennzeichnung. Gehört in die erste Migration, nicht
   in einen späteren Ausbau.
6. **Warteschlange, Wiederholung und Kontingent festlegen**, bevor Migrationen geschrieben werden:
   Statusautomat, Zähler für Versuche, Schutz gegen Doppelabrechnung, und ein Minutenkontingent je
   Betrieb, das **vor** dem Anbieteraufruf greift. Kein Anbieter hat eine harte Ausgabengrenze — die muss
   aus der eigenen Datenbank kommen.
7. **Plattformzusage klären:** iOS nimmt nicht im `webm`-Container auf, und der Kunstgriff mit dem
   stillen Dauerton ist dort ungetestet. Das Pfadmuster im Speicher entsprechend offen halten.
8. **Löschpfad vollständig denken** — eigener Speicher *und* Auftrag beim Anbieter. Für Fremdmandanten
   muss beides nachweisbar sein.
9. **Entscheiden, was mit der ausgelieferten Spracheingabe geschieht.** Bleibt sie neben dem
   Tonmitschnitt bestehen, verdoppelt sich die Testfläche.

---

## 11. Methodik und Grenzen dieser Recherche

**Umfang:** 31 Recherche-Agenten, rund 1800 Quellenabrufe. 16 Anbieter-Steckbriefe, 8
Querschnittsachsen (Imkerei-Apps, Schweizer Akzent, Fachwortmechanismen, Lernfähigkeit,
Marktentwicklung, Preise, Offline-Betrieb, Sprachmodelle mit Audio-Eingang), anschliessend sechs
adversariale Gegenprüfungen mit dem ausdrücklichen Auftrag, die bestbewerteten Steckbriefe zu
**widerlegen**, nicht zu bestätigen.

**Ergebnis der Gegenprüfung: drei von sechs Steckbriefen wurden in Teilen widerlegt.** Gefunden wurden
unter anderem die stille Trunkierung bei den OpenAI-4o-Modellen, ein falscher Standardwert bei
AssemblyAI (Sprache steht auf Englisch, wenn man sie nicht setzt), ein Codec-Wechsel, der als
harmloser Formatwechsel dargestellt war, und ein Beweisbruch bei der einzigen Fundstelle zu Schweizer
Hochdeutsch. Ohne diese Stufe wären mindestens zwei Fehler in die Empfehlung eingeflossen.

**Was diese Recherche nicht leisten kann:**

- **Es gibt für keinen einzigen Anbieter eine unabhängige Wortfehlerrate für Deutsch.** Alle
  vergleichbaren Messungen sind englischsprachig. Für Hochdeutsch mit Schweizer Akzent existiert
  nirgends eine Zahl.
- **Die Wirksamkeit der Fachwort-Mechanismen ist bei keinem Anbieter quantifiziert** — für keine
  Sprache. Dass eine Wortliste existiert, ist belegt; dass sie „Weiselzellen" rettet, ist Annahme.
- **Anbieter-Praxistests in diesem Segment sind teilweise nachweislich fabriziert.** Reichweitenangaben
  auf Werbeseiten weichen um Grössenordnungen von den App-Store-Daten ab.

**Daraus folgt der wichtigste methodische Satz dieses Dokuments:**

> Für Genauigkeit und Fachworterkennung sind die **eigenen Feldmessungen die beste verfügbare
> Datenquelle** — besser als alles öffentlich Publizierte. Sie gehören systematisch fortgeführt und
> protokolliert.

Ein Feldtest mit zehn echten Aufnahmen kostet bei jedem Kandidaten unter einem Franken und beantwortet
in einer Stunde, was keine Recherche der Welt beantworten kann.
