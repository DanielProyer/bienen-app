# Design-Spec: Material & Lager (Inventory)

*Stand: 2026-07-11 · Projekt Bienen Arosa · bienen_app*

## 1. Ziel
Aus der bestehenden Einkaufsliste ein **Material-/Lagersystem** machen: verfolgen, was gekauft wurde (Rückverfolgung + Einkaufsdetails), was im Bestand ist, und was unter Mindestbestand nachgekauft werden muss. Mehrere Shops (Imkerhof primär). Zusätzlich: Standbau-Einkauf (Bauhaus Mels) und Honigverarbeitung als eigene Bereiche.

## 2. Entscheidungen (bestätigt)
- Ein „Material"-Tab mit **3 Umschaltern**: Einkaufen · Bestand · Nachkaufen.
- **Volle Kauf-Historie** je Artikel (mehrere Käufe), optional Beleg-Foto.
- Bestand + Mindestbestand + Nachkauf-Warnung nur für **Verbrauchsmaterial**.
- Neues Feld **Bereich**: imkerei / standbau / honigverarbeitung.

## 3. Datenmodell

### 3.1 `materials` (erweitern)
Neue Spalten:
- `bereich text not null default 'imkerei'` — imkerei | standbau | honigverarbeitung
- `is_consumable boolean not null default false`
- `stock_qty numeric not null default 0` — aktueller Bestand (Verbrauchsmaterial)
- `min_qty numeric not null default 0` — Mindestbestand
- `status`-Werte migrieren: `offen → geplant`, `geliefert → gekauft`; Check `status in ('geplant','bestellt','gekauft')`.

### 3.2 `material_purchases` (neu)
Kauf-Historie, volle Rückverfolgung, mehrere Käufe je Artikel:
- `id uuid pk default gen_random_uuid()`
- `material_id uuid not null references materials(id) on delete cascade`
- `gekauft_am date`
- `menge numeric`
- `stueckpreis numeric`
- `gesamtpreis numeric`
- `shop text`
- `beleg_nr text`
- `beleg_foto text` (Public-URL im Storage)
- `notiz text`
- `created_at timestamptz default now()`
- RLS public (wie übrige Tabellen).

### 3.3 Storage
- Bucket `material-receipts` (public read/write) für Beleg-Fotos.

## 4. App-Modelle
- `MaterialItem` erweitern: `bereich`, `isConsumable`, `stockQty`, `minQty` (snake_case JSON: bereich, is_consumable, stock_qty, min_qty). Status-Werte geplant/bestellt/gekauft.
- Neues Model `MaterialPurchase` (materialId, gekauftAm, menge, stueckpreis, gesamtpreis, shop, belegNr, belegFoto, notiz) mit fromJson/toJson.

## 5. Provider
- `materialListProvider` (bestehend, erweitert).
- `materialPurchasesProvider` — alle Käufe (oder family je materialId); Map materialId → List<MaterialPurchase>.
- `selectedBereichProvider` (StateProvider<String?>): Filter Bereich.
- Abgeleitet:
  - `einkaufenItemsProvider` — Items mit status in (geplant, bestellt), gefiltert nach Bereich/Phase.
  - `bestandItemsProvider` — Items mit status = gekauft (oder stockQty > 0), gefiltert nach Bereich.
  - `nachkaufenItemsProvider` — `is_consumable` Items mit `stock_qty < min_qty`.
  - `nachkaufenCountProvider` — Anzahl (für Dashboard-Kachel).
- Aktionen im Notifier: `updateStatus`, `updateStock(id, qty)`, `setMinQty`, `addPurchase(purchase)` (schreibt in material_purchases; optional stock_qty += menge; setzt status='gekauft'), `deletePurchase`.

## 6. UI
### 6.1 MaterialPage → 3 Umschalter (TabBar)
- **Einkaufen**: wie bisher (nach Kategorie gruppiert, Summen), aber nur geplant/bestellt; Bereich-Filterchips (Alle/Imkerei/Standbau/Honigverarbeitung) + Phasen-Filter.
- **Bestand**: gekaufte Artikel nach Bereich/Kategorie; Verbrauchsmaterial zeigt Bestand (x/Mindest), Ausrüstung „vorhanden"; letzter Kauf (Datum/Shop/Preis); Button „Kauf erfassen".
- **Nachkaufen**: Verbrauchsmaterial unter Mindestbestand, prominent (amber), Button „→ auf Einkaufen setzen" (Status geplant).

### 6.2 Detail (material_detail_page erweitern)
- Artikel-Infos + Bereich/Bestand.
- **Kauf-Historie**: Liste der `material_purchases` (Datum, Menge, Preis, Shop, Beleg, Foto-Thumbnail).
- **„Kauf erfassen"**-Formular: Datum, Menge, Stückpreis (→ Gesamtpreis), Shop (Default Imkerhof), Beleg-Nr, optional Beleg-Foto (image_picker → Storage), Notiz. Speichern → Purchase + optional Bestand erhöhen + Status gekauft.
- Bei Verbrauchsmaterial: Bestand direkt editierbar (+/− / setzen), Mindestbestand editierbar.

### 6.3 Dashboard (optional)
- Kachel „Nachkaufen: X Artikel" → Material-Tab/Nachkaufen.

## 7. Datenbefüllung
- Bestehende 28 Imkerei-Positionen: `bereich='imkerei'`; Verbrauchsmaterial markieren (`is_consumable=true`, sinnvoller `min_qty`): Formivar, Oxuvar, Thymovar, BIO-Mittelwände (Brut/Honig), Bio-Sirup, Apifonda. Rest = Ausrüstung.
- Status-Migration offen→geplant.
- **Standbau (Bauhaus Mels)** neu (bereich=standbau, is_consumable=false, status=geplant, shop=Bauhaus Mels): Krinner U-FIX ×4, Douglasie 300 ×4, Douglasie 200 ×1, Schaltafel ×1, Nivellier-Set ×4, Schwerlast-Winkel ×8, 8×100 Edelstahl ×2, A2 5×50 ×1, 6×80 ×1, D4-Leim/Öl/Versiegelung ×1 (~CHF 499).
- **Honigverarbeitung** neu (bereich=honigverarbeitung, status=geplant, phase 3/später): Honigschleuder, Entdeckelungsgabel, Entdeckelungsgeschirr, Doppelsieb, Abfüllbehälter 25 kg, Honiggläser, Refraktometer (aus früherer Recherche; nächstes Jahr).
- **Schutz-Platzhalter** (bereich=imkerei, category=Schutz, status=gekauft): Imkerjacke Daniel, Imkerjacke/Anzug Lorena, Handschuhe Daniel, Handschuhe Lorena – Notiz „Produkt + Einkaufsdetails morgen ergänzen".

## 8. Fehlerbehandlung & Verifikation
- Async `.when`; Optimistic-Update + Revert wie bisher.
- Beleg-Foto-Upload wie construction-photos (try/catch + SnackBar).
- Verifikation: analyze + Tests + Web-Build + Browser (3 Umschalter, Bereich-Filter, Kauf erfassen, Nachkaufen-Ansicht), dann Deploy.

## 9. Umsetzung in Phasen
- **A – Supabase:** Schema erweitern + material_purchases + Bucket + Datenbefüllung (bereich, consumables, standbau, honigverarbeitung, schutz).
- **B – Modelle:** MaterialItem erweitern + MaterialPurchase.
- **C – Provider:** erweitern + abgeleitete Provider + Aktionen.
- **D – UI:** 3 Umschalter + Bestand/Nachkaufen + Detail mit Kauf-Historie/Formular.
- **E – Verifikation + Deploy.**
