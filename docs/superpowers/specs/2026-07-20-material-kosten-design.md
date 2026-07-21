# Material-Management-Überarbeitung + Kosten-Dashboard (Modul 4.22 / 4.10-Rework)

**Datum:** 2026-07-20 · **Track:** App · **Status:** Design freigegeben (Abschnitte 1–4), Spec zur Review
**Modell-Strategie:** Datenmodell/Migration N01 + Trigger Fable 5 hoch · Aggregation (rein) Fable 5 hoch · UI Opus 4.8

---

## 1. Ziel & Kontext

Das Material-Feature (`lib/features/material/`) vermischt heute Verbrauchs- und Investitionsmaterial in einer Liste, zeigt einen **fehlerhaften Nachkauf-Alarm** und trägt nicht mehr relevantes Standbau-Material mit. Ziel: **Material klar nach Typ trennen (Verbrauch / Anlage / Archiv), den Bug fixen, Standbau archivieren und ein aussagekräftiges Kosten-Dashboard** (Modul 4.22 Quick-Win) bauen.

**Bug-Ursache (verifiziert):** `nachkaufenItemsProvider` feuert bei `isConsumable && status=='gekauft' && stockQty < minQty`. Verbrauch (Behandlung/Fütterung) senkt `stock_qty`, **aber ein Kauf erhöht ihn nirgends** → frisch gekauftes Verbrauchsmaterial steht auf `stock_qty=0`, und mit `min_qty>0` gilt sofort `0 < min` → Fehlalarm, obwohl nichts verbraucht wurde. Die Mengen-Buchhaltung ist nur halb verdrahtet.

**Bestand:** `materials` (category, name, quantity, unit, price_chf, supplier, phase, status geplant|bestellt|gekauft, bereich imkerei|standbau|honigverarbeitung, is_consumable, stock_qty, min_qty, photo_urls/pdf_urls) · `material_purchases` (material_id-FK, gekauft_am, menge, stueckpreis, gesamtpreis, shop, beleg_nr, beleg_foto, zahlungsart) · `ausgabenUebersichtProvider` (bisher/geplant/bereich/zahlungsart — Dashboard-Basis existiert). Fachbezug: `imkerei/02_Recherche/20` (Wirtschaftlichkeit), `03` (Erstausstattung).

### Grundhaltung
- **Mandantenfähig, keine Arosa-Hardcodes.** Alle Änderungen betrieb-isoliert.
- **Typ-Trennung nutzt das bestehende `is_consumable`** (Verbrauch = true, Anlage = false) — **kein neues Typ-Feld**.

---

## 2. Scope & YAGNI

**In Scope:** (1) Nachkauf-Fix (Kauf→Bestand-Trigger + Bestands-Korrektur-Migration); (2) `archiviert`-Flag + Standbau archivieren + Archiv-Ansicht; (3) klare Typ-Trennung Verbrauch/Anlage/Archiv in der UI; (4) Kosten-Dashboard (Investition vs. laufend, Budget Soll/Ist, Kategorie, Jahr, Zahlungsart, Kosten je Volk, Archiv-Rubrik); (5) professionellere Material-Ansicht.

**Bewusst NICHT (YAGNI):** neues Typ-Enum (bool reicht); Austausch-/Nutzungsdauer-Horizont für Anlagegüter; Abschreibungslogik; Kosten-je-kg-Honig (keine Ernte); Budget-Prognose/Trend über Jahre (nur 2026-Daten); Multi-Stand-Kostenstellen; die **gesamte App-Layout-/Design-Überarbeitung** (späteres, separates Thema — hier nur die Material-/Kosten-Ansicht).

---

## 3. Datenmodell & Migration (N01)

`is_consumable` bleibt der Verbrauch/Anlage-Diskriminator. Neu: `archiviert`. `MaterialItem` bekommt `archiviert` (bool) in fromJson/toJson/copyWith (Default false).

