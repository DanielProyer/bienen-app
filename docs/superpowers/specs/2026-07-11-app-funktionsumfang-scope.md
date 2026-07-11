# Bienen Arosa – Funktionsumfang der App (finale Fassung)

*Stand: 2026-07-11 · Flutter Web + Supabase · GitHub Pages · Standort Maiensäss Tannen 85a, Arosa (1570 m)*

Dieses Dokument ist die verbindliche Ziel-Landkarte für die App. Es beschreibt, **was die App am Ende können soll** – nicht die Implementierung im Detail. Es bündelt Bestandsanalyse, Wettbewerbsrecherche, CH-/GR-Recht, Betriebsthemen und die eingearbeitete Kritik (Querschnitts-/Betriebslücken) zu einem vollständigen Bild. Grundprinzip: **pro Volk erfassen, aggregiert auswerten**, alles hängt an der Entität `voelker`, skalierbar bis 32 (evtl. 64) Völker ohne Hardcaps.

Prioritäten/Phasen durchgehend: **P1** = Herbst/Winter 2026 (Volk 1, Waage + Brutraumtemp live) · **P2** = Frühling/Sommer 2027 (2 Völker, 1. Ernte, Bio-Umstellung möglich) · **P3** = bis 2028 (4 Völker, Nachzucht) · **P4** = bis 2030 (max 8, evtl. Skalierung 32/64).

