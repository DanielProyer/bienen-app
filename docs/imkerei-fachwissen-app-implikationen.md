# Imkerei-Fachwissen → App-Implikationen (Wegweiser-Landkarte)

**Stand:** 2026-07-17 · **Typ:** Referenz-/Brückendokument (KEINE Implementierung, KEINE Roadmap-Änderung).

## Zweck & Status

Dieses Dokument ist die **Brücke** zwischen den 11 tiefen Fach-Recherchen der Imkerei-Schiene (`../imkerei/02_Recherche/10…20`) und den App-Modulen der Scope-Landkarte (`superpowers/specs/2026-07-11-app-funktionsumfang-scope.md`, Module 4.1–4.26 + Fundament F1–F5).

**Wichtig:**
- Es ist **keine Spec und kein Plan**, sondern eine **Implikations-Landkarte** als Grundlage für spätere `Spec → Plan → Implementierung`-Zyklen je Modul.
- Es **wirft die Roadmap nicht um** — die Phasen-/Prioritätenlogik (P1–P4) aus `roadmap-app.md` bleibt maßgeblich. Hier wird nur *verortet*, welche Fachrecherche welches Modul mit welchen Datenfeldern/Regeln speist.
- **Fachwissen wohnt in der Imkerei-Schiene.** Die App verweist darauf (relative Pfade `../imkerei/02_Recherche/…`), dupliziert es nicht. Zahlenwerte in den Recherchen sind überwiegend **Richtwerte**, die vor betrieblichen Entscheiden mit Fachstellen zu verifizieren sind (siehe offene Fragen je Thema).
- **Grundhaltung bleibt:** strikt **mandantenfähig** (`betrieb_id`-Isolation, RLS), **keine Arosa-Hardcodes** — Standort/Höhe/Rasse/Grenzwerte/Fristen/Defaults sind **Daten**, nicht Code. Arosa (1570 m, Buckfast, GR) ist das erste bespielte Profil, nicht die Annahme.

---

## Landkarte: Fachthema → App-Module/Datenfelder → Priorität

Prioritäten-Legende: **P1** = Herbst/Winter 2026 · **P2** = 2027 · **P3** = bis 2028 · **P4** = bis 2030. „Pflicht" = amtliche/gesetzliche Dokumentationspflicht (CH/GR bzw. Bio).

### 10 — Bienenbiologie: Das Bienenvolk als Superorganismus
Quelle: [`../imkerei/02_Recherche/10_Bienenbiologie_Das_Bienenvolk.md`](../imkerei/02_Recherche/10_Bienenbiologie_Das_Bienenvolk.md)

| Betroffene App-Module | Datenfelder / Regeln | Priorität |
|---|---|---|
| 4.2 Völker & Standorte · F4 Settings | Betriebs-/Standort-Stammdaten: `hoehe_m`, `saison_offset_tage` (Arosa +40–45), `region/kanton`, `rasse_default`, `beutensystem_default` — alles je `betrieb_id` | P1 |
| 4.4 Aufgaben & Kalender · 4.3 Durchsicht | Entwicklungsdauer-Referenz 16/21/24 als **konfigurierbarer Datensatz**; Prognose-Engine (aus Beobachtungsdatum → Deckelung/Schlupf/Begattung/Legekontrolle + Schwarmrisiko-Fenster, Offset-/Temperatur-korrigiert) | P1/P2 |
| 4.3 Durchsicht/Stockkarte | Vitalitäts-Indikatorfelder je Durchsicht: `brutbild`, `pollen_vorrat`, `weiselrichtigkeit`, `sanftmut`; Trigger `weisellos_vermutet` → Eskalations-Timeline | P1 |
| 4.17 Zucht/Königinnen | Königin-Objekt zuchtbuchfähig (Herkunft/Linie/Begattungsart/Bewertungen) als Selektionsbasis | P1 (Register) / P3 (voll) |
| 4.5 Behandlungen · 4.9 Monitoring | Winterbienen-/Behandlungsfenster aus Saison-Offset; Brutfreiheit-Erkennung via HiveWatch-Brutraumtemperatur → Restentmilbung-Vorschlag | P1 |
| 4.21 Wissensdatenbank | Glossar (QMP, Vitellogenin, Diutinus, Perga, Polyandrie, DCA) kontextuell an Ereignisse verlinkt | laufend |

### 11 — Imkerei-Grundlagen, Betriebsweisen & Handwerk
Quelle: [`../imkerei/02_Recherche/11_Imkerei_Grundlagen_Betriebsweisen.md`](../imkerei/02_Recherche/11_Imkerei_Grundlagen_Betriebsweisen.md)

