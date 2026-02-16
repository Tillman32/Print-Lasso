import 'dart:async';
import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:multicast_dns/multicast_dns.dart';

import '../constants.dart';
import 'service_candidate.dart';

class ServiceDiscoveryClient {
  const ServiceDiscoveryClient();

  static const int _defaultServicePort = 9000;
  static const int _maxProbeConcurrency = 32;
  static const List<String> _defaultProbeSubnets = <String>[
    '192.168.1',
    '192.168.0',
    '10.0.0',
    '10.0.1',
    '10.1.1',
  ];
  static const List<int> _priorityProbeHosts = <int>[
    50,
    100,
    10,
    20,
    30,
    40,
    60,
    70,
    80,
    90,
    110,
    120,
    130,
    140,
    150,
    160,
    170,
    180,
    190,
    200,
    210,
    220,
    230,
    240,
    250,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    1,
  ];

  Future<List<ServiceCandidate>> discover({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final Map<String, ServiceCandidate> discovered =
        <String, ServiceCandidate>{};

    final List<ServiceCandidate> mdnsCandidates = await _discoverViaMdns(
      timeout: timeout,
    );
    _mergeCandidates(discovered, mdnsCandidates);
    if (discovered.isNotEmpty) {
      return _sortedCandidates(discovered.values);
    }

    final List<ServiceCandidate> probeCandidates = await _discoverViaProbing(
      timeout: timeout,
    );
    _mergeCandidates(discovered, probeCandidates);

    return _sortedCandidates(discovered.values);
  }

  Future<List<ServiceCandidate>> _discoverViaMdns({
    required Duration timeout,
  }) async {
    final MDnsClient client = MDnsClient();
    final Map<String, ServiceCandidate> discovered =
        <String, ServiceCandidate>{};

    try {
      await client.start();
    } on Object {
      return const <ServiceCandidate>[];
    }

    try {
      final Set<String> serviceTypes = <String>{
        Constants.mdnsServiceType,
        Constants.mdnsServiceTypeNoTrailingDot,
      };

      for (final String serviceType in serviceTypes) {
        final List<PtrResourceRecord> pointerRecords =
            await _safeLookupRecords<PtrResourceRecord>(
              client.lookup<PtrResourceRecord>(
                ResourceRecordQuery.serverPointer(serviceType),
              ),
              timeout,
            );
        if (pointerRecords.isEmpty) {
          continue;
        }

        for (final PtrResourceRecord pointerRecord in pointerRecords) {
          final String serviceDomain = pointerRecord.domainName;
          final List<SrvResourceRecord> srvRecords =
              await _safeLookupRecords<SrvResourceRecord>(
                client.lookup<SrvResourceRecord>(
                  ResourceRecordQuery.service(serviceDomain),
                ),
                timeout,
              );
          if (srvRecords.isEmpty) {
            continue;
          }

          final List<TxtResourceRecord> txtRecords =
              await _safeLookupRecords<TxtResourceRecord>(
                client.lookup<TxtResourceRecord>(
                  ResourceRecordQuery.text(serviceDomain),
                ),
                timeout,
              );
          final Map<String, String> metadata = _parseTxtRecords(txtRecords);
          final String apiPath = _normalizeApiPath(
            metadata['api_path'] ?? Constants.defaultApiPath,
          );
          final String instanceName = _instanceNameFromDomain(serviceDomain);

          for (final SrvResourceRecord srvRecord in srvRecords) {
            final List<IPAddressResourceRecord> ipRecords =
                await _safeLookupRecords<IPAddressResourceRecord>(
                  client.lookup<IPAddressResourceRecord>(
                    ResourceRecordQuery.addressIPv4(srvRecord.target),
                  ),
                  timeout,
                );
            if (ipRecords.isEmpty) {
              continue;
            }

            for (final IPAddressResourceRecord ipRecord in ipRecords) {
              final String host = ipRecord.address.address;
              if (host.isEmpty || host == '127.0.0.1') {
                continue;
              }

              final Uri baseUri = Uri(
                scheme: 'http',
                host: host,
                port: srvRecord.port,
                path: apiPath,
              );
              final ServiceCandidate candidate = ServiceCandidate(
                instanceName: instanceName,
                host: host,
                port: srvRecord.port,
                apiPath: apiPath,
                baseApiUrl: baseUri.toString(),
                metadata: metadata,
              );
              discovered[_candidateKey(candidate)] = candidate;
            }
          }
        }
      }
    } finally {
      client.stop();
    }

    return _sortedCandidates(discovered.values);
  }

  Future<List<ServiceCandidate>> _discoverViaProbing({
    required Duration timeout,
  }) async {
    final Duration requestTimeout = _probeTimeout(timeout);
    final Queue<_ProbeTarget> queue = Queue<_ProbeTarget>()
      ..addAll(_buildProbeTargets());
    final Map<String, ServiceCandidate> discovered =
        <String, ServiceCandidate>{};
    final Dio dio = Dio(
      BaseOptions(
        connectTimeout: requestTimeout,
        receiveTimeout: requestTimeout,
        responseType: ResponseType.json,
      ),
    );

    try {
      Future<void> worker() async {
        while (queue.isNotEmpty) {
          if (discovered.isNotEmpty) {
            return;
          }

          final _ProbeTarget target = queue.removeFirst();
          final ServiceCandidate? candidate = await _probeService(
            dio: dio,
            target: target,
          );
          if (candidate != null) {
            discovered[_candidateKey(candidate)] = candidate;
          }
        }
      }

      final int workerCount = queue.length < _maxProbeConcurrency
          ? queue.length
          : _maxProbeConcurrency;
      if (workerCount == 0) {
        return const <ServiceCandidate>[];
      }

      await Future.wait(
        List<Future<void>>.generate(workerCount, (_) => worker()),
      );
      return _sortedCandidates(discovered.values);
    } finally {
      dio.close(force: true);
    }
  }

  Future<ServiceCandidate?> _probeService({
    required Dio dio,
    required _ProbeTarget target,
  }) async {
    final Uri statusUri = Uri(
      scheme: 'http',
      host: target.host,
      port: target.port,
      path: '${Constants.defaultApiPath}/status',
    );

    try {
      final Response<dynamic> response = await dio.getUri<dynamic>(statusUri);
      if (response.statusCode != 200) {
        return null;
      }

      final Map<String, dynamic>? payload = _asJsonMap(response.data);
      final String? status = payload?['status'] as String?;
      if (status == null || status.toLowerCase() != 'ok') {
        return null;
      }

      final Uri baseUri = Uri(
        scheme: 'http',
        host: target.host,
        port: target.port,
        path: Constants.defaultApiPath,
      );
      return ServiceCandidate(
        instanceName: 'Print Lasso Service (${target.host})',
        host: target.host,
        port: target.port,
        apiPath: Constants.defaultApiPath,
        baseApiUrl: baseUri.toString(),
        metadata: const <String, String>{'discovery': 'probe'},
      );
    } on Object {
      return null;
    }
  }

  List<_ProbeTarget> _buildProbeTargets() {
    final List<String> subnets = _buildProbeSubnets();
    final List<int> expandedHosts = _expandedProbeHosts();
    final List<_ProbeTarget> targets = <_ProbeTarget>[];

    for (int subnetIndex = 0; subnetIndex < subnets.length; subnetIndex++) {
      final List<int> hosts = subnetIndex == 0
          ? expandedHosts
          : _priorityProbeHosts;
      for (final int host in hosts) {
        targets.add(
          _ProbeTarget('${subnets[subnetIndex]}.$host', _defaultServicePort),
        );
      }
    }

    return targets;
  }

  List<String> _buildProbeSubnets() {
    final LinkedHashSet<String> subnets = LinkedHashSet<String>();
    final String? runtimeSubnet = _extractRuntimeSubnet(Uri.base.host);
    if (runtimeSubnet != null) {
      subnets.add(runtimeSubnet);
    }
    subnets.addAll(_defaultProbeSubnets);
    return subnets.toList(growable: false);
  }

  String? _extractRuntimeSubnet(String host) {
    final RegExp ipv4Pattern = RegExp(
      r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$',
    );
    final RegExpMatch? match = ipv4Pattern.firstMatch(host);
    if (match == null) {
      return null;
    }

    final List<int> octets = List<int>.generate(
      4,
      (int index) => int.tryParse(match.group(index + 1) ?? '') ?? -1,
    );
    if (octets.any((int value) => value < 0 || value > 255)) {
      return null;
    }

    final int first = octets[0];
    final int second = octets[1];
    final int third = octets[2];

    if (first == 10) {
      return '$first.$second.$third';
    }
    if (first == 192 && second == 168) {
      return '$first.$second.$third';
    }
    if (first == 172 && second >= 16 && second <= 31) {
      return '$first.$second.$third';
    }
    return null;
  }

  List<int> _expandedProbeHosts() {
    final LinkedHashSet<int> ordered = LinkedHashSet<int>()
      ..addAll(_priorityProbeHosts);
    for (int host = 1; host <= 254; host++) {
      ordered.add(host);
    }
    return ordered.toList(growable: false);
  }

  Duration _probeTimeout(Duration requestedTimeout) {
    final int ms = requestedTimeout.inMilliseconds;
    final int normalizedMs;
    if (ms < 600) {
      normalizedMs = 600;
    } else if (ms > 1500) {
      normalizedMs = 1500;
    } else {
      normalizedMs = ms;
    }
    return Duration(milliseconds: normalizedMs);
  }

  List<ServiceCandidate> _sortedCandidates(
    Iterable<ServiceCandidate> candidates,
  ) {
    final List<ServiceCandidate> sorted = candidates.toList()
      ..sort(
        (ServiceCandidate a, ServiceCandidate b) => a.instanceName
            .toLowerCase()
            .compareTo(b.instanceName.toLowerCase()),
      );
    return sorted;
  }

  void _mergeCandidates(
    Map<String, ServiceCandidate> into,
    Iterable<ServiceCandidate> from,
  ) {
    for (final ServiceCandidate candidate in from) {
      into[_candidateKey(candidate)] = candidate;
    }
  }

  String _candidateKey(ServiceCandidate candidate) {
    return '${candidate.host}:${candidate.port}${candidate.apiPath}';
  }

  String _normalizeApiPath(String value) {
    if (value.isEmpty) {
      return Constants.defaultApiPath;
    }

    final String withLeadingSlash = value.startsWith('/') ? value : '/$value';
    return withLeadingSlash.endsWith('/')
        ? withLeadingSlash.substring(0, withLeadingSlash.length - 1)
        : withLeadingSlash;
  }

  String _instanceNameFromDomain(String serviceDomain) {
    String normalized = serviceDomain;
    if (normalized.endsWith('.')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    final String suffix = '.${Constants.mdnsServiceTypeNoTrailingDot}';
    if (normalized.endsWith(suffix)) {
      return normalized.substring(0, normalized.length - suffix.length);
    }
    return normalized;
  }

  Map<String, String> _parseTxtRecords(List<TxtResourceRecord> txtRecords) {
    final Map<String, String> metadata = <String, String>{};
    for (final TxtResourceRecord txtRecord in txtRecords) {
      final List<String> keyValuePairs = txtRecord.text.split('\u0000');
      for (final String pair in keyValuePairs) {
        final int delimiter = pair.indexOf('=');
        if (delimiter <= 0) {
          continue;
        }
        final String key = pair.substring(0, delimiter).trim().toLowerCase();
        final String value = pair.substring(delimiter + 1).trim();
        metadata[key] = value;
      }
    }
    return metadata;
  }

  Map<String, dynamic>? _asJsonMap(Object? data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return data.cast<String, dynamic>();
    }
    return null;
  }

  Future<List<T>> _safeLookupRecords<T>(
    Stream<T> stream,
    Duration timeout,
  ) async {
    try {
      return await stream
          .timeout(
            timeout,
            onTimeout: (EventSink<T> sink) {
              sink.close();
            },
          )
          .toList();
    } on Object {
      return <T>[];
    }
  }
}

class _ProbeTarget {
  const _ProbeTarget(this.host, this.port);

  final String host;
  final int port;
}