**Migration `N01_material_rework.sql` (Produktion — separat freigeben):**
```sql
-- N01_material_rework.sql | Material-Rework: Archiv-Flag, Standbau archivieren, Bestands-Korrektur, Kauf→Bestand-Trigger.
alter table public.materials add column if not exists archiviert boolean not null default false;

-- (1) Standbau raus aus dem aktiven Betrieb (reversibel).
update public.materials set archiviert = true where bereich = 'standbau';

-- (2) Bestands-Korrektur (fixt den Fehlalarm): Verbrauchsmaterial-Bestand aus der Kauf-Historie,
--     und wo gekauft aber keine Kauf-Menge erfasst ist, mind. auf den Mindestbestand.
update public.materials m
   set stock_qty = greatest(m.stock_qty, coalesce(
       (select sum(p.menge) from public.material_purchases p where p.material_id = m.id and p.menge is not null), 0))
 where m.is_consumable;
update public.materials m
   set stock_qty = m.min_qty
 where m.is_consumable and m.status = 'gekauft' and m.stock_qty < m.min_qty
   and not exists (select 1 from public.material_purchases p where p.material_id = m.id and p.menge is not null);

-- (3) Kauf → Bestand-Trigger (nur Verbrauchsmaterial, nur wenn menge gesetzt). Plain (INVOKER):
--     der Nutzer aktualisiert den Bestand seines eigenen Materials via seiner RLS-Schreibrechte.
create or replace function public.material_bestand_nachfuehren() returns trigger
  language plpgsql set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    if new.menge is not null then
      update public.materials set stock_qty = stock_qty + new.menge
        where id = new.material_id and is_consumable;
    end if;
  elsif tg_op = 'DELETE' then
    if old.menge is not null then
      update public.materials set stock_qty = greatest(0, stock_qty - old.menge)
        where id = old.material_id and is_consumable;
    end if;
  elsif tg_op = 'UPDATE' then
    update public.materials set stock_qty = greatest(0, stock_qty
        + coalesce(new.menge,0) - coalesce(old.menge,0))
      where id = new.material_id and is_consumable;
  end if;
  return null;
end $$;
drop trigger if exists trg_material_bestand on public.material_purchases;
create trigger trg_material_bestand after insert or update or delete
  on public.material_purchases for each row execute function public.material_bestand_nachfuehren();
-- ROLLBACK: drop trigger trg_material_bestand on public.material_purchases;
--           drop function public.material_bestand_nachfuehren();
--           alter table public.materials drop column archiviert;  (Bestands-/Standbau-Updates sind Daten, nicht reversibel per DDL)
```
`material_purchases.betrieb_id` + Komposit-FK auf `materials(betrieb_id,id)` (Bestand) garantieren, dass der Trigger nur material desselben Betriebs trifft. `get_advisors(security)` + `(performance)` → **0 neue** Findings.

---

## 4. Bestands-/Nachkauf-Logik + Ansichts-Provider (`material_provider.dart`)

Alle aktiven Ansichten schließen `archiviert` aus.
```dart
final aktiveMaterialienProvider = Provider<List<MaterialItem>>((ref) =>
    (ref.watch(materialListProvider).valueOrNull ?? const []).where((i) => !i.archiviert).toList());

final verbrauchItemsProvider = Provider<List<MaterialItem>>((ref) =>
    ref.watch(aktiveMaterialienProvider).where((i) => i.isConsumable).toList());
final anlageItemsProvider = Provider<List<MaterialItem>>((ref) =>
    ref.watch(aktiveMaterialienProvider).where((i) => !i.isConsumable).toList());
final archivItemsProvider = Provider<List<MaterialItem>>((ref) =>
    (ref.watch(materialListProvider).valueOrNull ?? const []).where((i) => i.archiviert).toList());

// FIX: nur Verbrauch, nicht archiviert, mit Mindestbestand, unter Mindest.
final nachkaufenItemsProvider = Provider<List<MaterialItem>>((ref) =>
    ref.watch(verbrauchItemsProvider).where((i) =>
        i.status == 'gekauft' && i.minQty > 0 && i.stockQty < i.minQty).toList());
```
- Bestehende `einkaufenItems`/`bestandItems` bekommen den `!archiviert`-Filter.
- **`addPurchase`/`deletePurchase` invalidieren zusätzlich `materialListProvider`** — sonst zeigt die UI den vom Trigger geänderten `stock_qty` erst nach Reload.
- `updateStock`/`updateMinQty` (manuelle Korrektur) bleiben.
- Neuer `archivierenProvider`/Notifier-Methode `setArchiviert(id, bool)` (update `archiviert` + optimistic).
- Der bestehende Verbrauchs-Decrement in Behandlung/Fütterung bleibt unverändert (schließt mit dem neuen Kauf-Increment den Kreis).

