import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';

void main() {
  test('Signal-Rollen liefern Flächen/Text-Paar', () {
    expect(BeeSignal.warnung.flaeche, const Color(0xFFFAEEDA));
    expect(BeeSignal.warnung.text, const Color(0xFF854F0B));
    expect(BeeSignal.erfolg.text, const Color(0xFF3B6D11));
    expect(BeeSignal.gefahr.text, const Color(0xFFA32D2D));
    expect(BeeSignal.neutral.flaeche, BeeTokens.karte);
  });
  test('Abstände auf 4/8-Raster', () {
    expect([BeeTokens.xs, BeeTokens.sm, BeeTokens.md, BeeTokens.lg, BeeTokens.xl],
        [4.0, 8.0, 12.0, 16.0, 24.0]);
  });
}