| Betroffene App-Module | Datenfelder / Regeln | Priorität |
|---|---|---|
| 4.3 Durchsicht · 4.11 Wachskreislauf | Durchsicht-Feld `waben_erneuert`/`altwaben_entnommen` (Wabenhygiene-Zähler, Ziel ~⅓/Jahr) → speist Wachskreislauf | P1 |
| 4.2 Völker · F4 Settings | Königin-Jahresfarbe **automatisch** aus Schlupfjahr (fixer internationaler 5er-Zyklus, 2026=weiss — **kein** Mandanten-Config, siehe QM-5/QM-8); Winterfutter-Soll, Schwarm-Intervall, Saison-Offset dagegen als mandantenfähige Parameter je `betrieb_id` | P1 |
| 4.5 Behandlungen · 4.23 Recht/Bio | Bio-Regelprüfung mit Erlaubte-Mittel-Liste **und** Wachs-Rückstands-Richtwerten je Wirkstoff als Betriebsparameter (Bio Suisse/FiBL: Thymol ≤ 5 mg/kg, synth. Acarizide/Paradichlorbenzol je ≤ 0,5 mg/kg — Richtwerte, mit Kontrollstelle verifizieren) | P1/P2 |
| 4.11 Wachskreislauf | Wachs-Chargen-Kette (Herkunft→Einschmelzung→Mittelwand→Volk/Rähmchen) append-only; Wabenalter je Rähmchen + Überalterungs-Warnung ab Schwellwert | P1 (Basis)/P2 |

### 12 — Königinnenzucht (Zuchtstoff → begattete Königin)
Quelle: [`../imkerei/02_Recherche/12_Koeniginnenzucht.md`](../imkerei/02_Recherche/12_Koeniginnenzucht.md)

| Betroffene App-Module | Datenfelder / Regeln | Priorität |
|---|---|---|
| 4.17 Zucht/Königinnen | Königinnen-Register/Zuchtbuch: `kennung`, `schlupfjahr`→Jahresfarbe, `linie/herkunft`, `mutter_koenigin_id` (Stammbaum), `begattungsart/-ort`, `status`, `zeichnungsart`; Rasse als Betriebsstammdatum | P1 (Register)/P3 (voll) |
| 4.17 Zucht · 4.4 Kalender | Zuchtkalender: `start_datum`=Tag 0, auto-Trigger (+1 Annahme, +5 Verdeckelung/Erschütterungssperre, +10 Zellen verteilen, +12 Schlupf, +23–28 Legekontrolle) + Rückwärts-Trigger Drohnenaufzucht 45 Tage vor Begattung — Offsets als Betriebsvorlage | P3 |
| 4.5 Behandlungen · 4.16 Ableger | Brutfrei-Fenster-Trigger für Ableger/umgeweiselt: „erste Brut ausgelaufen → brutfreie OS möglich", verknüpft mit Behandlungsjournal | P1/P2 |
| 4.17 Zucht · 4.2 Völker | Königin↔Volk-Historie als Zeitachse pro Volk (Umweiselung = neuer Datensatz, alte ausgemustert) | P1 |
| 4.22 Auswertungen · 4.17 | Selektionsbewertung 1–4-Skala je Volk/Saison, betrieblich gewichtbar (alpin: Winterhärte höher) → Rangliste Zuchtstamm | P3 |
| 4.23 Recht/Bio · 4.16 Ableger | Compliance-Automatik: Zuchtereignisse spiegeln in Fütterungs-/Wachs-/Behandlungsjournal + Bestandeskontrolle; Regel-Flag „Clipping verboten" (Bio); Belegstellen-Verzeichnis je Rasse/Region | P1/P3 |

### 13 — Völkervermehrung (Ableger, Kunstschwarm, Schwarmmanagement)
Quelle: [`../imkerei/02_Recherche/13_Voelkervermehrung.md`](../imkerei/02_Recherche/13_Voelkervermehrung.md)