---

## 5. Kosten-Dashboard-Aggregation (rein)

Eine reine Funktion `berechneKostenDashboard(items, purchases, anzahlVoelker) → KostenDashboard`; ein `kostenDashboardProvider` ruft sie mit `materialListProvider`, `materialPurchasesProvider` und der aktiven Völkerzahl.
```dart
class KostenDashboard {
  final double bisher;              // Σ Käufe nicht-archivierter Artikel
  final double investitionIst;      // davon !is_consumable
  final double laufendIst;          // davon is_consumable
  final double geplant;             // Σ aktive Artikel status geplant/bestellt (price·qty)
  final double sollBudget;          // Σ aktive Artikel (price·qty), alle Status
  final double archivIst;           // Σ Käufe archivierter Artikel (Bau/Standbau) — separat
  final Map<String, double> proKategorie;   // Ist je category (nicht-archiviert)
  final Map<int, double> proJahr;           // Ist je Jahr (gekauft_am)
  final Map<String, double> proZahlungsart; // Ist je Zahlungsart
  final double kostenJeVolk;        // laufendIst / max(1, anzahlVoelker)
  const KostenDashboard({...});
  double get ausschoepfung => sollBudget > 0 ? bisher / sollBudget : 0; // Budget Soll/Ist
  double get offen => (sollBudget - bisher).clamp(0, double.infinity);
}
```
**Zuordnung:** jeder Kauf wird über `material_id` an sein `MaterialItem` gehängt → liefert `is_consumable`, `category`, `archiviert`. Betrag je Kauf = `gesamtpreis ?? (menge·stueckpreis) ?? 0`. Käufe ohne zuordenbares Material zählen zu `bisher`, aber nicht in Investition/laufend-Split (Rest-Eimer) — im Test abgedeckt. Charts schlicht (CSS-Balken bzw. `fl_chart`, Muster VarroaCockpit). Anzahl Völker aus dem bestehenden Völker-Provider (aktive).

---

## 6. Material-Ansicht (`material_page.dart` Umbau)

**Segmentleiste** (Primär = Typ): **Verbrauch · Anlagen · Ausgaben**; Archiv über ein Archiv-Symbol (Icon-Button → `archiv_ansicht`).
- **Verbrauch** (`verbrauch_ansicht`): Nachkauf-Banner (falls `nachkaufenItems` nicht leer) → „Im Bestand" (gekauft: Bestandsbalken `stockQty/minQty`, Badge *genug / nachbestellen*, `min_qty`/`stock_qty` inline editierbar) → „Auf der Einkaufsliste" (geplant/bestellt).
- **Anlagen** (`anlagen_ansicht`): „Vorhanden" (gekauft: Anzahl · Preis · Anschaffungsjahr aus letztem Kauf/`gekauft_am`; **kein** Bestandsbalken) → „Geplant". Nie Nachkauf.
- **Ausgaben** (`kosten_dashboard`): Kennzahlen (bisher/Investition/laufend/geplant), Budget-Soll/Ist-Balken, Nach Kategorie, Pro Jahr, Zahlungsart, Kosten je Volk, Archiv/Bau-Zeile.
- **Archiv** (`archiv_ansicht`): archivierte Artikel + „reaktivieren".
- **Detailseite** (`material_detail_page.dart`): Typ-Umschalter (Verbrauch/Anlage = `is_consumable`) + „archivieren/reaktivieren"-Aktion. Bestehende Foto-/PDF-/Kauf-Erfassung unverändert.

