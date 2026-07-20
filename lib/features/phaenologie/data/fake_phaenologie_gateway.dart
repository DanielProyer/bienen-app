import 'package:bienen_app/features/phaenologie/domain/beobachtung.dart';
import 'package:bienen_app/features/phaenologie/domain/phaenologie_gateway.dart';

class FakePhaenologieGateway implements PhaenologieGateway {
  final _map = <String, PhaenoBeobachtung>{}; // key = '$jahr-$anker'
  String _k(PhaenoBeobachtung b) => '${b.jahr}-${b.anker.name}';

  @override
  Future<List<PhaenoBeobachtung>> alle() async => _map.values.toList();

  @override
  Future<void> upsert(PhaenoBeobachtung b) async => _map[_k(b)] = b;
}
