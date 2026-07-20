# Königin-/Volk-Bewertung & Auslese (Baustein D2a · Modul 4.17) — Design-Spec (v1)

**Datum:** 2026-07-20 · **Status:** in Review · **Modul:** 4.17 Zucht & Königinnen (Baustein D2a) · **Version:** 1.19.0+40
**Anlass:** Die BGD-Auslese-Grundregel (Recherche `../imkerei/02_Recherche/26_Zucht_Voelkerbeurteilung_BGD.md` §1): „Wirtschaftsvölker aus dem **besten Drittel** dienen der Jungvolkbildung; bis 1/3 der Jungvölker auflösen." Ohne strukturierte Bewertung fehlt die Grundlage, um vor der Vermehrung (D1) das beste Volk als Zuchtmutter zu wählen. Diese Spec liefert eine **schlanke, BGD-strukturierte Volk-Bewertung + Auslese** — keine formale Leistungsprüfung.

> **Zerlegung:** Baustein **D2** von D (D1 Ableger/Event-Ketten live v1.18.0). **D2a = Königin-/Volk-Bewertung + Auslese** (dieser Zyklus). **D2b = Umlarv-/Nachzucht-Kalender** (Event-Kette, reuse D1-Engine) folgt separat.

> **Bewusst NICHT in Scope:** formale Leistungsprüfung, **BLUP-Zuchtwertschätzung**, Herdebuch/KID/Prüfprotokoll, Belegstations-/KB-Reglement, Flügel-/Exterieurmessung (Kubitalindex etc.) — das ist Erwerbszucht-/Carnica-Infrastruktur; der Betrieb ist Buckfast + Hobby (max. 8 Völker) + „Zucht als Erwerb nicht in Scope" (imkerei-CLAUDE.md). Der `koeniginnen`-Register (`begattungsart`/`mutter_koenigin_id`/`herkunft`/`rasse`/`linie`/`schlupfjahr`) ist bereits vorhanden und wird **nicht** erweitert; `eilage_datum` kommt mit D2b.

## 1. Ziele & Nicht-Ziele
**Ziele:**
1. **Volk-Bewertung erfassen** (mehrfach je Saison — die 3 BGD-Kontrolltermine Frühling/Sommer/Herbst) auf 5 BGD-Achsen (Skala 1–4), mit Snapshot der zugeordneten Königin.
2. **Saison-Aggregat je Volk** (pure): Mittelwert je Achse, **Minimum für Schwarmträgheit**; Gesamtnote = Ø der 5 Achsen.
3. **Auslese-Ranking** (pure): aktive bewertete Wirtschaftsvölker einer Saison in Drittel (bestes/mittel/schwächstes) → Empfehlung „Nachzucht / behalten / prüfen".
4. **Volk-Integration:** Bewerten vom Volk aus; Bewertungs-Sektion + Auslese-Klasse je Volk; Auslese-Übersicht auf der Projekt-Seite; Gesamtnote-Badge im Völker-Tab.

**Nicht-Ziele:** BLUP/formale Leistungsprüfung/Herdebuch/KID (s. o.); Königin-Register-Erweiterung; gewichtete Zuchtwerte; Honig-kg-Objektivmessung (kommt mit 4.7 Ernte — hier `honig` als relative 1–4-Note); Saison-übergreifende Trendanalyse.

## 2. Datenmodell