Badge-Ableitung (rein, zweistufig — deckungsgleich mit `nachkaufenItems`): `bestandStatus(item) → genug | nachbestellen` (`stockQty >= minQty` → genug, sonst nachbestellen; nur relevant für Verbrauch mit `minQty>0`).

---

## 7. Datei-Architektur
```
data/models/material_item.dart                 + archiviert
presentation/providers/material_provider.dart  aktive/verbrauch/anlage/archiv-Provider, nachkaufen-FIX,
                                                 kostenDashboardProvider, setArchiviert, addPurchase/deletePurchase → auch materialList invalidieren
presentation/pages/material_page.dart          Umbau: Segmente Verbrauch/Anlagen/Ausgaben + Archiv-Zugang
presentation/widgets/verbrauch_ansicht.dart    (neu)
presentation/widgets/anlagen_ansicht.dart      (neu)
presentation/widgets/kosten_dashboard.dart     (neu)
presentation/widgets/archiv_ansicht.dart       (neu)
presentation/pages/material_detail_page.dart   Typ-Umschalter + archivieren/reaktivieren
domain/ kosten_dashboard.dart                   berechneKostenDashboard + bestandStatus (REIN)
supabase/migrations/N01_material_rework.sql
```
Der bestehende `material_summary.dart`/`material_list_tile.dart` werden für die neuen Ansichten wiederverwendet/angepasst; `material_page.dart` wird verschlankt (nur noch Segment-Router).

---

## 8. Tests
- **`kosten_dashboard_test.dart` (rein):** `berechneKostenDashboard` — bisher/Investition/laufend korrekt getrennt (via is_consumable), Soll/Ist/Ausschöpfung/offen, proKategorie/proJahr/proZahlungsart, archivIst separat (nicht in bisher), Käufe-ohne-Material im Rest-Eimer, kostenJeVolk (÷ max(1,n)). `bestandStatus`-Schwellen.
- **`material_filter_test.dart` (rein):** verbrauch/anlage/archiv-Aufteilung; `nachkaufenItems` respektiert `archiviert`, `minQty>0`, `stockQty<minQty` (der Fehlalarm-Fall: frisch gekauft mit vollem Bestand → NICHT in nachkaufen).
- **Migration (manuell mit N01):** archiviert-Spalte da; `bereich=standbau` → archiviert; Bestands-Korrektur (Verbrauch nicht mehr unter Mindest ohne Verbrauch); Trigger: Kauf +menge / Löschen −menge / Update-Delta, nur Verbrauch, menge-null-Guard; `get_advisors` 0 neue.
- **Nicht getestet (bewusst):** Widget-Layout (manuell im Browser), echte Supabase-Trigger-Wirkung (Live-Test).

---

## 9. Migration/Deploy/Sicherheit
- **N01** einzige Produktions-Migration (separat freigeben): Spalte + Standbau-Archiv + Bestands-Korrektur + Trigger. Nummeriertes File **und** via Supabase-MCP `apply_migration`. Trigger ist **INVOKER** (Nutzer schreibt eigenes Material via RLS) mit `set search_path='' ` + voller Qualifizierung. Rollback-Kommentar. `get_advisors(security+performance)` → 0 neue.
- Deploy nach grünen Tests via `bash deploy.sh` (Version-Bump `1.29.0`). Keine Arosa-Hardcodes.

---

## 10. Offen (spätere Zyklen)
- Anlagegut-Nutzungsdauer/Austausch-Reminder + Abschreibung; Budget-Prognose/Mehrjahres-Trend; Kosten-je-kg-Honig (ab Ernte); Honigverarbeitungs-Bereich bei Bedarf ebenfalls archivierbar (Mechanik ist da); CSV/PDF-Export der Kostenübersicht (koppelt an 4.23 Recht/Export).
