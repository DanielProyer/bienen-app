import 'package:bienen_app/features/monitoring/data/models/weight_reading.dart';

/// Vendor-agnostic interface for fetching scale readings.
/// Implementations will be added once API access is confirmed
/// (HiveWatch or BroodMinder).
abstract class ScaleApiService {
  Future<List<WeightReading>> fetchReadings({
    required String scaleId,
    required DateTime since,
  });

  Future<bool> testConnection();
}

/// Placeholder for HiveWatch API integration.
/// Pending: Contact support@hivewatch.ch for API documentation.
class HiveWatchApiService implements ScaleApiService {
  final String apiKey;
  final String baseUrl;

  HiveWatchApiService({
    required this.apiKey,
    this.baseUrl = 'https://api.hivewatch.ch', // TBD
  });

  @override
  Future<List<WeightReading>> fetchReadings({
    required String scaleId,
    required DateTime since,
  }) async {
    // TODO: Implement once API docs are available
    throw UnimplementedError('HiveWatch API integration pending');
  }

  @override
  Future<bool> testConnection() async => false;
}

/// Placeholder for BroodMinder API integration.
/// Pending: Contact support@broodminder.com for API documentation.
class BroodMinderApiService implements ScaleApiService {
  final String token;
  final String baseUrl;

  BroodMinderApiService({
    required this.token,
    this.baseUrl = 'https://mybroodminder.com/api',
  });

  @override
  Future<List<WeightReading>> fetchReadings({
    required String scaleId,
    required DateTime since,
  }) async {
    // TODO: Implement once API access is confirmed
    throw UnimplementedError('BroodMinder API integration pending');
  }

  @override
  Future<bool> testConnection() async => false;
}
