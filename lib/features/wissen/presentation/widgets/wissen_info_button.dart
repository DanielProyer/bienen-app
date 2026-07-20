import 'package:flutter/material.dart';
import 'package:bienen_app/features/wissen/domain/wissen_katalog.dart';
import 'package:bienen_app/features/wissen/presentation/widgets/wissen_panel.dart';

/// Kleines ⓘ, das JEDES Modul über den Wissens-`key` andocken kann.
/// Rendert nichts, wenn der key unbekannt ist (kein dangling ⓘ).
class WissenInfoButton extends StatelessWidget {
  final String wissenKey;
  final double size;
  const WissenInfoButton({super.key, required this.wissenKey, this.size = 20});

  @override
  Widget build(BuildContext context) {
    if (wissenVon(wissenKey) == null) return const SizedBox.shrink();
    return IconButton(
      icon: Icon(Icons.info_outline, size: size),
      tooltip: 'Worauf achten?',
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      onPressed: () => openWissenPanel(context, wissenKey),
    );
  }
}
