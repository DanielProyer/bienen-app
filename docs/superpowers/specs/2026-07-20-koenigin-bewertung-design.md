# Volk-/Königin-Bewertung (Baustein D2a · Modul 4.17) — Design-Spec (v2)

**Datum:** 2026-07-20 · **Status:** in Review (v2 nach adversarialem Multi-Agent-Review) · **Modul:** 4.17 Zucht & Königinnen (Baustein D2a) · **Version:** 1.19.0+40
**Anlass:** Die BGD-Auslese-Grundregel (`../imkerei/02_Recherche/26_Zucht_Voelkerbeurteilung_BGD.md` §1): „nur gesunde, starke Völker am Stand halten … der Imker muss aktiv selektionieren." Ohne strukturierte Bewertung fehlt die Grundlage, die Qualität eines Volks über die Saison zu dokumentieren (und später die Zuchtmutter zu wählen). Diese Spec liefert eine **schlanke, BGD-strukturierte Volk-Bewertung je Volk** — kein volk-übergreifendes Ranking, keine formale Leistungsprüfung.

> **Zerlegung:** Baustein **D2** von D (D1 Ableger/Event-Ketten live v1.18.0). **D2a = Volk-Bewertung** (dieser Zyklus). **D2b = Umlarv-/Nachzucht-Kalender** (Event-Kette) folgt separat.

> **v2-Änderungen (aus dem Review, 25 bestätigte Findings):** (1) **Volk-übergreifendes Auslese-Ranking komplett aus v1 genommen** — greift erst ab 3 Völkern (Betrieb hat 1), vermischt Wirtschafts-/Jungvölker (die das Datenmodell gar nicht unterscheidet), braucht Vorjahresdaten für seinen Zweck, und war Quelle fast aller Ranking-Korrektheits-Nits. Folgt als eigener Zyklus, wenn ≥3 Völker existieren. (2) **Achsen verfeinert:** `vitalitaet` überladen → in **Volksstärke** + **Gesundheit** getrennt; **Brutbild** ergänzt; **Honig raus** (relative Note bei 1–2 Völkern sinnlos + doppelt mit 4.7 Ernte). (3) BGD-Verhaltensanker je Achse statt generischer Notenwörter. (4) `saison_jahr` abgeleitet statt gespeichert; `id`/Edit/Delete im Modell; Status-Guard.

## 1. Ziele & Nicht-Ziele
**Ziele:**
1. **Volk-Bewertung erfassen** (mehrfach je Saison — die BGD-Kontrolltermine Frühling/Sommer/Herbst) auf 6 BGD-Achsen (Skala 1–4 mit Verhaltensankern), mit Referenz auf die zum Zeitpunkt zugeordnete Königin.
2. **Saison-Aggregat je Volk** (pure): Mittelwert je Achse, **Minimum für Schwarmträgheit** (ein Schwarm zählt, BGD-Methode); Gesamtnote = Ø der 6 Achsen.
3. **Volk-Integration:** Bewerten vom Volk aus; Bewertungs-Sektion auf der Volk-Detailseite (Liste + Saison-Aggregat + Gesamtnote), editier-/löschbar.

**Nicht-Ziele (spätere Zyklen / bewusst draussen):**
- **Volk-übergreifendes Auslese-Ranking / Drittel-Klassen / Auslese-Übersicht / Völker-Tab-Badge** — Folge-Zyklus ab ≥3 Völkern (braucht dann auch ein Wirtschafts-/Jungvolk-Feld am Volk + Vorjahres-Saisonwahl).
- **BLUP-Zuchtwertschätzung, formale Leistungsprüfung, Herdebuch/KID/Prüfprotokoll, Belegstations-/KB-Reglement, Flügel-/Exterieurmessung** — Erwerbszucht-/Carnica-Infrastruktur; Betrieb ist Buckfast + Hobby (max. 8 Völker) + „Zucht als Erwerb nicht in Scope".
- **Honig-Achse** (kommt via 4.7 Ernte als kg, nicht als subjektive Relativ-Note); Königin-Register-Erweiterung (`eilage_datum` erst mit D2b); Serbelvolk↔Zukunftsvolk-Qualitativ-Logik; Saison-übergreifende Trends.

## 2. Datenmodell