| Betroffene App-Module | Datenfelder / Regeln | Priorität |
|---|---|---|
| 4.16 Schwärme & Ableger | Ableger-/Jungvolk-Entität (`betrieb_id`/RLS): `muttervolk_id`, `methode`-enum, `verweiselung`, `koenigin_id`, Status-Statuskette + `status_historie`, `staerke_waben`, `futter_kg`, `varroa_behandelt`; `vereinigt_in_id` → automatischer Bestandeskontroll-Abgang | P1/P2 |
| 4.17 Zucht · 4.2 | Königin: `jahresfarbe` **automatisch** aus `schlupf_jahr` (fixer 5er-Zyklus weiss/gelb/rot/grün/blau — **kein** Mandanten-Config); `begattungsart`, `anpaarung/drohnenherkunft` für Selektion | P1 |
| 4.22 Auswertungen · 4.16 | Vermehrungsplaner: konfigurierbare Zielkurve, Ist-vs-Ziel, Netto-Bedarf mit Puffer (Default ~1,4 Ableger/Ziel-Wintervolk) | P2 |
| 4.4 Kalender · 4.5 Behandlungen | Fristen-Trigger: Schwarmkontrolle alle 7 Tage (konfig. Saison); Ableger-Statuskette Tag ~5–7 / ~25–30; TBE-Ereignis erzeugt Entwurf-Journaleintrag (OS, Pflichtfelder); Weiselprobe-Schritt bei fehlenden Stiften; Begattungsfenster-Trigger (Höhe/Klima) | P1/P2 |
| 4.18 Karten · 4.16 · 4.23 Recht | Verflug-Warnung bei Ableger < konfig. Radius (Default 3 km) zum Muttervolk; Verstellungs-Reminder + Bestandeskontroll-Eintrag bei Wechsel Inspektionskreis | P2 |

Alle Schwellen (Ableger-/Begattungsfenster, Mindeststärke, Winterfutter-Ziel, Verflug-Radius, Puffer, Kontrollintervall) **pro `betrieb_id` konfigurierbar mit Defaults**.

### 14 — Bienengesundheit: Krankheiten, Schädlinge & CH-Melde-/Bekämpfungspflicht
Quelle: [`../imkerei/02_Recherche/14_Bienengesundheit_Krankheiten_CH.md`](../imkerei/02_Recherche/14_Bienengesundheit_Krankheiten_CH.md)

| Betroffene App-Module | Datenfelder / Regeln | Priorität |
|---|---|---|
| 4.14 Gesundheit/Schädlinge | Krankheits-/Schädlings-**Katalog** (betriebsübergreifende Stammdaten): `melde_flag`, `rechtskategorie` (zu bekämpfen/überwachen/nicht meldepflichtig), `betroffenes_stadium` (offen/verdeckelt/adult); inkl. Steinbrut, Braula coeca, Amöbenruhr | P1 (Katalog) |
| 4.14 · 4.23 Recht · 4.24 Kontakt | Meldepflicht-Engine: Auto-Pflichthinweis mit GR-Inspektor-Kontakt (aus Kontakt-/Notfall-Hub) + Checkliste „Volk geschlossen halten"; Status-/Fristen-Tracking; separater Neobiota-Zweig Vespa velutina (Link asiatischehornisse.ch) | P1/P3 |
| 4.14 Diagnose-Journal | Diagnose je Volk (`betrieb_id`-isoliert): geführter Entscheidungsbaum offen vs. verdeckelt, Schnelltest-/Streichholzprobe, Fotos, Labor-Auftrag; Standkoffer-Checkliste als Vorlage | P1/P3 |
| 4.23 Recht · F4 Settings | Sperr-/Sanierungsstatus je Standort mit konfig. Referenz-Radien 2 km (AFB) / 1 km (EFB) + ~30-Tage-Kontrollfrist als **versionierte Referenzdaten** | P1 |
| 4.4 Kalender | Saisonale Gesundheits-Erinnerungen mit Höhen-/Phänologie-Offset (Wabenerneuerung, Varroa-Fenster, Mäusegitter/Spechtschutz, Aethina-Falle, velutina-Wachsamkeit) | P1 |
| 4.17 Zucht · 4.22 | Proben-/Labor-Tracking (Futterkranz/Nosema/Sektion/Vergiftung); Gesundheitsereignisse → Zuchtbuch/Selektion (Ausräumverhalten/VSH, Kalkbrut-Anfälligkeit) | P2/P3 |

### 15 — Varroa-Bekämpfung: integriertes Konzept (alpine Dadant-Imkerei)
Quelle: [`../imkerei/02_Recherche/15_Varroa_Bekaempfungskonzept_alpin.md`](../imkerei/02_Recherche/15_Varroa_Bekaempfungskonzept_alpin.md)

