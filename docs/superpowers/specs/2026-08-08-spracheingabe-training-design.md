# Screen „Spracheingabe" — Erkennervergleich und Sprachtraining

**Datum:** 2026-08-08 · **Status:** von Daniel freigegeben · **Schiene:** App

Grundlage: `2026-07-28-durchsicht-tonmitschnitt-design.md` (Tonmitschnitt, Migrationen S01–S04),
`2026-07-28-erkenner-vergleich.md` (Plan, Task 6), Entscheide D-94, D-98b, D-99b bis D-99e.
Fremdprojekt als Vorbild: Heineken `ADR-0004` und `2026-08-08_Namenstest-Synthetisch.md`.

## Ziel

Ein Screen in der App, auf dem Daniel und Lorena **gezielt Fachwörter und ganze Sätze
einsprechen**, sofort sehen, was die Erkennung daraus macht, und die App aus den Abweichungen
lernen lassen. Der Screen führt zusammen, was heute auf der öffentlichen Testseite
`web/erkennervergleich.html` steht, und erweitert es um den Trainingsteil.

## Was „lernen" hier heisst — und was nicht

**Es wird kein Modell nachtrainiert.** D-99b hat das akustische Training mit Gründen gestrichen:
Azure verlangt Audioschnipsel bis 40 Sekunden mit wörtlichem Transkript, das Modell verfällt nach
zwei Jahren, und allein das Vorhalten eines Endpunkts kostet rund 471 USD im Jahr.

Gelernt wird stattdessen ein **Verhörer-Verzeichnis pro Person**: „so klingt es bei mir → so heisst
es richtig". Es wirkt an drei Stellen — als Nachkorrektur auf dem Transkript, als Eintrag in der
Wortliste des Erkenners und im Glossar der Sprachmodell-Stufe. Das entspricht D-98b und ist
anbieterunabhängig.

> **Nebenwirkung, die eine geschlossene Tür wieder öffnet.** D-99b wurde auch damit begründet, dass
> die nötigen Paare aus Ton und wörtlichem Text nicht von selbst anfallen. In diesem Screen fallen
> sie an — jede Drill-Probe ist genau so ein Paar. Ob daraus je ein Feinschliff eines offenen
> Modells wird, entscheidet sich später mit Daten; der Bestand entsteht unabhängig davon und
> gehört dem Betrieb.

## Warum das jetzt gebaut wird

Der Erkenner-Plan verlangt in **Task 6** vom Betreiber ein Gold-Set: echte Aufnahmen, von Hand
abgetippt, mit Soll-Werten. Dieser Screen erzeugt genau das — nur ohne Abtippen, weil bei einer
Vorgabe der Soll-Text bereits bekannt ist. Der Screen läuft dem Plan also nicht davon, sondern
erledigt dessen offenen Punkt.

## Bedienung

Route `/spracheingabe`, drei Segmente nach dem Muster des Material-Moduls.

### Segment „Üben"

Eine Karte steht gross im Bild — ein Fachwort oder ein ganzer Satz —, darunter der Aufnahmeknopf.
Nach dem Sprechen antwortet **ein** Anbieter innerhalb weniger Sekunden; die Karte färbt sich grün
oder rot und zeigt, was verstanden wurde. Danach die nächste Karte.

Die Reihenfolge ist nicht die Listenreihenfolge: Bevorzugt kommt, was zuletzt schlecht lief oder
lange nicht dran war. Ein Zähler zeigt den Fortschritt der Runde.

### Segment „Frei sprechen"

Kein Vorgabetext. Nach der Aufnahme erscheint das Transkript **bearbeitbar**. Was korrigiert wird,
ergibt beim Speichern über einen Wortvergleich die Lautvarianten; die korrigierte Fassung wird zum
Soll-Text der Probe.

Dieser Weg schliesst die Lücke, die der Drill offen lässt: Abgelesene Sätze klingen anders als
freie Rede. Beide Wege füllen dieselben Tabellen.

### Segment „Auswertung"

Bestand (Proben, Minuten), der Knopf **„Bestand neu messen"**, die Anbietertabelle mit Trefferquote
und Wortfehlerrate, und die Liste der gelernten Regeln — einsehbar, abschaltbar, löschbar. Ohne
diese Liste schleppt man eine falsch gelernte Regel jahrelang mit.

## Datenmodell — vier Migrationen, einzeln zur Freigabe

Alle Tabellen nach Hausmuster: `betrieb_id uuid NOT NULL` mit Default `private.aktive_betrieb_id()`,
`created_by`/`updated_by`, `created_at`/`updated_at`, `set_row_actor`-Trigger, stabile errcodes.

