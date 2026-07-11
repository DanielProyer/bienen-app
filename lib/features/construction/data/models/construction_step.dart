class ConstructionStep {
  final String id;
  final String phase;
  final String fotoCode;
  final String title;
  final String? soll;
  final int sortOrder;
  final bool isDone;
  final String? note;
  final String? photoUrl;
  final DateTime? photoTakenAt;

  const ConstructionStep({
    required this.id,
    required this.phase,
    required this.fotoCode,
    required this.title,
    this.soll,
    this.sortOrder = 0,
    this.isDone = false,
    this.note,
    this.photoUrl,
    this.photoTakenAt,
  });

  ConstructionStep copyWith({
    String? id,
    String? phase,
    String? fotoCode,
    String? title,
    String? soll,
    int? sortOrder,
    bool? isDone,
    String? note,
    String? photoUrl,
    DateTime? photoTakenAt,
  }) {
    return ConstructionStep(
      id: id ?? this.id,
      phase: phase ?? this.phase,
      fotoCode: fotoCode ?? this.fotoCode,
      title: title ?? this.title,
      soll: soll ?? this.soll,
      sortOrder: sortOrder ?? this.sortOrder,
      isDone: isDone ?? this.isDone,
      note: note ?? this.note,
      photoUrl: photoUrl ?? this.photoUrl,
      photoTakenAt: photoTakenAt ?? this.photoTakenAt,
    );
  }

  factory ConstructionStep.fromJson(Map<String, dynamic> json) {
    return ConstructionStep(
      id: json['id'] as String,
      phase: json['phase'] as String,
      fotoCode: json['foto_code'] as String,
      title: json['title'] as String,
      soll: json['soll'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isDone: json['is_done'] as bool? ?? false,
      note: json['note'] as String?,
      photoUrl: json['photo_url'] as String?,
      photoTakenAt: json['photo_taken_at'] != null
          ? DateTime.parse(json['photo_taken_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phase': phase,
      'foto_code': fotoCode,
      'title': title,
      'soll': soll,
      'sort_order': sortOrder,
      'is_done': isDone,
      'note': note,
      'photo_url': photoUrl,
      'photo_taken_at': photoTakenAt?.toIso8601String(),
    };
  }
}
