import 'package:bienen_app/features/durchsicht/sprache/domain/sprache_erkenner.dart';
import 'package:bienen_app/features/durchsicht/sprache/data/web_sprache_erkenner.dart';

/// Web-Ziel: echte Web-Speech-API-Kapsel.
SpracheErkenner spracheErkennerErstellen() => WebSpracheErkenner();
