import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';

/// Vollbild-Zoom einer SVG-Skizze. Wird per Navigator.push geöffnet (KEINE Route → kein extra-Problem).
class WissenSkizzePage extends StatelessWidget {
  final String assetPfad;
  final String? titel;
  const WissenSkizzePage({super.key, required this.assetPfad, this.titel});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titel ?? 'Skizze')),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Padding(
            padding: const EdgeInsets.all(BeeTokens.lg),
            child: assetPfad.toLowerCase().endsWith('.svg')
                ? SvgPicture.asset(assetPfad, fit: BoxFit.contain)
                : Image.asset(assetPfad, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}
