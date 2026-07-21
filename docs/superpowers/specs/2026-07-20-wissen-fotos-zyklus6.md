# Wissensdatenbank — kuratierte Fotos (Ebene C) + Attribution

**Datum:** 2026-07-20 · **Track:** App · **Baut auf:** Modul 4.21. Kein DB/Migration. Dritte Bild-Ebene: **mitgelieferte, lizenzsaubere Fotos** je Eintrag (neben SVG-Skizze [A] und eigenen Betriebs-Fotos [B]).

**Lizenz-Policy (verbindlich):** nur **CC0 / Public Domain / CC BY** (kommerziell nutzbar). **Kein CC-BY-SA, kein CC-NC/ND.** Jedes Foto einzeln auf Wikimedia Commons verifiziert (Lizenz + Motiv visuell). CC-BY braucht sichtbare Attribution.

## 1. Attribution-Manifest (7 Fotos, alle verifiziert, in `assets/wissen/fotos/`)

| Eintrag-key | Datei | Motiv | Autor | Lizenz | Commons-URL |
|---|---|---|---|---|---|
| `varroa_milbe` | varroa_milbe.jpg | Varroa-Milben auf Bienen-Vorpuppe | Denis Anderson (CSIRO) | CC BY 3.0 | https://commons.wikimedia.org/wiki/File:CSIRO_ScienceImage_7306_A_European_honey_bee_prepupa_with_varroa_mites.jpg |
| `koenigin_finden` | koenigin_finden.jpg | Brutwabe, Königin gelb markiert | USGS (M. Lubeck) | CC0 / Public Domain | https://commons.wikimedia.org/wiki/File:Queen_Bee_(16545241268).jpg |
| `weiselzelle` | weiselzelle.jpg | Unverdeckelte Weiselzelle mit Larve | Maja Dumat | CC BY 2.0 | https://commons.wikimedia.org/wiki/File:Unverdeckelte_Weiselzelle_003.jpg |
| `vespa_velutina` | vespa_velutina.jpg | Asiatische Hornisse (Seitenmakro) | Vespa-Watch | CC0 | https://commons.wikimedia.org/wiki/File:Vespa_velutina_165382529.jpg |
| `pollen` | pollen.jpg | Biene mit Pollenhöschen | Conall | CC BY 2.0 | https://commons.wikimedia.org/wiki/File:Honey_bee_on_Viburnum_davidii.jpg |
| `baurahmen_drohnen` | baurahmen_drohnen.jpg | Bienen entfernen Drohnenbrut | Nick Pitsas (CSIRO) | CC BY 3.0 | https://commons.wikimedia.org/wiki/File:CSIRO_ScienceImage_6961_Worker_honey_bees_removing_excess_drone_brood_from_the_hive.jpg |
| `kalkbrut` | kalkbrut.jpg | Kalkbrut-Mumien vor der Beute | Jeff Pettis | CC BY 3.0 US | https://commons.wikimedia.org/wiki/File:Ascosphaera_apis_(Maasen_ex_Claussen)_L.S._Olive_%26_Spiltoir_1324048.jpg |

Übersprungen (auf Commons nur CC-BY-SA verfügbar): `afb`, `brut_offen_verdeckelt`, `stifte`. `vespa_velutina.jpg` trägt einen kleinen Datumsstempel unten links (kosmetisch, Motiv eindeutig) — akzeptiert.

## 2. Modell (`lib/features/wissen/domain/wissen_eintrag.dart`)
```dart
/// Attribution eines kuratierten Fotos. CC-BY → Zeile sichtbar; CC0/PD → optional, aber wir zeigen sie einheitlich.
class WissensBildquelle {
  final String autor;   // '' bei anonym
  final String lizenz;  // 'CC BY 3.0' | 'CC BY 2.0' | 'CC0' | 'Public Domain' | 'CC0 / Public Domain' | 'CC BY 3.0 US'
  final String url;     // Commons File-Seite
  const WissensBildquelle({required this.autor, required this.lizenz, required this.url});
  String get zeile => autor.isEmpty ? 'Foto · $lizenz' : 'Foto: $autor · $lizenz';
}
```
`WissensEintrag` um zwei Felder ergänzen (optional):
```dart
  final String? foto;                 // Asset unter assets/wissen/fotos/
  final WissensBildquelle? fotoQuelle;
```
Im Konstruktor ergänzen: `this.foto, this.fotoQuelle,` + Assert `assert(foto == null || fotoQuelle != null, 'Foto braucht eine Attribution')`.