### 2.1 Migration L01 (`koenigin_bewertungen`, normale CRUD)
```sql
create table if not exists public.koenigin_bewertungen (
  id uuid primary key default gen_random_uuid(),
  volk_id uuid not null,
  koenigin_id uuid,                        -- Snapshot der zugeordneten Königin z. Bewertungszeitpunkt
  saison_jahr int not null,
  bewertet_am date not null,
  sanftmut smallint not null check (sanftmut between 1 and 4),
  wabensitz smallint not null check (wabensitz between 1 and 4),
  schwarmtraegheit smallint not null check (schwarmtraegheit between 1 and 4),
  honig smallint not null check (honig between 1 and 4),
  vitalitaet smallint not null check (vitalitaet between 1 and 4),
  notiz text,
  betrieb_id uuid not null default private.aktive_betrieb_id()
    references public.betriebe(id) on delete cascade,
  created_by uuid, updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (betrieb_id, id),
  constraint bewertung_volk_fk foreign key (betrieb_id, volk_id)
    references public.voelker (betrieb_id, id) on delete cascade,
  constraint bewertung_koenigin_fk foreign key (betrieb_id, koenigin_id)
    references public.koeniginnen (betrieb_id, id) on delete set null (koenigin_id),
  constraint bewertung_saison_chk check (saison_jahr between 2020 and 2100)
);
alter table public.koenigin_bewertungen enable row level security;
revoke all on public.koenigin_bewertungen from anon, public;
grant select, insert, update, delete on public.koenigin_bewertungen to authenticated;
create index if not exists idx_bewertung_volk on public.koenigin_bewertungen (betrieb_id, volk_id);
create index if not exists idx_bewertung_koenigin on public.koenigin_bewertungen (betrieb_id, koenigin_id);
-- set_row_actor + set_updated_at Trigger; RLS sel=meine_betrieb_ids, ins/upd/del=kann_schreiben (voll ausschreiben).
-- ROLLBACK: drop table public.koenigin_bewertungen;
```
- **Komposit-FK `koeniginnen`:** setzt `unique(betrieb_id, id)` auf `koeniginnen` voraus — im Plan verifizieren (sonst `unique`-Constraint mit-ergänzen). `koenigin_id` nullable + ON DELETE SET NULL (Bewertung überlebt Königin-Wechsel/-Löschung).
- Mehrere Bewertungen je Volk/Saison erlaubt (kein Unique auf (volk,saison)). Kein RPC/Errcode (BA050 frei).

### 2.2 Dart (`bewertung.dart`, Fachkonstante + Modell)
```dart
class BewertungsAchse {
  final String key;          // = DB-Spaltenname
  final String label;
  final String hilfetext;
  final bool aggregatMinimum; // true nur für schwarmtraegheit (ein Schwarm zählt → Min statt Ø)
  const BewertungsAchse({required this.key, required this.label, required this.hilfetext, this.aggregatMinimum = false});
}

const kBewertungsAchsen = <BewertungsAchse>[
  BewertungsAchse(key: 'sanftmut', label: 'Sanftmut', hilfetext: 'Ruhig beim Öffnen, wenig Stechlust.'),
  BewertungsAchse(key: 'wabensitz', label: 'Wabensitz', hilfetext: 'Bienen bleiben ruhig auf der Wabe, laufen nicht.'),
  BewertungsAchse(key: 'schwarmtraegheit', label: 'Schwarmträgheit', hilfetext: 'Wenig Schwarmtrieb bei angepasster Erweiterung.', aggregatMinimum: true),
  BewertungsAchse(key: 'honig', label: 'Honigertrag', hilfetext: 'Relativer Ertrag im Vergleich zu den anderen Völkern.'),
  BewertungsAchse(key: 'vitalitaet', label: 'Vitalität', hilfetext: 'Volksstärke im Jahresverlauf, Überwinterung, Gesundheit.'),
];
const kSkalaLabels = {1: 'ungenügend', 2: 'genügend', 3: 'gut', 4: 'sehr gut'};
```
`KoeniginBewertung`-Modell (`volkId, koeniginId?, saisonJahr, bewertetAm, sanftmut, wabensitz, schwarmtraegheit, honig, vitalitaet, notiz`) + `fromJson`/`toInsertJson` (ohne betrieb_id/id). Achsen-Wert-Zugriff über `wertFuer(achseKey)` (mappt Key→Feld) für generische UI/Aggregation.

