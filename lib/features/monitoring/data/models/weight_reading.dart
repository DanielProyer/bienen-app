class WeightReading {
  final String id;
  final String scaleId;
  final String hiveName;
  final double weightKg;
  final double? weightDeltaKg;
  final double? temperatureC;
  final double? humidityPct;
  final int? batteryPct;
  final DateTime recordedAt;
  final DateTime? syncedAt;
  final String source;

  const WeightReading({
    required this.id,
    required this.scaleId,
    required this.hiveName,
    required this.weightKg,
    this.weightDeltaKg,
    this.temperatureC,
    this.humidityPct,
    this.batteryPct,
    required this.recordedAt,
    this.syncedAt,
    this.source = 'api',
  });

  factory WeightReading.fromJson(Map<String, dynamic> json) {
    return WeightReading(
      id: json['id'] as String,
      scaleId: json['scale_id'] as String,
      hiveName: json['hive_name'] as String,
      weightKg: (json['weight_kg'] as num).toDouble(),
      weightDeltaKg: (json['weight_delta_kg'] as num?)?.toDouble(),
      temperatureC: (json['temperature_c'] as num?)?.toDouble(),
      humidityPct: (json['humidity_pct'] as num?)?.toDouble(),
      batteryPct: json['battery_pct'] as int?,
      recordedAt: DateTime.parse(json['recorded_at'] as String),
      syncedAt: json['synced_at'] != null
          ? DateTime.parse(json['synced_at'] as String)
          : null,
      source: json['source'] as String? ?? 'api',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'scale_id': scaleId,
      'hive_name': hiveName,
      'weight_kg': weightKg,
      'weight_delta_kg': weightDeltaKg,
      'temperature_c': temperatureC,
      'humidity_pct': humidityPct,
      'battery_pct': batteryPct,
      'recorded_at': recordedAt.toIso8601String(),
      'synced_at': syncedAt?.toIso8601String(),
      'source': source,
    };
  }
}