| Betroffene App-Module | Datenfelder / Regeln | Priorität |
|---|---|---|
| 4.5 Behandlungen | Enums breit: `wirkstoff` (ameisensaeure/oxalsaeure/milchsaeure/thymol/kombi_os_as/sonstige), `applikationsart` (traeufeln/spruehen/verdampfen/dispenser_verdunster/streifen_langzeit/biotechnik/waermebehandlung) als **konfigurierbare Referenzliste** pro Betrieb | P1 |
| 4.5 Behandlungen (Monitoring) | Varroa-Monitoring: Messung (gemuell/puderzucker/auswaschung) mit berechnetem Befall-% und Milben/Tag; saisonale Ampel-Schwellen als konfig. Tabelle (Höhen-/Kalender-Offset) | P1 |
| 4.5 · 4.23 Recht (Pflicht) | Behandlungsjournal: amtsfähige Pflichtdoku mit `charge/ablaufdatum`, Verknüpfung Behandlung↔Monitoring (Wirkungsgrad vorher/nachher), Export PDF/CSV für Inspektor GR / Bio-Inspektorat | P1 (Pflicht) |
| 4.23 Bio-Layer · 4.11 Wachs | Bio-Konformitätsprüfung: Wirkstoff-Whitelist pro Zertifizierung (Bio Suisse/EU-Bio/konventionell) mit Warnung; Wachskreislauf-Flag pro Volk/Charge | P1/P2 |
| 4.4 Kalender · 4.9 Monitoring | Trigger-Engine pro Betrieb: Windelkontrolle 4-wöchig, Sommerbehandlung nach Ernte-Ereignis, Brutfreiheit→Winter-OS, Drohnenrahmen-Schnitt alle 3 Wochen; Temperatur-Hinweis pro Präparat (AS-/Thymol-Fenster, OS kühl/kein Flug) | P1 |

### 16 — Honig: Ernte, Sorten, Qualität, Verarbeitung & Vermarktung (CH, alpin)
Quelle: [`../imkerei/02_Recherche/16_Honig_Ernte_Qualitaet_Vermarktung.md`](../imkerei/02_Recherche/16_Honig_Ernte_Qualitaet_Vermarktung.md)

| Betroffene App-Module | Datenfelder / Regeln | Priorität |
|---|---|---|
| 4.7 Ernte & Honig | Ernte-/Charge-Entität (`betrieb_id`): `charge_id/los_nr` (konfig. Muster), `erntedatum`, `standort_id`, `volk_ids[]`, `sorte/dominante_trachten[]`, `wassergehalt_prozent` (Pflicht), `erntemenge_kg`, `verarbeitungsart` (inkl. Wabenhonig), `hmf/diastase/labor` | P2 |
| 4.3 Durchsicht · 4.9 | Neues Volk-Feld `honigraum_aufsetzdatum` (Trachtverlauf) — verknüpft mit Waage/Trachtstart | P2 |
| 4.7 · 4.12 Geräte | Wassergehalt-Validierung: Warnung >18 %, Sperre/Warnhinweis >20 %; Charge ohne Wassergehalt/Los = nicht abfüllbereit (Refraktometer-Kalibrierung 4.12) | P2 |
| 4.23 Recht · 4.8 Verkauf | Etiketten-/Pflichtangaben-Generator (Produzent/Adresse/Ursprung/Füllmenge/MHD/Los aus Betrieb+Charge); Bio/Knospe nur bei hinterlegtem Zertifikat; Sortenname nur bei bestätigter Tracht; optionaler Säuglings-Warnhinweis | P2 |
| 4.10 Material · 4.11 Wachs | Produktlinie Wabenhonig als Gebinde-/Verarbeitungstyp; Wabenlager/Leerwaben mit Mottenschutz-Status (tiefgekühlt am …) | P2 |
| 4.4 Kalender | Trigger: Honigraum-Aufsetz-, Ernte-Reife- (Waage/Trachtende), Analyse-Fälligkeit HMF/Wasser, Wabenlager-Mottenschutz-, MHD-Ablauf-Reminder | P2 |
| 4.22 Auswertungen · 4.17 | Ertrag kg/Volk aggregiert & mehrjährig → Volk-/Königin-Bewertung (Honigleistung als Selektionskriterium) | P2/P3 |
| 4.8 Verkauf · 4.22 | Verkaufs-/Preis-/Kostenmodul → Deckungsbeitrag, Lagerwert, Ertrag/Jahr und /Volk | P2 |

### 17 — Wachs & Wabenmanagement: Kreislauf, Hygiene & Bio-Tauglichkeit
Quelle: [`../imkerei/02_Recherche/17_Wachs_Wabenmanagement.md`](../imkerei/02_Recherche/17_Wachs_Wabenmanagement.md)