## 3. Aggregation + Auslese (pure)
```dart
enum AusleseKlasse { bestes, mittel, schwaechstes }

/// Saison-Aggregat je Achse + Gesamtnote aus den (1..n) Saison-Bewertungen eines Volks.
class SaisonAggregat {
  final Map<String, double> achsen; // key → aggregierter Wert (Ø, ausser schwarmtraegheit = Min)
  final double gesamtnote;          // Ø der 5 Achsenwerte, 1.0..4.0
  final int anzahl;                 // Anzahl Bewertungen
}
SaisonAggregat? aggregiereSaison(List<KoeniginBewertung> bewertungenEinesVolks); // null wenn leer

/// Auslese: bewertete aktive Völker der Saison → Drittel.
class AusleseEintrag { final String volkId; final double gesamtnote; final int rang; final AusleseKlasse? klasse; } // klasse=null bei <3 Völkern
List<AusleseEintrag> ausleseRanking(Map<String, SaisonAggregat> proVolk); // absteigend nach Note
```
- **`aggregiereSaison`:** je Achse Mittelwert der Saison-Bewertungen; **`schwarmtraegheit` = Minimum**. Gesamtnote = ungewichteter Mittelwert der 5 Achsen-Aggregate (eine Nachkommastelle). `null` bei 0 Bewertungen.
- **`ausleseRanking`:** absteigend nach Gesamtnote sortiert (Tie-Break: `volkId` für Determinismus), Rang 1..n. **Drittel-Grenzen deterministisch** über Rang-Position; bei **< 3 Völkern `klasse=null`** (nur Note+Rang, keine Drittel-Auslese). Nur aktive Völker mit ≥1 Saison-Bewertung.
- **Provider:** `bewertungenProvider` (alle des Betriebs) → `saisonAggregatProvider` (Map volkId→Aggregat, aktuelle Saison) → `ausleseProvider` (Ranking). In `_datenNeuLaden` invalidieren.

## 4. UX
### 4.1 Bewerten (vom Volk aus)
Route `/voelker/:id/bewertung` (Kind unter `/voelker/:id`, analog gesundheit/vermehrung), Aktion „Bewerten" auf der Volk-Detailseite. Formular: 5 Achsen als `SegmentedButton` 1–4 (mit `hilfetext`), `bewertet_am` (Default heute; `saison_jahr = bewertet_am.year`), `notiz`. Speichern → `koeniginId` Snapshot aus `volk.koeniginId` (aus dem Volk-Objekt), `betrieb_id`/id per DB-Default. Rollen-Guard (viewer read-only), fehlerfest (try/catch + Snackbar), invalidiert `bewertungenProvider`.

### 4.2 Bewertungs-Sektion (Volk-Detailseite)
Zeigt die Bewertungen dieses Volks (Liste neueste zuerst, editier-/löschbar) + das **Saison-Aggregat** (Gesamtnote + Achsen-Balken) + die **Auslese-Klasse-Badge** (bestes/mittel/schwächstes, grün/neutral/amber; bei <3 Völkern nur die Note). Leerzustand: „Noch nicht bewertet — jetzt bewerten".

### 4.3 Auslese-Übersicht (Projekt-Seite) + Völker-Tab-Badge
- **Projekt-Seite:** neue Sektion „Auslese (Saison JJJJ)" — Rangliste der bewerteten aktiven Völker (Note, Drittel-Farbe, Rang) + „nicht bewertet"-Rest; bei <3 Völkern Hinweis „ab 3 bewerteten Völkern Drittel-Auslese". Reine Ableitung aus `ausleseProvider` (kein neuer Fetch).
- **Völker-Tab:** kompakte **Gesamtnote-Badge** auf den Volk-Karten (Note + Klasse-Farbe), reine Ableitung.

