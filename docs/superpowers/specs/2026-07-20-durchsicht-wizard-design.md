# Geführte Durchsicht + Waben-Erfassung (Modul 4.3-Ausbau) — Design-Spec (v2)

**Datum:** 2026-07-20 · **Status:** in Review (v2 nach adversarialem Multi-Agent-Review) · **Modul:** 4.3 Durchsicht/Stockkarte (Ausbau) · **Version:** 1.20.0+41
**Anlass:** Das bestehende Durchsicht-Formular ist ein langes Scroll-Formular mit vielen **Number-TextFields** — mit Handschuhen mühsam. Zwei Ziele: (1) **Beurteilung der einzelnen Rähmchen/Waben** und (2) **geführte, handschuh-taugliche Eingabe** (große Ziele, kaum Tastatur).

> **Kern-Insight:** Wer Wabe für Wabe durchgeht, kann Volk-Kennzahlen (v. a. Brutwaben) **ableiten** statt tippen. Aber: die Waben-Erfassung ist **optional/überspringbar** — nicht jede Durchsicht wird Wabe-für-Wabe erfasst.

> **Zerlegung:** **Zyklus 1 (diese Spec) = geführter Wizard + Waben-Erfassung.** **Zyklus 2 (später) = Spracheingabe.**

> **v2-Änderungen (aus dem Review, 28 bestätigte Findings, 3 Blocker):** (1) **Wizard behält ALLE Bestandsfelder** (nichts fällt weg) — verteilt auf 3 Schritte; das alte Formular wird abgelöst, aber vollständig ersetzt (Blocker: 7 Felder wären gedroppt). (2) **Waben-Schritt optional/überspringbar** (Default = Kennzahlen direkt eingeben). (3) **Ableitung überschreibt keine Handwerte** und feuert nur bei genutzten Waben (Blocker: leere Waben → 0/false). (4) **Stifte/Eier** ergänzt (primäres Weiselsignal); **Weiselzellen-Typ** bleibt; **besetzte Gassen NICHT aus Inhalt abgeleitet** (misst Bienenbesatz, nicht Inhalt); Futter nur als Vorschlag. (5) `pos`→Listenindex, Konstruktor-Invarianten, View-Neubau, Migration **D03**. Register §9.

## 1. Ziele & Nicht-Ziele
**Ziele:**
1. **Geführter 3-Schritt-Wizard** (Kontext → optional Waben → Kennzahlen/Abschluss) mit großen Touch-Zielen; **ersetzt** das Scroll-Formular und deckt **alle** bisherigen Felder ab.
2. **Optionale Waben-Erfassung:** Wabe für Wabe Inhalte antippen (Brut/Pollen/Futter/Honig/Mittelwand/leer/Baurahmen, Mehrfach) + Flags (Königin · Weiselzelle · **Stifte**) + **Trennschied**. Überspringbar.
3. **Auto-Vorbefüllung** (nur wenn Waben erfasst, nur als überschreibbarer Vorschlag): `brut_waben`, `koenigin_gesehen`, `stifte_gesehen`; `futter_kg` als **Hinweis**. **`staerke_wabengassen` wird NICHT abgeleitet** (Bienenbesatz ≠ Inhalt) — direkte Tap-Eingabe. `weiselzellen_anzahl` bleibt manuell (die Wabe-Flags markieren nur *wo*).
4. **Feld-Tauglichkeit:** Number-TextFields → **Tap-Stepper**; Waben-Anzahl aus letzter Durchsicht/Beute vorbelegt, +/− anpassbar (auch <10, Ablegerkasten); Trennschied engt ein.
5. **Rückwärtskompatibel:** additives `waben jsonb`; Bestands-Durchsichten (`waben = null`) unverändert; View/Timeline/Detail laufen weiter.

**Nicht-Ziele:** Spracheingabe (Zyklus 2); Brut-*Stadien*/Verdeckelungsgrad je Wabe; Honigraum-Waben-für-Waben; Mittelschied/zweivölkig; Offline.

## 2. Datenmodell

### 2.1 Migration D03 (additiv; **View-Neubau** nötig)
```sql
-- D03_inspections_waben.sql | Waben-Beobachtungen je Durchsicht (geführte Durchsicht).
alter table public.inspections add column if not exists waben jsonb;
-- billiger Struktur-CHECK (bricht Bestandszeilen mit waben=null NICHT):
alter table public.inspections drop constraint if exists inspections_waben_chk;
alter table public.inspections add constraint inspections_waben_chk
  check (waben is null or jsonb_typeof(waben) = 'array');
-- View v_letzte_durchsichten mit `select *` friert die Spaltenliste zur Erstellzeit ein → waben
-- käme nie mit. Neu bauen (security_invoker beibehalten, exakte SELECT-Liste aus D01 + waben):
drop view if exists public.v_letzte_durchsichten;
create view public.v_letzte_durchsichten with (security_invoker = true) as
  select distinct on (volk_id) * from public.inspections order by volk_id, durchgefuehrt_am desc, id desc;
-- (Die konkrete SELECT-Form aus D01 im Plan verifizieren; `select *` picks up waben automatisch beim Neubau.)
-- ROLLBACK: drop constraint inspections_waben_chk; alter table inspections drop column waben; View aus D01 wiederherstellen.
```