**T01 `sprach_karten`** — der Übungsstoff.

| Spalte | Bedeutung |
|---|---|
| `art` | `wort` oder `satz` |
| `soll_text` | was gesprochen werden soll |
| `pruefbegriffe text[]` | bei Sätzen: welche Fachwörter gezählt werden |
| `herkunft` | `start` · `verhoerer` · `eigen` |
| `person_id` | **darf leer sein** — leer heisst: gilt für alle im Betrieb |
| `aktiv` | abschaltbar statt löschbar, damit Messungen ihren Bezug behalten |

Startbestand: die 30 Begriffe aus `fachwoerter.ts` als Wortkarten plus **acht bis zwölf Satzkarten**
aus echten Durchsicht-Formulierungen. Karten aus einem Verhörer sind immer persönlich.

**Zwei Messgrössen, je nach Kartenart.** Bei einer Wortkarte zählt allein der Treffer (der Begriff
steht im Transkript oder nicht) — eine Wortfehlerrate über ein einzelnes Wort wäre nur eine
umständliche Schreibweise desselben. Bei einer Satzkarte zählen beide: der Treffer für die
markierten Fachbegriffe, die Wortfehlerrate für den Satz als Ganzes. Sonst bliebe unbemerkt, wenn
ein Erkenner zwar alle Fachwörter trifft, den Rest des Satzes aber zerlegt.

**T02 `sprach_proben`** + privater Bucket `sprach-proben` — jede Aufnahme.

`person_id` (wer gesprochen hat, NOT NULL), `karte_id` (leer = frei gesprochen), `pfad`, `dauer_ms`,
`groesse_b`, `mime`, `modus` (`drill`/`frei`).

**`soll_text` wird als Schnappschuss mitgespeichert**, nicht nur über `karte_id` verwiesen. Ändert
sich die Karte später, bleiben alte Messungen auswertbar — sonst misst man gegen einen Text, der
beim Sprechen gar nicht dastand.

Pfadmuster `<betrieb_id>/<person_id>/<uuid>.webm`, Zugriff über signierte URLs.

**T03 `sprach_ergebnisse`** — je Probe × Anbieter × Wortliste-an/aus eine Zeile.

`probe_id`, `anbieter`, `modell`, `mit_wortliste bool`, `transkript`, `treffer_quote numeric`,
`wortfehlerrate numeric`, `dauer_ms`, `gemessen_am`.

**Bewusst ohne Eindeutigkeitsregel über die Zeit.** Eine zweite Messung derselben Probe legt eine
neue Zeile an, statt die erste zu überschreiben. Das ist der Zweck der Tabelle: Ein neuer Anbieter
oder eine neue Modellgeneration wird gegen den vorhandenen Bestand gemessen, und die Frage „war
ElevenLabs im Januar besser als im Juli?" beantworten Daten statt Erinnerung.

**T04 `sprach_korrekturen`** — setzt S03 der Tonmitschnitt-Spec um.

`person_id`, `falsch`, `richtig`, `treffer int`, `zuletzt_am`, `quelle`
(`training`/`durchsicht`/`manuell`), `aktiv`. Eindeutig über (`betrieb_id`, `person_id`, `falsch`).

### Personenbezug ist hier eine Verschärfung, keine Formalie

`sprach_proben`, `sprach_ergebnisse` und `sprach_korrekturen` sind **personenbezogen wie
`benachrichtigungs_einstellungen`**: nur die eigene Zeile, auch für Mitglieder desselben Betriebs.
Eine Sprachaufnahme ist die Stimme eines Menschen; sie geht Kollegen nichts an.

`sprach_ergebnisse` **muss dieselbe Einschränkung erben**, obwohl es wie eine reine Messtabelle
aussieht: Es enthält das Transkript, also den Wortlaut des Gesagten. Wäre es nach Betriebsmuster
lesbar, könnte jedes Mitglied nachlesen, was ein anderes gesprochen hat — der Schutz auf
`sprach_proben` wäre dann wertlos. Die Policy hängt deshalb an der zugehörigen Probe, nicht an der
Ergebniszeile selbst.

Das ist zugleich fachlich richtig: Eine über mehrere Sprecher gemittelte Trefferquote wäre
irreführend, weil Daniel und Lorena unterschiedlich sprechen (D-98b). Messwerte gehören zur Stimme,
nicht zum Betrieb.

`sprach_karten` folgt als einzige dem normalen Betriebsmuster — ein Übungsstoff ohne Stimme darin.

## Datenfluss

