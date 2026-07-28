# Grafik-Register bienen.ch (Diagramme für App/Wissensdatenbank)

> **Quelle:** BienenSchweiz / Bienengesundheitsdienst (BGD · apiservice), bienen.ch — Katalog wertvoller BGD-Grafiken mit Quell-URLs. Ausgewertet 2026-07-19 im Rahmen der bienen.ch-Wissenserschliessung (96 Merkblätter/PDFs, Textextraktion + visuelle Grafik-Auswertung).
> **Charakter:** Offizielles Schweizer BGD-Fachwissen (frei zugänglich). Zahlen sind BGD-Richtwerte — vor amtlicher Nutzung Fachstellen-Check. Hotline Bienengesundheit 0800 274 274.
> **Zusammenhang:** Ergänzt alle obigen BGD-Recherchen (21–28) um visuell ausgewertete Schlüsselgrafiken. App-Verbesserungsvorschläge aus dieser Quelle: siehe App-Schiene `bienen_app/docs/bienen-ch-findings.md`.

---

# Grafik-Register bienen.ch (BGD / apiservice)

Katalog wertvoller Grafiken/Diagramme von bienen.ch für spätere App-/Wissensdatenbank-Nutzung. Quelle: Bienengesundheitsdienst BGD (apiservice), frei zugänglich unter bienen.ch. Alle Merkblätter tragen Hotline 0800 274 274.

## ⭐ Schlüssel-Grafik 1 — Varroa-Behandlungskonzept (Ampel-Jahresraster)
- **Quelle:** https://bienen.ch/wp-content/uploads/2023/01/Varroakonzept_D.pdf (V 2606, 1 Seite A4)
- **Visuell ausgewertet:** Ja. Farbcodiertes Monatsraster (Feb–Jan) mit 3 Phasen-Legende:
  - 🟡 **gelb = Varroaentwicklung bremsen** (März–Juni: Drohnenwabe einhängen + mehrmals verdeckelte Drohnenbrut ausschneiden; Jungvolkbildung)
  - 🟢 **grün = Milbenbefall schätzen** (Mai: natürlicher Milbenfall, **>3 Milben/Tag → Notbehandlung**; Juli: **>10 Milben/Tag → Notbehandlung oder sofortige Sommerbehandlung**; Januar: Behandlungstotenfall, **>500 Milben in 2 Wochen nach Winterbehandlung → wiederholen**)
  - 🔴 **rot = behandeln** (Juli 1. Sommerbehandlung ohne AS [Brutstopp/Bannwabe/Brutentnahme] Beginn 1. Juli-Hälfte, oder mit Ameisensäure Beginn vor Ende Juli; Sept 2. Sommerbehandlung **immer mit Ameisensäure** Beginn spätestens Mitte Sept.; Nov/Dez **Oxalsäure brutfrei** = Winterbehandlung)
- **App-Nutzen:** Die 3-Phasen-Ampel (bremsen/schätzen/behandeln) ist eine ideale Vorlage für die Varroa-Cockpit-Visualisierung (4.5) und den Aufgaben-Generator. Schwellen >3/>10/>500 bestätigen/präzisieren unsere Ampel-Schwellen.