### 2.1 Migration L01 (`volk_bewertungen`, normale CRUD)
```sql
create table if not exists public.volk_bewertungen (
  id uuid primary key default gen_random_uuid(),
  volk_id uuid not null,
  koenigin_id uuid,                        -- Zuordnungs-Referenz z. Bewertungszeitpunkt (nullable, SET NULL)
  bewertet_am date not null,               -- Saison = extract(year from bewertet_am), NICHT separat gespeichert
  sanftmut smallint not null check (sanftmut between 1 and 4),
  wabensitz smallint not null check (wabensitz between 1 and 4),
  schwarmtraegheit smallint not null check (schwarmtraegheit between 1 and 4),
  brutbild smallint not null check (brutbild between 1 and 4),
  volksstaerke smallint not null check (volksstaerke between 1 and 4),
  gesundheit smallint not null check (gesundheit between 1 and 4),
  notiz text,
  betrieb_id uuid not null default private.aktive_betrieb_id()
    references public.betriebe(id) on delete cascade,
  created_by uuid, updated_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (betrieb_id, id),
  constraint bewertung_volk_fk foreign key (betrieb_id, volk_id)
    references public.voelker (betrieb_id, id) on delete cascade,   -- operativ (wie aufgaben), keine Pflichtdaten
  constraint bewertung_koenigin_fk foreign key (betrieb_id, koenigin_id)
    references public.koeniginnen (betrieb_id, id) on delete set null (koenigin_id),
  constraint bewertung_zukunft_chk check (bewertet_am <= current_date + 7)  -- ODER Formular-Plausi (Plan entscheidet, J01-Konvention)
);
alter table public.volk_bewertungen enable row level security;
revoke all on public.volk_bewertungen from anon, public;
grant select, insert, update, delete on public.volk_bewertungen to authenticated;
create index if not exists idx_bewertung_volk on public.volk_bewertungen (betrieb_id, volk_id);
create index if not exists idx_bewertung_koenigin on public.volk_bewertungen (betrieb_id, koenigin_id);
-- set_row_actor + set_updated_at Trigger + 4 RLS-Policies (sel=meine_betrieb_ids, ins/upd/del=kann_schreiben) — im Plan voll ausschreiben.
-- ROLLBACK: drop table public.volk_bewertungen;
```
- **`saison_jahr` NICHT als Spalte** — Single Source of Truth ist `bewertet_am`; die Saison wird in der Aggregation aus `year(bewertet_am)` abgeleitet (Review: keine Drift/Kohärenz-Falle).
- **Komposit-FK `koeniginnen`** setzt `unique(betrieb_id, id)` auf `koeniginnen` voraus — **im Plan per `pg_constraint` verifizieren** (C03), sonst mit-ergänzen.
- **`bewertet_am`-Zukunfts-Guard:** entweder immutabler CHECK-Kompromiss oder (J01-Konvention-konform, wie bei Vermehrung) rein im Formular — der Plan entscheidet; wenn CHECK, dann Doku als „kleiner Toleranz-Guard". Kein RPC/Errcode (BA050 frei).

### 2.2 Dart (`bewertung.dart`, Fachkonstante + Modell)
```dart
class BewertungsAchse {
  final String key;          // = DB-Spaltenname
  final String label;
  final List<String> anker;  // 4 Verhaltensanker, Index 0 = Note 1 … Index 3 = Note 4
  const BewertungsAchse({required this.key, required this.label, required this.anker});
}

// Reihenfolge = Anzeigereihenfolge; alle 'höher = besser'.
const kBewertungsAchsen = <BewertungsAchse>[
  BewertungsAchse(key: 'sanftmut', label: 'Sanftmut',
      anker: ['stechlustig', 'nervös', 'sanft', 'sehr sanft']),
  BewertungsAchse(key: 'wabensitz', label: 'Wabensitz',
      anker: ['flüchtig/abtropfend', 'laufend', 'ruhig', 'fest sitzend']),
  BewertungsAchse(key: 'schwarmtraegheit', label: 'Schwarmträgheit',
      anker: ['geschwärmt/starker Trieb', 'deutlicher Trieb', 'geringer Trieb', 'kein Schwarmtrieb']),
  BewertungsAchse(key: 'brutbild', label: 'Brutbild',
      anker: ['stark löchrig/Buckelbrut', 'lückig', 'gut, wenige Lücken', 'geschlossen/lückenlos']),
  BewertungsAchse(key: 'volksstaerke', label: 'Volksstärke',
      anker: ['sehr schwach/Serbel', 'schwach', 'durchschnittlich', 'stark (jahreszeit-entsprechend)']),
  BewertungsAchse(key: 'gesundheit', label: 'Gesundheit',
      anker: ['stark belastet/Symptome', 'Varroa-/Krankheitszeichen', 'leichte Auffälligkeit', 'keine Auffälligkeiten']),
];
```
- **`schwarmtraegheit` und `gesundheit` bewusst eigene Achsen:** so kann ein starkes, aber varroa-/krankheitsbelastetes Volk seine Gesundheitsnote nicht hinter Stärke verstecken (Review: vitalitaet-Maskierung).
- `VolkBewertung`-Modell: `id, volkId, koeniginId?, bewertetAm, sanftmut, wabensitz, schwarmtraegheit, brutbild, volksstaerke, gesundheit, notiz` + `fromJson`/`toInsertJson` (ohne betrieb_id/id; `id:''` bei Neu → DB vergibt). Achsen-Wert-Zugriff `wertFuer(achseKey)` (Key→Feld) für generische UI/Aggregation.

