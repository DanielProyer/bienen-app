import 'dart:typed_data';

/// Nicht-Web-Ziele (VM/Tests): die dart:js_interop-Kapsel baut dort nicht,
/// also ein No-op — ein Browser-Download hat ausserhalb des Browsers keinen Sinn.
void downloadImBrowser(Uint8List bytes, String dateiname) {}
