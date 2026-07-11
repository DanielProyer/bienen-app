# Design-Plan: Monitoring-Erweiterung – Funkstationen & Skalierung

*Stand: 2026-07-11 · Projekt Bienen Arosa · bienen_app · Status: EINGEPLANT (Umsetzung wenn Hardware da / auf Zuruf)*

## 1. Ziel & Kontext
Das Monitoring (Waage-Tab) soll vom Start (2 Völker, Frühling 2027) bis zum Vollausbau (max. 8 Völker bis 2030) skalieren – mit **4–8 HiveWatch-Funkstationen** (je Volk 1 Waage, Funkstationen als Basisstationen/Gateways). Das App-Datenmodell soll auf **max. 32 (evtl. 64) Völker** ausgelegt sein (keine harten Limits, dynamische Listen/Charts).

## 2. Ist-Stand (Datenmodell)
- `scales`: id, hive_name (= Volk), vendor (HiveWatch/BroodMinder), location, installed_at, alert_swarm_threshold, alert_enabled, api_config (jsonb), created_at.
- `weight_readings`: Messwerte je Waage (scale_id, recorded_at, weight, …).
- `scale_alerts`: Alerts je Waage.
- Kein Funkstations-/Gateway-Begriff, keine Entkopplung Volk ↔ Waage.

## 3. Erweiterung

### 3.1 Neue Tabelle `funkstationen` (Gateways/Basisstationen)
Eine Funkstation empfängt mehrere Waagen und funkt in die Cloud (HiveWatch: 4G/LTE-M).
- `id` (uuid), `name`, `vendor` (default 'HiveWatch'), `gateway_id`/`hardware_id`,
  `location`, `status` ('online'|'offline'|'unbekannt'), `battery_pct` (numeric),
  `signal` (numeric/text), `last_seen_at` (timestamptz), `api_config` (jsonb),
  `notes`, `created_at`. RLS public.

### 3.2 `scales` erweitern
- `funkstation_id` (FK → funkstationen, nullable), `active` (bool default true), `sort_order` (int).
- Jede Waage = 1 Volk, hängt an einer Funkstation. 4–8 Stationen für bis zu 8 Waagen.

### 3.3 Optional (empfohlen für 32/64-Skalierung): Tabelle `voelker`
Für **alle** Völker (auch ohne Waage) – die eigentliche Grundlage für 32/64:
- `id` (uuid), `name`, `rasse` (default 'Buckfast'), `standort`, `koenigin_jahr` (int),
  `herkunft`, `einweiselung_am` (date), `status` ('aktiv'|'aufgelöst'|'abgegeben'),
  `notes`, `created_at`.
- `scales.volk_id` (FK → voelker, nullable) entkoppelt Volk ↔ Waage (nicht jedes Volk hat eine Waage).
- Damit wird die App zur echten Völkerverwaltung (Basis für Stockkarte, Behandlungen, Nachzucht-Tracking).

## 4. UI (Waage-Tab)
- Waagen **nach Funkstation gruppiert**; je Station eine Karte mit Status/Batterie/Signal/last_seen.
- Waage-Einstellungen: Waage einer Funkstation **und** einem Volk zuordnen.
- Übersicht: Stationen online/offline, Völker mit/ohne Waage.
- Alles über `ListView.builder`/dynamische Provider → skaliert auf viele Waagen/Stationen ohne Hardcaps.

## 5. Skalierung / Performance (32/64 Völker)
- `weight_readings`-Abfragen je Volk + Zeitfenster begrenzen (gte-Filter besteht bereits), ggf. Aggregation/Downsampling für Charts.
- Realtime-Subscriptions gezielt (pro sichtbarem Volk) statt global bei vielen Völkern.
- Keine fixen Arrays/Limits; Nav/Charts virtualisieren.

## 6. Umsetzungs-Phasen (wenn es soweit ist)
- **A – Schema:** `funkstationen` + `scales.funkstation_id/active/sort_order` (+ optional `voelker` + `scales.volk_id`).
- **B – Modelle/Provider:** Funkstation-Model + Provider; scales um funkstation_id/volk_id.
- **C – UI:** Gruppierung nach Funkstation, Stationskarten, Zuordnung in den Einstellungen.
- **D – Verifikation + Deploy.**

## 7. Offene Entscheidungen (vor Umsetzung)
- **Umfang:** nur Funkstation + Waage, ODER auch die `voelker`-Tabelle (echte Völkerverwaltung, empfohlen für 32/64).
- **Timing:** Schema-Foundation jetzt anlegen (leere Tabellen, vorbereitet) oder erst mit der Hardware (Frühling 2027).
- **HiveWatch-API:** genaues Funkstations-/Gateway-Modell + Felder aus der HiveWatch-Schnittstelle bestätigen, sobald Zugang da ist.