## 5. Architektur & Dateien
```
supabase/migrations/L01_koenigin_bewertungen.sql
lib/features/zucht/domain/bewertung.dart              (Modell, kBewertungsAchsen, AusleseKlasse, aggregiereSaison, ausleseRanking, wertFuer — pure)
lib/features/zucht/domain/bewertung_gateway.dart      (abstrakt) + data/{fake,supabase}_bewertung_gateway.dart
lib/features/zucht/presentation/providers/bewertung_provider.dart (Gateway + bewertungenProvider + saisonAggregatProvider + ausleseProvider)
lib/features/zucht/presentation/pages/bewertung_form_page.dart
lib/features/zucht/presentation/widgets/bewertung_sektion.dart      (Volk-Detailseite)
lib/features/zucht/presentation/widgets/auslese_uebersicht.dart     (Projekt-Seite)
```
**Modify:** Volk-Detailseite (Bewerten-Aktion + `BewertungSektion`) · Völker-Tab-Karten (Note-Badge) · Projekt-Seite (`AusleseUebersicht`) · `auth_providers._datenNeuLaden` (+`bewertungenProvider`) · `app_router` (Route).
**Import-Richtung (einseitig):** `zucht → voelker` (liest `volk.koeniginId`/Status). `voelker` importiert **nicht** `zucht` (die Badges lesen `ausleseProvider` in der Völker-Tab-Page, nicht im Volk-Modell).

## 6. Tests
- **`aggregiereSaison`:** Mittelwert je Achse; **Minimum für schwarmtraegheit** (Bewertungen [4,4,1] → schwarm-Aggregat 1, andere Ø); Gesamtnote = Ø der 5; 1 Bewertung → Aggregat=Werte; 0 → null.
- **`ausleseRanking`:** 3 Völker → je 1 pro Drittel; 6 → 2/2/2; 9 → 3/3/3; **< 3 → keine Klasse**; deterministischer Tie-Break bei gleicher Note; absteigend sortiert; Rang korrekt.
- **Katalog-Invarianten:** genau 5 Achsen, Keys eindeutig + = DB-Spalten, **nur schwarmtraegheit `aggregatMinimum`**, Skala 1–4 vollständig.
- **Modell:** fromJson/toInsertJson (ohne betrieb_id/id, koenigin_id-Snapshot nullable); **Achsen-Wertebereich-Parität** (Dart-Validierung 1–4 == DB-CHECK); `wertFuer` mappt alle 5 Keys.
- **Gateway/Provider:** Fake-CRUD; `saisonAggregat`/`ausleseProvider`-Ableitung; `_datenNeuLaden`-Invalidierung.

## 7. Deploy
Version **1.19.0+40** (Minor). Migration L01 auf Produktion `dcdcohktxbhdxnxjvcyp` (freigabepflichtig). `get_advisors(security + performance)` → 0 neue (FK-Indizes volk_id/koenigin_id gesetzt). Kein RPC/Errcode. `bash deploy.sh` nach grünen Tests.

## 8. decision-log / Roadmap
- **D-55 (neu):** Königin-Auslese als schlanke 5-Achsen-Bewertung (BGD-Skala 1–4) + Drittel-Ranking — bewusst OHNE BLUP/Herdebuch/formale Leistungsprüfung (Buckfast + Hobby + nicht-Erwerb). Schwarmträgheit als Minimum aggregiert (BGD-Methode). Speist später die Zuchtmutter-Wahl für D2b (Umlarv-Kalender).
- **Roadmap:** 4.17 Basis (Auslese) LIVE (D2a); D2b Umlarv-Kalender folgt.

## 9. Offene Punkte (Plan)
- `unique(betrieb_id, id)` auf `koeniginnen` vor dem Komposit-FK verifizieren (pg_constraint) — sonst mit-ergänzen.
- Exakte Drittel-Grenzen-Formel (z. B. `rang <= ceil(n/3)` bestes, `rang > n - floor(n/3)` schwächstes) im Plan festnageln, inkl. Tests für n=3/4/5/6/9.
- `saison_jahr`-Auswahl in der Auslese-Übersicht (v1: aktuelle Saison = `DateTime.now().year`; Vorjahre out of scope).