| Betroffene App-Module | Datenfelder / Regeln | Priorität |
|---|---|---|
| 4.11 Wachskreislauf | „Waben & Rahmen": Rahmen-Entität mit `betrieb_id`, `einbau_datum`, `typ` (Mittelwand/Naturbau/Drohnenrahmen), `wachs_charge_id`, `farbcode_jahr`; auto-Wabenalter + konfig. Umtrieb-Erinnerung (2/3 Jahre) | P1 (Basis)/P2 |
| 4.11 · 4.23 Bio | Naturbau-Quote je Brutraum auto-berechnet vs. konfig. Bio-Mindestquote (EU-Bio 10 %) → Bio-Ampel; Wachs-Chargen-Kreislauf lückenlos (Herkunft→Verwendung); Zukauf erst „einsetzbar" nach Rückstandszertifikat | P1/P2 |
| 4.5 Behandlungen · 4.11 | Wirkstoff-Stammdaten mit Wachs-Verhalten-Flag: `wachsneutral` (org. Säuren) / `wachsanreichernd_bio` (Thymol → Waben aus Honig-/Umarbeitungspool, Grenzwert konfig., Default 5 mg/kg) / `acarizid_gesperrt` (Kontaminationswarnung) | P1/P2 |
| 4.15 Ausfall · 4.14 Gesundheit | Seuchen-Sperre: Charge aus Volk mit AFB-/EFB-Ereignis vollständig sperren (kein Umarbeiten/Verkauf) | P1 |
| 4.4 Kalender | Saison-Trigger (Umtrieb, Drohnenschnitt-Intervall, Frost-/Mottenfenster) an betriebsspezifisches Phänologie-/Höhen-Offset gekoppelt | P1/P2 |
| 4.23 Recht/Bio | Bio-Doku-Export (PDF) aus Wachs-/Waben-Historie, verknüpft mit Behandlungsjournal/Bestandeskontrolle/TVD | P2 |

### 18 — Bio-Imkerei Schweiz: Weg zur Knospe (Bio Suisse) & Bio-Verordnung
Quelle: [`../imkerei/02_Recherche/18_Bio_Imkerei_Knospe_Schweiz.md`](../imkerei/02_Recherche/18_Bio_Imkerei_Knospe_Schweiz.md)

| Betroffene App-Module | Datenfelder / Regeln | Priorität |
|---|---|---|
| 4.23 Recht/Bio (Querschnitt) | **Bio-Konformitäts-Layer** quer über Fütterung/Behandlung/Wachs/Ernte/Zukauf, mandantenfähig: `label_ziel`, `zert_status`, `kontrollstelle`, `mo`, Fristen als **Daten** | P2 |
| F4 Settings · 4.23 | Grenzwerte als label-/betriebsabhängige Konfiguration: Thymol ≤ 5 mg/kg & synth. Acarizide ≤ 0,5 mg/kg (FiBL/Bio Suisse, Richtwerte), Wasser 18 %, HMF konfigurierbar, Trachtradius-% — Demeter/Bund/Knospe & alpin vs. Flachland rein über Daten | P2 |
| 4.23 Regel-Engine · 4.6 Fütterung | **Blockier-Rot** (synth. Akarizid, Thymol>Grenzwert, Nicht-Bio-Futter, Wasser>18 %, PVC, chem. Abkehrmittel, Knospe-Auslobung vor 2. Kontrolle) & **Warn-Gelb** (Fütterung außerhalb Fenster / <15 Tage vor Tracht, Wachs ohne Analyse, Wabenerneuerung<⅓, Ernte ohne brutfreien Honigraum); Futter-Regeln greifen am Fütterungs-Log (`bio_qualitaet`) | P2 |
| 4.7 Ernte · 4.23 | Ernte-/Produktfelder: `abkehrmethode`, `brutfrei_bestaetigt`, `verpackung_typ` + `konformitaetserklaerung_upload`, `produktart`, `knospe_typ`, `etikett_bezeichnung` (Produzent:in ab 1.1.2028) | P2 |
| 4.23 Assistent | Ein-Klick Bio-Doku-Export (Standortverzeichnis + Journale) + Umstellungs-/Zertifizierungs-Assistent als 8-Schritt-Statusmaschine mit Fristen-Triggern (Kontrollvertrag 30.04., Wachsprobe UJ1, 2. Kontrolle bis Mai UJ2) | P2 |

### 19 — Recht, Tierverkehr & Bestandeskontrolle (CH & Graubünden)
Quelle: [`../imkerei/02_Recherche/19_Recht_Tierverkehr_Bestandeskontrolle_CH_GR.md`](../imkerei/02_Recherche/19_Recht_Tierverkehr_Bestandeskontrolle_CH_GR.md)

