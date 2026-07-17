import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/monitoring/data/models/scale.dart';

void main() {
  test('Scale.fromJson liest volk_id', () {
    final s = Scale.fromJson({
      'id': 'sc1', 'hive_name': 'W1', 'vendor': 'HiveWatch', 'volk_id': 'v1',
    });
    expect(s.volkId, 'v1');
    expect(s.toJson()['volk_id'], 'v1');
  });
}
