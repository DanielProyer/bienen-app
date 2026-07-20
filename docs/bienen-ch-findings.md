# bienen.ch / BGD — App-Verbesserungs-Findings

**Erstellt:** 2026-07-19 · **Quelle:** vollständige Auswertung von bienen.ch (BienenSchweiz / Bienengesundheitsdienst): 96 Merkblätter/PDFs (74 nummerierte BGD-Merkblätter 1.x–4.x + Reglemente + Honig/Recht + Vespa), Textextraktion + visuelle Grafik-Auswertung. Fachwissen in `../imkerei/02_Recherche/21–29_*` (BGD-Serie).

> **Zweck:** Abgleich der bestehenden App-Module mit dem offiziellen Schweizer Imkerei-Fachwissen + Empfehlungen für Folgemodule. Alle Zahlen sind BGD-Richtwerte (Stand 2022–2026); vor amtlicher Nutzung Fachstellen-Check. Keine dieser Änderungen ist bereits umgesetzt — es ist eine kuratierte Vorschlagsliste zur Priorisierung.

## 0. Kernbotschaft in 3 Sätzen
Die App ist **fachlich auf dem richtigen Weg** — Architektur (mandantenfähig, Datenwerte statt Hardcodes), Integritätsstufen und die bisherigen Module decken sich mit dem offiziellen BGD-Konzept. Der grösste strukturelle Hebel: der **Aufgaben-Generator (4.4)** ist heute rein kalendarisch (+42-Offset), das offizielle CH-Konzept ist dagegen **phänologisch** (an Indikatorpflanzen gekoppelt) — und ihm fehlt die **ganze Vermehrungs-/Zucht-Schiene** plus einige Varroa-Sicherheitsschritte. Zwei kleinere Timing-Kopplungen im Generator sind zudem für Höhenlagen/Mehrmandantenfähigkeit fehleranfällig.

---

## 1. Bestätigt (bienen.ch validiert unseren Bau)
- **Winterfutter-Ziel:** 22 kg ist alpin korrekt (bienen.ch-Standard = 20 kg Mittelland-Minimum; Arosa 22–25 kg lt. Recherche). **Richtig als Mandantenparameter** `winterfutter_ziel_kg` gebaut, kein Hardcode. ✅
- **4.5 Behandlungsjournal (TAMV):** Pflicht bestätigt (Aufbewahrung 3 J.), revisionssicher-Ansatz korrekt. ✅
- **4.14 Krankheits-Katalog:** afb/efb-Trennung korrekt (zwei Merkblätter, beide „zu bekämpfen"); Rechtskategorien der meldepflichtigen (AFB/EFB/Kleiner Beutenkäfer) korrekt. Tropilaelaps als `zuBekaempfen` wahrscheinlich TSV-konform (Merkblatt untertreibt mit „überwachen"). ✅
- **4.4-Fütterungsregeln** (startfuetterung/hauptfuetterung/auffuetterung) decken sich zeitlich sauber mit bienen.ch. ✅
- **Mandantenfähigkeit/keine Arosa-Hardcodes** — durchgängig als richtiges Muster bestätigt (auch bienen.ch trennt nationale Fachdaten von kantonalen Zuständigkeiten). ✅

---

## 2. Verbesserungen an bestehenden Modulen (priorisiert)

> **Umsetzungs-Status (2026-07-20, v1.15.3):** Nach Code-Prüfung waren mehrere „Quick Wins" bereits vorhanden oder brauchen Infrastruktur/Migration. **Umgesetzt:** 4.5 Puderzucker-Ampel monatsabhängig (Jul>1 %/Aug>2 %/Sep>3 %); 4.4 Fluglochhöhe-6 mm-Text. **Als Spec vorgemerkt** (nicht „quick"): 4.6 futterart-Konzentrations-Enum (existiert bereits als `zuckersirup/zuckerwasser/…` → Konzentrations-Split = DB-Migration) + Honigreinheit-Warnung (braucht Tracht-Kalender); 20-kg-Warnschwelle (keine Settings-UI); 4.4 gemuelldiagnose-Timing (verhakt mit Offset-Strategie + 2. Ernte). Diese gehören zur phänologischen Generator-Spec (D-41).

