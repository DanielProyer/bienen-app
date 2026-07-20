# Vermehrungs-Event-Ketten (Baustein D1 · Modul 4.16) — Design-Spec (v2)

**Datum:** 2026-07-20 · **Status:** in Review (v2 nach adversarialem Multi-Agent-Review) · **Modul:** 4.16 Schwarmkontrolle/Ableger (Baustein D1) · **Version:** 1.18.0+39
**Anlass:** Ableger-/Schwarm-Vermehrung ist eine **Event-Kette**: der Imker erfasst ein Startereignis (z. B. „Brutableger gebildet am 5.6."), daraus entsteht eine terminierte Folge von Aufgaben mit **relativen** Fristen (Tag 9 Zellen brechen · Tag 25–30 Weiselkontrolle + Oxalsäure · …). Der heutige Generator kennt nur statische Saisonregeln ohne Folgekette. Fachgrundlage: `../imkerei/02_Recherche/25_Vermehrung_Jungvolkbildung_BGD.md` (§10 Übersichtstabelle).

> **Zerlegung:** Baustein **D** von A→B→C→D (decision-log D-45). **D1 = Event-Ketten-Engine + Ableger/Schwarm (4.16)**. C (Phänologie) ist live (v1.17.0).

> **Abgrenzung zu C:** C verschiebt den **Kalender** (Phänologie-Offset). D ist **event-getrieben** mit **relativen, kalenderunabhängigen** Tagesfristen (Recherche 25 Z.279).

> **v2-Änderungen (aus dem Review, 29 bestätigte Findings):** (1) **4 Methoden statt 7** — die verschachtelten/mehr-spender-Methoden sprengen das flache Modell (Blocker). (2) **OS-Gate entfernt** — es hätte die zwingende Weiselkontrolle mit-unterdrückt (Blocker); `os_bei_erstellung` bleibt reines Notiz-Feld. (3) Dedup/Unique **ohne volk_id**. (4) **Überfällige Einmal-Schritte surfacen** statt lautlos zu verschwinden. (5) DB-Härtungen (stammvolk SET NULL, kein `current_date`-CHECK, jungvolk-Index, RLS/Trigger voll). (6) Jungvolk-null → ein Hinweis statt volk-loser Kette. (7) Kellerhaft-Offset + Stammvolk-OS-Schritte fachlich korrigiert. Register §9.

## 1. Ziele & Nicht-Ziele
**Ziele:**
1. **Vermehrungs-Ereignisse erfassen** (4 BGD-Methoden) mit Stammvolk-Bezug, optionalem Jungvolk, Startdatum, `os_bei_erstellung` (Notiz).
2. **Ketten-Generator** leitet aus Ereignis + Methoden-Katalog **datierte Aufgaben-Vorschläge** ab (relative Fristen); Annehmen materialisiert eine normale `aufgabe`, Überspringen dedupt (Saison-Muster). **Überfällige, noch offene Einmal-Schritte bleiben sichtbar.**
3. **Ketten-Vorschau** im Erfassungs-Formular (Fahrplan sichtbar, bevor gespeichert wird).
4. **Volk-Integration:** Erfassung vom Stammvolk aus; Ketten-Aufgaben je Volk (Stamm/Jung) auf der Detailseite; **OS-Schritte tragen `kategorie='behandlung'`** (der Imker erfasst die Behandlung im amtlichen Journal 4.5 wie gewohnt — keine neue Deep-Link-Kopplung).

**Nicht-Ziele (spätere Zyklen):**
- **3 komplexere Methoden:** `sammelbrutableger` (3–5 Spendervölker → n:m, Milbenfall-Gate), `natur_schwarm` (Stammvolk oft null [Fremdschwarm], bedingte Nachschwarm-Nachfrist +14), `schwarmtrieb_vermehrung` (verschachtelt: Kö-Kunstschwarm + bis 4 Brutableger mit zweitem Anker) — brauchen Modell-Erweiterungen (mehrere Jungvölker / zweiter Anker / bedingte Schritte).
- **`os_bei_erstellung` → Saison-`sommerbehandlung_1`-Unterdrückung** (BGD „erste Sommerbehandlung optional"): cross-feature, später.
- 4.17 Königin-**Bewertung** (7-Stufen-Skala, Zuchtwerte/BLUP, Herdebuch) + **Umlarv-Kalender** (D2); Schwarmtrieb-Frühwarnung; Methoden-Wissensmodul (4.21).
- **Kein Genericity-Anspruch:** die Engine wird konkret für Vermehrung gebaut; ob 4.17 sie wiederverwendet, wird bei echten 4.17-Anforderungen entschieden (kein spekulativer Polymorphismus).

## 2. Datenmodell

### 2.1 Migration K01 (`vermehrungs_ereignisse` + `aufgaben`-Erweiterung)
```sql
-- Neue Tabelle: das erfasste Startereignis (normale CRUD, Muster H01).
create table if not exists public.vermehrungs_ereignisse (
  id uuid primary key default gen_random_uuid(),
  methode text not null check (methode in
    ('kunstschwarm','koeniginnen_kunstschwarm','brutableger','flugling')),   -- v1: 4 Methoden
  erstellt_am date not null,               -- Tag 0 der Kette (Plausi im Formular, NICHT per current_date-CHECK)
  stammvolk_id uuid,                        -- Komposit-FK (betrieb_id, stammvolk_id)
  jungvolk_id uuid,                         -- optional, Komposit-FK
  os_bei_erstellung boolean not null default false,  -- reines Notiz-Feld (kein Ketten-Gate in v1)
  notiz text,
  betrieb_id uuid not null default private.aktive_betrieb_id()
    references public.betriebe(id) on delete cascade,
  created_by uuid, updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (betrieb_id, id),
  constraint vermehrung_stammvolk_fk foreign key (betrieb_id, stammvolk_id)
    references public.voelker (betrieb_id, id) on delete set null (stammvolk_id),  -- Ereignis + Jungvolk-Kette überleben
  constraint vermehrung_jungvolk_fk foreign key (betrieb_id, jungvolk_id)
    references public.voelker (betrieb_id, id) on delete set null (jungvolk_id)
);
alter table public.vermehrungs_ereignisse enable row level security;
revoke all on public.vermehrungs_ereignisse from anon, public;
grant select, insert, update, delete on public.vermehrungs_ereignisse to authenticated;
create index if not exists idx_vermehrung_stammvolk on public.vermehrungs_ereignisse (betrieb_id, stammvolk_id);
create index if not exists idx_vermehrung_jungvolk  on public.vermehrungs_ereignisse (betrieb_id, jungvolk_id);  -- FK-Index (Advisor)

drop trigger if exists trg_vermehrung_actor on public.vermehrungs_ereignisse;
create trigger trg_vermehrung_actor before insert or update
  on public.vermehrungs_ereignisse for each row execute function private.set_row_actor();
drop trigger if exists trg_vermehrung_updated on public.vermehrungs_ereignisse;
create trigger trg_vermehrung_updated before update
  on public.vermehrungs_ereignisse for each row execute function private.set_updated_at();

drop policy if exists vermehrung_sel_member on public.vermehrungs_ereignisse;
create policy vermehrung_sel_member on public.vermehrungs_ereignisse
  for select to authenticated using (betrieb_id in (select private.meine_betrieb_ids()));
drop policy if exists vermehrung_ins_writer on public.vermehrungs_ereignisse;
create policy vermehrung_ins_writer on public.vermehrungs_ereignisse
  for insert to authenticated with check (private.kann_schreiben(betrieb_id));
drop policy if exists vermehrung_upd_writer on public.vermehrungs_ereignisse;
create policy vermehrung_upd_writer on public.vermehrungs_ereignisse
  for update to authenticated using (private.kann_schreiben(betrieb_id)) with check (private.kann_schreiben(betrieb_id));
drop policy if exists vermehrung_del_writer on public.vermehrungs_ereignisse;
create policy vermehrung_del_writer on public.vermehrungs_ereignisse
  for delete to authenticated using (private.kann_schreiben(betrieb_id));

-- aufgaben-Erweiterung: Ketten-Schritte materialisieren als normale Aufgaben (Analog quelle='regel').
alter table public.aufgaben add column if not exists ereignis_id uuid;
alter table public.aufgaben add column if not exists schritt_key text;
-- Bestands-CHECK: inline Column-Check aus H01 heisst deterministisch aufgaben_quelle_check (im Plan vor dem drop
-- per pg_constraint verifizieren):
alter table public.aufgaben drop constraint if exists aufgaben_quelle_check;
alter table public.aufgaben add constraint aufgaben_quelle_check
  check (quelle in ('manuell','regel','ereignis'));
alter table public.aufgaben add constraint aufgaben_ereignis_fk
  foreign key (betrieb_id, ereignis_id) references public.vermehrungs_ereignisse (betrieb_id, id) on delete cascade;
alter table public.aufgaben add constraint aufgaben_ereignis_chk
  check ((quelle = 'ereignis') = (ereignis_id is not null and schritt_key is not null));
-- Dedup OHNE volk_id: (ereignis_id, schritt_key) ist der natürliche Schlüssel (schritt_key je Methode eindeutig,
-- ein Ereignis = eine Methode) → genau EINE Materialisierung je Schritt, egal ob angenommen oder übersprungen.
create unique index if not exists aufgaben_ereignis_dedup on public.aufgaben
  (betrieb_id, ereignis_id, schritt_key) where quelle = 'ereignis';
-- ROLLBACK (Ops): FK/CHECK/Index/Spalten droppen + drop table vermehrungs_ereignisse;
```
- **`aufgaben.ereignis_id` ON DELETE CASCADE:** Löschen eines Ereignisses entfernt seine Ketten-Aufgaben (auch erledigte Reminder). **Unkritisch:** die *amtliche* Behandlung liegt separat & immutable in `behandlungen` (4.5); die Ketten-Aufgabe ist nur der Reminder. UX-Zusage in §4.2 entsprechend korrigiert (Bestätigungsdialog).
- **Kein `erstellt_am`-CHECK** (kein `current_date` im CHECK — J01-Konvention). Zukunfts-/Vergangenheits-Plausi im Formular (§4.1).
- **Errcode/RPC:** keiner. BA050 frei.

### 2.2 Dart-Ketten-Katalog (`vermehrungs_ketten.dart`)
```dart
enum KettenZiel { stammvolk, jungvolk }

class KettenSchritt {
  final String schrittKey;      // eindeutig je Methode
  final String titel;
  final String beschreibung;
  final int tagVon;             // relativ zu erstellt_am (Tag 0)
  final int tagBis;             // Fenster-Ende (>= tagVon); Fälligkeit = tagBis
  final KettenZiel ziel;
  final String kategorie;       // = aufgaben-CHECK-Wert (OS-Schritt → 'behandlung')
  const KettenSchritt({...});   // KEIN optionalBeiOs/aktionRoute (v2)
}

const kVermehrungsKetten = <String, List<KettenSchritt>>{ ... };
```
**Fachliche Ketten (Recherche 25 §10, im Plan als Katalog ausformuliert + Fachstellen-Check-Kommentar):**
- **`brutableger`** (1.4.4): Tag 9 „Weiselzellen bis auf 1 ausbrechen" (jungvolk, durchsicht) · Tag 25–30 „Weiselkontrolle + Oxalsäure bei Eilage" (jungvolk, behandlung).
- **`kunstschwarm`** (1.4.2): Tag 3–5 „Kellerhaft beenden, einlogieren" (jungvolk, durchsicht) · **Tag 10–12** „Weiselkontrolle (Königin-Annahme) + Oxalsäure bei Eilage" (jungvolk, behandlung). **Achtung Kellerhaft-Offset:** die BGD-Frist „≤7 T nach Einlogieren" zählt ab Einlogieren (nach 3–5 T Kellerhaft), NICHT ab Tag 0 → konservativ Tag 10–12; im Plan dokumentieren.
- **`koeniginnen_kunstschwarm`** (1.4.3): Jungvolk Tag 10–12 „Weiselkontrolle + OS" · **Stammvolk Tag 9** „Weiselzellen bis auf 1 ausbrechen" · **Stammvolk Tag 25–30** „Weiselkontrolle + OS bei Brutfreiheit" (die zweite Bremse — sonst geht der halbe Methodennutzen verloren).
- **`flugling`** (1.4.5): Flugling(=jungvolk) Tag 9 „Weiselzellen bis auf 1" · Flugling Tag 25–30 „Weiselkontrolle + OS" · **Brutling(=stammvolk) Tag 25–30** „Oxalsäure nach Auslaufen der Brut". **Form-Hinweis (kein Schritt):** Bildung 11–15 Uhr bei regem Flug.

`VermehrungsEreignis`-Modell (`methode, erstelltAm, stammvolkId, jungvolkId?, osBeiErstellung, notiz`) + `fromJson`/`toInsertJson` (ohne betrieb_id/id). **Methoden-Metadaten** (`vermehrung.dart`): Label + `brutfreiBeiErstellung`-Flag je Methode (steuert die Sichtbarkeit des OS-Switch, §4.1).

## 3. Ketten-Generator
Pure Funktion (in `vermehrungs_ketten.dart`):
```dart
List<KettenVorschlag> kettenVorschlaege({
  required DateTime stichtag,
  required List<VermehrungsEreignis> ereignisse,
  required List<Aufgabe> kettenAufgaben,   // alle Aufgaben mit quelle='ereignis' (jeder Status)
  required Set<String> aktiveVolkIds,
})
```
`final heute = _tag(stichtag);` **zuerst normalisieren** (Datum, keine Uhrzeit) — sonst Off-by-one am Rand-Tag. Je Ereignis:
- **Katalog null-tolerant:** `kVermehrungsKetten[methode]` fehlt → Ereignis überspringen (kein Crash bei Katalog/DB-Drift).
- Je Schritt:
  1. **Fenster:** `start = erstellt_am + tagVon`, `ende = erstellt_am + tagBis` — DST-sicher (`DateTime(j,m,d+n)`, nie `Duration`).
  2. **Ziel-Volk:** `stammvolk`→`stammvolkId` (kann null sein → überspringen mit Notiz); `jungvolk`→`jungvolkId`. **Ist `jungvolkId` null: KEINE volk-losen Einzelschritte**, stattdessen genau **ein** Sammel-Vorschlag „Jungvolk anlegen & verknüpfen" pro Ereignis (§4.2). Ist das Ziel-Volk gesetzt, aber nicht in `aktiveVolkIds` → überspringen.
  3. **Dedup:** existiert eine `kettenAufgabe` mit `ereignisId==ereignis.id && schrittKey==schritt.schrittKey` → überspringen (angenommen ODER übersprungen). **Ohne volk_id im Schlüssel** → keine Doppel-Materialisierung, wenn das Jungvolk nachträglich verknüpft wird.
  4. **Sichtbarkeit (Einmal-Kette):** Vorschlag ab `heute ≥ start−14`; **nach `ende` NICHT unterdrücken** — noch offene, überfällige Schritte bleiben als `ueberfaellig=true` sichtbar (Einmal-Ereignis, nicht selbstkorrigierend wie Saison). Fälligkeit = `ende`.
- `KettenVorschlag{ereignis, schritt, fensterStart, fensterEnde, faelligAm=ende, volkId, ueberfaellig, beschreibung}`.

**Provider:** `kettenVorschlaegeProvider` (watcht `vermehrungsProvider` + gefilterte `aufgabenListProvider`[quelle='ereignis'] + `aktiveVoelkerProvider`). In `AuthController._datenNeuLaden` invalidieren.
**Annehmen:** materialisiert `aufgabe` (`quelle='ereignis'`, `ereignis_id`, `schritt_key`, `volk_id`, `faellig_am`, Titel/Beschreibung, `kategorie`). `KettenSchritt.aktionRoute` gibt es nicht — die Route-Verlinkung im Vorschlag/der Karte leitet sich aus `kategorie` ab (Bestandsmuster; die materialisierte Aufgabe trägt keine `aktion_route`-Spalte). **Überspringen:** `aufgabe` `status='uebersprungen'` (dedupt den Schritt).

## 4. UX
### 4.1 Ableger erfassen (vom Volk aus)
Route **`/voelker/:id/vermehrung`** (Plural, Kind-Route unter `/voelker/:id` — analog gesundheit), Aktion „Ableger/Vermehrung erfassen" auf der Volk-Detailseite (Stammvolk vorbelegt). Formular: **Methode** (Dropdown, 4 Methoden), **Erstellt am** (Default heute; **Plausi:** nicht in der Zukunft, Warnhinweis wenn > ~60 T zurück → „Kette evtl. schon abgelaufen"), **Oxalsäure bei Erstellung** (Switch — **nur sichtbar bei `brutfreiBeiErstellung`-Methoden**: kunstschwarm/koeniginnen_kunstschwarm), **Jungvolk** (optional verknüpfen | „später"), **Notiz**. Rollen-Guard (viewer read-only), fehlerfest (try/catch + Snackbar), invalidiert `vermehrungsProvider`.
**Ketten-Vorschau (live):** sobald Methode gewählt, read-only-Liste der datierten Kette („Tag 9 · 14.6.: Weiselzellen brechen · Stammvolk" …), aus **derselben pure-Funktion** (geteilte Datumsberechnung, keine Logik-Duplikation) + `erstellt_am`. Beim Flugling zusätzlich der 11–15-Uhr-Hinweis.

### 4.2 Vermehrungs-Sektion (Volk-Detailseite)
Listet Ereignisse mit diesem Volk als Stamm- **oder** Jungvolk (Methode, Datum, Fortschritt „x/n Schritte" — n = Katalog-Schrittzahl der Methode, x = materialisierte Aufgaben). Ist `jungvolk_id` null → prominenter Button **„Jungvolk anlegen & verknüpfen"** (das neue Volk über den 4.2-Flow mit `mutter_volk_id`; danach `jungvolk_id` setzen). **Ereignis löschen** mit Bestätigungsdialog („entfernt das Ereignis und seine Ketten-Aufgaben, auch erledigte; erfasste Behandlungen im Journal bleiben erhalten").

### 4.3 Aufgaben-Tab
Neue Vorschlags-Sektion **„Vermehrung"** neben „Saison". Überfällige Ketten-Schritte oben, als „überfällig" markiert. Annehmen/Überspringen wie oben. **`aufgabe_form_page`** muss beim generischen Bearbeiten `ereignisId`+`schrittKey` durchreichen (Roundtrip, sonst bricht der Biconditional-CHECK) — ODER quelle='ereignis'-Aufgaben dort read-only. Angenommene Ketten-Aufgaben sind sonst normale Aufgaben (Cockpit, Volk-Section, Abhaken).

## 5. Architektur & Dateien
```
supabase/migrations/K01_vermehrungs_ereignisse.sql
lib/features/vermehrung/domain/vermehrung.dart              (VermehrungsMethode-Labels + brutfreiBeiErstellung)
lib/features/vermehrung/domain/vermehrungs_ketten.dart      (KettenSchritt, kVermehrungsKetten, kettenVorschlaege, KettenVorschlag, kettenVorschauFuer — pure)
lib/features/vermehrung/domain/vermehrungs_ereignis.dart    (Modell)
lib/features/vermehrung/domain/vermehrung_gateway.dart      (abstrakt) + data/{fake,supabase}_vermehrung_gateway.dart
lib/features/vermehrung/presentation/providers/vermehrung_provider.dart (Gateway + Liste + kettenVorschlaegeProvider + annehmen/ueberspringen)
lib/features/vermehrung/presentation/pages/vermehrung_form_page.dart    (Erfassung + Ketten-Vorschau)
lib/features/vermehrung/presentation/widgets/vermehrung_sektion.dart    (Volk-Detailseite)
```
**Modify:** `aufgaben/domain/aufgabe.dart` (+`ereignisId`/`schrittKey`, fromJson/toInsertJson — beim quelle≠'ereignis' weglassen) · `data/supabase_aufgaben_gateway.dart` · `aufgaben/presentation/pages/aufgaben_page.dart` (Vermehrungs-Sektion) · **`aufgabe_form_page`** (ereignis-Felder Roundtrip/read-only) · Volk-Detailseite (Sektion + Route) · `auth_providers._datenNeuLaden` (+`vermehrungsProvider`) · `app_router.dart` (Kind-Route `/voelker/:id/vermehrung`).
**Import-Richtung (einseitig):** `vermehrung → aufgaben/voelker`. `aufgaben` importiert **nicht** `vermehrung` (Aufgabe trägt nur generische `ereignisId`/`schrittKey`).

## 6. Tests
- **`kettenVorschlaege`:** Dedup (angenommen/übersprungen → kein Vorschlag; **Jungvolk nachträglich verknüpft → keine Doppel-Materialisierung**, da Dedup ohne volk_id); Vorlauf (heute<start−14 → nicht); **überfälliger offener Schritt (heute>ende) → sichtbar + `ueberfaellig`**; **stichtag mit Uhrzeit am Rand-Tag → korrekt** (Normalisierung); jungvolk_id null → **ein** „Jungvolk verknüpfen"-Vorschlag, keine volk-losen Einzelschritte; Ziel-Volk gelöscht → nicht; DST-Sicherheit (Fenster über Zeitumstellung); **Methode ohne Katalog-Eintrag → Ereignis übersprungen (kein Crash)**.
- **Katalog-Invarianten:** je Methode ≥1 Schritt; `tagVon ≤ tagBis`; `schrittKey` eindeutig je Methode; Schritte chronologisch; `kategorie` ∈ aufgaben-CHECK-Whitelist; **jeder DB-CHECK-Methodenwert (4) hat genau einen Katalog-Eintrag** (kein Drift).
- **Modell:** `toInsertJson` ohne betrieb_id/id; fromJson-Roundtrip. **Aufgabe:** `quelle='ereignis'`-Roundtrip (ereignisId/schrittKey in fromJson/toInsertJson; bei quelle≠'ereignis' weggelassen); Annehmen → aufgabe mit richtigen Feldern; Überspringen → status='uebersprungen'.
- **Gateway/Provider:** Fake-CRUD; Provider-Roundtrip; `_datenNeuLaden`-Invalidierung.

## 7. Deploy
Version **1.18.0+39** (Minor). Migration K01 auf Produktion `dcdcohktxbhdxnxjvcyp` (separat freigabepflichtig). `get_advisors(security **+ performance**)` → 0 neue Findings (inkl. FK-Index-Advisor). Kein RPC/Errcode-Block. `bash deploy.sh` (stehende Freigabe nach grünen Tests).

## 8. decision-log / Roadmap
- **D-52 (neu):** Vermehrung als **Event-Ketten** (Ereignis-Anker + relative Fristen aus Dart-Katalog), materialisiert über die bestehende `aufgaben`-Infrastruktur (quelle='ereignis', Analog quelle='regel'). Relative Fristen **kalenderunabhängig** (anders als C). **v1 = 4 flach-modellierbare Methoden**; 3 komplexere (Sammelbrut/Natur-Schwarm/Schwarmtrieb) + `os_bei_erstellung`-Gating bewusst deferred (Blocker-Vermeidung). **Kein Genericity-Anspruch** für 4.17.
- **Roadmap:** 4.16 Basis LIVE (D1).

## 9. Review-Korrekturen (v1→v2, Kurzregister)
| # | Lupe | Korrektur |
|---|---|---|
| B1 | fachlich (Blocker) | OS-Gate entfernt (hätte die Pflicht-Weiselkontrolle mit-unterdrückt); `os_bei_erstellung` = Notiz, Switch nur bei brutfreien Methoden |
| B2 | scope (Blocker) | v1 = 4 flach-modellierbare Methoden; Sammelbrut/Natur-Schwarm/Schwarmtrieb deferred (Modell-Sprenger) |
| W1 | generator/db | Dedup + Unique-Index **ohne volk_id** → keine Doppel-Materialisierung bei nachträglicher Jungvolk-Verknüpfung |
| W2 | generator | Überfällige Einmal-Schritte surfacen (nicht lautlos nach fensterEnde verschwinden) |
| W3 | generator | `stichtag` auf Datum normalisieren (Rand-Tag-Off-by-one) |
| W4 | db | stammvolk-FK ON DELETE SET NULL (Ereignis + Jungvolk-Kette überleben); UX-Löschzusage korrigiert |
| W5 | db | kein `current_date`-CHECK auf erstellt_am (Formular-Plausi); RLS/Trigger voll ausgeschrieben; jungvolk-FK-Index |
| W6 | fachlich | Kunstschwarm/Kö-Kunstschwarm Weiselkontrolle Tag 10–12 (Kellerhaft-Offset), nicht Tag 7 |
| W7 | fachlich | Stammvolk-OS-Schritt ~Tag 25–30 bei Kö-Kunstschwarm + Flugling-Brutling (Doppelbremse) |
| W8 | architektur | `aufgabe_form_page` in Modify (ereignis-Felder Roundtrip/read-only, sonst CHECK-Bruch) |
| W9 | architektur | OS→Behandlung via `kategorie='behandlung'` (keine aktion_route-Spalte, keine Import-Verletzung); Ziel 4 präzisiert |
| N1 | architektur | Route `/voelker/:id/vermehrung` (Plural, Konvention) |
| N2 | scope | Jungvolk-null → **ein** „verknüpfen"-Hinweis statt volk-loser Kette |
| N3 | generator | Katalog-Lookup null-tolerant + Invariantentest Methode↔Katalog |
| N4 | scope | Genericity-Anspruch (4.17-Wiederverwendung) gestrichen |
| N5 | fachlich | Flugling 11–15-Uhr als Form-Hinweis (kein Ketten-Schritt) |

## 10. Offene Punkte (Plan)
- Vollständige Schritt-/Tageswerte der 4 Ketten aus Recherche 25 §10 (inkl. Kellerhaft-Offset-Doku) — im Plan als Katalog.
- Exakten Bestands-Constraint-Namen des `quelle`-CHECK (`aufgaben_quelle_check`) vor dem `drop` per `pg_constraint` verifizieren.
- `ueberfaellig`-Darstellung im Aufgaben-Tab (Badge) + wie lange überfällige Schritte sichtbar bleiben (bis angenommen/übersprungen).