### 2.2 Dart `wabe.dart` (Modell + Whitelist, pure)
```dart
class WabeBeobachtung {          // Position = Listenindex (kein pos-Feld → redundanzfrei)
  final bool schied;             // Trennschied → keine Wabe, keine Inhalte/Flags
  final Set<String> inhalte;     // aus kWabenInhalte; leer wenn schied
  final bool koenigin;
  final bool weiselzelle;
  final bool stifte;             // frische Eier/Stifte gesehen (primäres Weiselsignal)
  const WabeBeobachtung({this.schied = false, this.inhalte = const {},
      this.koenigin = false, this.weiselzelle = false, this.stifte = false})
      : assert(!schied || (inhalte.length == 0 && !koenigin && !weiselzelle && !stifte),
               'Schied trägt keine Inhalte/Flags');

  static const kWabenInhalte = <String>{'brut', 'pollen', 'futter', 'honig', 'mittelwand', 'leer', 'baurahmen'};

  factory WabeBeobachtung.fromJson(Map<String, dynamic> j) {
    final schied = (j['schied'] as bool?) ?? false;
    if (schied) return const WabeBeobachtung(schied: true); // normalisiert: Schied ⇒ nichts
    return WabeBeobachtung(
      inhalte: ((j['inhalte'] as List?)?.cast<String>().where(kWabenInhalte.contains).toSet()) ?? const {},
      koenigin: (j['koenigin'] as bool?) ?? false,
      weiselzelle: (j['weiselzelle'] as bool?) ?? false,
      stifte: (j['stifte'] as bool?) ?? false,
    );
  }
  Map<String, dynamic> toJson() => schied
      ? {'schied': true}
      : {
          if (inhalte.isNotEmpty) 'inhalte': inhalte.where(kWabenInhalte.contains).toList(),
          if (koenigin) 'koenigin': true,
          if (weiselzelle) 'weiselzelle': true,
          if (stifte) 'stifte': true,
        };
}
```
Positionen hinter einem Schied werden nicht gespeichert (implizit ungenutzt). `leer` und `mittelwand` sind **getrennte** Toggles (UI + Whitelist).

