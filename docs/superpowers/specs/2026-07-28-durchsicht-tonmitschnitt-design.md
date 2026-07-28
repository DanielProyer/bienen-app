# Durchsicht mit Tonmitschnitt — Design

**Stand:** 2026-07-28 · **Status:** freigegeben, bereit für den Umsetzungsplan
**Ersetzt:** [2026-07-28-sprachband-durchsicht-design.md](2026-07-28-sprachband-durchsicht-design.md) (Live-Erkennung, im Feld gescheitert)
**Vorarbeit:** [2026-07-28-sprachband-erkennungsdienst-vergleich.md](2026-07-28-sprachband-erkennungsdienst-vergleich.md)

## Der Kerngedanke

Während der Durchsicht läuft **ein Tonmitschnitt pro Volk**. Er wird nicht live
ausgewertet. Beim Abschluss der Durchsicht wird die Aufnahme transkribiert, die
Felder werden vorbefüllt, der Imker prüft und korrigiert. **Die Aufnahme bleibt
liegen** — wo die Erkennung danebenlag, hört er nach und trägt von Hand ein.

Diese Umkehr ist der eigentliche Entwurfsgewinn: Die Erkennung muss nicht mehr
zuverlässig sein, sondern nur hilfreich. Sie spart Tipparbeit; verlieren kann
nichts gehen. Damit fällt der Anspruch weg, an dem der erste Entwurf gescheitert
ist — und mit ihm die gesamte Live-Technik.

## Was der Feldtest ergeben hat

Zehn Testfassungen auf zwei eigenen Seiten (`web/sprachtest.html` F1–F10,
`web/tontest.html` T1–T3), alle Läufe auf Android 10 / Chrome 150.

**Die Web Speech API trägt kein Dauerband.** Massgeblicher Lauf: 17 Minuten,
4 von 5 Prüfungen verpasst, 353 Sekunden am Stück ohne jede Erkennung, 187
erzwungene Abbrüche. Chrome geht nach einigen Minuten taub — das Mikrofon öffnet
weiter, aber es kommt nichts mehr durch.

**Das Mikrofon ist auf Android exklusiv.** Solange die Web-Speech-Erkennung
läuft, bekommt ein paralleler Mitschnitt nichts (Chromium 41083534). Hält die App
den Strom dagegen selbst, gibt es nur einen Zugriff und der Konflikt entfällt —
ein Argument, das erst durch den Verzicht auf Live-Erkennung nutzbar wird.

**Der Mitschnitt überlebt die Bildschirmsperre nur mit Hilfe.** Ohne: nach rund
einer Minute friert Android den Tab ein (T1: von 20:14 Laufzeit blieben 9:50 Ton,
grösste Lücke 389 s). Es ist kein Verbot, sondern das Einfrieren untätiger Tabs —
und **einen Tab, der Ton abspielt, friert Chrome nicht ein**. Mit einem unhörbaren
Dauerton (30 Hz, Pegel 0.003) lief T3 **lückenlos**, davon 3:29 am Stück mit
dunklem Bildschirm in der Tasche.

**Datenmenge:** 24 kbit/s Opus ergeben gemessen **0,08 MB je Tonminute** — Opus
senkt die Rate bei Stille selbsttätig, und eine Durchsicht ist grösstenteils
still. Pro Volk rund 1,2 MB, bei 8 Völkern und 10 Durchsichten **rund 96 MB im
Jahr**. Der Speicher ist damit auf Jahre hinaus kein Thema.

**Erkennungsqualität der Fachsprache** (aus den Sprachläufen, gilt weiter):
Varroa, Drohnenbrut, Ableger, „Königin auf Wabe 8", „Brut in allen Stadien",
„Futter reicht noch zwei Wochen" kamen korrekt an. Verhört wurden
**Weiselzellen → „weissenzellen"**, **Milben → „Minuten"**,
**Schwarmtrieb → „schwadentrieb"**.

## Ablauf

1. **Durchsicht starten** — ein Knopf, der später handschuhtauglich vergrössert
   wird. Er startet Aufnahme *und* Zeitmessung. Kein automatischer Start: Ein
   Mikrofon, das ungefragt läuft, gehört bewusst eingeschaltet.