### 🟢 Quick Wins (klein, hoher Nutzen)
1. **4.6 Fütterung — `futterart`-Enum ergänzen.** Heute nur `menge_pro_volk_kg`. Enum {`zuckerwasser_1_1`, `zuckerwasser_3_2`, `invertsirup_72`, `futterteig`, `eigener_honig`} macht den **Bio-Nachweis belastbar** und erlaubt die **Honigreinheit-Warnung** (kein Zuckerwasser im Trachtfenster). Optional kg↔Liter-Helfer (1:1≈1,7; 3:2≈1,4; Invert≈1,2).
2. **4.6 Fütterung — 20 kg als BGD-Warnschwelle.** UI-Hinweis „unter BGD-Minimum", wenn ein Mandant `winterfutter_ziel_kg` < 20 setzt. Wertebereich-Hint 20–25.
3. **4.5 Varroa — Diagnose-Schwellen präzisieren.** Puderzucker 50 g Bienen + **35 g** Zucker; Schwellen Juli >5 (>1 %) / Aug >10 (>2 %) / Sept >15 (>3 %). Gemüll Ende Mai >3, Juni/Juli >10 Milben/Tag. Auswaschung >10 % = Volk-Tod. In `ampel_schwellen.dart` gegen unsere Werte prüfen/ergänzen.
4. **4.4 Generator — Bug: `gemuelldiagnose_sommer` an die Ernte koppeln.** Sie ist kalenderfix 1.–15. Juli OHNE Offset, `honigernte` aber offset-basiert (+42) → in Höhenlagen fällt die „nach der Ernte"-Diagnose VOR die Ernte. Fix: Offset anwenden oder als Folgeschritt aus honigernte.
5. **4.4 Generator — `maeuseschutz_ansetzen` um „Fluglochhöhe max. 6 mm" ergänzen** (Beschreibung).

### 🟡 Mittel (neue Generator-Regeln / Felder)
6. **4.4 Generator — fehlende Regeln ergänzen** (offizieller Jahresplan verlangt sie): Jungvolkbildung/Ableger (Mai–Juni), Königinnenvermehrung (Mai–Juli), Umweiselung (August), **befallsorientierte Notbehandlung** (>10 Milben/Tag → sofort), **Winterbehandlungs-Erfolgskontrolle** (+14 T Totenfall, >500 → wiederholen), Serbelvölker auflösen/abschwefeln, **Trachtlücken-/Notfütterung Juni**, `fluglochunterlage_beobachten` (Feb/März, wöchentlich, Vollbeobachtung), `wabenumtrieb_herbst`/`_fruehjahr` (33 %-Ziel).
7. **4.5 Varroa — Methoden-Katalog als strukturierte Daten** (analog `wirkstoff.dart`): je Methode `Mittel · Konzentration · Dosis/Wabenseite · temp_min/max · Dauer · Wirksamkeit% · brutfrei_pflicht · Saison`. Werte im Recherche-File 22. Ermöglicht **Temperatur-Gate** (Behandlung nur im Methodenfenster vorschlagen — alpin wertvoll) und **brutfrei-Pflicht** als harte Vorbedingung für Oxalsäure.
8. **4.5 Varroa — Wartefristen automatisieren:** nach Winterbehandlung Task „Totenfall in 14 T; >500 → wiederholen"; Behandlungstotenfall-Sperre (Milbenfall erst 2 Wochen später werten); Sequenz-Regel „2. Sommerbehandlung immer mit AS".
9. **4.3 Durchsicht — Fluglochbeobachtung/Gemüllbefund als Felder** (Mehrfachauswahl Merkmal→Deutung→Folgeaufgabe): Stummelflügel→Varroa, Kotspritzer→Nosema/Durchfall, Gemüllstreifen→Wintersitz, Wasserlachen→„brütet".
10. **4.5 ↔ 4.7 — Honig-Rückstandssperre:** Flag „mit Oxalsäure/AS in Saison behandelt" → Warnung bei Honigernte-Erfassung des Volkes.

### 🔵 Grösser / strukturell (Spec-würdig)
11. **4.4 — Phänologie-Anker statt reinem +42-Offset.** Der offizielle Plan taktet über **Indikatorpflanzen** (Schneeglöckchen→Sal-Weide→Löwenzahn→Linde). Ein optionaler „Zeigerpflanze beobachtet"-Trigger (oder Grad-Tage) macht den flachen Offset robust gegen Witterungs-/Jahresschwankung und andere Mandantenstandorte. Koppelt an Modul 4.20 (Trachtpflanzen/Phänologie). **Tiefste strukturelle Empfehlung.**
12. **Betriebskonzept als Onboarding/App-Struktur (F5).** Region/Höhe → `saison_offset`; Strategie-Weichen (Sommerbehandlung mit AS vs. Brutstopp; Anzahl Ernten; Vermehrung ja/nein) steuern den Regelkatalog mandantengerecht. Wissens-Menü = die 4 BGD-Merkblatt-Gruppen. Optional Kalender-/Rad-View (Volksentwicklungs-Phasen als Ringe) = visuelle Entsprechung des offiziellen Jahresplan-Posters.
13. **4.14 — Katalog-Feinschliff:** `maikrankheit` als eigene Kategorie (verwechselbar mit `vergiftung`); CBPV/Bienenparalyse dokumentieren (`viren` = CBPV+DWV+BQCV) oder eigene `cbpv`; `steinbrut`/`braula`/`tracheenmilbe` als „ohne BGD-Merkblatt-Quelle" kennzeichnen.

---

