class MaterialItem {
  final String id;
  final String category;
  final String name;
  final String? description;
  final int quantity;
  final String? unit;
  final double? priceCHF;
  final String? supplier;
  final String? supplierUrl;
  final int phase;
  final String status; // 'geplant', 'bestellt', 'gekauft'
  final String? notes;
  final int sortOrder;
  final String bereich; // 'imkerei', 'standbau', 'honigverarbeitung'
  final bool isConsumable;
  final bool archiviert; // ausgemustert/verkauft — nicht in aktiven Ansichten
  final double stockQty;
  final double minQty;
  final List<String> photoUrls; // Produktfotos (max 4, App-seitig begrenzt)
  final List<String> pdfUrls; // PDF-Anleitungen/Manuals (max 4)
  final List<String> pdfNames; // Anzeigenamen zu pdfUrls (parallel)

  const MaterialItem({
    required this.id,
    required this.category,
    required this.name,
    this.description,
    this.quantity = 1,
    this.unit,
    this.priceCHF,
    this.supplier,
    this.supplierUrl,
    this.phase = 1,
    this.status = 'geplant',
    this.notes,
    this.sortOrder = 0,
    this.bereich = 'imkerei',
    this.isConsumable = false,
    this.archiviert = false,
    this.stockQty = 0,
    this.minQty = 0,
    this.photoUrls = const [],
    this.pdfUrls = const [],
    this.pdfNames = const [],
  });

  MaterialItem copyWith({
    String? id,
    String? category,
    String? name,
    String? description,
    int? quantity,
    String? unit,
    double? priceCHF,
    String? supplier,
    String? supplierUrl,
    int? phase,
    String? status,
    String? notes,
    int? sortOrder,
    String? bereich,
    bool? isConsumable,
    bool? archiviert,
    double? stockQty,
    double? minQty,
    List<String>? photoUrls,
    List<String>? pdfUrls,
    List<String>? pdfNames,
  }) {
    return MaterialItem(
      id: id ?? this.id,
      category: category ?? this.category,
      name: name ?? this.name,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      priceCHF: priceCHF ?? this.priceCHF,
      supplier: supplier ?? this.supplier,
      supplierUrl: supplierUrl ?? this.supplierUrl,
      phase: phase ?? this.phase,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      sortOrder: sortOrder ?? this.sortOrder,
      bereich: bereich ?? this.bereich,
      isConsumable: isConsumable ?? this.isConsumable,
      archiviert: archiviert ?? this.archiviert,
      stockQty: stockQty ?? this.stockQty,
      minQty: minQty ?? this.minQty,
      photoUrls: photoUrls ?? this.photoUrls,
      pdfUrls: pdfUrls ?? this.pdfUrls,
      pdfNames: pdfNames ?? this.pdfNames,
    );
  }

  static List<String> _strList(dynamic v) =>
      (v as List?)?.map((e) => e.toString()).toList() ?? const [];

  factory MaterialItem.fromJson(Map<String, dynamic> json) {
    return MaterialItem(
      id: json['id'] as String,
      category: json['category'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      quantity: json['quantity'] as int? ?? 1,
      unit: json['unit'] as String?,
      priceCHF: (json['price_chf'] as num?)?.toDouble(),
      supplier: json['supplier'] as String?,
      supplierUrl: json['supplier_url'] as String?,
      phase: json['phase'] as int? ?? 1,
      status: json['status'] as String? ?? 'geplant',
      notes: json['notes'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      bereich: json['bereich'] as String? ?? 'imkerei',
      isConsumable: json['is_consumable'] as bool? ?? false,
      archiviert: json['archiviert'] as bool? ?? false,
      stockQty: (json['stock_qty'] as num?)?.toDouble() ?? 0,
      minQty: (json['min_qty'] as num?)?.toDouble() ?? 0,
      photoUrls: _strList(json['photo_urls']),
      pdfUrls: _strList(json['pdf_urls']),
      pdfNames: _strList(json['pdf_names']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'name': name,
      'description': description,
      'quantity': quantity,
      'unit': unit,
      'price_chf': priceCHF,
      'supplier': supplier,
      'supplier_url': supplierUrl,
      'phase': phase,
      'status': status,
      'notes': notes,
      'sort_order': sortOrder,
      'bereich': bereich,
      'is_consumable': isConsumable,
      'archiviert': archiviert,
      'stock_qty': stockQty,
      'min_qty': minQty,
      'photo_urls': photoUrls,
      'pdf_urls': pdfUrls,
      'pdf_names': pdfNames,
    };
  }

  double get totalPrice => (priceCHF ?? 0) * quantity;
}
