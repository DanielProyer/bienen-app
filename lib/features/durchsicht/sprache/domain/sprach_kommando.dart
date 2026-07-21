/// Deutsche Zahl aus einem bereits normalisierten Token: Ziffern ODER Zahlwörter 0-99. null = keine Zahl.
num? deutscheZahl(String s) {
  final t = s.trim();
  if (t.isEmpty) return null;
  final z = num.tryParse(t.replaceAll(',', '.'));
  if (z != null) return z;
  const einer = {
    'null': 0, 'eins': 1, 'ein': 1, 'eine': 1, 'zwei': 2, 'drei': 3, 'vier': 4, 'fuenf': 5,
    'sechs': 6, 'sieben': 7, 'acht': 8, 'neun': 9,
  };
  const teens = {
    'zehn': 10, 'elf': 11, 'zwoelf': 12, 'dreizehn': 13, 'vierzehn': 14, 'fuenfzehn': 15,
    'sechzehn': 16, 'siebzehn': 17, 'achtzehn': 18, 'neunzehn': 19,
  };
  const zehner = {
    'zwanzig': 20, 'dreissig': 30, 'vierzig': 40, 'fuenfzig': 50, 'sechzig': 60,
    'siebzig': 70, 'achtzig': 80, 'neunzig': 90,
  };
  if (einer.containsKey(t)) return einer[t];
  if (teens.containsKey(t)) return teens[t];
  if (zehner.containsKey(t)) return zehner[t];
  // Kompositum "<einer>und<zehner>" z.B. zweiundzwanzig
  final i = t.indexOf('und');
  if (i > 0) {
    final e = einer[t.substring(0, i)];
    final z2 = zehner[t.substring(i + 3)];
    if (e != null && z2 != null) return z2 + e;
  }
  return null;
}

enum SprachKontext { kontext, kennzahlen, waben }

sealed class SprachKommando {
  const SprachKommando();
}
class ZahlKommando extends SprachKommando { final String feld; final num wert; const ZahlKommando(this.feld, this.wert); }
class EnumKommando extends SprachKommando { final String feld; final String wert; const EnumKommando(this.feld, this.wert); }
class BoolKommando extends SprachKommando { final String feld; final bool wert; const BoolKommando(this.feld, this.wert); }
class AuffaelligkeitKommando extends SprachKommando { final String key; final bool an; const AuffaelligkeitKommando(this.key, this.an); }

/// Normalisiert: lowercase, Umlaut-Folding, Mehrfach-Space → einzeln, trim.
String normalisiere(String s) => s
    .toLowerCase()
    .replaceAll('ä', 'ae').replaceAll('ö', 'oe').replaceAll('ü', 'ue').replaceAll('ß', 'ss')
    .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

enum _Typ { zahl, boolWert, enumWert }

class _Regel {
  final String feld;
  final List<String> trigger;                 // normalisierte Feldwörter/Aliase (längere zuerst!)
  final _Typ typ;
  final Map<String, List<String>>? enumWerte;  // canonicalKey → normalisierte Wortaliase (nur enum)
  const _Regel(this.feld, this.trigger, this.typ, [this.enumWerte]);
}

const _negation = {'nein', 'kein', 'keine', 'ohne', 'nicht'};