## 3. Katalog (`wissen_katalog.dart`) — die 7 Einträge um `foto` + `fotoQuelle` ergänzen
Jeweils in den bestehenden `WissensEintrag(...)` einfügen (Beispiel varroa_milbe):
```dart
    foto: 'assets/wissen/fotos/varroa_milbe.jpg',
    fotoQuelle: WissensBildquelle(autor: 'Denis Anderson (CSIRO)', lizenz: 'CC BY 3.0',
        url: 'https://commons.wikimedia.org/wiki/File:CSIRO_ScienceImage_7306_A_European_honey_bee_prepupa_with_varroa_mites.jpg'),
```
Analog für die anderen 6 (Werte exakt aus dem Manifest §1):
- `koenigin_finden`: foto `assets/wissen/fotos/koenigin_finden.jpg`, autor `USGS (M. Lubeck)`, lizenz `CC0 / Public Domain`, url s. §1.
- `weiselzelle`: `.../weiselzelle.jpg`, autor `Maja Dumat`, lizenz `CC BY 2.0`, url s. §1.
- `vespa_velutina`: `.../vespa_velutina.jpg`, autor `Vespa-Watch`, lizenz `CC0`, url s. §1.
- `pollen`: `.../pollen.jpg`, autor `Conall`, lizenz `CC BY 2.0`, url s. §1.
- `baurahmen_drohnen`: `.../baurahmen_drohnen.jpg`, autor `Nick Pitsas (CSIRO)`, lizenz `CC BY 3.0`, url s. §1.
- `kalkbrut`: `.../kalkbrut.jpg`, autor `Jeff Pettis`, lizenz `CC BY 3.0 US`, url s. §1.

## 4. Panel (`lib/features/wissen/presentation/widgets/wissen_panel.dart`)
Direkt VOR dem bestehenden Skizze-Block einen Foto-Block einfügen (Foto = echtes Beispiel zuerst, dann die annotierte Skizze):
```dart
if (e.foto != null) ...[
  const SizedBox(height: 16),
  GestureDetector(
    onTap: () => root.push(MaterialPageRoute(fullscreenDialog: true,
        builder: (_) => WissenSkizzePage(assetPfad: e.foto!, titel: e.titel))),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(e.foto!, height: 180, width: double.infinity, fit: BoxFit.cover),
    ),
  ),
  Padding(
    padding: const EdgeInsets.only(top: 4),
    child: GestureDetector(
      onTap: () => launchUrl(Uri.parse(e.fotoQuelle!.url), mode: LaunchMode.externalApplication),
      child: Text(e.fotoQuelle!.zeile, style: const TextStyle(fontSize: 11, color: Colors.black54, decoration: TextDecoration.underline)),
    ),
  ),
],
```
(`root` = das bereits vorhandene `Navigator.of(context, rootNavigator: true)`; `launchUrl`/`url_launcher` ist im Panel bereits importiert.)

## 5. Vollbild für Raster (`wissen_skizze_page.dart` erweitern)
`WissenSkizzePage` so anpassen, dass sie SVG **und** Raster kann:
```dart
child: assetPfad.toLowerCase().endsWith('.svg')
    ? SvgPicture.asset(assetPfad, fit: BoxFit.contain)
    : Image.asset(assetPfad, fit: BoxFit.contain),
```
(Import `flutter_svg` bleibt.)

## 6. pubspec
Unter `flutter: assets:` ergänzen: `- assets/wissen/fotos/`. Version → `1.26.0+47`.

## 7. Tests (`wissen_katalog_test.dart` erweitern)
Neuer Testblock „kuratierte Fotos":
- jeder Eintrag mit `foto != null` hat `fotoQuelle != null`.
- jede `foto`-Datei existiert (`File.existsSync`) und ist von einer pubspec-Deklaration abgedeckt (Präfix `assets/wissen/fotos/`).
- **Lizenz-Guard (kommerzielle Sicherheit):** jede `fotoQuelle.lizenz` enthält `CC0`, `Public Domain` ODER `CC BY`, und enthält NICHT `SA` und NICHT `NC` (case-insensitive). Verhindert, dass je ein Share-alike-/NC-Foto durchrutscht.
- jede `fotoQuelle.url` beginnt mit `https://`.

## 8. Deploy
`flutter analyze`+`flutter test` grün → `bash deploy.sh`. Kein Migrations-Schritt.

## 9. Offen (spätere Chargen)
Fotos für `afb`/`brut_offen_verdeckelt`/`stifte` (bisher nur CC-BY-SA gefunden) — später CC0/CC-BY-Quelle suchen (USDA/ARS, Agroscope-Freigaben). Optional: zentrale „Bildnachweise"-Seite (die Panel-Attribution erfüllt CC-BY bereits).
