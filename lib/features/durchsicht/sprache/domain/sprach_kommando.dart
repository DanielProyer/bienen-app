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