**Drill:** aufnehmen → Bucket → Zeile in `sprach_proben` → Live-Anbieter über die Edge Function →
Zeile in `sprach_ergebnisse` → Treffer und Wortfehlerrate über reine Dart-Funktionen → grün/rot.

**Frei:** aufnehmen → Bucket → Probe → Live-Anbieter → Transkript bearbeitbar → beim Speichern
Wortvergleich → Korrekturvorschläge → `soll_text` = korrigierte Fassung.

**Vollvergleich:** über die gespeicherten Proben, je gewähltem Anbieter, mit und ohne Wortliste.
Läuft sichtbar im Vordergrund mit Fortschritt und Abbruch — kein Cron, kein Hintergrundlauf.
**Vor dem Start steht die Kostenangabe** (Minuten × Anbieter × Ansatz je Minute). Eine Funktion,
die im Hintergrund fremdes Geld ausgibt, ist keine gute Funktion.

## Lernregeln

**Eine Regel entsteht nicht aus einem einzelnen Fehltreffer.** Erst wenn derselbe Verhörer
**mindestens zweimal** auftritt, wird er zur Korrekturregel. Ein einzelner Fehltreffer erzeugt
stattdessen eine neue Übungskarte.

Begründung: Räuspern, ein Windstoss oder ein verschlucktes Wort erzeugen einmalige Abweichungen.
Würde daraus sofort eine Regel, lernte die App Zufall — und wendete ihn danach auf jedes Transkript
an. Die Schwelle ist der billigste verfügbare Schutz dagegen.

Es gelten weiter die Listenregeln aus D-99d: **keine Seuchenbegriffe** (Wortlisten können Begriffe
einfügen, die nie gesagt wurden; ein halluzinierter Faulbrut-Befund wäre gravierender als ein
fehlender) und **keine Alltagswörter mit Sonderbedeutung** (Beute, Windel, Stifte, Schied).
Entsteht ein Vorschlag für einen solchen Begriff, wird er abgelehnt und begründet.

## Anwendung der Korrektur

Eine reine Funktion nimmt Transkript und Regeln und gibt **zwei** Dinge zurück: den korrigierten
Text **und die Liste der Ersetzungen** mit Position, Vorher und Nachher.

Die Liste ist keine Zugabe, sie ist der Grund für die gewählte Bauform. Nur mit ihr lässt sich jede
Stelle markieren, antippen und einzeln zurücknehmen. Still ersetzen wurde verworfen: In einem
Bestandesbuch mit amtlichem Charakter muss nachvollziehbar bleiben, was eine Maschine vorgeschlagen
hat — dieselbe Forderung, die D-99d als Herkunftsspalte je Feld stellt.

## Anbieter und Edge Function

Die bestehende Function `transkription` bekommt einen **zweiten Eingang**: Neben dem Testwort für
die öffentliche Testseite akzeptiert sie ein gültiges Nutzer-JWT für den App-Weg. Dasselbe Muster
fährt `taeglicher-ueberblick` bereits (Cron-Secret bzw. selbst validierter Nutzer-JWT); `verify_jwt`
bleibt deshalb `false`, weil die Function ihre Berechtigung selbst prüft.

Der Live-Anbieter für den Drill ist einstellbar. **Vorgabe bis zum Entscheid D-100: ElevenLabs** —
als einziger der drei antwortet er synchron, ohne Warteschlange und ohne Batch-Abfrage. Danach wird
es der gemessene Sieger. Wer ausschliesslich Schweizer Verarbeitung will, stellt auf Infomaniak um
und nimmt rund fünf Sekunden je Karte in Kauf.

## Aufnahme im Browser

Flutter Web über `dart:js_interop` mit VM-Stub, nach dem Muster von `ohne_metadaten.dart` —
erprobtes Gelände in diesem Repo. Format `audio/webm;codecs=opus` mit 24 kbit/s, wie im Tontest
gemessen (0,08 MB je Tonminute).

Den stillen 30-Hz-Dauerton aus D-98c braucht es hier **nicht**: Er löst das Einfrieren von Tabs im
Hintergrund, und beim Drill bleibt der Bildschirm an.

## Aufbewahrung

**Trainingsproben bleiben unbegrenzt.** Sie sind bewusst und von der sprechenden Person selbst
erzeugt, und ihr Wert liegt gerade im Bleiben — ein Bestand, der sich jährlich selbst löscht, kann
keinen neuen Anbieter gegen die Vergangenheit messen.

