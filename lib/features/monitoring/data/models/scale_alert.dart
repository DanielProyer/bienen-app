class ScaleAlert {
  final String id;
  final String scaleId;
  final String alertType; // 'swarm', 'tracht_start', 'tracht_end', 'low_battery', 'offline'
  final String? message;
  final String? weightReadingId;
  final bool acknowledged;
  final DateTime createdAt;

  const ScaleAlert({
    required this.id,
    required this.scaleId,
    required this.alertType,
    this.message,
    this.weightReadingId,
    this.acknowledged = false,
    required this.createdAt,
  });

  factory ScaleAlert.fromJson(Map<String, dynamic> json) {
    return ScaleAlert(
      id: json['id'] as String,
      scaleId: json['scale_id'] as String,
      alertType: json['alert_type'] as String,
      message: json['message'] as String?,
      weightReadingId: json['weight_reading_id'] as String?,
      acknowledged: json['acknowledged'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'scale_id': scaleId,
      'alert_type': alertType,
      'message': message,
      'weight_reading_id': weightReadingId,
      'acknowledged': acknowledged,
    };
  }

  String get alertLabel {
    switch (alertType) {
      case 'swarm':
        return 'Schwarm-Warnung';
      case 'tracht_start':
        return 'Tracht-Beginn';
      case 'tracht_end':
        return 'Tracht-Ende';
      case 'low_battery':
        return 'Batterie schwach';
      case 'offline':
        return 'Waage offline';
      default:
        return alertType;
    }
  }
}
