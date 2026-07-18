import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/voelker/domain/betriebs_einstellungen.dart';

void main() {
  test('winterfutterZielKg aus JSON, Default 22 bei fehlend/leer', () {
    expect(BetriebsEinstellungen.fromJson({'winterfutter_ziel_kg': 24}).winterfutterZielKg, 24);
    expect(BetriebsEinstellungen.fromJson({}).winterfutterZielKg, 22);
    expect(const BetriebsEinstellungen.leer().winterfutterZielKg, 22);
  });
}
