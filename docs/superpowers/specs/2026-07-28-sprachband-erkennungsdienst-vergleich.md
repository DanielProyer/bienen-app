# Sprachband: welcher Erkennungsdienst? — Entscheidungsvorlage

**Stand:** 2026-07-28 · **Status:** offen, wartet auf Entscheid
**Vorgeschichte:** [2026-07-28-sprachband-durchsicht-design.md](2026-07-28-sprachband-durchsicht-design.md)

## Warum überhaupt ein Dienst

Der Feldtest (Testseite `web/sprachtest.html`, Fassungen F1–F10) hat die Web
Speech API als Grundlage für ein Dauerband **ausgeschlossen**. Der massgebliche
Lauf: 17 Minuten, **4 von 5 Prüfungen verpasst**, eine Phase von 353 Sekunden
ohne jede Erkennung. Chrome bricht auf Android alle rund fünf Sekunden ab
(187 Abbrüche im Lauf) und geht nach einigen Minuten ganz taub — das Mikrofon
öffnet weiter, aber es kommt nichts mehr durch.

Was der Test **positiv** geklärt hat und für jede Lösung weitergilt:

| Frage | Ergebnis |
|---|---|
| Erkennungsqualität der Fachsprache | gut: Varroa, Drohnenbrut, Ableger, „Königin auf Wabe 8" ✓ |
| Verhörer | Weiselzellen → „weissenzellen", Milben → „Minuten", Schwarmtrieb → „schwadentrieb" |
| Signalton der Erkennung | verschwindet, wenn das Handy stumm geschaltet ist ✓ |
| Mikrofon-Zugriff | auf Android **exklusiv**: Mitschnitt und Erkennung schliessen sich aus |
| Bildschirmsperre | beendet die Erkennung — Wake Lock ist für **jede** Lösung nötig |

Der vorletzte Punkt ist der wichtigste fürs Design: Solange die Erkennung über
die Web Speech API läuft, kann kein Mitschnitt parallel laufen. Hält die App den
Mikrofon-Strom dagegen selbst, kann sie daraus **gleichzeitig** aufnehmen und
zur Erkennung schicken — ein Zugriff, kein Konflikt.

## Mengengerüst

Vom Betreiber vorgegeben: **8 Völker · 15 Minuten pro Durchsicht · 10 Durchsichten
pro Jahr** → 8 × 10 × 15 min = **1200 Minuten (20 Stunden) Sprache im Jahr**.

Für die spätere Vermarktung: Pro zusätzlichem Betrieb dieser Grösse kommen
20 Stunden dazu. Bei 100 Betrieben also 2000 Stunden — dann gehört der Posten in
die Preiskalkulation, bleibt aber im dreistelligen Franken-Bereich pro Jahr.

## Kosten (Stand Juli 2026, vor Umsetzung neu prüfen)

| Weg | Preis/Min | 1 Durchsicht (15 min) | **pro Jahr** |
|---|---|---|---|
| Häppchen-Batch, gpt-4o-mini-transcribe | $0.003 | ~3 Rp. | **~CHF 3** |
| Häppchen-Batch, Whisper / gpt-4o-transcribe | $0.006 | ~7 Rp. | **~CHF 6** |
| Echtes Streaming, Deepgram Nova-3 + Fachwortliste | $0.0090 | ~11 Rp. | **~CHF 11** |
| Echtes Streaming, OpenAI Realtime | $0.017 | ~20 Rp. | **~CHF 20** |

**Die Kosten entscheiden nichts.** Alle Wege liegen unter zwanzig Franken im
Jahr — weniger als ein einzelner Mittelwand-Karton. Damit entscheiden
Datenschutz, Fachwort-Erkennung und Aufwand.

## Streaming oder Häppchen?

„Echtes" Streaming (WebSocket, Erkennung im Sekundentakt) kostet das Zwei- bis
Dreifache und braucht deutlich mehr Technik. Die Alternative: Die App schneidet
mit und schickt **alle 20 bis 30 Sekunden ein Häppchen** zur Batch-Erkennung.

