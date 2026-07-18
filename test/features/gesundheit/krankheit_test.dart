import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/gesundheit/domain/krankheit.dart';

// Spiegel der G01 krankheit-CHECK-Whitelist. MUSS mit kKrankheiten UND der Migration synchron bleiben (M3).
const _dbCheckKeys = <String>{
  'afb', 'efb', 'kleiner_beutenkaefer', 'tropilaelaps', 'varroa', 'kalkbrut', 'steinbrut', 'sackbrut',
  'nosema', 'ruhr', 'viren', 'wachsmotte', 'braula', 'tracheenmilbe', 'vergiftung', 'vespa_velutina', 'sonstige',
};

void main() {
  test('Katalog-Keys == DB-CHECK-Whitelist (Parität, M3)', () {
    expect(krankheitKeys, _dbCheckKeys);
  });
  test('Rechtskategorie je Krankheit (verifiziert Recherche 14)', () {
    for (final k in ['afb', 'efb', 'kleiner_beutenkaefer', 'tropilaelaps']) {
      expect(rechtskategorieVon(k), Rechtskategorie.zuBekaempfen, reason: k);
      expect(istMeldepflichtig(k), isTrue, reason: k);
    }
    expect(rechtskategorieVon('varroa'), Rechtskategorie.zuUeberwachen);
    expect(istMeldepflichtig('varroa'), isFalse);
    for (final k in ['kalkbrut', 'sackbrut', 'nosema', 'tracheenmilbe', 'vergiftung']) {
      expect(rechtskategorieVon(k), Rechtskategorie.nichtMeldepflichtig, reason: k);
    }
    expect(rechtskategorieVon('vespa_velutina'), Rechtskategorie.neobiotaMeldung);
    expect(istMeldepflichtig('vespa_velutina'), isTrue);
  });
  test('kein GR-Hardcode im Melde-Text (M1)', () {
    for (final k in kKrankheiten) {
      expect(k.meldehinweis ?? '', isNot(contains('GR')), reason: k.key);
    }
  });
  test('durchsichtFlagZuKrankheit-Mapping', () {
    expect(durchsichtFlagZuKrankheit('faulbrut_verdacht'), 'afb');
    expect(durchsichtFlagZuKrankheit('sauerbrut_verdacht'), 'efb');
    expect(durchsichtFlagZuKrankheit('varroa_sichtbar'), 'varroa');
    expect(durchsichtFlagZuKrankheit('raeuberei'), isNull);
    expect(durchsichtFlagZuKrankheit('kahlflug'), isNull);
  });
}
