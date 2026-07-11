/// Fortschritt zu einem Bauschritt (Supabase). Die fachlichen Inhalte
/// (Titel, Anleitung, Zeichnungen, Soll) liegen statisch in
/// `build_step_content.dart` und werden über [stepKey] verbunden.
class ConstructionStep {
  final String stepKey;
  final bool isDone;
  final String? note;
  final String? photoUrl;
  final DateTime? photoTakenAt;
  final int sortOrder;

  const ConstructionStep({
    required this.stepKey,
    this.isDone = false,
    this.note,
    this.photoUrl,
    this.photoTakenAt,
    this.sortOrder = 0,
  });

  ConstructionStep copyWith({
    String? stepKey,
    bool? isDone,
    String? note,
    String? photoUrl,
    DateTime? photoTakenAt,
    int? sortOrder,
  }) {
    return ConstructionStep(
      stepKey: stepKey ?? this.stepKey,
      isDone: isDone ?? this.isDone,
      note: note ?? this.note,
      photoUrl: photoUrl ?? this.photoUrl,
      photoTakenAt: photoTakenAt ?? this.photoTakenAt,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  factory ConstructionStep.fromJson(Map<String, dynamic> json) {
    return ConstructionStep(
      stepKey: json['step_key'] as String,
      isDone: json['is_done'] as bool? ?? false,
      note: json['note'] as String?,
      photoUrl: json['photo_url'] as String?,
      photoTakenAt: json['photo_taken_at'] != null
          ? DateTime.parse(json['photo_taken_at'] as String)
          : null,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'step_key': stepKey,
      'is_done': isDone,
      'note': note,
      'photo_url': photoUrl,
      'photo_taken_at': photoTakenAt?.toIso8601String(),
      'sort_order': sortOrder,
    };
  }
}
