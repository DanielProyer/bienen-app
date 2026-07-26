import 'package:flutter/material.dart';
import 'package:bienen_app/core/storage/foto_quelle.dart';
import 'package:bienen_app/core/storage/foto_speicher.dart';
import 'package:bienen_app/core/supabase/supabase_config.dart';
import 'package:bienen_app/core/theme/app_tokens.dart';

/// Zeigt ein Bild aus einem PRIVATEN Storage-Bucket.
///
/// Seit P01 steht in der DB der PFAD, der zur Laufzeit signiert wird. Ein
/// uebersehener Altwert mit voller URL wird direkt geladen ([istVolleUrl]) —
/// so bleibt die Galerie in jedem Fall sichtbar statt leer.
///
/// Die Signed-URL wird im State gehalten und NICHT im build erzeugt: sonst
/// wuerde jeder Rebuild neu signieren und das Bild flackern.
class SignedImage extends StatefulWidget {
  /// Pfad im Bucket — oder eine volle Alt-URL.
  final String wert;
  final String bucket;
  final double? breite;
  final double? hoehe;
  final BoxFit fit;

  /// Ersatzdarstellung, wenn das Signieren oder das Laden scheitert.
  final Widget? fehlerBild;

  const SignedImage({
    super.key,
    required this.wert,
    required this.bucket,
    this.breite,
    this.hoehe,
    this.fit = BoxFit.cover,
    this.fehlerBild,
  });

  @override
  State<SignedImage> createState() => _SignedImageState();
}

class _SignedImageState extends State<SignedImage> {
  late Future<String> _url;

  @override
  void initState() {
    super.initState();
    _url = _laden();
  }

  @override
  void didUpdateWidget(covariant SignedImage alt) {
    super.didUpdateWidget(alt);
    if (alt.wert != widget.wert || alt.bucket != widget.bucket) {
      _url = _laden();
    }
  }

  Future<String> _laden() => istVolleUrl(widget.wert)
      ? Future.value(widget.wert)
      : FotoSpeicher(SupabaseConfig.client, widget.bucket)
          .signedUrl(widget.wert);

  /// Fester Rahmen, damit Ladeanzeige und Fehlerbild auch dort eine Groesse
  /// haben, wo das Bild selbst unbegrenzt waechst (Vollbild-Dialog).
  Widget _rahmen(Widget kind) => SizedBox(
        width: widget.breite ?? 48,
        height: widget.hoehe ?? 48,
        child: Center(child: kind),
      );

  Widget get _fehler =>
      widget.fehlerBild ??
      _rahmen(const Icon(Icons.broken_image_outlined,
          color: BeeTokens.textGedaempft));

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _url,
      builder: (context, snap) {
        if (snap.hasError) return _fehler;
        if (!snap.hasData) {
          return _rahmen(const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ));
        }
        return Image.network(
          snap.data!,
          width: widget.breite,
          height: widget.hoehe,
          fit: widget.fit,
          errorBuilder: (_, _, _) => _fehler,
        );
      },
    );
  }
}