Für die Durchsicht reicht das. Der Imker hat die Wabe in beiden Händen und
schaut ohnehin nicht aufs Handy; der Zweck von „direkt erkennbar" ist, dass er
**noch während der Durchsicht** merkt, ob etwas angekommen ist — und dafür sind
dreissig Sekunden Verzug unerheblich. Gegen echtes Streaming spricht ausserdem,
dass jede Netzlücke am Bienenstand die Verbindung reisst, während sich ein
Häppchen einfach später nachschicken lässt.

**Empfehlung: Häppchen-Batch.** Echtes Streaming bleibt eine spätere Option,
falls sich der Verzug im Betrieb doch als störend erweist.

## Datenschutz — das eigentliche Kriterium

Sprachaufnahmen aus dem Bienenstand sind für sich harmlos. Relevant wird es
durch zwei Dinge: Die App ist **mandantenfähig und soll vermarktet werden**, und
gesprochene Notizen enthalten unvermeidlich Beiläufiges (Namen, Orte, Privates).
Damit gilt für Fremdmandanten das Schweizer DSG und für EU-Kunden die DSGVO.

| Anbieter | Sitz | EU-Verarbeitung |
|---|---|---|
| OpenAI | US | nein (Standardweg) |
| Deepgram | US | nein (Standardweg) |
| AssemblyAI | US | **ja**, über `api.eu.assemblyai.com` |
| Soniox | — | **ja**, Sovereign Cloud in EU-Hoheit |
| Speechmatics | UK/EU | ja; beste gemessene Deutsch-Qualität (2,2 % Fehlerrate) |
| Whisper selbst betrieben | eigener Server | vollständig, aber eigener Betrieb |

Für den Eigenbetrieb (ein Mandant, der Betreiber selbst) ist jeder Weg
vertretbar. **Für die Vermarktung ist EU-Verarbeitung faktisch Pflicht** — und
sie nachträglich einzuziehen ist teurer, als sie gleich zu wählen.

## Fachwörter

Das ist der Punkt, an dem die Erkennung im Feld gescheitert ist
(„weissenzellen"). Alle ernsthaften Dienste können dagegen etwas tun:

- **Deepgram** — Keyterm Prompting, bis 100 Begriffe, +$0.0013/min
- **OpenAI** — `prompt`-Parameter, rund 224 Token Fachwortliste, ohne Aufpreis
- **AssemblyAI / Speechmatics** — Custom Vocabulary bzw. Wortlisten

Eine Liste mit rund vierzig Imkerei-Begriffen (Weiselzellen, Drohnenbrut,
Varroa, Ableger, Zander, Dadant, Mittelwand, Windel, Ameisensäure, Oxalsäure …)
deckt das Feld ab. **Zusätzlich braucht es eine eigene Korrekturschicht** in der
App, die bekannte Verhörer zurückbiegt — die kostet nichts und fängt auch ab,
was der Dienst falsch liefert.

## Empfehlung

**AssemblyAI mit EU-Verarbeitung, Häppchen-Batch alle 20–30 Sekunden, mit
Fachwortliste.** Begründung: erfüllt die Datenschutz-Anforderung der geplanten
Vermarktung, hat Custom Vocabulary, und der Preisunterschied zum billigsten Weg
liegt im einstelligen Franken-Bereich pro Jahr — also unterhalb jeder Relevanz.

Wer den Eigenbetrieb schnell will und die Vermarktung später neu bewerten mag,
fährt mit **OpenAI Batch** günstiger und einfacher; der Wechsel bleibt möglich,
weil hinter einer eigenen Schnittstelle gekapselt.

## Was vor der Umsetzung zu klären ist

1. **Preise und EU-Endpunkt beim gewählten Anbieter direkt nachprüfen** — diese
   Vorlage stützt sich auf Websuche, nicht auf die Preisseite des Anbieters.
2. **Schlüssel setzt der Betreiber selbst** (Supabase Secret, nie im Repo, nie im
   Client) — die Anfrage läuft über eine Edge Function, nicht aus der App.
3. **Kurzer Qualitätstest vor dem Bau**: dieselben Sätze wie im Feldtest, gegen
   den gewählten Dienst, mit und ohne Fachwortliste. Erst danach implementieren.
4. **Aufbewahrung klären**: Werden Aufnahmen nach der Erkennung gelöscht? Für
   Fremdmandanten muss die Antwort „ja, sofort" lauten und dokumentiert sein.