## 3. Findings für Folgemodule (bereits fundiert für die Umsetzung)
- **4.16 Schwarmkontrolle/Ableger:** vollständiges Datenmodell + Fristen-Engine in Recherche 25 (Event→Offset→Aufgabe, Tag 9 / Tag 25–30; `methode`-Enum, `stammvolk_id`/`jungvolk_id`/`erstellungsdatum`, `standort_typ`, `os_bei_erstellung`).
- **4.17 Zucht:** Bewertungssystematik in Recherche 26 (7-Stufen-Skala 1,0–4,0; Sanftmut/Wabensitz=Mittelwert, Schwarmträgheit=Minimum; Honigertrag getrennt Früh/weitere; Nadeltest; Zuchtwerte %). Königin-Register 4.2 erweitern (`herdebuchnummer` strukturiert, `eilage_datum`, `begattungsart`, `herdebuchklasse`). Umlarv-Kalender-Trigger (T0→T10 verschulen→T12 Schlupf→T18 Begattung→T21–25 Eilage).
- **4.7 Ernte:** Wassergehalt-Ampel (>20 % rot/gesetzeswidrig, >18,5 % orange/Goldsiegel); **Losnummer amtlich Pflicht**; Rückstellmuster 250 g/Los bis MHD; MHD-Automatik (Erntejahr-Ende + max 3 J.). Details Recherche 28.
- **4.8 Verkauf/Etiketten-Generator:** exakte Pflichtangaben-Liste + Validierungen (MHD-Wortlaut, Los „L", MeAV-Toleranz, Schrift x-Höhe ≥1,2 mm, Heilversprechen-Blocker). Recherche 28.
- **4.23 Recht & Bestandeskontrolle:** **PDF-Export im BLV-Formular-Stil** (App als Führungsform amtlich anerkannt, TSV 20); tagesaktuelle Zu-/Abgänge; kantonale Imker-/Stand-ID; **TAM-Inventarliste** (Pflicht-Lücke zu 4.5); Verstell-Workflow (beetraffic); **kein TVD/Identitas** (kantonal). Recherche 28.
- **4.14 Vespa velutina (eigene Schutz-Domäne):** Melde-Deeplink `asiatischehornisse.ch` (App = kein Meldekanal), kantonale Neobiota-Stelle aus `betrieb`-Kanton; Schutzstatus je Stand (`gitterschutz_montiert` 10–25 mm ab August bei Beflug, `fluglochschieber_5mm` bei Flugende); Generator-Regeln kanton-/befallsabhängig (GR = Monitoring); Terminologie „Gelbbeinige Hornisse". **GR 2023 noch nicht betroffen**, Ausbreitung ×3–4/Jahr → mittelfristig relevant. Recherche 24.
- **4.11 Wachs:** Wabenumtrieb-Tracking (Ziel 33 %/Jahr, Balken), Wachskreislauf-Log für Bio-Nachweis. Recherche 27.
- **4.9 Monitoring:** — (kein direkter bienen.ch-Input; Waage kommt separat).

---

## 4. ⚠️ Verifikationspunkte vor Umsetzung (compliance)
1. **Tropilaelaps** Rechtskategorie: Merkblatt V2603 „zu überwachen" vs. TSV teils „zu bekämpfen". Unsere App: `zuBekaempfen` (vermutlich korrekt) — gegen aktuelle TSV SR 916.401 bestätigen.
2. **TSV 18a Meldefrist** Standänderung: Quellen nennen 3 **und** 10 Arbeitstage — aktuelle Fassung prüfen.
3. Lebensmittelrecht-Sammlung Stand 2022; alle Zahlen BGD-Richtwerte → Fachstellen-Check vor amtlicher Nutzung.

---

## 5. Empfohlene nächste Schritte (Vorschlag zur Priorisierung)
1. **Sofort-Patch-Bündel** (Quick Wins 1–5): kleine, isolierte Änderungen an 4.6/4.5/4.4 — ein Spec-armer Umsetzungslauf.
2. **4.4-Generator-Ausbau** (Findings 6–8) als eigene Spec — die fehlenden Regeln + Timing-Fixes, mit Strategie-Flags-Vorbereitung.
3. **Phänologie-Konzept (Finding 11) + Betriebskonzept-Onboarding (12)** als grössere Brainstorming-Spec, wenn Modul 4.20/F5 ansteht.
4. Folgemodule (4.16/4.17/4.7/4.8/4.23) ziehen ihr Fachfundament direkt aus den Recherchen 21–29.

> Grafik-Hinweis: Die App zeigt bewusst keine bienen.ch-Grafiken direkt (Urheberrecht BGD) — für die Wissensdatenbank verlinken wir auf die frei zugänglichen Merkblätter und bauen eigene, angelehnte Grafiken (z. B. die Varroa-Ampel bremsen/schätzen/behandeln). Katalog: `../imkerei/02_Recherche/29_BGD_Grafik_Register.md`.
