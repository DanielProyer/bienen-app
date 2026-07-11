class Scale {
  final String id;
  final String hiveName;
  final String vendor;
  final String? location;
  final DateTime? installedAt;
  final double alertSwarmThreshold;
  final bool alertEnabled;
  final Map<String, dynamic>? apiConfig;
  final DateTime? createdAt;

  const Scale({
    required this.id,
    required this.hiveName,
    required this.vendor,
    this.location,
    this.installedAt,
    this.alertSwarmThreshold = -1.0,
    this.alertEnabled = true,
    this.apiConfig,
    this.createdAt,
  });

  Scale copyWith({
    String? id,
    String? hiveName,
    String? vendor,
    String? location,
    DateTime? installedAt,
    double? alertSwarmThreshold,
    bool? alertEnabled,
    Map<String, dynamic>? apiConfig,
  }) {
    return Scale(
      id: id ?? this.id,
      hiveName: hiveName ?? this.hiveName,
      vendor: vendor ?? this.vendor,
      location: location ?? this.location,
      installedAt: installedAt ?? this.installedAt,
      alertSwarmThreshold: alertSwarmThreshold ?? this.alertSwarmThreshold,
      alertEnabled: alertEnabled ?? this.alertEnabled,
      apiConfig: apiConfig ?? this.apiConfig,
      createdAt: createdAt,
    );
  }

  factory Scale.fromJson(Map<String, dynamic> json) {
    return Scale(
      id: json['id'] as String,
      hiveName: json['hive_name'] as String,
      vendor: json['vendor'] as String,
      location: json['location'] as String?,
      installedAt: json['installed_at'] != null
          ? DateTime.parse(json['installed_at'] as String)
          : null,
      alertSwarmThreshold:
          (json['alert_swarm_threshold'] as num?)?.toDouble() ?? -1.0,
      alertEnabled: json['alert_enabled'] as bool? ?? true,
      apiConfig: json['api_config'] as Map<String, dynamic>?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hive_name': hiveName,
      'vendor': vendor,
      'location': location,
      'installed_at': installedAt?.toIso8601String(),
      'alert_swarm_threshold': alertSwarmThreshold,
      'alert_enabled': alertEnabled,
      'api_config': apiConfig,
    };
  }
}