### 2.3 Ableitungs-Funktionen (pure, `wabe.dart`)
```dart
const kFutterKgProWabe = 2.0; // grober Richtwert (Füllgrad ignoriert) → nur Hinweis, kein Auto-Wert
bool _istWabe(WabeBeobachtung w) => !w.schied;

int brutWabenAus(List<WabeBeobachtung> ws) => ws.where((w) => _istWabe(w) && w.inhalte.contains('brut')).length;
bool koeniginAus(List<WabeBeobachtung> ws) => ws.any((w) => _istWabe(w) && w.koenigin);
bool stifteAus(List<WabeBeobachtung> ws) => ws.any((w) => _istWabe(w) && w.stifte);
num futterKgHinweisAus(List<WabeBeobachtung> ws) =>
    ws.where((w) => _istWabe(w) && (w.inhalte.contains('futter') || w.inhalte.contains('honig'))).length * kFutterKgProWabe;
```
**Bewusst KEINE `gassenAus`/`weiselzellenAnzahlAus`:** besetzte Gassen = Bienenbesatz (nicht aus Inhalt ableitbar) → direkte Eingabe; Zellenzahl = echte Zellen (nicht #Waben-mit-Zelle) → manuell.

### 2.4 `durchsicht.dart` (Modify)
`+ final List<WabeBeobachtung> waben;` (Default `const []`). `fromJson`: `waben: ((j['waben'] as List?)?.map((e) => WabeBeobachtung.fromJson(e as Map)).toList()) ?? const []`. `toInsertJson`: `'waben': waben.isEmpty ? null : waben.map((w) => w.toJson()).toList()`. Bestehende Kennzahl-Felder unverändert; der Wizard *befüllt* sie (überschreibbar) — siehe §3.

## 3. UX — der Wizard (ersetzt das Formular, alle Felder erhalten)
Neue Seite `durchsicht_wizard_page.dart`, nimmt (wie das alte Formular) `Durchsicht? bestehend` **als Objekt** (kein `?d=`-Query, kein Extra-Ladepfad). 3 Schritte via `PageView`/Stepper, großer „Weiter"/„Zurück", Fortschritt oben.

- **① Kontext:** Datum (Default heute), Wetter/Temp/Dauer (kompakt), Weiselzustand (Chips). **Stifte gesehen** als Toggle (falls keine Waben erfasst werden).
- **② Waben (OPTIONAL):** Ein **Umschalter „Waben einzeln erfassen"** (Default aus → direkt weiter). Bei ein: Waben-Streifen + je Wabe Inhalts-Toggles (Brut/Pollen/Futter/Honig/Mittelwand/leer/Baurahmen) + Flags (Königin · Weiselzelle · Stifte) + **Schied** („dahinter Schluss"). „Nächste Wabe →"/Zurück, +/− Wabenzahl (Default = letzte Durchsicht dieses Volks, sonst 10). Unten live: Brutwaben, Königin, Stifte.
- **③ Kennzahlen/Abschluss** (alle Tap-freundlich; **abgeleitete Werte vorbefüllt, wenn Waben erfasst, sonst leer/manuell**): Brutbild (Chip), Brutwaben (Stepper, vorbefüllt), **besetzte Gassen (Stepper, immer manuell)** + Bienen-Schätzung, Futter-kg (Stepper; abgeleiteter Wert nur als **Hinweistext** „≈ N kg aus Waben", überschreibt das Feld **nicht**), Pollen (Chip), Platz (Chip), Weiselzellen-**Typ** (Chip: keine/Spielnäpfchen/Schwarm/Nachschaffung) + Anzahl (Stepper, manuell), Königin/Stifte gesehen (Toggles, vorbefüllt), Sanftmut/Wabensitz (Tap-Buttons 1–4), Auffälligkeiten (FilterChips), Maßnahmen, nächste Durchsicht (Vorschlag), Foto, Notiz.

**Vorbefüllung/Überschreib-Regel:** Beim Verlassen des Waben-Schritts werden `brut_waben`/`koenigin_gesehen`/`stifte_gesehen` **einmalig** aus den Waben vorbefüllt; danach frei editierbar (kein erneutes Auto-Überschreiben). Ohne Waben: normale Eingabe. **Ableitung feuert nie bei leerer Waben-Liste** → im Edit-Fall (alte Durchsicht ohne Waben) bleiben die gespeicherten Werte erhalten.
**Speichern:** baut `Durchsicht` mit `waben` + den (ggf. vorbefüllten) Feldern, via bestehendem `durchsichtenFuerVolkProvider.speichern`.

## 4. Architektur & Dateien
```
supabase/migrations/D03_inspections_waben.sql
lib/features/durchsicht/domain/wabe.dart                          (neu: WabeBeobachtung, Whitelist, Ableitung — pure)
lib/features/durchsicht/domain/durchsicht.dart                    (Modify: +waben)
lib/features/durchsicht/presentation/pages/durchsicht_wizard_page.dart (neu; ersetzt durchsicht_form_page)
lib/features/durchsicht/presentation/widgets/waben_schritt.dart         (neu; controlled: Input List<WabeBeobachtung> + onChanged)
```
**Modify (Pflicht):** `app_router` (`/voelker/:id/durchsicht` → Wizard) · Volk-Detailseite („Durchsicht"-Aktion → Wizard) · **`durchsicht_detail_page.dart` (Bearbeiten-Button → Wizard mit `bestehend`)** · **`durchsicht_karte`/`durchsicht_timeline`** falls sie aufs Formular verlinken (prüfen). Das alte **`durchsicht_form_page.dart` entfernen** (der Wizard deckt alle Felder ab → kein Fallback-Bedarf; keine verwaisten Felder). Optional: Waben-Streifen (read-only) im Detail.
**`waben_schritt.dart`:** stateless/controlled — `List<WabeBeobachtung> waben` + `ValueChanged<List<WabeBeobachtung>>`; Wahrheit (Liste, aktive Position, Wabenzahl) hält die Wizard-Page.
**Gateway/Provider/Tabelle:** unverändert; `toInsertJson`/`fromJson` tragen `waben` mit.

## 5. Tests
- **Ableitung (pure):** `brutWabenAus` (Schied zählt nicht); `koeniginAus`/`stifteAus` (`_istWabe`-Guard → Schied-Flags lecken nicht); `futterKgHinweisAus` (Futter+Honig × Richtwert); **leere Liste → 0/false** (aber Wizard ruft nur bei nicht-leer auf, s. u.).
- **WabeBeobachtung:** fromJson/toJson-Roundtrip über alle Zustände (schied, Flags, Inhalte); **Konstruktor-assert** (schied ⇒ leer/false); fromJson-Normalisierung (schied verwirft Inhalte); Inhalte-Whitelist filtert ungültige; `leer`/`mittelwand` getrennt.
- **Durchsicht:** fromJson/toInsertJson **mit** waben (Roundtrip); **waben leer → `toInsertJson['waben']==null`**; Bestandstests grün.
- **Vorbefüll-/Überschreib-Regel (Wizard-Logik als pure Helper testbar):** Waben vorhanden → Vorbefüllung; **leere Waben → keine Überschreibung** der Bestandswerte (Edit-Fall); manuell geänderter Wert wird nicht re-überschrieben.
- Wizard/UI: `flutter analyze` grün.

## 6. Deploy
Version **1.20.0+41** (Minor). Migration D03 auf Produktion `dcdcohktxbhdxnxjvcyp` (freigabepflichtig; ALTER + View-Neubau). `get_advisors(security+performance)` → 0 neue. Kein RPC/Errcode. `bash deploy.sh` nach grünen Tests.

## 7. decision-log / Roadmap
- **D-57 (neu):** Durchsicht als **geführter 3-Schritt-Wizard** (ersetzt das Formular, **alle Felder erhalten**) mit **optionaler Waben-für-Waben-Erfassung** (Multi-Toggle + Flags inkl. Stifte + Trennschied). Ableitung nur als überschreibbare Vorbefüllung, **nie bei leeren Waben** (kein Datenverlust im Edit). Additives `waben jsonb` + View-Neubau. Bienenbesatz/Gassen + Zellenzahl bleiben direkte Eingaben (nicht aus Inhalt ableitbar). Spracheingabe = Zyklus 2.
- **Roadmap:** 4.3 Durchsicht — Ausbau „geführt + Rähmchen" LIVE (v1.20.0).

## 8. Review-Korrekturen (v1→v2, Kurzregister)
| # | Lupe | Korrektur |
|---|---|---|
| B1 | architektur | Wizard behält ALLE Bestandsfelder (7 wären gedroppt); Bearbeiten-Button/Karte/Timeline mit-umverdrahtet |
| B2 | architektur | Ableitung feuert nur bei nicht-leeren Waben → kein 0/false-Overwrite im Edit |
| B3 | scope | Waben-Schritt optional/überspringbar (Default = direkte Kennzahlen) |
| W1 | fachlich | Stifte/Eier ergänzt (primäres Weiselsignal) — Flag je Wabe + Toggle |
| W2 | fachlich | besetzte Gassen NICHT aus Inhalt abgeleitet → direkte Eingabe |
| W3 | fachlich | Weiselzellen-Typ (Chip) bleibt; Zellenzahl manuell (nicht #Waben-mit-Zelle) |
| W4 | fachlich | Futter-kg nur Hinweis (Füllgrad ignoriert), überschreibt Handwert nicht |
| W5 | korrektheit | `_istWabe`-Guard in koeniginAus/stifteAus; Konstruktor-assert (schied ⇒ leer) |
| W6 | korrektheit | `pos`→Listenindex (redundanzfrei); toJson kompakt + roundtrip-sicher |
| W7 | korrektheit | UPDATE-Pfad: Edit lädt waben mit (Objekt-Push), leer→null nur bei echt leer |
| W8 | db | View `v_letzte_durchsichten` in D03 neu gebaut (sonst waben eingefroren) |
| W9 | db | Struktur-CHECK `jsonb_typeof(waben)='array'`; Migration als D03 (Durchsicht-Serie) |
| W10 | architektur | Edit über Objekt-Push (`Durchsicht? bestehend`), kein `?d=`-Query |
| W11 | architektur | `waben_schritt` controlled (Input+onChanged), State in der Wizard-Page |

## 9. Offene Punkte (Plan)
- Exakte SELECT-Liste der View aus D01 übernehmen (der `select *`-Neubau muss die reale Form treffen).
- Waben-Streifen im Detail-Ansicht: mit (nice) oder Zyklus 2.
- `kFutterKgProWabe`/Bienen-Schätzung als Richtwert-Kommentar markieren; Füllgrad-Gewichtung optional später.
- Prüfen, ob `durchsicht_karte`/`durchsicht_timeline` aufs alte Formular verlinken (mit-umverdrahten).
- Konstruktor-Invariante: falls der const-`assert` mit `inhalte.length` nicht const-evaluierbar ist, entfällt er — die Invariante tragen die fromJson-Normalisierung (schied ⇒ nichts) + der toJson-Guard bereits vollständig; alternativ ein nicht-const-Named-Constructor mit assert.
