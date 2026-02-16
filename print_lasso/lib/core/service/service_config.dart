import 'service_candidate.dart';

class ServiceConfig {
  const ServiceConfig({
    required this.instanceName,
    required this.host,
    required this.port,
    required this.apiPath,
    required this.baseApiUrl,
    required this.lastSeenAt,
  });

  final String instanceName;
  final String host;
  final int port;
  final String apiPath;
  final String baseApiUrl;
  final DateTime lastSeenAt;

  ServiceCandidate toCandidate() {
    return ServiceCandidate(
      instanceName: instanceName,
      host: host,
      port: port,
      apiPath: apiPath,
      baseApiUrl: baseApiUrl,
    );
  }

  factory ServiceConfig.fromCandidate(ServiceCandidate candidate) {
    return ServiceConfig(
      instanceName: candidate.instanceName,
      host: candidate.host,
      port: candidate.port,
      apiPath: candidate.apiPath,
      baseApiUrl: candidate.baseApiUrl,
      lastSeenAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'instance_name': instanceName,
      'host': host,
      'port': port,
      'api_path': apiPath,
      'base_api_url': baseApiUrl,
      'last_seen_at': lastSeenAt.toIso8601String(),
    };
  }

  factory ServiceConfig.fromJson(Map<String, dynamic> json) {
    return ServiceConfig(
      instanceName: json['instance_name'] as String? ?? '',
      host: json['host'] as String? ?? '',
      port: json['port'] as int? ?? 0,
      apiPath: json['api_path'] as String? ?? '/api/v1',
      baseApiUrl: json['base_api_url'] as String? ?? '',
      lastSeenAt:
          DateTime.tryParse(json['last_seen_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
