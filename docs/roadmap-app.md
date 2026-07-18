# App-/Software-Roadmap — Bienen Arosa

**Stand:** 2026-07-18 · **App-Version:** 1.12.0+30 · nachgeführt bei Arbeitsschluss.
**Grundlage:** [Funktionsumfang-Scope](superpowers/specs/2026-07-11-app-funktionsumfang-scope.md) (26 Module + Fundament). Diese Roadmap ist die *lebende* Umsetzungssicht; die Scope-Spec die verbindliche Ziel-Landkarte.
**Fachliche Untermauerung (2026-07-16):** Die Module sind neu mit 11 tiefen Imkerei-Recherchen hinterlegt — welche Recherche welches Modul mit welchen Datenfeldern/Regeln speist, steht in [imkerei-fachwissen-app-implikationen.md](imkerei-fachwissen-app-implikationen.md) (Wegweiser-Landkarte, **keine** Roadmap-Änderung). Fachwissen wohnt in `../imkerei/02_Recherche/10–20`; Zahlen dort sind Richtwerte (Fachstellen-Check).

**Prinzipien:** Volk-zentriert (alles hängt an `voelker`/`betrieb_id`) · CH-/GR-konform ab Volk 1 · alpin getunt (1570 m) · **strikt mandantenfähig, keine Arosa-Hardcodes** · Muster an KMU Tool 2 ausgerichtet · skalierbar auf 32 (evtl. 64) Völker.

**Phasen-Legende:** P1 = Herbst/Winter 2026 · P2 = Frühling/Sommer 2027 · P3 = bis 2028 · P4 = bis 2030.
**Status-Legende:** ✅ fertig · 🔨 in Arbeit · 🔜 geplant/als Nächstes · ⬜ offen · (Demo) = Platzhalter im Code.

---

## Fundament (P1, vor allen Fachmodulen)

| Baustein | Status | Notiz |
|---|---|---|
| **Auth & Rollen (owner/editor/viewer) + RLS-Härtung + Mandantenfähigkeit** | ✅ **LIVE** (2026-07-16, v1.8.1) | E-Mail+Passwort, JWT-Claim-Tenancy, `betriebe`/`betrieb_mitglieder`/`einladungen`, `betrieb_id` NOT NULL auf allen 8 Tabellen. Plan 1 (DB A01–A13) + Plan 2 (Flutter-Auth) + Plan 3 (Cutover B01/B02) umgesetzt & live-verifiziert. Echte Mandanten-Isolation, `anon` ausgesperrt. |
| Backup, Restore & Import (F1) | ⬜ P1 | tägl. DB+Storage-Backup, Offsite, Keep-alive, „Jetzt exportieren"-ZIP, CSV/Alt-App-Import. |
| Datenschutz & Aufbewahrung (F2) | ⬜ P1 | Soft-Delete/Löschsperre amtl. Daten, EXIF-Stripping, Bearbeitungsverzeichnis, Retention. |
| Benachrichtigungs-Engine (F3) | ⬜ P1 | Web-Push + E-Mail/Telegram-Fallback, Routing, Quittierung, Ruhezeiten. |
| Einstellungen/Settings (F4) | ⬜ P1 | Defaults (Winterfutter 22 kg, Varroa-Schwellen …), Mitgliederverwaltung, Theme. |
| Onboarding-/Setup-Assistent (F5) | ⬜ P1 | owner-Ersteinrichtung, Empty-States, kuratierte Gast-Ansicht. |

## Phase 1 — Herbst/Winter 2026 (Volk 1, Waage + Brutraumtemp live)