## 3. Aggregation (pure)
```dart
class SaisonAggregat {
  final Map<String, double> achsen; // key → aggregierter Wert (Ø, ausser schwarmtraegheit = Min)
  final double gesamtnote;          // Ø der 6 Achsenwerte (VOLLPRÄZISE; Rundung nur Anzeige)
  final int anzahl;
}
SaisonAggregat? aggregiereSaison(List<VolkBewertung> bewertungenEinesVolksEinerSaison); // null wenn leer
```
- Je Achse Mittelwert der (1..n) Saison-Bewertungen; **`schwarmtraegheit` = Minimum** (hart verdrahtet mit BGD-Kommentar — kein generischer Flag). Gesamtnote = ungewichteter Mittelwert der 6 **rohen** Achsen-Aggregate; **Rundung auf 1 Nachkommastelle ist reine Anzeige**, nie im Vergleich (kein Ranking in v1, aber Konvention festgehalten).
- **Königin-Zäsur (bekannte v1-Grenze):** wird ein Volk mitten in der Saison umgeweiselt, mischt das Aggregat zwei Königinnen. Für v1 akzeptiert (selten; die Einzelbewertungen bleiben sichtbar); die Segmentierung nach `koenigin_id` kommt bei Bedarf mit D2b.
- **Provider:** `bewertungenProvider` (alle des Betriebs), `bewertungenFuerVolkProvider.family<List, volkId>` (reine Ableitung), Aggregat wird in der Sektion via `aggregiereSaison` (aktuelle Saison = `year(now)`) berechnet. `bewertungenProvider` in `_datenNeuLaden` invalidieren.

## 4. UX
### 4.1 Bewerten (vom Volk aus)
Route `/voelker/:id/bewertung` (Kind unter `/voelker/:id`, analog gesundheit/vermehrung), Aktion „Bewerten" auf der Volk-Detailseite. Das Formular **watcht `voelkerListProvider`** und findet das Volk per id (Muster vermehrung_form_page) → `koeniginId`-Referenz aus `volk.koeniginId`. Felder: 6 Achsen als `SegmentedButton` 1–4 mit dem jeweiligen `anker`-Text unter dem Regler, `bewertet_am` (Default heute), `notiz`. **Guards:** Rollen-Guard (viewer read-only); **Status-Guard** — bei inaktivem Volk (status ≠ aktiv) Hinweis „Volk inaktiv" (Bewerten bleibt möglich, aber markiert). Fehlerfest (try/catch + Snackbar), invalidiert `bewertungenProvider`.

### 4.2 Bewertungs-Sektion (Volk-Detailseite)
- **Saison-Aggregat** dieses Volks (aktuelle Saison): **Gesamtnote** (1.0–4.0, 1 NKS) + Achsen-Balken (je Achse der aggregierte Wert). Leerzustand „Noch nicht bewertet — jetzt bewerten".
- **Liste** der Bewertungen (neueste zuerst, mit Datum + Kurznoten), je Eintrag **editier-/löschbar** (Popup-Menü, Muster aufgaben/vermehrung): Editieren → `/voelker/:id/bewertung?b=<id>` (Formular im Edit-Modus, lädt die Bewertung); Löschen → Bestätigungsdialog.
- **Kein volk-übergreifendes Ranking** in v1 (weder hier noch auf der Projekt-Seite noch als Völker-Tab-Badge).