## ⭐ Schlüssel-Grafik 2 — Jahresplanung nach Betriebskonzept (Indikatorpflanzen)
- **Quelle:** https://bienen.ch/wp-content/uploads/.../jahresplan_betriebskonzept.pdf (Poster, 2 Seiten)
- **Visuell ausgewertet:** Ja (Seite 1). „Strassen"-Infografik: der Bienenjahr-Ablauf ist an **Indikatorpflanzen-Blüte** geknüpft statt an fixe Kalenderdaten:
  - **Schneeglöckchen:** Futterkontrolle, bei Bedarf Futterteig
  - **Sal-Weide:** Flugloch-Beobachtung, Unterlagen-Kontrolle, Frühjahrskontrolle, Einengen
  - **Traubenhyazinthe/Schlüsselblume:** Gesundheitskontrolle, Auflösen Serbelvölker, Vereinen mit Jungvölkern
  - **Vogelkirsche:** Erweitern, Drohnenwabe einhängen
  - **Löwenzahn:** Honigaufsatz geben, Drohnenschnitt, Schwarmverhinderung, Jungvölker bilden/behandeln/füttern, Königinnen vermehren
  - **Apfel/Raps/Berg-Ahorn:** Schwarmverhinderung, Bienenvergiftungen (Achtung), Honigernte Frühling, Jungvölker bilden/behandeln/füttern, Königinnen vermehren
  - **Linde/Edelkastanie:** Vereinigen gesunder abgeschwärmter Völker, Serbelvölker abschwefeln, Trachtlücken erkennen, Notfütterung, Königin zeichnen
  - **Weisstanne:** Honigernte Sommer
- **App-Nutzen (WICHTIG, Verbesserungspotenzial):** Der offizielle CH-Ansatz ist **phänologisch** (an Blüte-Indikatoren gekoppelt), NICHT an fixe Daten. Für alpin Arosa (1570 m, Saison ~40 Tage später) ist das die robustere Logik als unser fixer `saison_offset_tage=+42`. → Kandidat für 4.4-Generator-Weiterentwicklung + Modul 4.20 (Trachtpflanzen/Phänologie): Nutzer meldet Indikatorpflanzen-Blüte, Generator triggert daraus. Siehe App-Findings.

## Vespa-velutina-Fundtabelle 2023
- **Quelle:** Tabelle_D.pdf (Funde 2023). Visuell gesichtet: Kanton/Ort/Neststatus. **Relevanz:** Ausbreitung 2023 auf West-/Nordschweiz (GE, VD, JU, BL, FR, NE, SO, AG) beschränkt — **Graubünden 2023 noch nicht betroffen**, aber Ausbreitung Richtung Osten absehbar → für Arosa mittelfristig relevant (Wachsamkeit).

## Weitere wertvolle Grafiken (gerendert bzw. Quelle notiert — bei Bedarf visuell auswertbar)
| Grafik | Quelle-URL | Inhalt |
|---|---|---|
| Übersicht Methoden Jungvolkbildung (Entscheidungsdiagramm) | .../1.4_uebersicht_methoden_jungvolkbildung.pdf | Entscheidungsbaum Vermehrungsmethoden (gerendert p1) |
| Übersicht Krankheiten/Schädlinge | .../2_uebersicht_krankheiten_schaedlinge.pdf | 5-seitige Symptom-/Rechtsstatus-Übersicht |
| Poster Bienenkrankheiten & Schädlinge | .../poster_bienenkrankheiten_schaedlinge_d.pdf | 8-seitiges Bestimmungs-Poster mit Symptombildern |
| Bestimmungshilfe Kleiner Beutenkäfer | .../Bestimmungshilfe_..._a4_web.pdf | Identifikations-Bildtafel |
| Übersicht Gute imkerliche Praxis | .../4_uebersicht_gute_imkerliche_praxis.pdf | Struktur der 4.x-Merkblätter |
| Übersicht Methoden Sommerbehandlung | .../1.2_uebersicht_methoden_sommerbehandlung.pdf | Vergleichstabelle AS-Verdunster |
| Poster Jahresplanung Vespa velutina | .../Poster-Jahresplanung-Vespa_velutina.pdf | Abwehr-Jahresplan Asiatische Hornisse |

> Hinweis: Die App zeigt Recherche-Texte, keine bienen.ch-Grafiken direkt (Urheberrecht BGD). Für die Wissensdatenbank können wir auf die Merkblätter **verlinken** (frei zugänglich) und eigene, an bienen.ch angelehnte Grafiken (z. B. Varroa-Ampel) selbst nachbauen.
