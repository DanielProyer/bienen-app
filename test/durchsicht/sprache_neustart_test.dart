import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/features/durchsicht/sprache/domain/sprach_neustart.dart';

void main() {
  group('istFataler Fehler — danach darf NICHT neu gestartet werden', () {
    test('verweigerte Berechtigung ist fatal', () {
      // Der Loop-Auslöser: ohne Mikrofonfreigabe endet die Erkennung sofort
      // wieder, ein blinder Neustart dreht dann mit voller Geschwindigkeit.
      expect(istFatalerFehler('not-allowed'), isTrue);
      expect(istFatalerFehler('service-not-allowed'), isTrue);
      expect(istFatalerFehler('audio-capture'), isTrue);
    });

    test('Sprechpausen und Abbrüche sind harmlos', () {
      expect(istFatalerFehler('no-speech'), isFalse);
      expect(istFatalerFehler('aborted'), isFalse);
    });

    test('Netzfehler ist nicht fatal — am Bienenstand reisst die Verbindung ab', () {
      // Hier ist ein gebremster Neustart richtig, kein Aufgeben.
      expect(istFatalerFehler('network'), isFalse);
    });

    test('unbekannter Code gilt als nicht fatal', () {
      expect(istFatalerFehler(''), isFalse);
      expect(istFatalerFehler('irgendwas-neues'), isFalse);
    });
  });

  group('NeustartBremse', () {
    test('lässt die ersten Neustarts durch', () {
      final b = NeustartBremse(maxVersuche: 3, fenster: const Duration(seconds: 10));
      final t = DateTime(2026, 7, 27, 12, 0, 0);
      expect(b.darfNeuStarten(t), isTrue);
      expect(b.darfNeuStarten(t.add(const Duration(seconds: 1))), isTrue);
      expect(b.darfNeuStarten(t.add(const Duration(seconds: 2))), isTrue);
    });

    test('bremst, wenn es zu schnell zu oft neu startet', () {
      // Genau das war der Fehler: onend -> start -> onend -> start …
      final b = NeustartBremse(maxVersuche: 3, fenster: const Duration(seconds: 10));
      final t = DateTime(2026, 7, 27, 12, 0, 0);
      for (var i = 0; i < 3; i++) {
        expect(b.darfNeuStarten(t.add(Duration(milliseconds: i * 50))), isTrue);
      }
      expect(b.darfNeuStarten(t.add(const Duration(milliseconds: 200))), isFalse,
          reason: 'vierter Versuch im Zeitfenster muss abgelehnt werden');
    });

    test('nach Ablauf des Zeitfensters ist wieder frei', () {
      // Ein Dauerbetrieb über Stunden soll weiterlaufen; nur Sturzfolgen bremsen.
      final b = NeustartBremse(maxVersuche: 2, fenster: const Duration(seconds: 10));
      final t = DateTime(2026, 7, 27, 12, 0, 0);
      expect(b.darfNeuStarten(t), isTrue);
      expect(b.darfNeuStarten(t.add(const Duration(seconds: 1))), isTrue);
      expect(b.darfNeuStarten(t.add(const Duration(seconds: 2))), isFalse);
      expect(b.darfNeuStarten(t.add(const Duration(seconds: 30))), isTrue,
          reason: 'alte Versuche fallen aus dem Fenster');
    });

    test('zuruecksetzen macht den Zähler frei', () {
      final b = NeustartBremse(maxVersuche: 1, fenster: const Duration(seconds: 10));
      final t = DateTime(2026, 7, 27, 12, 0, 0);
      expect(b.darfNeuStarten(t), isTrue);
      expect(b.darfNeuStarten(t), isFalse);
      b.zuruecksetzen(); // beim bewussten Neustart durch den Nutzer
      expect(b.darfNeuStarten(t), isTrue);
    });

    test('ein erfolgreicher Lauf entlastet den Zähler', () {
      // Sonst würde stundenlanges Diktieren irgendwann grundlos blockiert.
      final b = NeustartBremse(maxVersuche: 2, fenster: const Duration(seconds: 10));
      final t = DateTime(2026, 7, 27, 12, 0, 0);
      b.darfNeuStarten(t);
      b.darfNeuStarten(t);
      b.erfolgreichGelaufen(); // Erkennung lief lange genug -> kein Sturz
      expect(b.darfNeuStarten(t), isTrue);
    });
  });
}