> ## Abgestimmt mit Daniel (2026-07-11)
> - **Ausrichtung: vollwertig ersetzen.** Die App wird die **vollständige, CH-/GR-konforme Betriebssoftware** inkl. gesetzlichem Behandlungsjournal + Bestandeskontrolle (PDF-Export für Kontrollen). Kein Dauerbetrieb von BelloBee/BeeSmart nötig – wir tragen die Konformität selbst.
> - **Vorgehen: pragmatischer Mix.** Zuerst schlanke Basis (Auth + Rollen + **RLS-Härtung** + Betrieb/Mitglieder), dann **sofort** die Kernmodule (Völker → Durchsicht → Behandlung → Fütterung/Monitoring) **mit RLS von Anfang an**; Backup/Datenschutz/Benachrichtigung laufen direkt parallel. Ziel: rechtzeitig nutzbar für Volk 1 (Herbst 2026).
> - **Roadmap: max. 8 Völker bis 2030** (die neuere Entscheidung gilt; das alte `00_Entscheidungen.md` mit „ab 2036/Pensionierung Lorena" ist überholt). Datenmodell/UI **von Beginn auf 32 (evtl. 64) Völker** auslegen, keine Hardcaps.
> - **Mandantenfähig & vermarktbar.** Eine **spätere Vermarktung der App** ist möglich → strikt **mehrmandantenfähig** über die Entität `betriebe` (jeder Betrieb isoliert per RLS), **keine Arosa-Hardcodes** (Standort, Rasse, Defaults, Texte konfigurierbar/betriebsbezogen), generische Domänenmodelle, i18n-fähig vorsehen. Arosa ist der erste Mandant, nicht die Annahme.

---

## 1. Vision & Leitprinzipien

**Vision:** Eine einzige App, mit der Daniel und Lorena ihre alpine Bio-Imkerei in Arosa **vollständig planen, durchführen, dokumentieren und auswerten** können – von der ersten Durchsicht bis zum etikettierten Honigglas, vom einzelnen Volk bis zur Betriebsstatistik über Jahre. Die App ist zugleich Betriebssoftware, gesetzeskonformes Journal, Sensor-Cockpit, wachsendes Nachschlagewerk **und der eigene, jederzeit exportier- und wiederherstellbare Datentresor** (keine Fremdabhängigkeit, kein Datenverlust).

**Leitprinzipien:**

1. **Volk-zentriert.** Die Entität `voelker` ist das Herzstück. Durchsicht, Behandlung, Fütterung, Ernte, Königin, Waage, Temperatur, Aufgaben, Gesundheit, Wachs – alles verknüpft über `volk_id`. Die Volk-Detailseite bündelt eine chronologische **Timeline** plus Live-Sensordaten. Zentraler USP gegenüber getrennten Waagen- und Verwaltungs-Apps.
2. **Integrierte Sicht statt Insellösungen.** Monitoring (HiveWatch-Waage + Brutraumtemperatur), Stockkarte, Aufgaben, Material und Wachskreislauf verschmelzen. Der Markt trennt diese Welten – Arosa führt sie zusammen.
3. **Alpin getunt.** Kein Flachland-Standardkalender. Saison ~40–45 Tage später, Haupttracht Mitte Juni–Ende Juli, nur 1 Ernte/Jahr, Winterfutter 20–25 kg/Volk, enge Behandlungsfenster, standortkritische Winter-/Schutztermine (Mäusegitter, Specht, Sturm/Schnee). Defaults für 1570 m überall hinterlegt.
4. **CH-konform ab Volk 1.** Bestandeskontrolle, Behandlungsjournal (Pflicht seit Juli 2022), Seuchen-Meldung, Honig-Selbstkontrolle/Etikett sind gesetzlich – unabhängig von Bio. Ein Datenmodell bedient Pflicht **und** Bio Suisse.
5. **Bio-tauglich by Design.** Fütterung, Behandlung, Wachskreislauf, Wassergehalt, Trachtradius lückenlos dokumentiert – die Knospe-Zertifizierung ist ein Aufsatz, kein Umbau.
6. **Datensicherheit & Portabilität sind Kern, nicht Kür.** Automatisiertes Backup, Offsite-Snapshot, Restore-Prozess, Import/Export gehören zum Fundament – gerade weil das Supabase-Projekt bei Inaktivität pausiert und der Free-Tier kein PITR bietet. Amtliche Pflichtdaten (3 Jahre) dürfen nie einem Totalverlust ausgesetzt sein.
7. **Datenschutz & Aufbewahrung eingebaut.** revDSG-konform: Bearbeitungsverzeichnis, Zweckbindung, Lösch-/Aufbewahrungskonzept, EXIF-Stripping. **Soft-Delete/Löschsperre** für amtliche Pflichtdaten – ein editor darf gesetzliche Datensätze nicht hart löschen.
8. **Erfassung ist Voraussetzung für Auswertung.** Schnellerfassung am Stand (wenige Pflichtfelder, Schieberegler, Foto, Spracheingabe, QR/NFC), Statistik passiv daraus generiert.
9. **Feldtauglich, offline-resilient, handschuhtauglich.** Am Stand oft kein/schlechtes Netz und volle Hände: Read-Cache, Write-Outbox, Offline-Fotos, grosse Touch-Targets, Sonnenlicht-Lesbarkeit, Spracheingabe, klare Offline-Banner.
10. **Zuverlässige Benachrichtigung.** Kritische Alerts (Schwarm, Diebstahl, Frost) erreichen den Empfänger garantiert – Web-Push mit **E-Mail-/Telegram-Fallback**, Empfänger-Routing, Quittierung.
11. **Nachvollziehbarkeit & Vertrauen.** Zwei gleichberechtigte Editoren + späterer Gast (nur lesen). Änderungs- und Autor-Historie (wer/wann) macht amtliche Aufzeichnungen glaubwürdig.
12. **Qualität vor Preis, langlebig, erweiterbar.** Konsistentes Muster (Riverpod AsyncNotifier, Supabase inline, optimistic update+revert, Foto+PDF). Datenmodell und Wissensbasis wachsen mit dem Betrieb (1→8, später 32/64).

---

## 2. Nutzerrollen & Rechte

**Aktueller Zustand (offener Punkt):** RLS ist `public read/write` ohne Auth – jeder mit dem Anon-Key kann schreiben. Das ist die **grösste Sicherheitslücke** und muss **vor** dem Gast-Account gehärtet werden.

### Rollenmodell (3 Rollen genügen vollständig)

| Rolle | Rechte | Wer |
|---|---|---|
| **owner** | alles + Mitglieder einladen/entfernen, Rollen ändern, Backup/Settings, harte Löschung amtlicher Daten (mit Bestätigung) | Daniel |
| **editor** | alle Fachdaten anlegen/ändern; Soft-Delete, aber **kein** Hard-Delete amtlicher Pflichtdaten | Lorena |
| **viewer** | ausschliesslich lesen, keine Mutation | Gast (ab 2027) |

Rolle als Postgres-`enum` (`betrieb_rolle`).

### Sharing-Modell: „Betrieb" als Klammer

- Tabelle `betriebe` (z. B. „Imkerei Arosa") + `betrieb_mitglieder` (`user_id → rolle`).
- Alle Fachtabellen erhalten `betrieb_id`. Minimal, skalierbar auf mehrere Stände/Betriebe.

### Auth/RLS-Ansatz (Supabase, konkret)

- **Supabase Auth** (Email/Magic-Link).
- **Helper** `private.rolle_im_betrieb(b_id)` mit `security definer stable` (verhindert rekursive RLS).
- **Policies pro Operation:** `SELECT` alle Mitglieder (inkl. viewer), Schreiben nur owner/editor, Hard-Delete amtlicher Tabellen nur owner.
- **Performance:** `auth.uid()` immer als `(select auth.uid())`; `TO authenticated`; Index auf jede Policy-Spalte.
- **Audit/Historie:** Auditing-Muster (`audit.record_version`, JSONB old/new) auf die compliance-relevanten Tabellen; `updated_by uuid default auth.uid()` auf Fachtabellen → „Geändert von X um HH:MM".

### Aufgaben-Zuständigkeit & Zusammenarbeit (Mehrbenutzer-Feinschliff)

- `tasks.assigned_to` (Bearbeiter) – „wer macht was" ist bei 2 gleichberechtigten Editoren zentral.
- **Erledigt-von-Historie** (`done_by`, `done_at`), gegenseitige Benachrichtigung bei Zuweisung/Statuswechsel.
- **Kommentar-/Notiz-Thread** an Objekten (`comments` polymorph an Volk/Task/Durchsicht) für Absprachen.

### Gast/Onboarding-Praxis

- **Gast-Onboarding:** zunächst ein von Daniel (owner) manuell angelegter viewer-Account. Volle Self-Service-Einladung via Edge Function (`invite-member`) erst bei Bedarf; Privilege-Escalation vermeiden.
- **UI-Konsequenz:** Mutations-Buttons für viewer ausgeblendet, Read-only-Badge, kuratierte Gast-Startseite (Highlights statt Rohdaten).

---

## 3. Modul-Landkarte

„Bestehend" = heute in der App gebaut. Neue Querschnitts-/Betriebsmodule sind gegenüber dem Entwurf ergänzt (Backup, Datenschutz, Karte, Wetter, Tracht, Wachs, Settings, Onboarding, Geräte, Verkauf/Versicherung, Kontakte, Ausfall-Workflow, Benachrichtigung).

| # | Modul | Zweck | Priorität | Status |
|---|---|---|---|---|
| — | **Auth & Rollen** | Login, owner/editor/viewer, RLS-Härtung, Audit, Zuständigkeit | P1 (Fundament) | Neu |
| — | **Backup, Restore & Import** | tägliches Backup, Offsite-Snapshot, Restore, CSV/Excel-Import, Alt-App-Migration, Storage-Backup | P1 (Fundament) | Neu |
| — | **Datenschutz & Aufbewahrung** | Bearbeitungsverzeichnis, Soft-Delete/Löschsperre, EXIF-Stripping, Löschkonzept | P1 (Fundament) | Neu |
| — | **Benachrichtigungs-Engine** | Web-Push + E-Mail/Telegram-Fallback, Routing, Quittierung, Ruhezeiten | P1 | Neu |
| — | **Einstellungen/Settings** | Defaults, Benachrichtigungs-Präferenzen, Einheiten, Theme, Mitglieder, Backup | P1 | Neu |
| — | **Onboarding-/Setup-Assistent** | owner-Ersteinrichtung, Empty-States, kuratierte Gast-Ansicht | P1 | Neu |
| 4.1 | **Dashboard/Cockpit** | Status jetzt, Ampeln, Alarm-Feed, „was ist zu tun" | P1, laufend | Bestehend (statisch) → erweitern |
| 4.2 | **Völker & Standorte** | Volk-Stammdaten, Königin, Beute, Stand (GPS/amtl. Nr./TVD) | P1 | Neu (Tabellen leer) |
| 4.3 | **Durchsicht/Stockkarte** | Geführte Kontrolle je Volk, Timeline, Foto | P1 | Neu |
| 4.4 | **Aufgaben & Kalender** | To-dos je Volk/Stand, Saison-/Wetter-/Schutz-Regeln, Reminder | P1 | Neu (heute statisch) |
| 4.5 | **Behandlungen (Varroa/Gesundheit)** | CH-Behandlungsjournal + Milbendiagnose + Ampel | P1 (Pflicht) | Neu |
| 4.6 | **Fütterung** | Fütterungs-Log, Winterfutter 20–25 kg, Bio-Nachweis | P1 | Neu |
| 4.7 | **Ernte & Honig** | Charge, Wassergehalt, Verarbeitung, Etikett/Rückverfolgung | P2 | Neu |
| 4.8 | **Verkauf & Vertrieb** | Produktlager, Kunden, Preise, Quittung, MwSt-Einordnung | P2 | Neu |
| 4.9 | **Monitoring/Waage** | HiveWatch Gewicht + Brutraumtemp, Alerts, Analytics, Datenqualität | P1 erweitern | Bestehend (Demo) → ausbauen |
| 4.10 | **Material & Lager** | Einkauf/Bestand/Käufe/Ausgaben, Verbrauch↔Behandlung/Fütterung | laufend | Bestehend → verzahnen |
| 4.11 | **Wachskreislauf** | Eigenwachs-Bilanz, Mittelwand-Umarbeitung, Wabenerneuerung/-alter | P1 (Basis)/P2 | Neu |
| 4.12 | **Geräte-Inventar, Kalibrierung & Wartung** | Refraktometer/Waage/Schleuder, Kalibrier-/Wartungshistorie | P1/P2 | Neu |
| 4.13 | **Bau** | Bienenstand + Honigverarbeitungsraum, geführte Schritte | P1/P2 | Bestehend |
| 4.14 | **Gesundheit/Schädlinge** | Krankheits-Katalog, Diagnose-Journal, Melde-Assistent | P1 (Katalog)/P3 (voll) | Neu |
| 4.15 | **Volk-Ausfall & Desinfektion** | totes/aufgelöstes Volk, Autopsie, Abflammen, Desinfektions-Log | P1 | Neu |
| 4.16 | **Schwärme & Ableger** | Schwarmkontrolle, Ableger-Manager, Einfang-Log | P1/P2 (Kontrolle)/P3 (voll) | Neu |
| 4.17 | **Zucht/Königinnen** | Register, Umlarv-Kalender, Belegstelle, Leistungsprüfung, Pedigree | P3 (ab 2028) | Neu |
| 4.18 | **Karten-/GPS** | Stände auf Karte, Navigation, Bio-3-km-Radius, Offline-Kacheln | P1 (Basis)/P2 | Neu |
| 4.19 | **Wetter** | MeteoSchweiz-Integration, Warnungen, Wetter-Gewicht-Korrelation | P1 (Basis)/P2 | Neu |
| 4.20 | **Trachtpflanzen/Phänologie** | alpiner Blühkalender, Trachtlücken, Bienenweide | P2/P3 | Neu |
| 4.21 | **Wissensdatenbank** | Kategorien, Volltextsuche, Kontext-Verknüpfung, offline | laufend | Bestehend (statisch) → DB-gestützt |
| 4.22 | **Auswertungen/Statistik** | KPIs, Charts, Benchmarks, Jahres-Report/Export | P2+ | Neu |
| 4.23 | **Recht & Rückverfolgbarkeit** | TVD/Standnummer, Bestandeskontrolle, Selbstkontrolle, Bio-Assistent, Wanderung | P1 (Pflicht) | Neu |
| 4.24 | **Kontakt-/Notfall-Hub** | Inspektor, Veterinäramt, Tino, HiveWatch-Support, Direkt-Anruf/Melde-Buttons | P1 | Neu |
| 4.25 | **Medien-/Foto-Verwaltung** | zentrale Galerie/Suche, Kompression, EXIF-Stripping, Quota, verwaiste Objekte | P1 (Basis)/P2 | Neu |
| 4.26 | **Versicherung & Schaden** | Policen, Schadensfälle (Diebstahl/Sturm/Bär), Belege | P2/P3 | Neu |
| — | **Entscheidungen** | getroffene/offene Projekt-Entscheide | laufend | Bestehend |

---

## 4. Module im Detail

### Fundament-Module (P1, vor allen Fachmodulen)

#### F1. Backup, Restore & Import (P1 – dringlichste Nachbesserung)

**Zweck:** Der beworbene USP „eigener, exportierbarer Datenbestand" muss real abgesichert sein. Supabase Free-Tier macht **kein PITR**, und das Projekt **pausiert bei Inaktivität** → ohne Backup drohen Datenverlust und Nichtverfügbarkeit amtlicher Pflichtdaten (Bestandeskontrolle 3 J., Behandlungsjournal).

**Kernfeatures:**
- **Automatisiertes tägliches DB-Backup** via Edge Function/Cron (analog `sync-scale-data`): kompletter Dump als JSON/CSV in einen separaten Storage-Bucket **und** Offsite (z. B. zweiter Bucket/GitHub-Release/lokaler Download-Reminder).
- **Storage-Backup:** Fotos/Belege (`construction-photos`, `material-receipts`, künftige Buckets) mit sichern – nicht nur die DB.
- **Manueller „Jetzt exportieren"-Button** (kompletter Betrieb als ZIP: CSV je Tabelle + Medien) im Settings-Modul.
- **Restore-/Disaster-Recovery-Prozess** dokumentiert und getestet: Reaktivierung des pausierten Projekts, Reimport, Storage-Rückspielung.
- **Keep-alive** gegen Inaktivitäts-Pause (leichter Cron-Ping) + Warnung im Dashboard, wenn letztes Backup zu alt.
- **Import/Migration:**
  - CSV/Excel-Import für Erst-Erfassung (Alt-Papierstockkarten, Materialliste, bestehende 151 Waagen-Demo-Rows).
  - Bulk-Import beim Skalieren (mehrere Völker/Standorte auf einmal).
  - Migration von anderen Apps (Apiary-Book-/BelloBee-Exportformate) als Best-Effort-Mapper.
- **Datenportabilität** (auch DSG-relevant: Auskunfts-/Herausgaberecht): Export in offenen Formaten.

**Datenobjekte:** `backups` (typ, umfang, groesse, storage_path, offsite_ok, status), `import_jobs` (quelle, format, mapping, ergebnis/fehler), Storage-Bucket `backups`.

**Priorität:** P1 (Fundament, parallel zur RLS-Härtung).

#### F2. Datenschutz & Aufbewahrung (P1)

**Zweck:** revDSG-Konformität (seit Sept 2023) und Schutz amtlicher Pflichtdaten vor versehentlicher/böswilliger Löschung.

**Kernfeatures:**
- **Soft-Delete** auf allen Fachtabellen (`deleted_at`, `deleted_by`); Standard-Queries filtern gelöschte aus, Archiv einsehbar.
- **Löschsperre für amtliche Pflichtdaten** (Bestandeskontrolle, Behandlungen, Ernten): kein Hard-Delete durch editor; Hard-Delete nur owner mit Bestätigung nach Ablauf der Aufbewahrungsfrist (min. 3 Jahre).
- **Aufbewahrungs-/Auto-Archivierungsregeln** je Datentyp (Frist konfigurierbar, Default 3 J.).
- **Bearbeitungsverzeichnis** (revDSG): welche Personendaten (Kunden aus Verkauf, Mitglieder, Gast), Zweck, Aufbewahrung, Empfänger.
- **EXIF-Stripping** aller Foto-Uploads (entfernt GPS/Personen-Metadaten → verhindert Standort-Verrat) + optionale Bildkompression.
- **Datenschutzerklärung/Einwilligung** für Gast (viewer) und Kundendaten; Zweckbindung dokumentiert.
- **Supabase-Region klären** (EU bevorzugt) + Auftragsverarbeitung notieren.

**Datenobjekte:** `datenschutz_verzeichnis`, `deleted_at`/`deleted_by`/`retention_until` auf Fachtabellen.

**Priorität:** P1 (nach RLS-Härtung, vor Verkauf/Kundendaten).

#### F3. Benachrichtigungs-Engine (P1)

**Zweck:** Kritische Alerts (Schwarm, Diebstahl/Umkippen, Frost, low_battery, offline) müssen zuverlässig ankommen. Web-Push auf iOS funktioniert nur bei installierter PWA (iOS ≥16.4) und ist verzögert/unzuverlässig → **Fallback nötig**.

**Kernfeatures:**
- **Kanal-Fallback** für kritische Alerts: Web-Push + **E-Mail** (Supabase/Resend) + optional **Telegram-Bot** (robust, kostenlos, sofort).
- **Empfänger-Routing:** wer bekommt welchen Alert-Typ (Schwarm → beide; low_battery → owner; Aufgabe zugewiesen → Bearbeiter).
- **Quittierung/Eskalation:** unbestätigter kritischer Alert wird nach X min über Zweitkanal wiederholt.
- **Ruhezeiten** (nachts nur kritische Alerts) + **pro-Nutzer-Präferenzen** (welche Kanäle, welche Typen).
- Zentraler Alert-Feed im Dashboard (aus `scale_alerts` + Aufgaben + Gesundheit + Wetter).

**Datenobjekte:** `notifications` (empfaenger, typ, kanal, status, quittiert_am), `notification_prefs` (user_id, kanal, typen, ruhezeiten).

**Priorität:** P1 (Waage/Schwarm-Alarm ab Herbst 2026 live).

#### F4. Einstellungen/Settings (P1)

**Zweck:** Zentrale Konfiguration statt verstreuter Konstanten.

**Kernfeatures:**
- **Fachliche Defaults:** Winterfutter-Ziel (Vorschlag 22 kg), Varroa-Schwellen (Sommer/Herbst/Restfall), Zielgewicht Einwinterung, Wassergehalt-Grenzen (20 %/18 %).
- **Benachrichtigungs-Präferenzen** (siehe F3).
- **Einheiten/Datumsformat**, Sprache (DE), Theme (hell/dunkel).
- **Backup-Einstellungen** (Frequenz, Offsite-Ziel, letzter Lauf).
- **Mitgliederverwaltung** (nur owner): einladen/entfernen, Rollen.

**Datenobjekte:** `betrieb_settings` (JSONB Defaults), `notification_prefs`.

**Priorität:** P1.

#### F5. Onboarding-/Setup-Assistent (P1)

**Zweck:** Erste Einrichtung geführt, nicht ins Leere startend (Tabellen heute leer).

**Kernfeatures:**
- **owner-Ersteinrichtung:** Betrieb anlegen → 1. Standort (GPS/Höhe) → 1. Volk → TVD/Standnummer → Inspektor-Kontakt → erste Waage/Funkstation zuordnen.
- **Empty-States mit Handlungsaufforderung** in jedem Modul (statt leerer Liste).
- **Tooltips/Kurz-Tutorials** für Schnellerfassung, Spracheingabe, QR/NFC.
- **Verzahnung mit Compliance-Checkliste** (Recht-Modul) als Onboarding-Schritte.
- **Kuratierte Gast-Ansicht** beim ersten viewer-Login.

**Priorität:** P1.

---

### 4.1 Dashboard/Cockpit (P1, laufend)

**Zweck:** „Status jetzt" auf einen Blick + „was ist zu tun".

**Kernfeatures:**
- Kachel-Reihe: aktive Völker, offene/überfällige Aufgaben, Varroa-Warnungen, Gewichts-Trend 24 h, Ertrag YTD, **Backup-Status**, **Wetter-Warnung**.
- **Alarm-Feed** (aus Benachrichtigungs-Engine): Waage-Alerts, Gesundheits-Ampeln, fällige Wartezeiten, Frost/Sturm.
- **Saison-Kontext** („was ist jetzt zu tun", an Monat + 1570 m gekoppelt).
- Drill-down zum Volk.

**Datenobjekte:** aggregiert, keine eigene Tabelle.

**Priorität:** P1, iterativ erweitern.

### 4.2 Völker & Standorte (P1 – zentrales Herzstück)

**Zweck:** Jedes Volk als Datensatz; Skalierungs-Grundlage 32/64. Alle Ereignisse hängen hier an.

**Kernfeatures:**
- Völkerliste mit Ampel-Status (Weiselrichtigkeit, Varroa-Last, Futterstand, letzte Durchsicht, Gewichtstrend, Gesundheit) + Filter/Suche.
- **Volk-Detailseite als Drehscheibe:** Stammdaten + Timeline (Durchsicht/Behandlung/Fütterung/Ernte/Alarm/Ausfall) + Gewichts-/Temperaturchart + offene Aufgaben + verknüpfte Wissensartikel + Kommentar-Thread.
- Königin-Zuordnung mit **automatischer Jahresfarbe** (2026 weiss, 2027 gelb, 2028 rot, 2029 grün, 2030 blau).
- Beutenkonfiguration (Dadant Blatt 10er, Zargen/Waben, Schied-Position, Brutraum 5–7 Brutwaben).
- **Standortverwaltung:** GPS, amtliche Standnummer, TVD-Betriebsnummer, Inspektor-Kontakt, Trachtbeschreibung, Bio-3-km-Umkreis, Sperrbezirk-Flag.
- **QR/NFC-Etikett** am Volk für Schnellerfassung (Multi-Scan-Sammelaktionen im Feld).

**Datenobjekte:** `voelker` (erweitern: standort_id, status, beutentyp, zargen/waben, herkunft, einweiselung_am, queen_id, mutter_volk_id, bio_status, gesundheitsstatus, sort_order), `standorte`, `queens`.

**Priorität:** P1, höchste.

### 4.3 Durchsicht/Stockkarte (P1 – wichtigste neue Tabelle)

**Zweck:** Digitale Stockkarte statt Papier; strukturierte Einträge je Volk, am Stand offline mit wenigen Taps.

**Kernfeatures:**
- **Geführte Durchsicht** (HiveTracks-Muster): konfigurierbare Felder, Schieberegler für Stärke/Sanftmut, Foto + Freitext + **Spracheingabe**, datiert.
- Kriterien: Wetter/Temp/Dauer; Volksstärke (besetzte Wabengassen, ~1000 Bienen/Gasse); Brutbild + Brutstadien (Stifte/offen/verdeckelt → Weiselrichtigkeit); Sanftmut/Wabensitz; Weiselzustand (Königin/Stifte gesehen, Weiselzellen-Typ + Anzahl); Futter + kg-Schätzung + Pollen; Platzbedarf/Honigraum; Auffälligkeiten (Kalkbrut/Ruhr/Räuberei/Wachsmotte); Massnahmen (Tag-Liste + Freitext).
- **Folge-Aufgaben-Vorschlag** („in 7 Tagen Schwarmkontrolle") → erzeugt `tasks`.
- Timeline-Filter nach Volk/Stand/Saison; Vorschlag nächster Durchsichtstermin.

**Datenobjekte:** `inspections` (volk_id, inspected_at, inspector, alle Felder, foto_urls[], folge_task_id).

**Priorität:** P1.

### 4.4 Aufgaben & Kalender (P1)

**Zweck:** Alle Arbeiten planbar/abhakbar/erinnernd – der **alpine Jahresablauf Arosa 1570 m** als aktive Aufgaben.

**Kernfeatures:**
- To-dos je Volk/Stand mit Fälligkeit, Priorität, Status, **`assigned_to` (Bearbeiter)**, wiederkehrend.
- **Regelbasierter Generator** (Schweizer Varroakonzept + alpiner KW-Kalender): Auswinterung/Schied (Ende März), Honigraum (bei Trachtbeginn/Waage), Schwarmkontrolle 7-Tage-Rhythmus (Mai–Juli), Drohnenschnitt (14-Tage, Mai–Aug), Sommerbehandlung Ameisensäure (nach Abschleudern), Einfütterung (ab Ende Juli, Abschluss ~10. Sept.), Restentmilbung Oxalsäure (brutfrei Nov/Dez), Winterkontrolle.
- **Standortkritische alpine Schutztermine (neu):** Mäusegitter/Fluglochkeil ansetzen (Herbst) + entfernen (Frühling), **Spechtschutz** (Grünspecht, Netz/Verkleidung), **Windsicherung/Beschwerung** gegen Sturm, Schneeräumung/Zugang bei Strassensperre, Marder-/Bärenschutz-Check.
- Push/E-Mail-Reminder (Benachrichtigungs-Engine); Wetter-Kontext für Behandlungs-/Trachtfenster.
- Werkstatt-/Winterarbeiten (Rähmchen drahten, Mittelwände, Schleuder reinigen, Material bestellen).
- **Sammelaktionen (Bulk)** über mehrere Völker – wichtig ab 8–32.

**Datenobjekte:** `tasks` (volk_id?, standort_id, kategorie, faellig_am, erinnerung_am, prioritaet, status, assigned_to, done_by, done_at, quelle manuell|regel, regel_key, link_entity/link_id), optional `task_recurrences` (rrule).

**Priorität:** P1.

### 4.5 Behandlungen (Varroa & Gesundheit) (P1 – gesetzlich Pflicht)

**Zweck:** CH-konformes **Behandlungsjournal** (Pflicht seit Juli 2022, TAMV) + Varroa-Diagnose + Empfehlung. Bio-tauglich.

**Kernfeatures:**
- **Milbendiagnose** getrennt von Behandlung: Gemülldiagnose (Milbenfall/Tag), Puderzucker/Auswaschung (%/Milben/10 g). Saisonale **Ampel-Schwellen** (konfigurierbar in Settings) → automatischer Behandlungsvorschlag.
- **Behandlungs-Log:** Mittel (Ameisensäure/Formivar, Oxalsäure/Oxuvar, Thymovar, Milchsäure), Wirkstoff, Methode (Verdunster, Träufeln, Sublimieren, Streifen, Drohnenschnitt), Dosis, Start/Ende, Aussentemp, **Wartefrist/Honigraum-Sperre** (Countdown, sperrt Ernte), Charge/Beleg, Behandler.
- **Verknüpfung Material & Lager:** Verbrauch bucht `stock_qty` ab → Nachkauf-Logik.
- **Varroa-Cockpit je Volk:** Milbenfall/Tag-Trend (fl_chart) mit Behandlungs-Markern + Schwellenlinie; Vorher/Nachher-Wirksamkeit.
- **Thymol-Warnung für Bio** (Bio-Suisse-Grenzwert 5 mg/kg Wachs vs. Bund 500).

**Datenobjekte:** `treatments`, `mite_counts`/`varroa_kontrollen`.

**Priorität:** P1.

### 4.6 Fütterung (P1)

**Zweck:** Fütterungs-Log; Winterfutter-Ziel überwachen; Bio-Nachweis.

**Kernfeatures:**
- Erfassung: Datum, Futterart (Sirup 3:2/1:1, Apiinvert, Apifonda/Futterteig, Reiz-/Notfütterung), Menge (kg/Liter), Zweck, Charge/Lieferant, **Bio-Qualität ja/nein**.
- **Winterfutter-Rechner:** Ziel alpin 20–25 kg/Volk (Default aus Settings), Etappen-Tracking, Aggregat je Volk → Dashboard-Kennzahl Einwinterungsgewicht (koppelbar an Stockwaage 37–45 kg Dadant).
- Verknüpfung Materialbestand (Sirup/Apifonda).

**Datenobjekte:** `feedings` (volk_id, datum, futterart, menge_wert+einheit, zweck, charge/beleg, bio_qualitaet).

**Priorität:** P1.

### 4.7 Ernte & Honig (P2 – ab Sommer 2027)

**Zweck:** Erntemengen je Volk, Qualität messen, Verarbeitung führen, gesetzeskonform etikettieren/rückverfolgen.

**Kernfeatures:**
- **Erntecharge:** Erntedatum, Schleuderdatum, Sorte (Alpenblüten/Alpenrosen/Wald/Blatt – Melezitose als Winterverlust-Risiko taggen), Standort, **Wassergehalt-Pflichtfeld** (max 20 %, Knospe/Goldsiegel ≤18 %) mit Qualitäts-Ampel, Menge kg, Gläserzahl/-grösse, MHD.
- **Erntedetail je Volk** (`harvest_frames`): Beitrag je Volk zur Charge (Rückverfolgbarkeit).
- **Geführter Verarbeitungs-Workflow** (analog Bau): Entdeckeln → Schleudern → Sieben → Klären 12–24 h → Wassergehalt → cremig Rühren → Abfüllen → Etikettieren, mit Datumsstempeln.
- **Los-Nummer-Generator** + **Etiketten-Generator** (Pflichtangaben: Sachbezeichnung, Name/Adresse, Produktionsland, Nettogewicht, MHD, Los-Nr.) + **Warnung bei verbotenen Anpreisungen** („rein/naturbelassen", Heilaussagen).
- Ertrags-Auswertung je Volk/Stand/Jahr/Sorte.

**Datenobjekte:** `harvests`/`ernten_chargen`, `harvest_frames`, `honig_etikett`.

**Priorität:** P2.

### 4.8 Verkauf & Vertrieb (P2 – bei Direktverkauf)

**Zweck:** Vom Glas zum Kunden: Bestand, Abgabe, Rückruf, steuerliche Einordnung. (Falls vorerst nur Eigenbedarf: nur Abgabejournal aus 4.7, Rest P3.)

**Kernfeatures:**
- **Fertigprodukt-/Glas-Lager:** wie viele Gläser welcher Charge/Grösse noch vorrätig (bucht aus Erntecharge ab).
- **Verkaufs-/Abgabejournal:** an wen, Menge, Datum, Preis, Kanal (Direkt/Verein/Markt) → Basis für Rückruf (Selbstkontrolle LMG Art. 26).
- **Kunden-/Stammkundenverwaltung** (revDSG-konform, siehe F2), Quittung/Beleg-PDF.
- **MwSt-/Steuer-Hinweis:** Hobby vs. Landwirtschaft/Liebhaberei, Umsatzschwellen (Info, keine Steuerberatung).
- **Verpackungs-/Etiketten-Inventar** (Gläser, Deckel – keine PVC/PVDC für Bio, Etiketten).

**Datenobjekte:** `honig_verkaeufe`, `produkt_lager`, `kunden`, `verpackung_inventar`.

**Priorität:** P2 (Umfang abhängig von offener Frage Direktverkauf).

### 4.9 Monitoring/Waage (bestehend – P1 erweitern)

**Zweck:** HiveWatch-Sensorik live und historisch, Volk-verknüpft.

**Kernfeatures:**
- **Funkstations-UI** (heute nur Schema): Kanalbelegung X/8 (1 Kanal = 1 Waage **oder** 1 Brutraumsensor; Modell 4× Gewicht + 4× Temperatur je Stand), Batterie/Signal/last_seen.
- **Brutraumtemperatur** je Volk als Chart-Overlay (Brutaktivität/-stopp).
- **Analytics:** Tages-Gewichtsdelta (Nektareintrag) als Balken, geglätteter 7-Tage-Trend, Trachtbeginn/-ende, **Schwarm-Alarm** (>2 kg Abfall), Winter-Futterverbrauch. Ereignis-Marker aus `scale_alerts`.
- Alert-Typen: swarm, tracht_start, tracht_end, low_battery, offline, **diebstahl/umkippen**.
- **Wetter-Korrelation** (Tracht vs. Wetter, siehe 4.19); Gewichtsabfall + Brutraumtemperatur als **Schwarm-Frühwarnung**.
- **Sensor-Datenqualität (neu):** Umgang mit Messlücken/Ausreissern/Sensorausfall (Glättung, Lückenmarkierung im Chart, Ausreisser-Filter), **API-Credential-Verwaltung/Rotation** (`api_config`), Rate-Limits, Doppel-/Nachlieferung dedupen, **Kanal↔Waage↔Sensor-Zuordnungshistorie** bei Umstecken.
- Vendor-agnostisch (HiveWatch primär, BroodMinder optional).

**Datenobjekte:** `weight_readings`, `scales` (volk_id/funkstation_id), `scale_alerts` (+diebstahl), `funkstationen` (UI), `sensor_zuordnung_historie`.

**Priorität:** P1.

### 4.10 Material & Lager (bestehend – laufend verzahnen)

**Zweck:** Materialwirtschaft inkl. Kosten; Basis für Behandlung/Fütterung/Ernte-Verbrauch.

**Kernfeatures:**
- 4 Tabs (Einkaufen/Bestand/Nachkaufen/Ausgaben), Bereiche imkerei/standbau/honigverarbeitung, Foto/PDF/Beleg, Kauf-Historie, Zahlungsart-Auswertung.
- **Neu:** Behandlung/Fütterung buchen Verbrauchsmaterial ab → Nachkauf-Logik automatisch.
- **Waben-/Wachs-Lager** mit Wachsmottenschutz-Status (48–72 h einfrieren, B401/Essigsäure) + Erinnerung → verzahnt mit Wachskreislauf (4.11); Honig-Lager (10–15 °C, <55 %, dunkel).
- Geräte-Inventar → ausgelagert in 4.12.

**Datenobjekte:** `materials`, `material_purchases`.

**Priorität:** bestehend, iterativ.

### 4.11 Wachskreislauf (P1 Basis · P2 voll – Bio-relevant)

**Zweck:** Geschlossener Wachskreislauf, den Bio Suisse verlangt; Wabenhygiene.

**Kernfeatures:**
- **Wachs-Bilanz:** Entdeckelungswachs → Einschmelzen → Eigenwachs-Charge → Mittelwände (gegossen/umgearbeitet); kg ein/aus je Jahr.
- **Trennung Eigenwachs vs. Zukauf**, Zukauf mit **Thymolwert/Wachsanalyse-Charge** (Bio-Nachweis).
- **Wabenerneuerung/-alter je Volk:** 1/3 pro Jahr, Wabenhygiene-Erinnerung, Wabenalter-Tracking.
- **Seuchenwachs-Vernichtung** bei AFB (Log, verknüpft mit Ausfall-Workflow 4.15).

**Datenobjekte:** `wachs_chargen` (typ eigen/zukauf, kg, thymolwert, analyse), `waben` (volk_id, jahr, status), `wachs_bilanz` (View).

**Priorität:** P1 (Wabenalter/Zukauf-Doku), voller Kreislauf P2.

### 4.12 Geräte-Inventar, Kalibrierung & Wartung (P1/P2)

**Zweck:** Messmittel und Geräte gepflegt und dokumentiert – Wassergehalt ist Pflichtfeld + Bio-Grenze, also Refraktometer-Kalibrierung kritisch.

**Kernfeatures:**
- Geräte-Inventar (Refraktometer, Waage/Wägezellen, Schleuder, Rührwerk, Schmelzer).
- **Kalibrier-/Wartungshistorie** als wiederkehrende, dokumentierte Ereignisse: Refraktometer-Kalibrierung (Datum/Referenz), Waagen-Tara/Kalibrierung, Schleuder-/Rührwerk-Reinigung/Wartung.
- Reminder über Aufgaben-Generator (z. B. Refraktometer vor Erntesaison prüfen).

**Datenobjekte:** `geraete`, `geraete_wartungen` (geraet_id, typ kalibrierung/wartung, datum, ergebnis, beleg).

**Priorität:** Refraktometer P1 (wegen Wassergehalt), Rest P2.

### 4.13 Bau (bestehend)

**Zweck:** Bienenstand + Honigverarbeitungsraum als geführte Bauprojekte.

**Kernfeatures:**
- Bienenstand: 12 geführte Bauschritte + Bauplan-Tab (Markdown + ISO + PDF).
- **Ergänzen:** Schneelast-Statik (SIA 261, 6–8 kN/m²), Aufständerung > Schneelinie, PV-Insel (400 Wp + LiFePO4), Bienentränke, **Bewilligungs-Checkliste** (<25 m² fundamentfrei bewilligungsfrei KRVO GR Art. 40 Ziff. 20; Bauamt Arosa, Gefahrenzone, Ausbildungsnachweis GR).
- Honigverarbeitungsraum: Schleuderraum 12–15 m² + Lager, CH-Hygienerecht (abwaschbar, Insektengitter, FI/RCD 30 mA), Ausstattungs-Checkliste.

**Datenobjekte:** `construction_steps`, Storage `construction-photos`.

**Priorität:** P1/P2.

### 4.14 Gesundheit/Schädlinge (P1 Katalog · P3 voll)

**Zweck:** Krankheiten/Schädlinge erkennen, dokumentieren, gesetzeskonform melden.

**Kernfeatures:**
- **Wissens-Katalog** (statisch seedbar): Varroose, AFB, EFB, Nosemose, Wachsmotte, Kalkbrut, Asiatische Hornisse – je Erreger/Symptome/Diagnose/Massnahmen/Vorbeugung/Meldepflicht/Bio, mit Symptomfotos.
- **Diagnose-Journal je Volk:** Datum, Befund, Verdacht, **1-Klick „Meldung an Inspektor erfasst"**, Massnahme (Sanierung/Kunstschwarm/Vernichtung), Foto, Statusflag (gesund/verdacht/gesperrt).
- **Behörden-Meldeassistent:** AFB/EFB/Varroose → Bieneninspektor GR + Sperrgebiet-Info; Vespa velutina → Foto + Direktlink asiatischehornisse.ch + Standort (Karte).
- **Gesundheits-Ampel je Volk** im Dashboard.

**Datenobjekte:** `gesundheit_diagnosen`, `krankheiten_katalog` (seed).

**Priorität:** P1 (Katalog + Journal), voller Ausbau P3.

### 4.15 Volk-Ausfall & Desinfektion (P1 – neu)

**Zweck:** Ereignis-Workflow, wenn ein Volk stirbt/aufgelöst/vereinigt wird – nicht nur als Statistik-KPI.

**Kernfeatures:**
- **Totes-Volk-Erfassung:** Datum, **Totenfallkontrolle/Autopsie** (Ursache: Varroa/Weisellosigkeit/Futter/Melezitose/unbekannt), Foto.
- **Beuten-Desinfektions-Log:** Abflammen (bei AFB gesetzlich), Reinigung, Equipment-Freigabe; Wachs-/Waben-Entsorgung (verknüpft Wachskreislauf 4.11).
- **Vereinigung/Auflösung** als Bestandeskontrolle-Ereignis (→ `volk_movements`), Status im Volk (aufgelöst/vereinigt mit …).
- Speist Winterverlust-Statistik (4.22) und Bestandeskontrolle (4.23).

**Datenobjekte:** `volk_ausfaelle` (volk_id, datum, ursache, autopsie_notiz, foto), `desinfektionen` (beute, methode, datum), Bezug `volk_movements`.

**Priorität:** P1 (Winterverluste treffen Volk 1 realistisch bereits Winter 2026/27).

### 4.16 Schwärme & Ableger (P1/P2 Kontrolle · P3 voll)

**Zweck:** Schwarmtrieb kontrollieren, Ableger als neue Völker führen (Skalierungspfad 1→8).

**Kernfeatures:**
- **Schwarmkontroll-Checkliste** 7-Tage-Rhythmus (Mai–Juli alpin): Weiselzellen unterscheiden (Spielnäpfchen/Schwarm-/Nachschaffungs-/Umweiselungszellen), Königin/Stifte gesehen, Massnahme, Reminder-Zyklus.
- **Ableger-Manager:** erzeugt neues `voelker`-Volk, verknüpft Mutter/Tochter; Kontrolle Eilage nach 4–5 Wochen.
- **Schwarm-Einfang-Log:** Datum, **GPS/Karte**, Grösse, Herkunft, eingeschlagen in Beute, Königin gefunden, Status, Foto.

**Datenobjekte:** `schwarmkontrollen`, `ableger`/`swarm_events`, `schwarm_einfaenge`.

**Priorität:** Kontrolle P1/P2, Ableger/Einfang P3.

### 4.17 Zucht/Königinnen (P3 – ab 2028)

**Zweck:** Königin-Register, Nachzucht, Buckfast-F2-Management (Wechsel alle 2 Jahre, Belegstation Fideris).

**Kernfeatures:**
- **Königin-Register** je Volk: Jahr + Jahresfarbe, Zeichnung/Opalith, Herkunft, Status, ein-/ausgeweiselt.
- **Umlarv-Kalender** mit Auto-Terminen + Push: Tag 0 Umlarven → ~Tag 5 verdeckelt → **Tag 10–11 verschulen** (zeitkritisch) → Tag 15–16 Schlupf → Begattung/Legebeginn.
- **Belegstellen-Verwaltung** (Fideris/Valzeina).
- **Leistungsprüfungs-Bogen** (Skala 1–6: Sanftmut, Wabensitz, Schwarmtrieb, Honigertrag, Überwinterung, Hygiene/SMR, Recapping) + Völker-Ranking.
- **Pedigree/Stammbaum** über `mutter_koenigin_id`-Selbstreferenz.
- **Königin-Wechsel-Erinnerung** (F2, alle 2 Jahre) als wiederkehrende Aufgabe.

**Datenobjekte:** `koeniginnen`, `zuchtserien`, `belegstellen`, `leistungspruefungen`.

**Priorität:** P3.

### 4.18 Karten-/GPS (P1 Basis · P2 voll)

**Zweck:** GPS wird ohnehin gespeichert – hier sichtbar/nutzbar machen.

**Kernfeatures:**
- **Kartenansicht der Stände** (Marker mit Status).
- **Navigation** zum Stand (Deep-Link Karten-App).
- **Bio-3-km-Trachtradius** einzeichnen (Nachweis ≥50 % Bio/ÖLN/Wald) + Sperrbezirk-Overlay.
- **Schwarm-Einfang-Position** auf Karte.
- **Offline-Kartenkacheln** für den netzlosen Stand (Basiskarte gecacht).

**Datenobjekte:** nutzt `standorte` (gps), `schwarm_einfaenge`.

**Priorität:** Kartenansicht P1, Radius/Offline-Kacheln P2 (Bio).

### 4.19 Wetter (P1 Basis · P2 voll)

**Zweck:** Wetter ist für alpine Trachtprognose, Behandlungsfenster und Völkerschutz kernrelevant – nicht nur Kontext.

**Kernfeatures:**
- **MeteoSchweiz-/Windy-Integration** (aktuell + Prognose für den Standort).
- **Automatische Wetter-Warnungen:** Frost/Kälteeinbruch (Behandlungsfenster + Völkerschutz), Sturm (Windsicherung), Hitze → als Alerts (Benachrichtigungs-Engine).
- **Wetter-Gewicht-Korrelation:** historische Wetterdaten über den Gewichtsverlauf legen (Tracht vs. Wetter).
- Wetter automatisch in Durchsicht/Behandlung vorbefüllen (statt manuell).

**Datenobjekte:** `wetter_readings` (standort_id, zeit, temp, wind, niederschlag, quelle) – gecacht via Edge Function.

**Priorität:** Basis-Anzeige + Warnungen P1, Korrelation/Historie P2.

### 4.20 Trachtpflanzen/Phänologie (P2/P3)

**Zweck:** Alpiner Blühkalender und Trachtlücken – HiveTracks-Stärke, hier für 1570 m getunt.

**Kernfeatures:**
- **Alpiner Blühkalender** (Löwenzahn, Alpenrose, Linde, Weissklee, Waldtracht/Honigtau) mit Blühbeginn je Höhenlage.
- **Phänologie-Tracking:** eigene Blühbeobachtungen erfassen (verschiebt Kalender realistisch).
- **Trachtlücken-Erkennung** → Reizfütterungs-Vorschlag (verknüpft 4.6).
- **Bienenweide-Planung** (Notizen/Empfehlungen).

**Datenobjekte:** `trachtpflanzen` (seed), `phaenologie_beobachtungen`.

**Priorität:** P2 (Blühkalender-Anzeige), Tracking/Lücken P3.

### 4.21 Wissensdatenbank (bestehend statisch → DB-gestützt, laufend)

**Zweck:** Erweiterbares, durchsuchbares Nachschlagewerk. Marktlücke.

**Kernfeatures:**
- **Kategorien-Baum** (Völkerführung, Varroa/Gesundheit, Honig/Ernte, Zucht, Überwinterung, Recht/Bio, Alpine Besonderheiten, Ausrüstung).
- Artikel als **Markdown** (`body_md`, Bilder, Tags, Saison-Monate, Region „alpin/1570 m", Quellen).
- **Volltextsuche** Postgres-nativ (`tsvector` deutsch + `pg_trgm`), Facetten-Filter.
- **Kontext-Verknüpfung (Killer-Feature):** polymorphe `knowledge_links` zu Volk/Task/Krankheit/Material/Bauschritt. Varroa-Ampel rot → Artikel „Sommerbehandlung" + Material einblenden.
- **Offline:** Artikel lokal gecacht (Service Worker + IndexedDB), Bilder als Blobs.

**Datenobjekte:** `knowledge_categories`, `knowledge_articles`, `knowledge_sources`, `knowledge_links`.

**Priorität:** laufend.

### 4.22 Auswertungen/Statistik (P2+)

**Zweck:** Pro Volk erfassen, aggregiert auswerten; gegen eigene Vorjahre **und** CH-Referenz.

**Kern-KPIs:**
1. **Honigertrag** kg/Volk/Jahr/Sorte, gestapelte Balken + Jahresvergleich + Saisonkurve; Referenzlinie CH ~20 kg (2025: 23,6 kg); Alpin-Korrektur.
2. **Völkerentwicklung/Bestand:** aktive Völker über Zeit, Stärke-Index, Zu-/Abgänge.
3. **Winterverluste:** Verlustquote %/Saison + Herbstverluste; Ursachen-Donut (aus Ausfall-Workflow 4.15); CH-Vergleich (Winter 2024/25: 18,9 %).
4. **Varroa-Verlauf:** Befall/Zeit je Volk mit Behandlungs-Markern; Ampel-Matrix.
5. **Gewicht/Tracht:** Delta/Trend/Trachtfenster + Temp-/Wetter-Overlay.
6. **Kosten/Wirtschaftlichkeit:** Ausgaben/Jahr/Bereich, **CHF/Volk, CHF/kg Honig**, kumulierte Investition + Break-even; **Abschreibung/Investition vs. Betriebskosten getrennt** (Steuer-Report), Belege für Steuererklärung.

**Export:** Jahres-Rückblick als PDF (Ertrag, Verluste, Behandlungen, Kosten je Volk) – auch für Bio-Suisse-Kontrolle.

**Priorität:** ab P2.

### 4.23 Recht & Rückverfolgbarkeit (P1 – Pflicht, CH/GR/Bio)

**Zweck:** Alle gesetzlichen Pflichten ab Volk 1 erfüllbar; Bio Suisse vorbereitet. Ein Datenmodell für Pflicht + Bio.

**Kernfeatures:**
- **Compliance-Checkliste** (verzahnt mit Onboarding F5): TVD/AGATE registriert, Stand mit Kennnummer markiert, beim Bieneninspektor GR angemeldet, Veterinäramt GR kontaktiert.
- **Bestandeskontrolle** (Pflicht, min. 3 J., Löschsperre F2): Zu-/Abgänge, Standortwechsel/Verstellung je Volk, Meldung bei Wechsel des Inspektionskreises; PDF/CSV-Export.
- **Behandlungsjournal** (siehe 4.5) + Wartezeit-Dokumentation.
- **Seuchen-Meldung** (siehe 4.14).
- **Honig-Selbstkontrolle & Etikett** (siehe 4.7/4.8).
- **Bio-Suisse-Umstellungs-Assistent:** 3-km-Trachtradius (Karte 4.18), Fütterungsjournal (Bio-Zucker), Wachs/Thymol-Doku (4.11) + Wachsanalyse-Erinnerung, 1 Umstellungsjahr, 2 Kontrollen (Vertrag bis 30.04.), keine PVC/PVDC-Deckel, Wassergehalt ≤18 %.
- **Wanderung (explizit adressiert):** aktuell laut MEMORY nicht in Scope. **Falls** zur Einwinterung ins Tal gewandert wird: Transport-Checkliste, Gesundheitszeugnis/Wanderattest, Ziel-Standort-Anmeldung, Bestandeskontrolle-Verstellung; die amtliche Wandermeldung selbst kein Eigenbau, sondern **Deep-Link auf BeeTraffic** + Reminder. Als offene Frage geführt (siehe §9).
- **Änderungs-/Autor-Historie** (Audit) für amtliche Aufzeichnungen.

**Datenobjekte:** `standorte` (amtl. Nr./TVD/GPS/Inspektor/Bio-Umkreis/Sperrbezirk), `volk_movements`/`bestandeskontrolle`, plus Bezug auf 4.5/4.6/4.7/4.11/4.14.

**Priorität:** P1.

### 4.24 Kontakt-/Notfall-Hub (P1 – neu)

**Zweck:** Schnellzugriff auf alle relevanten Kontakte, statt Inspektor nur je Standort.

**Kernfeatures:**
- Zentrale Kontaktliste: Bieneninspektor GR, Veterinäramt GR, Tino Hassler, Nachbar-Imker, Verein/apisuisse, HiveWatch-Support, bio.inspecta.
- **Direkt-Anruf-/Melde-Buttons** (tel:/mailto:), Verknüpfung mit Melde-Assistent (4.14).
- Rollen/Zuständigkeit je Kontakt.

**Datenobjekte:** `kontakte` (name, rolle, tel, email, notiz, standort_id?).

**Priorität:** P1 (klein, hoher Nutzen).

### 4.25 Medien-/Foto-Verwaltung (P1 Basis · P2 voll)

**Zweck:** Fotos hängen je Objekt – zusätzlich zentrale Verwaltung, Datenschutz, Speicherhygiene.

**Kernfeatures:**
- **Zentrale Galerie/Suche** über alle Fotos (Volk/Durchsicht/Bau/Beleg/Krankheit).
- **Bildkompression** beim Upload + **EXIF-Stripping** (F2) → Speicher + Datenschutz.
- **Speicher-Quota-Management** + **Bereinigung verwaister Storage-Objekte** (MEMORY nennt gh-pages-/Storage-Leichen).
- **Foto-Backup** (verzahnt F1 Storage-Backup).

**Datenobjekte:** `media` (storage_path, objekt-Verknüpfung, groesse, exif_stripped), sonst Storage-Buckets.

**Priorität:** Kompression/EXIF P1, Galerie/Quota P2.

### 4.26 Versicherung & Schaden (P2/P3)

**Zweck:** Werte absichern und Schäden dokumentieren (Diebstahl-Alert existiert, aber kein Schadensmodul).

**Kernfeatures:**
- **Policen-Übersicht** (Völker-/Sachversicherung: Feuer/Diebstahl/Vandalismus/Sturm), Fristen.
- **Schadensfall-Log:** Datum, Art (Diebstahl/Umkippen/Bär/Marder/Sturm), betroffene Völker/Geräte, Fotos, Meldung an Versicherung/Polizei, Status.
- Verknüpfung mit Waage-Alert (Diebstahl/Umkippen) und Kosten-Report.

**Datenobjekte:** `versicherungen`, `schaeden`.

**Priorität:** P2/P3.

---

## 5. Datenmodell-Überblick

Alle neuen Tabellen mit `id uuid pk`, `created_at`, `updated_at`, `created_by`, `updated_by`, `betrieb_id` **sowie `deleted_at`/`deleted_by`/`retention_until`** (Soft-Delete + Aufbewahrung). Alles über `volk_id`-FK an `voelker` – kein Hardcap (32/64).

**Betrieb & Rollen & Fundament:** `betriebe` · `betrieb_mitglieder` (rolle enum) · `invitations` · `profiles` · `betrieb_settings` · `notification_prefs` · `notifications` · `comments` (polymorph) · `audit.record_version` · `backups` · `import_jobs` · `datenschutz_verzeichnis`.

**Kern-Imkerei:**
- `voelker` (erweitern: standort_id, status, beutentyp, zargen/waben, herkunft, einweiselung_am, queen_id, mutter_volk_id, bio_status, gesundheitsstatus, sort_order)
- `standorte` (name, hoehe_m, gps, standortnummer, tvd_betriebsnummer, funkstation_id, bieneninspektor, tracht_beschreibung, bio_umkreis_notiz, sperrbezirk_flag)
- `queens`/`koeniginnen` (volk_id, jahr, jahresfarbe abgeleitet, zeichnung, herkunft, mutter_koenigin_id self-FK, belegstelle_id, begattungsart, status, ein-/ausgeweiselt_am)
- `inspections` · `tasks` (+ `assigned_to`, `done_by/at`; optional `task_recurrences`)
- `treatments` · `mite_counts`/`varroa_kontrollen`
- `feedings`
- `harvests`/`ernten_chargen` + `harvest_frames` + `honig_etikett` + `honig_verkaeufe` + `produkt_lager` + `kunden` + `verpackung_inventar`
- `swarm_events`/`ableger` · `schwarmkontrollen` · `schwarm_einfaenge`
- `zuchtserien` · `belegstellen` · `leistungspruefungen`
- `gesundheit_diagnosen` · `krankheiten_katalog` (seed) · `volk_ausfaelle` · `desinfektionen`
- `wachs_chargen` · `waben` · `wachs_bilanz` (View)
- `geraete` · `geraete_wartungen`
- `volk_movements`/`bestandeskontrolle` (CH-Pflicht, Löschsperre)
- `versicherungen` · `schaeden`
- `kontakte`

**Standort/Umwelt:** `wetter_readings` · `trachtpflanzen` (seed) · `phaenologie_beobachtungen` · Karten-Nutzung aus `standorte`.

**Wissen:** `knowledge_categories` · `knowledge_articles` · `knowledge_sources` · `knowledge_links` (polymorph).

**Medien:** `media` + Storage-Buckets (`construction-photos`, `material-receipts`, `backups`, neue).

**Bestehend (erweitern):** `materials`, `material_purchases`, `weight_readings`, `scales` (+volk_id/funkstation_id), `scale_alerts` (+diebstahl), `funkstationen` (UI), `sensor_zuordnung_historie`, `construction_steps`.

**Verknüpfungs-Logik (roter Faden):** Durchsicht → Folge-Task · Varroakonzept-Regeln → Tasks/Treatments · `mite_counts` > Schwelle → Behandlungsvorschlag · Treatment-Wartezeit → sperrt Ernte · Fütterung/Behandlung/Ernte/Wachs tragen `charge`/`beleg` → lückenlose Bio-Rückverfolgung · Volk-Ausfall → Bestandeskontrolle + Winterverlust-Statistik · Wetter-Warnung/Waage-Alert → Benachrichtigungs-Engine (mit Fallback).

---

## 6. Technik

**Mehrbenutzer & Sicherheit:** Supabase Auth + `betrieb_mitglieder` + RLS (Helper `security definer`, `SELECT` alle / Schreiben owner+editor / Hard-Delete amtlich nur owner), `(select auth.uid())`, `TO authenticated`, Indizes. RLS-Härtung **zuerst**. Audit-Tracking + `updated_by`. **Soft-Delete/Aufbewahrung** systemweit (F2).

**Backup/Resilienz (F1, Fundament):** täglicher Cron-Dump (DB + Storage) in separaten/Offsite-Bucket, Keep-alive gegen Pause, Restore-Runbook, „Jetzt exportieren"-ZIP. Import via `import_jobs`.

**Benachrichtigung (F3):** Web-Push + E-Mail (Resend) + Telegram-Fallback; Routing/Quittierung/Ruhezeiten; kritische Alerts nie nur Web-Push (iOS-Einschränkung).

**Offline/PWA am Stand (Flutter Web, 1570 m oft kein Netz):** Stufenplan:
1. **PWA-Basics** (Manifest + Service Worker, App-Shell + Assets offline).
2. **Read-Cache** (IndexedDB via hive/drift): Völkerliste, Material, letzte Mess-/Temp-Werte, **Wissensartikel + Offline-Kartenkacheln**, mit „Stand von HH:MM · offline"-Banner.
3. **Write-Outbox** (optimistic): Kontrollen/Notizen/Fotos lokal puffern, bei Reconnect syncen; **LWW pro Feld** (nur 2 Editoren).
4. **Offline-Fotos** in IndexedDB/Blob + Upload-Queue (EXIF-Strip + Kompression vor Upload).
5. **UI-Resilienz:** Timeouts, Retry-Buttons, kein Endlos-Spinner.
6. **PowerSync** (native SQLite-Replika, LWW out-of-the-box) erst evaluieren, wenn native App kommt.

**Feldtauglichkeit/A11y:** grosse Touch-Targets (Handschuhe), High-Contrast/Sonnenlicht-Modus, Einhand-Bedienung, **Spracheingabe** für Durchsicht/Notiz, QR/NFC + Multi-Scan.

**Skalierung 32/64 Völker:** keine Hardcaps; Listen virtualisiert, Charts aggregiert; Sammelaktionen (Bulk); ab 4 Völkern 2. Stand/2. Funkstation über `standorte`.

**Sensor-Integration (4.9):** Credential-Rotation, Rate-Limits, Lücken-/Ausreisser-Handling, Zuordnungshistorie.

**Bestehendes Muster:** Riverpod AsyncNotifier ohne Codegen, Supabase inline, optimistic update+revert, Foto+PDF; Reminder/Backup/Wetter via Edge Function/Cron. Deploy manuell (`deploy.sh`, Cache-Busting). Supabase-Region EU prüfen (Datenschutz).

---

## 7. Phasen-Roadmap

**Phase 1 – Herbst/Winter 2026 (Volk 1, Waage + Brutraumtemp live):**
- **Fundament (zwingend zuerst):** Auth + Rollen + **RLS-Härtung**, Betrieb/Mitglieder, Audit; **Backup/Restore/Import (F1)**; **Datenschutz + Soft-Delete/Aufbewahrung (F2)**; **Benachrichtigungs-Engine mit Fallback (F3)**; **Settings (F4)**; **Onboarding-Assistent (F5)**.
- **Völker & Standorte** (Drehscheibe), **Königin-Register** (Jahresfarbe weiss 2026).
- **Durchsicht/Stockkarte**, **Aufgaben/Kalender** (alpiner Generator inkl. Schutztermine Mäusegitter/Specht/Sturm), Zuständigkeit `assigned_to`.
- **Behandlungen + Varroa-Diagnose + Ampel**, **Fütterung** (Winterfutter-Ziel), **Schädlings-Katalog + Gesundheits-Journal**, **Volk-Ausfall/Desinfektion**.
- **Monitoring-Ausbau** (Funkstations-UI, Brutraumtemp, Delta/Tracht/Schwarm-Alarm, Datenqualität).
- **Wachs-Basis** (Wabenalter/Zukauf-Doku), **Refraktometer-Kalibrierung**.
- **Recht:** Onboarding-/Compliance-Checkliste (TVD/Inspektor GR), Bestandeskontrolle, Behandlungsjournal-Export; **Kontakt-/Notfall-Hub**.
- **Karten-Basis** (Stände-Ansicht), **Wetter-Basis** (Anzeige + Frost/Sturm-Warnung).
- **Wissensdatenbank** DB-gestützt (iterativ), **Kosten-Dashboard** (Quick-Win), **Medien-Basis** (EXIF/Kompression).

**Phase 2 – Frühling/Sommer 2027 (Volk 2, 2. Waage, 1. Honigernte, Bio-Umstellung möglich):**
- **Ernte & Honig** + **Verkauf/Vertrieb** (Charge, Wassergehalt, Verarbeitung, Etikett, Produktlager, Kunden).
- **Schwarmkontrolle + Ableger-Manager**, **Leistungsprüfung** (Vorstufe).
- **Ertrags-Dashboard + Waage-/Wetter-Analytics** (Korrelation), **Trachtpflanzen/Blühkalender**.
- **Wachskreislauf voll**, **Geräte-Wartung**, **Versicherung/Schaden**.
- **Bio-Suisse-Assistent** (Trachtradius auf Karte, Fütterungs-/Wachs-Doku, Kontrolltermine), **Gast-viewer-Account**.
- **PWA-Härtung + Read-Cache + Write-Outbox + Offline-Kacheln**, **Medien-Galerie/Quota**.

**Phase 3 – bis 2028 (4 Völker, Nachzucht):**
- **Volle Zucht** (Umlarv-Kalender, Belegstelle, Pedigree, Wechsel-Erinnerung), **Schwarm-Einfang-Log**.
- **Gesundheit voll** (Melde-Assistent, Sperrbezirk), **Phänologie-Tracking/Trachtlücken**.
- 2. Stand/2. Funkstation, Sammelaktionen (Bulk) prominenter.

**Phase 4 – bis 2030 (max 8, evtl. 32/64):**
- Betrieb über mehrere Stände, erweiterte Statistik/Benchmarks, Jahres-Report-Export, ggf. native App + PowerSync-Evaluation.

---

## 8. Benchmarks (Kurzvergleich)

| App | Stärke | Was Arosa übernimmt / besser macht |
|---|---|---|
| **HiveTracks** (US) | Geführte Durchsicht + Empfehlung, Pflanzen-KI, Phänologie | Geführte Stockkarte + Trachtpflanzen/Blühkalender; keine CH-Pflichten dort |
| **Apiary Book** (RO) | Detailtiefe, Timeline, Ernte, Sprach-Eingabe | Volk-Timeline, Ernte, Spracheingabe; Vorbild Datentiefe |
| **BelloBee** (CH) | CH-Behandlungsjournal + Standjournal, PDF, KI-Berater, Hornissen-KI | Direktester Wettbewerber – CH-Konformität als Muss; wir integrieren eigene Waage + Backup/Export |
| **BeeInTouch / BeeSaver** (DE/AT) | Offline-Sync, QR/NFC, Multi-Scan | UX-Muster: QR/NFC am Volk, Bulk, Offline-First |
| **iBeekeeper** (DE/CH) | Bestandeskontrolle CH/FL, konfigurierbare Stockkarten | CH-Bestandeskontrolle nativ + Soft-Delete/Aufbewahrung |
| **Apiara** (CH) | Kantonale Stand-Anmeldung | Onboarding-Checkliste GR |
| **bee-o-meter/BeeWatch** | Gewichts-Charts, Schwarm-Alarm | Integriert im Verbund mit Verwaltung + zuverlässiger Alert-Fallback |
| **Varroa-App/BeeSmart** | Behandlungsrechner, Ampel | Varroa-Cockpit mit Schwellen + Material-Kopplung |
| **BeeTight** (UK, eingestellt) | – (Lektion) | Exportierbarer Supabase-Bestand **plus reales Backup/Restore** → keine Abhängigkeit, kein Datenverlust |

**Marktlücken = Arosa-USPs:** (1) Monitoring **+** Verwaltung in einer App; (2) saubere Rollen (2 Editoren + Gast) mit Zuständigkeit/Benachrichtigung; (3) erweiterbare Wissensdatenbank mit Kontext-Verknüpfung; (4) native CH-Pflicht + Bio + Soft-Delete/Aufbewahrung; (5) alpiner/Höhenlage-Kontext (Wetter, Tracht, Schutztermine); (6) Material↔Behandlung/Fütterung-Verbrauchskopplung; (7) **echtes Backup/Restore/Import + Datenschutz** – das hat sonst kaum eine Hobby-App.

---

## 9. Offene Fragen an Daniel (priorisiert, max 8)

1. **Backup-Offsite-Ziel:** Wohin soll das tägliche Offsite-Backup (DB + Fotos) gehen – zweiter Supabase-Bucket, GitHub-Release, oder regelmässiger lokaler Download-Reminder? Und ist dir ein **Keep-alive** gegen die Supabase-Inaktivitäts-Pause recht (leichter Cron-Ping)?
2. **Datenschutz/Region:** Kundennamen aus dem Verkauf und Gast-Zugang lösen revDSG aus. Sollen wir die Supabase-Region auf **EU** festlegen (falls möglich) und ein einfaches Bearbeitungsverzeichnis + EXIF-Stripping standardmässig aktivieren? Ok, dass amtliche Pflichtdaten (Bestandeskontrolle/Behandlungen) **nur du (owner)** und erst nach 3 Jahren hart löschen kannst?
3. **Benachrichtigungs-Kanal:** Für zeitkritische Alerts (Schwarm, Diebstahl, Frost) ist iOS-Web-Push unzuverlässig. Bevorzugst du als Fallback **E-Mail**, **Telegram** oder beides?
4. **Verkauf/Vermarktung:** Direktverkauf ab Kleinmengen geplant (→ Produktlager + Kunden + Quittung + Etikett, P2) oder vorerst Eigenbedarf/Verschenken (→ nur schlankes Abgabejournal)?
5. **Bio-Zeitpunkt & Übernahme:** Ab wann Knospe ernsthaft (Vertrag bis 30.04., 1 Umstellungsjahr)? Ist **Tinos** Volk 1 bereits Knospe-zertifiziert am selben Standort (könnte das Umstellungsjahr beeinflussen)?
6. **Wanderung ins Tal:** MEMORY sagt „nicht in Scope", in alpiner Imkerei ist Talwanderung zur Einwinterung aber üblich. Planst du das? Falls ja: schlankes Transport-/Anmelde-Modul + BeeTraffic-Deep-Link, sonst bewusst weglassen.
7. **Feld-Bedienung:** Willst du **Spracheingabe** (Durchsicht mit vollen Händen) und **QR/NFC-Etiketten** an den Beuten? Beides lohnt v. a. ab 4–8 Völkern.
8. **Winterfutter-Default:** Recherche 15–20 kg (allgemein) vs. 20–25 kg (alpin 1570 m). Setzen wir **22 kg** als Default im Fütterungs-Rechner (in Settings jederzeit änderbar)?

---

## Empfehlung zum weiteren Vorgehen

1. **Fundament-Spec zuerst und gebündelt** (eine Spec): Auth/Rollen/RLS-Härtung **+ Backup/Restore/Import + Datenschutz/Soft-Delete + Benachrichtigungs-Engine + Settings + Onboarding**. Diese Querschnittsthemen sind die realen Lücken und blockieren sonst später jede Nachrüstung (RLS und Soft-Delete lassen sich nicht sauber „von hinten" einziehen). Erst danach Fachmodule.
2. **Danach eine Spec je Fachmodul**, in Umsetzungsreihenfolge, jeweils nach dem bewährten Muster (Riverpod AsyncNotifier, Supabase inline, optimistic update+revert, Foto+PDF) und je mit Migration, RLS-Policies, Seed und Test:
   (1) Völker & Standorte, (2) Durchsicht/Stockkarte, (3) Behandlungen + Varroa, (4) Fütterung + Monitoring-Ausbau, (5) Kosten-Dashboard (Quick-Win), (6) Volk-Ausfall + Wachs-Basis + Kontakt-Hub, (7) Karten-/Wetter-Basis, (8) Wissensdatenbank iterativ parallel.
3. **P2/P3-Module** (Ernte/Verkauf, Schwarm/Ableger, Zucht, Trachtpflanzen, Versicherung) erst spezifizieren, wenn Phase 1 steht und die offenen Fragen 4–6 beantwortet sind.
4. **Vor jeder Modul-Spec** kurz die betroffenen offenen Fragen klären (z. B. Verkauf-Umfang vor Ernte-Spec, Bio-Zeitpunkt vor Bio-Assistent), damit keine Nacharbeit entsteht.
5. **Bestehende Daten** (151 Waagen-Demo-Rows, Materialliste) über das Import-Modul migrieren, sobald F1 steht – dann als realer erster Testfall für Backup/Restore nutzen.

*Dieses Dokument ist die verbindliche Grundlage für die Modul-Specs. Empfohlene Reihenfolge: Fundament-Spec → Fachmodul-Specs P1 → P2/P3 nach Klärung der offenen Fragen.*