## 5. Architektur & Dateien
```
supabase/migrations/L01_volk_bewertungen.sql
lib/features/zucht/domain/bewertung.dart              (VolkBewertung-Modell, kBewertungsAchsen, SaisonAggregat, aggregiereSaison, wertFuer — pure)
lib/features/zucht/domain/bewertung_gateway.dart      (abstrakt) + data/{fake,supabase}_bewertung_gateway.dart
lib/features/zucht/presentation/providers/bewertung_provider.dart (Gateway + bewertungenProvider + bewertungenFuerVolkProvider + speichern/loeschen)
lib/features/zucht/presentation/pages/bewertung_form_page.dart      (Erfassung/Edit, 6 Achsen)
lib/features/zucht/presentation/widgets/bewertung_sektion.dart      (Volk-Detailseite)
```
**Modify:** Volk-Detailseite (Bewerten-Aktion + `BewertungSektion`) · `auth_providers._datenNeuLaden` (+`bewertungenProvider`) · `app_router` (Route `/voelker/:id/bewertung`, optional `?b=<id>` für Edit).
**Import-Richtung:** `zucht → voelker` einseitig (liest `volk.koeniginId`/Status). `voelker` importiert **nicht** `zucht` (keine Badges im Völker-Tab in v1 → keine Rückkante).

## 6. Tests
- **`aggregiereSaison`:** Mittelwert je Achse; **Minimum für schwarmtraegheit** (Bewertungen mit schwarm [4,4,1] → 1, andere Achsen Ø); Gesamtnote = Ø der 6 rohen Aggregate (nicht der gerundeten); 1 Bewertung → Aggregat = Werte; leere Liste → null.
- **Katalog-Invarianten:** genau 6 Achsen; Keys eindeutig + = DB-Spaltennamen; je Achse genau 4 Anker; `wertFuer` mappt alle 6 Keys.
- **Modell:** fromJson/toInsertJson (ohne betrieb_id/id; koeniginId-Referenz nullable; `id:''`-Neu-Pfad); Wertebereich-Parität (Dart 1–4 == DB-CHECK je Achse).
- **Gateway/Provider:** Fake-CRUD (speichern/loeschen/alle); `bewertungenFuerVolkProvider`-Ableitung; `_datenNeuLaden`-Invalidierung.

## 7. Deploy
Version **1.19.0+40** (Minor). Migration L01 auf Produktion `dcdcohktxbhdxnxjvcyp` (freigabepflichtig). `get_advisors(security + performance)` → 0 neue (FK-Indizes volk_id/koenigin_id gesetzt). Kein RPC/Errcode. `bash deploy.sh` nach grünen Tests.

## 8. decision-log / Roadmap
- **D-55 (neu):** Volk-Bewertung als schlanke **6-Achsen-BGD-Bewertung je Volk** (Sanftmut/Wabensitz/Schwarmträgheit/Brutbild/Volksstärke/Gesundheit, Skala 1–4 mit Verhaltensankern) + Saison-Aggregat + Gesamtnote. Schwarmträgheit als Minimum aggregiert; Gesundheit bewusst eigene Achse (Maskierung vermeiden). **Kein volk-übergreifendes Ranking in v1** (greift erst ab ≥3 Völkern, vermischt Populationen ohne Wirtschafts-/Jungvolk-Feld, braucht Vorjahresdaten) — Folge-Zyklus. Kein BLUP/Herdebuch (Buckfast + Hobby). Honig via 4.7 (kg), nicht als Relativ-Note.
- **Roadmap:** 4.17 Basis (Volk-Bewertung) LIVE (D2a); Auslese-Ranking + D2b Umlarv-Kalender folgen.

## 9. Offene Punkte (Plan)
- `unique(betrieb_id, id)` auf `koeniginnen` vor dem Komposit-FK verifizieren (pg_constraint) — sonst mit-ergänzen.
- `bewertet_am`-Zukunfts-Guard: CHECK (immutabler Kompromiss) vs. Formular-Plausi — Plan entscheidet (J01-Konvention: eher Formular).
- Edit-Modus des Formulars (`?b=<id>`): Bewertung laden + `koeniginId`/`bewetetAm` erhalten (Roundtrip), wie aufgabe_form_page.