2. **Arbeiten und reden.** Die Seite hält sich mit dem stillen Dauerton wach; das
   Handy darf dunkel in der Tasche liegen. Ein sichtbarer Zustand („Aufnahme
   läuft, 4:12") gehört auf den Schirm, damit niemand im Zweifel ist.
3. **Durchsicht beenden** — Aufnahme stoppt, Dauer steht fest (gemessen, vor dem
   Speichern korrigierbar).
4. **Auswerten**: Aufnahme hochladen → Edge Function → Azure Speech →
   Korrekturschicht → Felder vorbefüllt.
5. **Prüfen und speichern.** Die Aufnahme bleibt abrufbar; ein Knopf „sauber
   eingetragen" gibt sie zum Löschen frei.

Schlägt der Upload fehl (kein Netz am Bienenstand), bleibt die Aufnahme lokal
liegen und wird beim nächsten Netz nachgereicht. Die Durchsicht lässt sich auch
ohne Transkription speichern — die Erkennung ist Zugabe, nie Voraussetzung.

## Erkennung: Azure Speech, Region Schweiz

Gewählt, weil es als einziger grosser Dienst **akustische Anpassung** anbietet
und eine Region **Switzerland North** hat — die Daten bleiben im Land, was für
die geplante Vermarktung stärker wiegt als jede EU-Lösung. Kosten in derselben
Grössenordnung wie alle Alternativen: deutlich unter zwanzig Franken im Jahr.

Der Schlüssel wird als Supabase-Secret gesetzt (**vom Betreiber selbst**, nie im
Repo, nie im Client). Die Anfrage läuft über eine Edge Function.

## Lernfähigkeit in zwei Stufen

**Stufe 1 — Korrekturschicht in der App.** Eine Verhörer-Tabelle, geführt **pro
Person** innerhalb des Betriebs: Daniel und Lorenz sprechen unterschiedlich, und
später jeder Kunde anders. Korrigiert jemand „weissenzellen" zu „Weiselzellen",
merkt die App sich das Paar und wendet es künftig selbst an. Wirkt ab der ersten
Korrektur, kostet nichts, ist anbieterunabhängig, von Haus aus mandantenfähig.
Die gelernten Paare sind in den Einstellungen einsehbar und löschbar — sonst
schleppt man eine falsche Regel jahrelang mit.

Zusätzlich geht eine **statische Fachwortliste** (rund 40 Begriffe) als Custom
Vocabulary an Azure mit.

**Stufe 2 — akustisches Training auf die Stimme.** Braucht Paare aus Ton und
korrektem Text. Genau die entstehen in Stufe 1 von selbst: Die Aufnahme liegt
vor, der korrigierte Text auch. Nach einer Saison ist das Material beisammen; ob
es sich lohnt, entscheidet sich dann mit Daten statt mit Vermutungen. Ein
Trainingslauf kostet rund fünfzig Dollar.

## Datenmodell

**Migration S01 — `durchsicht_aufnahmen`**
`id`, `betrieb_id` (NOT NULL, Default `private.aktive_betrieb_id()`),
`durchsicht_id`, `pfad`, `dauer_s`, `groesse_b`, `status`
(`aufgenommen` / `transkribiert` / `eingetragen`), `transkript`,
`erkannt_am`, `created_by`, `updated_by`, `created_at`, `updated_at`.
RLS nach Hausmuster: SELECT = Mitglied, Schreiben = owner/editor,
`set_row_actor`-Trigger.

**Migration S02 — Bucket `durchsicht-audio`**, privat, Zugriff über signierte
URLs, Pfadmuster `<betrieb_id>/<durchsicht_id>/<uuid>.webm`.

**Migration S03 — `sprach_korrekturen`**
`id`, `betrieb_id`, `person_id` (der Benutzer, nicht der Betrieb — das ist der
Kern der Personalisierung), `falsch`, `richtig`, `treffer` (Zähler),
`zuletzt_am`. Eindeutig über (`betrieb_id`, `person_id`, `falsch`).

**Migration S04 — Aufbewahrung** in den Betriebseinstellungen:
`aufnahme_aufbewahrung_tage` (Default `null` = unbegrenzt),
`aufnahme_loeschen_nach_eintrag` (Default `false`).
Für Fremdmandanten ist die Obergrenze **ein Jahr** — begründet durch das
Sprachmodell-Training, nicht durch Speicherbedarf.

> Migrationen werden **einzeln zur Freigabe vorgelegt**, keine läuft ungefragt
> gegen die Produktionsdatenbank.

## Einstellungen: aus einer Seite wird ein Bereich

Die heutige Seite „Betriebs-Einstellungen" ist bereits ein Sammelbecken. Sie
wird zum Einstieg in einen Bereich mit Unterseiten:

| Unterseite | Inhalt | wann |
|---|---|---|
| **Betrieb** | Saison-Offset, Winterfutter, Ernten, Sommerbehandlung, Vermehrung, Phänologie | vorhanden, wird verschoben |
| **Aufnahme & Sprache** | Aufbewahrung, „nach Eintrag löschen", Tonqualität, Erkennung an/aus, Sprache, **gelernte Verhörer pro Person** | **jetzt** |
| **Feld & Bedienung** | Bildschirm wachhalten (Rückfall), später grosse Schaltflächen, Schriftgrösse, Kontrast, Vibration | **jetzt** (nur Wachhalten) |
| **Daten & Aufbewahrung** | Fristen für Aufnahmen *und Fotos* (die haben heute keine), Backup-Export | später |
| **Über die App** | Version, Diagnose-Protokoll | später (Version ist seit v1.64 da) |

## Was bewusst nicht gebaut wird

Keine Live-Erkennung, keine Sprachkommandos während der Arbeit, keine
Sprachausgabe als Rückmeldung. Alles drei stand im ersten Entwurf und ist an der
Technik oder am Nutzen gescheitert. Falls der Verzug beim Auswerten im Betrieb
doch stört, ist der nächste Schritt Häppchen-Erkennung alle 20–30 Sekunden —
nicht die Rückkehr zur Web Speech API.

## Vor der Umsetzung zu klären

1. **Azure-Preise und Verfügbarkeit von Switzerland North** direkt beim Anbieter
   prüfen. Diese Vorlage stützt sich auf Websuche.
2. **Qualitätsvergleich vor dem Bau**: dieselben Sätze wie im Feldtest gegen
   Azure, mit und ohne Fachwortliste. Erst wenn „Weiselzellen" ankommt, lohnt
   die Umsetzung. Diesmal wird gemessen, bevor gebaut wird.
3. **Löschpfad prüfen**: Wird eine Aufnahme wirklich aus dem Bucket entfernt,
   nicht nur der Datensatz? Für Fremdmandanten muss das nachweisbar sein.