| Betroffene App-Module | Datenfelder / Regeln | Priorität |
|---|---|---|
| 4.2 Völker & Standorte · 4.23 | Datenmodell (`betrieb_id`/RLS): `betrieb/halter`, `standort` (Standnummer, GPS, Höhe, Inspektionskreis/AFA Bi, Plakette-Flag), `volk` (Register-Kern mit Königin-Linie) | P1 |
| 4.23 Recht (Pflicht) | `bestandeskontrolle_ereignis` (append-only), `behandlung` (TAMV-Journal), `tierarzneimittel_inventar`, `fuetterung`, `honig_los/ernte`, Dokument-/Belege-Ablage | P1 (Pflicht) |
| 4.4 Kalender · 4.23 | Wiederkehrender Frist-Trigger „jährliche Völkererhebung/Bestandesmeldung" im kantonsspezifischen Meldefenster (Stichtag als Datensatz); App schlägt aktuelle Völkerzahl je Stand aus Register vor | P1 |
| 4.5 Behandlungen · 4.6 Fütterung · 4.23 | **Ein-Eintrag-drei-Nachweise:** eine Behandlung/Fütterung erzeugt TAMV-Journal + Bestandeskontroll-Bezug + Bio-Nachweis; Pflichtfeld-Validierung (kein Speichern ohne Wirkstoff/Menge/Datum); Wartefrist-Wächter (keine Ernte vor Ablauf) | P1 (Pflicht) |
| 4.5 · F4 | Behandlung-Felder: Präparat/Wirkstoff-Enum/Konzentration/ml-oder-g-pro-Volk/Anwendungsart/Außentemperatur (AS temperaturkritisch, alpin) + Bio-Flag | P1 |
| 4.23 Export · F1 Backup | Revisionssicherer Export (append-only, änderungsverfolgt) im BLV-Layout: Behandlungsjournal, Inventar, Bestandeskontrolle, Fütterungsnachweis, Los-/Etikettendaten | P1/P2 |
| F4 Settings (Kanton-Steuerfeld) | **Kanton als Steuerfeld:** Formularnamen, Fristen, Kennzeichnungsvorgaben, Kontaktstellen pro Kanton als Daten (GR exemplarisch, generisch für ZH/BE/…); 10-Tage-Wandermeldung als kantonsspezifischer Regel-Datensatz | P1 |

### 20 — Wirtschaftlichkeit & Betriebsführung (Kosten, Ertrag, Zeit, Nebenerwerb)
Quelle: [`../imkerei/02_Recherche/20_Wirtschaftlichkeit_Betriebsfuehrung.md`](../imkerei/02_Recherche/20_Wirtschaftlichkeit_Betriebsfuehrung.md)