| # | Modul | Status |
|---|---|---|
| 4.1 | Dashboard/Cockpit (Ampeln, Alarm-Feed, Saison-Kontext) | 🔨 statisch → erweitern |
| 4.2 | **Völker & Standorte** (Drehscheibe, Königin-Register Jahresfarbe) | ✅ **LIVE** (v1.9.0) — `standorte`/`koeniginnen`/`betriebs_einstellungen`, `volk_umweiseln`, Nav-Umbau |
| 4.3 | **Durchsicht/Stockkarte** (geführt, Timeline, Foto) | ✅ **LIVE** (v1.10.0) — `inspections` + View, privater Foto-Bucket (Signed-URL), Andocken an Volk-Detailseite. Spracheingabe/Offline später |
| 4.4 | Aufgaben & Kalender (alpiner Generator + Schutztermine) | 🔜 (heute statisch) |
| 4.5 | **Behandlungen (Varroa/Gesundheit)** — CH-Behandlungsjournal (Pflicht) | ✅ **LIVE** (v1.11.0) — `varroa_kontrollen`/`behandlungen` (amtlich, RESTRICT/Immutable-Trigger), RPC `behandlung_erfassen`, methodenbewusstes Cockpit, Material-Kopplung |
| 4.6 | **Fütterung** (Winterfutter-Ziel, Bio-Nachweis) | ✅ **LIVE** (v1.12.0) — `fuetterungen` (Bio-Nachweis, volk-FK RESTRICT/Soft-Delete), RPC `fuetterung_erfassen`, Winterfutter-Balken (Saison-Σ), `betriebs_einstellungen.winterfutter_ziel_kg`, Material-Kopplung |
| 4.9 | Monitoring/Waage (HiveWatch, Brutraumtemp, Alerts, Datenqualität) | 🔨 Demo → ausbauen |
| 4.10 | Material & Lager (Verbrauch↔Behandlung/Fütterung koppeln) | ✅ bestehend → verzahnen |
| 4.11 | Wachskreislauf-Basis (Wabenalter/Zukauf-Doku) | ⬜ |
| 4.12 | Geräte/Kalibrierung — **Refraktometer** (wg. Wassergehalt) | ⬜ |
| 4.13 | Bau (Bienenstand + Honigverarbeitungsraum) | ✅ bestehend |
| 4.14 | Gesundheit/Schädlinge — Katalog + Diagnose-Journal | ⬜ |
| 4.15 | Volk-Ausfall & Desinfektion | ⬜ |
| 4.18 | Karten-Basis (Stände-Ansicht) | ⬜ |
| 4.19 | Wetter-Basis (Anzeige + Frost/Sturm-Warnung) | ⬜ |
| 4.21 | Wissensdatenbank DB-gestützt (iterativ) | 🔨 statisch → DB |
| 4.22 | Kosten-Dashboard (Quick-Win aus Material-Käufen) | ⬜ |
| 4.23 | **Recht & Rückverfolgbarkeit** — Compliance-Checkliste, Bestandeskontrolle, Journal-Export (Pflicht) | ⬜ |
| 4.24 | Kontakt-/Notfall-Hub | ⬜ |
| 4.25 | Medien-Basis (Kompression + EXIF) | ⬜ |

## Phase 2 — Frühling/Sommer 2027 (Volk 2, 2. Waage, 1. Ernte, Bio möglich)

Ernte & Honig (4.7) · Verkauf & Vertrieb (4.8) · Schwarmkontrolle + Ableger (4.16) · Ertrags-/Waage-/Wetter-Analytics (Korrelation) · Trachtpflanzen/Blühkalender (4.20) · Wachskreislauf voll (4.11) · Geräte-Wartung (4.12) · Versicherung/Schaden (4.26) · Bio-Suisse-Assistent (4.23) · Gast-viewer-Account · PWA-Härtung (Read-Cache/Write-Outbox/Offline-Kacheln) · Medien-Galerie/Quota.

## Phase 3 — bis 2028 (4 Völker, Nachzucht)

Volle Zucht/Königinnen (4.17: Umlarv-Kalender, Belegstelle, Pedigree, Leistungsprüfung) · Schwarm-Einfang-Log · Gesundheit voll (Melde-Assistent, Sperrbezirk) · Phänologie-Tracking/Trachtlücken · 2. Stand / 2. Funkstation · Sammelaktionen (Bulk) prominenter.

## Phase 4 — bis 2030 (max 8 Völker, evtl. Skalierung 32/64)

Betrieb über mehrere Stände · erweiterte Statistik/Benchmarks · Jahres-Report-Export · ggf. native App + PowerSync-Evaluation · ggf. Vermarktung als Multi-Mandanten-Produkt.

---

## Umsetzungs-Reihenfolge (Empfehlung aus Scope §Empfehlung)

1. **Fundament-Spec (gebündelt)** — Auth/Rollen/RLS **+** F1–F5. *(läuft: Auth-Teil zuerst)*
2. Danach je Fachmodul-Spec in Reihenfolge: (1) Völker & Standorte · (2) Durchsicht · (3) Behandlungen+Varroa · (4) Fütterung + Monitoring-Ausbau · (5) Kosten-Dashboard · (6) Volk-Ausfall + Wachs-Basis + Kontakt-Hub · (7) Karten-/Wetter-Basis · (8) Wissensdatenbank iterativ.
3. P2/P3-Module erst spezifizieren, wenn P1 steht.

## Technik-Marker

Flutter Web (3.41.x), Riverpod AsyncNotifier (ohne Codegen), Go Router, Supabase (Auth/DB/Storage/Edge Functions), fl_chart. Deploy manuell via `deploy.sh` (Cache-Busting). Migrations-Disziplin + Auth-Muster an KMU Tool 2 ausgerichtet (siehe `../CLAUDE.md`).
