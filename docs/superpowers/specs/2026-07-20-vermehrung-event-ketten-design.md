# Vermehrungs-Event-Ketten (Baustein D1 · Modul 4.16) — Design-Spec (v1)

**Datum:** 2026-07-20 · **Status:** in Review · **Modul:** 4.16 Schwarmkontrolle/Ableger (Baustein D1) · **Version:** 1.18.0+39
**Anlass:** Ableger-/Schwarm-Vermehrung ist eine **Event-Kette**: der Imker erfasst ein Startereignis (z. B. „Brutableger gebildet am 5.6."), daraus entsteht eine terminierte Folge von Aufgaben mit **relativen** Fristen (Tag 9 Zellen brechen · Tag 25–30 Weiselkontrolle + Oxalsäure · …). Der heutige Generator kennt nur statische Saisonregeln (`jungvoelker_bilden`/`koeniginnen_vermehren`, gated durch `vermehrungAktiv`) ohne Folgekette. Fachgrundlage: `../imkerei/02_Recherche/25_Vermehrung_Jungvolkbildung_BGD.md` (7 Methoden, methodenscharfe Fristen §10).

> **Zerlegung:** Baustein **D** von A→B→C→D (decision-log D-45). **D1 = Event-Ketten-Engine + Ableger/Schwarm (4.16)** — dieser Zyklus. Die Engine wird generisch gebaut, sodass der **Umlarv-Kalender + Königin-Bewertung (4.17, D2)** sie später wiederverwenden. C (Phänologie) ist live (v1.17.0).

> **Abgrenzung zu C:** C verschiebt den **Kalender** (Phänologie-Offset). D ist **event-getrieben** mit **relativen, kalenderunabhängigen** Tagesfristen (Recherche 25 Z.279: „die relativen Tagesfristen bleiben unverändert gültig — sie hängen an der Volksbiologie, nicht am Kalender; nur der Startzeitpunkt verschiebt sich"). Kein Offset, keine Phänologie in den Ketten.

## 1. Ziele & Nicht-Ziele
**Ziele:**
1. **Vermehrungs-Ereignisse erfassen** (7 BGD-Methoden) mit Stammvolk-Bezug, optionalem Jungvolk, Startdatum, OS-bei-Erstellung.
2. **Ketten-Generator** leitet aus Ereignis + Methoden-Katalog **datierte Aufgaben-Vorschläge** ab (relative Fristen), die im Aufgaben-Tab als eigene Sektion erscheinen; Annehmen materialisiert eine normale `aufgabe`, Überspringen dedupt (Saison-Muster).
3. **Ketten-Vorschau** im Erfassungs-Formular (ganzer Fahrplan sichtbar, bevor gespeichert wird).
4. **Volk-Integration:** Erfassung vom Stammvolk aus; Ketten-Aufgaben erscheinen je Volk (Stamm/Jung) auf der Detailseite; OS-Schritte verlinken ins Behandlungsjournal (4.5).
5. **Generisch:** Engine + Datenmodell so, dass 4.17 (Umlarv/Zucht) sie wiederverwendet.

**Nicht-Ziele (spätere Zyklen):** 4.17 Königin-**Bewertung** (7-Stufen-Skala, Zuchtwerte/BLUP, Herdebuch-Register-Ausbau) + Umlarv-Kalender (D2); automatische Kopplung `os_bei_erstellung` → Saison-`sommerbehandlung_1`-Unterdrückung (BGD „erste Sommerbehandlung optional" — später); Schwarm­trieb-**Frühwarnung**/Wetterkopplung; Grafik-/Wissensmodul der Methoden (4.21).

## 2. Datenmodell

### 2.1 Migration K01 (`vermehrungs_ereignisse` + `aufgaben`-Erweiterung)
```sql
-- Neue Tabelle: das erfasste Startereignis (normale CRUD, Muster H01).
create table if not exists public.vermehrungs_ereignisse (
  id uuid primary key default gen_random_uuid(),
  methode text not null check (methode in
    ('kunstschwarm','koeniginnen_kunstschwarm','brutableger','sammelbrutableger',
     'flugling','natur_schwarm','schwarmtrieb_vermehrung')),
  erstellt_am date not null,               -- Tag 0 der Kette
  stammvolk_id uuid,                        -- Komposit-FK (betrieb_id, stammvolk_id)
  jungvolk_id uuid,                         -- optional, Komposit-FK
  os_bei_erstellung boolean not null default false,
  notiz text,
  betrieb_id uuid not null default private.aktive_betrieb_id()
    references public.betriebe(id) on delete cascade,
  created_by uuid, updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (betrieb_id, id),
  constraint vermehrung_stammvolk_fk foreign key (betrieb_id, stammvolk_id)
    references public.voelker (betrieb_id, id) on delete cascade,     -- operative Planung wie aufgaben
  constraint vermehrung_jungvolk_fk foreign key (betrieb_id, jungvolk_id)
    references public.voelker (betrieb_id, id) on delete set null (jungvolk_id),
  constraint vermehrung_erstellt_chk check (erstellt_am <= current_date + 30)
);
alter table public.vermehrungs_ereignisse enable row level security;
revoke all on public.vermehrungs_ereignisse from anon, public;
grant select, insert, update, delete on public.vermehrungs_ereignisse to authenticated;
-- set_row_actor + set_updated_at Trigger; RLS sel=meine_betrieb_ids, ins/upd/del=kann_schreiben.
create index if not exists idx_vermehrung_stammvolk on public.vermehrungs_ereignisse (betrieb_id, stammvolk_id);

-- aufgaben-Erweiterung: Ketten-Schritte materialisieren als normale Aufgaben (Analog quelle='regel').
alter table public.aufgaben add column if not exists ereignis_id uuid;
alter table public.aufgaben add column if not exists schritt_key text;
alter table public.aufgaben drop constraint if exists aufgaben_quelle_check; -- neu mit 'ereignis'
alter table public.aufgaben add constraint aufgaben_quelle_check
  check (quelle in ('manuell','regel','ereignis'));
alter table public.aufgaben add constraint aufgaben_ereignis_fk
  foreign key (betrieb_id, ereignis_id) references public.vermehrungs_ereignisse (betrieb_id, id) on delete cascade;
alter table public.aufgaben add constraint aufgaben_ereignis_chk
  check ((quelle = 'ereignis') = (ereignis_id is not null and schritt_key is not null));
create unique index if not exists aufgaben_ereignis_dedup on public.aufgaben
  (betrieb_id, ereignis_id, schritt_key, volk_id) nulls not distinct where quelle = 'ereignis';
-- ROLLBACK (Ops): FK/CHECK/Index droppen + Spalten droppen + drop table vermehrungs_ereignisse;
```
- **`quelle`-CHECK-Neuanlage:** der Bestands-CHECK (`aufgaben_kategorie_chk`? real `quelle`-CHECK aus H01) wird per `drop constraint if exists` + neu erstellt — **exakten Constraint-Namen aus H01 im Plan verifizieren** (`\d aufgaben`), sonst wird nichts gedroppt und der ALTER-add doppelt.
- **Errcode/RPC:** keiner (normale CRUD wie 4.4). BA050 frei.

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
  final String kategorie;       // = aufgaben-CHECK-Wert
  final String? aktionRoute;    // 'behandlung'|'durchsicht'|… (OS-Schritt → 'behandlung')
  final bool optionalBeiOs;     // entfällt, wenn os_bei_erstellung=true
  const KettenSchritt({...});
}

const kVermehrungsKetten = <String, List<KettenSchritt>>{
  'brutableger': [
    KettenSchritt(schrittKey: 'zellen_brechen', tagVon: 9, tagBis: 9, ziel: jungvolk,
        titel: 'Weiselzellen bis auf 1 ausbrechen', kategorie: 'durchsicht', …),
    KettenSchritt(schrittKey: 'weiselkontrolle_os', tagVon: 25, tagBis: 30, ziel: jungvolk,
        titel: 'Weiselkontrolle + Oxalsäure bei Eilage', kategorie: 'behandlung', aktionRoute: 'behandlung', …),
  ],
  'kunstschwarm': [
    KettenSchritt(schrittKey: 'kellerhaft_ende', tagVon: 3, tagBis: 5, ziel: jungvolk, …),
    KettenSchritt(schrittKey: 'weiselkontrolle_os', tagVon: 7, tagBis: 7, ziel: jungvolk,
        aktionRoute: 'behandlung', optionalBeiOs: true, …),
  ],
  'koeniginnen_kunstschwarm': [ /* Jungvolk Tag 7 + Stammvolk Tag 9 Zellen brechen */ ],
  'brutableger'/'sammelbrutableger'/'flugling'/'natur_schwarm'/'schwarmtrieb_vermehrung': [ … Recherche 25 §10 ],
};
```
Konkrete Schritt-/Tageswerte je Methode aus Recherche 25 §10 (Übersichtstabelle) — im Plan vollständig ausformuliert (Fachstellen-Check-Kommentar). `VermehrungsEreignis`-Modell (`methode, erstelltAm, stammvolkId, jungvolkId?, osBeiErstellung, notiz`) + `fromJson`/`toInsertJson` (ohne betrieb_id/id → DB-Default).

## 3. Ketten-Generator
Pure Funktion (in `vermehrungs_ketten.dart`):
```dart
List<KettenVorschlag> kettenVorschlaege({
  required DateTime stichtag,
  required List<VermehrungsEreignis> ereignisse,
  required List<Aufgabe> ketten­Aufgaben,   // alle Aufgaben mit quelle='ereignis' (jeder Status)
  required Set<String> aktiveVolkIds,
})
```
Je Ereignis → `kVermehrungsKetten[methode]`; je Schritt:
1. **Fenster:** `start = erstellt_am + tagVon`, `ende = erstellt_am + tagBis` — DST-sicher (Kalenderkomponenten `DateTime(j,m,d+n)`, nie `Duration`).
2. **OS-Gate:** `schritt.optionalBeiOs && ereignis.osBeiErstellung` → überspringen.
3. **Ziel-Volk:** `stammvolk` → `stammvolkId`; `jungvolk` → `jungvolkId` (kann null sein → `volkId=null`, betriebsweiter Vorschlag mit Hinweis „Jungvolk anlegen & verknüpfen"). Ist das Ziel-Volk gesetzt, aber nicht in `aktiveVolkIds` (gelöscht/inaktiv) → überspringen.
4. **Dedup:** existiert eine `ketten­Aufgabe` mit `ereignisId==ereignis.id && schrittKey==schritt.schrittKey` (+ passender/leerer volkId) → überspringen (angenommen ODER übersprungen).
5. **Vorlauf** `kVorlaufTage=14` (Bestandskonstante): Vorschlag nur, wenn `heute ≥ start−14` **und** `heute ≤ ende`.
6. `KettenVorschlag{ereignis, schritt, fensterStart, fensterEnde, faelligAm=ende, volkId, beschreibung}`.

**Provider:** `kettenVorschlaegeProvider` (watcht `vermehrungsProvider` + `aufgabenListProvider` [quelle='ereignis'-Teilmenge] + `aktiveVoelkerProvider`). In `AuthController._datenNeuLaden` invalidieren.
**Annehmen:** materialisiert `aufgabe` (`quelle='ereignis'`, `ereignis_id`, `schritt_key`, `volk_id`, `faellig_am`, Titel/Beschreibung, `kategorie`, `aktionRoute`) → normale Abhak-/Volk-Logik. **Überspringen:** `aufgabe` `status='uebersprungen'` ohne volk_id (dedupt den Schritt).

## 4. UX
### 4.1 Ableger erfassen (vom Volk aus)
Route `/volk/:id/vermehrung`, Aktion „Ableger/Vermehrung erfassen" auf der Volk-Detailseite (Stammvolk vorbelegt). Formular: **Methode** (Dropdown; alpin-tragende zuerst: Kunstschwarm/Königinnen-Kunstschwarm/Brutableger/Flugling, dann Rest), **Erstellt am** (Default heute), **Oxalsäure bei Erstellung** (Switch), **Jungvolk** (optional: bestehendes Volk verknüpfen | „später"), **Notiz**. Rollen-Guard (viewer read-only), fehlerfest (try/catch + Snackbar), invalidiert `vermehrungsProvider`.
**Ketten-Vorschau (live):** sobald Methode gewählt, read-only-Liste der ganzen datierten Kette („Tag 9 · 14.6.: Weiselzellen brechen · Stammvolk" …), aus Katalog + `erstellt_am` gerechnet (OS-Gate berücksichtigt).

### 4.2 Vermehrungs-Sektion (Volk-Detailseite)
Listet aktive Ereignisse mit diesem Volk als Stamm- **oder** Jungvolk (Methode, Datum, Fortschritt „x/n Schritte" aus materialisierten Aufgaben). Aktion **„Jungvolk verknüpfen"** (setzt `jungvolk_id` auf ein bestehendes Volk; das neue Volk legt man über den 4.2-Flow mit `mutter_volk_id` an). **Ereignis löschen** (kaskadiert offene Ketten-Aufgaben).

### 4.3 Aufgaben-Tab
Neue Vorschlags-Sektion **„Vermehrung"** neben „Saison" (aus `kettenVorschlaegeProvider`). Annehmen/Überspringen wie oben. Angenommene Ketten-Aufgaben sind normale Aufgaben (Cockpit-Zählung, Volk-Section, Abhaken) — keine neue Abhak-Logik.

## 5. Architektur & Dateien
```
supabase/migrations/K01_vermehrungs_ereignisse.sql
lib/features/vermehrung/domain/vermehrung.dart              (VermehrungsMethode-Labels + alpinRelevant)
lib/features/vermehrung/domain/vermehrungs_ketten.dart      (KettenSchritt, kVermehrungsKetten, kettenVorschlaege, KettenVorschlag — pure)
lib/features/vermehrung/domain/vermehrungs_ereignis.dart    (Modell)
lib/features/vermehrung/domain/vermehrung_gateway.dart      (abstrakt) + data/{fake,supabase}_vermehrung_gateway.dart
lib/features/vermehrung/presentation/providers/vermehrung_provider.dart (Gateway + Liste + kettenVorschlaegeProvider + annehmen/ueberspringen)
lib/features/vermehrung/presentation/pages/vermehrung_form_page.dart    (Erfassung + Ketten-Vorschau)
lib/features/vermehrung/presentation/widgets/vermehrung_sektion.dart    (Volk-Detailseite)
```
**Modify:** `aufgaben/domain/aufgabe.dart` (+`ereignisId`/`schrittKey`, fromJson/toInsertJson) · `data/supabase_aufgaben_gateway.dart` · Aufgaben-Tab-Page (Vermehrungs-Sektion) · Volk-Detailseite (Sektion + Route) · `auth_providers._datenNeuLaden` (+`vermehrungsProvider`) · go_router.
**Import-Richtung (einseitig):** `vermehrung → aufgaben/voelker`. `aufgaben` importiert **nicht** `vermehrung` (Aufgabe trägt nur generische `ereignisId`/`schrittKey`).

## 6. Tests
- **`kettenVorschlaege`:** Dedup (angenommen/übersprungen → kein Vorschlag), Vorlauf (heute<start−14 → nicht; im Fenster → ja), nach `fensterEnde` → nicht; **Jungvolk-Ziel null → volkId null + Hinweis**; Ziel-Volk gelöscht (nicht in aktiveVolkIds) → nicht; **OS-Gate** (`optionalBeiOs`+`osBeiErstellung` → Schritt entfällt); **DST-Sicherheit** (Fenster über Zeitumstellung, z. B. erstellt_am Ende März + Tag 9).
- **Katalog-Invarianten:** je Methode ≥1 Schritt; `tagVon ≤ tagBis`; `schrittKey` eindeutig je Methode; Schritte chronologisch (`tagVon` aufsteigend); `kategorie` ∈ aufgaben-CHECK-Whitelist; `aktionRoute` gültig/null.
- **Modell:** `toInsertJson` ohne betrieb_id/id; fromJson-Roundtrip (methode/datum/os-Flag/jungvolk null).
- **Aufgabe:** `quelle='ereignis'`-Roundtrip (ereignisId/schrittKey in fromJson/toInsertJson); Annehmen → aufgabe mit den richtigen Feldern; Überspringen → status='uebersprungen'.
- **Gateway/Provider:** Fake-CRUD; Provider-Roundtrip; `_datenNeuLaden`-Invalidierung.

## 7. Deploy
Version **1.18.0+39** (Minor). Migration K01 auf Produktion `dcdcohktxbhdxnxjvcyp` (separat freigabepflichtig). `get_advisors(security)` → 0 neue Findings. Kein RPC/Errcode-Block. `bash deploy.sh` (stehende Freigabe nach grünen Tests).

## 8. decision-log / Roadmap
- **D-52 (neu):** Vermehrung als **Event-Ketten** (Ereignis-Anker + relative Fristen aus Dart-Katalog), materialisiert über die bestehende `aufgaben`-Infrastruktur (quelle='ereignis', Analog zu quelle='regel'). Engine generisch für 4.17 (Umlarv/Zucht). Relative Fristen **kalenderunabhängig** (anders als C).
- **Roadmap:** 4.16 Basis LIVE (D1); 4.17 (Zucht-Bewertung/Umlarv, D2) als Folgezyklus.

## 9. Offene Punkte (Plan)
- Vollständige Schritt-/Tageswerte aller 7 Ketten aus Recherche 25 §10 (Kellerhaft, Weiselkontrolle, Zellen brechen, Stammvolk-Nachbetreuung Tag 21, Nachschwarm +14 …) — im Plan als Katalog ausformulieren.
- Exakter Bestands-Constraint-Name des `quelle`-CHECK in `aufgaben` (H01) vor dem `drop constraint` verifizieren.
- Fortschritts-Anzeige „x/n Schritte" — zählt materialisierte Aufgaben je Ereignis (Ableitung, kein neuer Fetch).