| Betroffene App-Module | Datenfelder / Regeln | Priorität |
|---|---|---|
| 4.10 Material & Lager | `material_purchases` erweitern: `kategorie` (Enum), `kostentyp` (investition/variabel/fix), `volk_id`, `nutzungsdauer_jahre` (AfA), `bio_relevant` — je `betrieb_id` | P1/P2 |
| 4.22 Auswertungen · 4.7/4.8 | Neue Tabellen `ernten` (menge_kg, wassergehalt, anzahl_glaeser, charge_los, bio_status), `erloese` (produkt, kanal, stueckpreis), `zeiterfassung` (dauer_min, taetigkeit, person) | P2 |
| F4 Settings | `betriebs_parameter` je `betrieb_id`: `arbeitslohn_ansatz_chf_h`, `ziel_verkaufspreis_kg`, `ertrag_plan_kg_volk`, `waehrung` — **keine Arosa-Hardcodes** (30/40/12 nur als Mandantenwert) | P1 |
| 4.22 Kosten-Dashboard | Kennzahlen-Kacheln: Deckungsbeitrag/Volk, Ergebnis vor/nach Arbeitslohn, AfA, Amortisation, Vollkostenpreis/Glas in 3 Stufen (var / +Fix+AfA / +Arbeit) — DB- und Vollkostensicht getrennt | P1 (Quick-Win)/P2 |
| 4.22 Szenario | Szenario-Rechner (Ertrag×Preis-Sensitivität) + Mehrjahres-Liquiditäts-/Kapitalbedarfsprognose (Cash-Tief Aufbaujahre) | P2/P3 |
| 4.4 Kalender · 4.23 | Trigger: Saison-Fixkosten fällig, AHV-Schwellen-Warnung (konfig. Freigrenze Default 2'300), Steuer-Export Jahresende, Chargen-/Losnummer-Pflichtfeld, Versicherungs-/Seuchen-Check vor Verkaufsstart | P2 |
| 4.23 Bio-Check · 4.22 Auswertungen | Bio-Wirtschafts-Check ab konfig. Völkerschwelle (Aufpreis × Menge vs. Kontrollkosten) | P2/P3 |

---

## Querschnitt-Muster (modulübergreifend)

Diese Muster tauchen in mehreren Recherchen auf und sind die eigentlichen **Architektur-Bausteine**. Sie sollten je einmal sauber entworfen und dann wiederverwendet werden.

### QM-1 · Rechtssichere Pflicht-Dokumentation (append-only Journale)
Behandlungsjournal (TAMV), Bestandeskontrolle, Fütterungs-, Wachs- und Ernte-Journal sind **amtlich/gesetzlich** und müssen **append-only, änderungsverfolgt, revisionssicher** und exportierbar (BLV-Layout, PDF/CSV) sein. Kern-Prinzip **„Ein Eintrag → mehrere Nachweise"**: eine Behandlung speist gleichzeitig TAMV-Journal + Bestandeskontrolle + Bio-Nachweis. Pflichtfeld-Validierung blockt unvollständige Speicherung. Aufbewahrungsfristen (TAMV 3 J.; Bestandeskontrolle GR zu verifizieren) als Retention-Regel. → Quellen 14, 15, 19; Module 4.5, 4.6, 4.23, F1/F2.

### QM-2 · Bio-Konformitäts-Layer (Regel-Engine über viele Module)
Querschnittlicher Layer über Fütterung/Behandlung/Wachs/Ernte/Zukauf mit **Blockier-Rot / Warn-Gelb**-Regeln. **Grenzwerte, erlaubte Mittel und Fristen sind Daten** (label-/betriebsabhängig), nie hartkodiert — so trennen sich Knospe/EU-Bio/konventionell und alpin/Flachland rein über Konfiguration. Wirkstoff-Whitelist + Wachs-Verhalten-Flags (wachsneutral/anreichernd/gesperrt) sind der gemeinsame Nenner von Varroa, Wachs und Recht; die Fütterungs-Regeln (Bio-Zucker, Fenster) hängen am Fütterungs-Log. → Quellen 11, 15, 17, 18, 19; Module 4.23, 4.5, 4.6, 4.11, F4.

### QM-3 · Fristen-/Saison-Trigger-Engine mit Höhen-/Phänologie-Offset
Alle Erinnerungen (Schwarmkontrolle 7-tägig, Windelkontrolle, Behandlungsfenster, Wabenumtrieb, Drohnenschnitt, Fütterung, Ernte-Reife, MHD, jährliche Bestandesmeldung) hängen an einem **konfigurierbaren `saison_offset`** (Arosa +40–45 Tage) statt an festen Kalenderdaten. Temperatur-/Wetter- und Waage-/Brutraumtemperatur-Signale (HiveWatch) triggern kontextabhängig (z. B. Brutfreiheit → Restentmilbung). → Quellen 10, 13, 14, 15, 16, 17; Module 4.4, 4.9, F3.

### QM-4 · Journal-/Timeline-Muster je Volk
Jede volk-bezogene Entität (Durchsicht, Behandlung, Fütterung, Königin-Wechsel, Gesundheitsereignis, Ernte) erscheint als **chronologische Timeline** am Volk. Vitalitäts-/Diagnose-Indikatoren aus der Durchsicht speisen Selektion und Prognose. Volk-zentriert, alles hängt an `voelker`/`betrieb_id`. → Quellen 10, 11, 14; Module 4.2, 4.3.

### QM-5 · Zuchtbuch & Selektion (mehrjährig, betrieblich gewichtet)
Königin-Objekt mit Stammbaum (`mutter_koenigin_id`), Herkunft/Linie/Begattung, Jahresfarbe (**automatisch** aus Schlupfjahr, fixer 5er-Zyklus), Königin↔Volk-Historie und 1–4-Bewertungen. Leistungsdaten aus Ernte (kg/Volk), Sanftmut, Winterhärte, VSH/Ausräumverhalten fließen zusammen zur Rangliste. Rasse ist **Betriebsstammdatum**, kein Buckfast-Hardcode. → Quellen 10, 12, 13, 14, 16; Module 4.17, 4.2, 4.22.

### QM-6 · Ableger-/Volk-Statusketten mit automatischen Folgeeffekten
Ableger/Jungvölker als leichte Volk-Entität mit **Statuskette** (gebildet → brutfrei → behandelt → aufgebaut → Wintervolk) und `status_historie`. Zustandsübergänge lösen automatisch Folgeeffekte aus: Vereinigung → Bestandeskontroll-Abgang; TBE → Journal-Entwurf; Erfolg → Zählung in Völker-Meldung. → Quellen 12, 13, 15; Module 4.16, 4.23.

### QM-7 · Wachs-/Waben-Chargen-Kette (append-only Rückverfolgung)
Lückenlose Kette Herkunft → Einschmelzung → Mittelwand → Volk/Rähmchen, mit Wabenalter, Naturbau-Quote und Seuchen-/Kontaminationssperren. Bindeglied zwischen Wachskreislauf, Bio-Layer und Gesundheitsmodul. → Quellen 11, 17, 18; Module 4.11, 4.23, 4.15.

### QM-8 · Mandantenfähige Stammdaten & Referenzlisten (keine Hardcodes)
Zwei Ebenen: (a) **betriebsübergreifende Kataloge/Referenzdaten** (Krankheiten mit Melde-Flag, Wirkstoffe, Jahresfarben, Entwicklungsdauer 16/21/24, Sperrgebiets-Radien) — versioniert, gemeinsam; (b) **betriebs-/label-/standortspezifische Parameter** (Höhe, Offset, Grenzwerte, Fristen, Schwellen, Preise, Rasse, Kanton) je `betrieb_id`. Der **Kanton ist Steuerfeld** für Formulare/Fristen/Kontakte. → alle Quellen; Module F4, 4.23, 4.2.

---

## Empfohlene nächste App-Schritte / offene Produktentscheide

**Diese Landkarte ändert die Roadmap nicht** — sie ist Vorlauf für die je-Modul `Spec → Plan`-Zyklen. Empfehlungen in Roadmap-Reihenfolge:

1. **Völker & Standorte (4.2) zuerst spezifizieren** — es ist die Drehscheibe (QM-4/5/8) und Voraussetzung für fast alles. Datenmodell aus Quelle 19 (standort mit Standnummer/GPS/Höhe/Inspektionskreis) + Königin-Objekt aus 12/13. **Produktentscheid:** Umfang Königin-Register in P1 (nur Kennung/Jahresfarbe/Linie) vs. voller Zuchtbuch-Aufschub auf P3.
2. **Durchsicht/Stockkarte (4.3)** mit Vitalitäts-Indikatorfeldern (Quelle 10) + Wabenhygiene-Zähler (11) — speist QM-4/5/7.
3. **Behandlungen + Varroa-Monitoring (4.5)** als erstes **Pflicht-Journal** (QM-1) mit breiten, konfigurierbaren Enums (Quelle 15) und Ein-Eintrag-drei-Nachweise (19). **Produktentscheid:** Wie tief die Bio-Regel-Engine (QM-2) schon in P1 mitläuft vs. reiner Warnhinweis, formelle Knospe erst P2.
4. **Recht & Rückverfolgbarkeit (4.23)** parallel zu 4.5 als append-only-Fundament + Kanton-Steuerfeld (QM-8) — **vor** dem ersten Honigverkauf (2027) nötig.
5. **Kosten-Dashboard (4.22, Quick-Win)** aus erweiterten `material_purchases` (Quelle 20) — geringer Aufwand, hoher Nutzen; `betriebs_parameter`-Tabelle als Basis für QM-8.
6. **Querschnitt-Muster früh als Shared-Bausteine entwerfen:** Trigger-Engine (QM-3) und append-only-Journal-Basis (QM-1) einmal sauber, dann je Modul instanziieren — vermeidet Duplikation über 4.5/4.6/4.7/4.11/4.14/4.23.

**Offene Produktentscheide (modulübergreifend):**
- **Referenzdaten-Governance:** Wer pflegt die betriebsübergreifenden Kataloge (Krankheiten/Melde-Flags, Sperrgebiets-Radien, zugelassene Präparate) und wie werden sie versioniert/aktualisiert, wenn sich CH-Recht/Bio-Richtlinien ändern? (Alle Zahlen sind heute Richtwerte, siehe unten.)
- **Bio-Layer-Tiefe pro Phase:** ab wann Blockier-Rot (harte Sperre) statt nur Warn-Gelb — vor formeller Zertifizierung riskant, wenn Regeln fehlkonfiguriert.
- **Zuchtbuch-Scope:** minimal in P1 vs. voller Umlarv-Kalender/Pedigree in P3 — beeinflusst Königin-Datenmodell schon jetzt.
- **Export-Format-Verbindlichkeit:** BLV-Layout / kantonale Formulare GR verifizieren, bevor der revisionssichere Export gebaut wird.

**Verifizierungs-Vorbehalt (wichtig):** Sämtliche Grenzwerte, Fristen, Radien, Preise, Steuer-/AHV-/Bio-Kostenwerte in den Recherchen 10–20 sind **Richtwerte Stand 2025/26** und explizit mit Fachstellen (Bieneninspektor GR, Bio Suisse/bio.inspecta, apiservice, ALT/Veterinäramt GR, Tino Hassler) zu verifizieren. Die App muss sie deshalb konsequent als **konfigurierbare Daten** modellieren (QM-8), nie als Code-Konstanten — die je-Thema offenen Fragen der Recherchen sind die konkrete Verifizierungs-Checkliste.

---

*Verweise: Fachrecherchen unter `../imkerei/02_Recherche/10…20`. App-Modul-Landkarte: `superpowers/specs/2026-07-11-app-funktionsumfang-scope.md`. Umsetzungssicht: `roadmap-app.md`. Dieses Dokument ist Grundlage, keine Implementierung.*