Das ist die begründete Ausnahme zur Ein-Jahres-Grenze aus **S04**, die für *Durchsichts*aufnahmen
gilt: Die entstehen nebenbei, können Dritte enthalten und sollen nach der Übernahme verschwinden
können. Beide Regeln in einer Tabelle zu führen hiesse, die Löschregel dauernd zu durchlöchern —
der Grund, warum der Trainingskorpus eigene Tabellen bekommt.

Löschbar einzeln und komplett („alle meine Trainingsdaten löschen"), ohne fremde Zeilen zu
berühren.

## Fehlerfälle

| Fall | Verhalten |
|---|---|
| Kein Mikrofon / Erlaubnis verweigert | Meldung **an Ort und Stelle**, nicht in einem Protokoll ausserhalb des Sichtfelds (D-94) |
| Anbieter fällt aus | Probe bleibt liegen, Ergebnis fehlt, wird beim nächsten Vollvergleich nachgeholt |
| Upload scheitert | Fehler mit Wiederholknopf; die Aufnahme bleibt bis dahin im Speicher |
| Whisper erfindet bei kurzen Karten | Bekannte Schwäche bei Stille; die Wortfehlerrate macht es sichtbar statt es zu verstecken |
| Vorschlag betrifft Seuchen-/Alltagsbegriff | Abgelehnt mit Begründung (D-99d) |

## Tests

Reine Funktionen nach TDD, wie im Repo üblich:

- `wortfehlerrate` — neu
- `korrekturenAnwenden` — neu, gibt Text **und** Ersetzungsliste zurück
- `verhoererAusDiff` — neu, Wortvergleich Transkript gegen korrigierte Fassung
- `zaehleTreffer` — **wird wiederverwendet**, nicht neu gebaut (sieben Tests, zeichengleich zur
  Browserfassung)

Dazu Gateway-Tests gegen einen Fake, ein Wächter für die Zweier-Schwelle (mit einem einzelnen
Fehltreffer darf keine Regel entstehen), ein Wächter für die Ablehnung von Seuchenbegriffen, und
Rollback-DO-SQL-Tests je Migration. `get_advisors(security)` muss 0 neue Findings zeigen.

## Was bewusst nicht gebaut wird

- **Kein akustisches Modelltraining** (D-99b).
- **Keine Offline-Erkennung** auf dem Gerät.
- **Keine automatische Formularbefüllung** — das ist Block D/E des Tonmitschnitts und hängt weiter
  am Messergebnis.
- **Kein Hintergrundlauf** für den Vollvergleich.
- **Keine Mengenbegrenzung je Betrieb.** Bei einem Mandanten unnötig; vor der Vermarktung
  nachzuholen, weil ein Screen, der Anbieteraufrufe auslöst, sonst offen für Missbrauch ist.
- Die Testseite `web/erkennervergleich.html` **bleibt vorerst** und wird erst abgelöst, wenn der
  Screen sich bewährt hat. Sie funktioniert ohne Login und ohne Flutter-Build — das ist bei einer
  Störung wertvoll.

## Bauabschnitte

Der Umfang trägt keinen einzelnen Durchgang. Vorschlag für den Plan, jeder Abschnitt für sich
lauffähig und abnehmbar:

1. **Fundament** — Migrationen T01–T04 (einzeln zur Freigabe), Domänenmodelle, Gateway mit Fake,
   die drei reinen Funktionen nach TDD. Ohne Oberfläche.
2. **Aufnehmen und Üben** — js-interop-Aufnahme, JWT-Eingang der Function, Segment „Üben".
   Ab hier ist der Screen benutzbar.
3. **Frei sprechen** — Transkript bearbeiten, Wortvergleich, Korrekturvorschläge.
4. **Auswertung** — Bestand, Vollvergleich mit Kostenangabe, Regelverwaltung.

## Vor der Umsetzung zu klären

1. **Reihenfolge der Migrationen.** T01–T04 werden einzeln vorgelegt; T02 hängt am Bucket, T03 an
   T02, T04 ist unabhängig und könnte zuerst laufen.
2. **Startsätze.** Die 30 Wortkarten stehen fest; die acht bis zwölf Satzkarten müssen noch
   geschrieben werden. Beste Quelle ist die erste ausgewertete echte Durchsicht — bis dahin
   behelfsweise aus den Formularfeldern des Durchsicht-Wizards abgeleitet.
3. **Löschpfad im Storage.** „Alle meine Trainingsdaten löschen" muss Zeilen **und** Objekte
   entfernen. Der Backup-Vorfall von 2026-07-27 hat gezeigt, wie leicht dabei Waisen entstehen —
   der Löschpfad braucht dieselbe Storage-Gegenprobe wie das Backup.
