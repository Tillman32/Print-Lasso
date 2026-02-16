class ServiceCandidate {
  const ServiceCandidate({
    required this.instanceName,
    required this.host,
    required this.port,
    required this.apiPath,
    required this.baseApiUrl,
    this.metadata = const {},
  });

  final String instanceName;
  final String host;
  final int port;
  final String apiPath;
  final String baseApiUrl;
  final Map<String, String> metadata;
}