// Reihenfolge zählt: spezifischere/längere Trigger zuerst (z.B. 'anzahl weiselzellen' vor 'weiselzellen').
final Map<SprachKontext, List<_Regel>> _grammatik = {
  SprachKontext.kontext: [
    const _Regel('temperatur', ['temperatur', 'grad'], _Typ.zahl),
    const _Regel('dauer', ['dauer'], _Typ.zahl),
    const _Regel('weiselzustand', ['weiselzustand', 'weisel'], _Typ.enumWert, {
      'weiselrichtig': ['weiselrichtig', 'richtig'],
      'weisellos': ['weisellos', 'los'],
      'drohnenbruetig': ['drohnenbruetig', 'drohnenmuetterchen'],
      'unsicher': ['unsicher'],
    }),
  ],
  SprachKontext.kennzahlen: [
    const _Regel('wz_anzahl', ['anzahl weiselzellen', 'weiselzellen anzahl'], _Typ.zahl),
    const _Regel('brutwaben', ['brutwaben'], _Typ.zahl),
    const _Regel('staerke', ['wabengassen', 'gassen', 'staerke'], _Typ.zahl),
    const _Regel('futter', ['futter'], _Typ.zahl),
    const _Regel('sanftmut', ['sanftmut'], _Typ.zahl),
    const _Regel('wabensitz', ['wabensitz'], _Typ.zahl),
    const _Regel('koenigin', ['koenigin', 'chuengin', 'wysle', 'weisel', 'majestaet'], _Typ.boolWert),
    const _Regel('stifte', ['stifte', 'stift', 'eier'], _Typ.boolWert),
    const _Regel('weiselzellen', ['weiselzellen'], _Typ.enumWert, {
      'keine': ['keine'],
      'spielnaepfchen': ['spielnaepfchen', 'napf', 'naepfchen'],
      'schwarmzellen': ['schwarmzellen', 'schwarm'],
      'nachschaffungszellen': ['nachschaffungszellen', 'nachschaffung'],
    }),
    const _Regel('brutbild', ['brutbild', 'brut'], _Typ.enumWert, {
      'geschlossen': ['geschlossen', 'lueckenlos'],
      'lueckig': ['lueckig', 'loechrig'],
      'bunt': ['bunt'],
      'kaum': ['kaum'],
      'kein': ['kein'],
    }),
    const _Regel('pollen', ['pollen'], _Typ.enumWert, {
      'viel': ['viel'], 'mittel': ['mittel'], 'wenig': ['wenig'], 'kein': ['kein'],
    }),
    const _Regel('platz', ['platz'], _Typ.enumWert, {
      'ok': ['ok', 'okay', 'passt'],
      'eng': ['eng'],
      'honigraum_noetig': ['honigraum', 'honigraum noetig'],
      'zu_gross': ['zu gross', 'gross'],
    }),
  ],
  SprachKontext.waben: const [], // v2
};

// Auffälligkeiten (kontextfrei auf der Kennzahlen-Seite): Trigger 'auffaelligkeit <wort>' oder direkt das Wort.
const _auffaelligkeitAlias = <String, String>{
  'kalkbrut': 'kalkbrut', 'sackbrut': 'sackbrut',
  'faulbrut': 'faulbrut_verdacht', 'amerikanische faulbrut': 'faulbrut_verdacht',
  'sauerbrut': 'sauerbrut_verdacht',
  'ruhr': 'ruhr', 'durchfall': 'ruhr',
  'raeuberei': 'raeuberei', 'wachsmotte': 'wachsmotte',
  'varroa': 'varroa_sichtbar', 'milben': 'varroa_sichtbar',
  'kahlflug': 'kahlflug',
};

/// Ganzwortiges (space-begrenztes) Matching — verhindert Substring-Kollisionen (weisel ⊄ weiselzellen, brut ⊄ brutwaben).
bool _wort(String q, String t) => (' $q ').contains(' $t ');

SprachKommando? parseKommando(String transkript, SprachKontext kontext) {
  final q = normalisiere(transkript);
  if (q.isEmpty) return null;

  if (kontext == SprachKontext.kennzahlen) {
    for (final e in _auffaelligkeitAlias.entries) {
      if (_wort(q, e.key)) return AuffaelligkeitKommando(e.value, !_negation.any((n) => _wort(q, n)));
    }
  }

  for (final regel in _grammatik[kontext] ?? const <_Regel>[]) {
    if (!regel.trigger.any((t) => _wort(q, t))) continue;
    switch (regel.typ) {
      case _Typ.zahl:
        for (final tok in q.split(' ')) {   // Zahl irgendwo im Satz ("Temperatur 22" ODER "22 Grad")
          final n = deutscheZahl(tok);
          if (n != null) return ZahlKommando(regel.feld, n);
        }
        continue; // Feldwort ohne Zahl → nächste Regel probieren
      case _Typ.boolWert:
        return BoolKommando(regel.feld, !_negation.any((n) => _wort(q, n)));
      case _Typ.enumWert:
        for (final ew in regel.enumWerte!.entries) {
          if (ew.value.any((w) => _wort(q, w))) return EnumKommando(regel.feld, ew.key);
        }
        continue; // Feldwort ohne gültigen Wert → weiter
    }
  }
  return null;
}
