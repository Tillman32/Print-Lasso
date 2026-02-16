import 'dart:async';

import 'package:multicast_dns/multicast_dns.dart';

import '../constants.dart';
import 'service_candidate.dart';

class ServiceDiscoveryClient {
  const ServiceDiscoveryClient();

  Future<List<ServiceCandidate>> discover({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final MDnsClient client = MDnsClient();
    final Map<String, ServiceCandidate> discovered =
        <String, ServiceCandidate>{};

    await client.start();
    try {
      final List<PtrResourceRecord> pointerRecords =
          await _lookupRecords<PtrResourceRecord>(
            client.lookup<PtrResourceRecord>(
              ResourceRecordQuery.serverPointer(Constants.mdnsServiceType),
            ),
            timeout,
          );

      for (final PtrResourceRecord pointerRecord in pointerRecords) {
        final String serviceDomain = pointerRecord.domainName;
        final List<SrvResourceRecord> srvRecords =
            await _lookupRecords<SrvResourceRecord>(
              client.lookup<SrvResourceRecord>(
                ResourceRecordQuery.service(serviceDomain),
              ),
              timeout,
            );
        final List<TxtResourceRecord> txtRecords =
            await _lookupRecords<TxtResourceRecord>(
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
              await _lookupRecords<IPAddressResourceRecord>(
                client.lookup<IPAddressResourceRecord>(
                  ResourceRecordQuery.addressIPv4(srvRecord.target),
                ),
                timeout,
              );

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
            final String key = '${baseUri.host}:${baseUri.port}${baseUri.path}';
            discovered[key] = ServiceCandidate(
              instanceName: instanceName,
              host: host,
              port: srvRecord.port,
              apiPath: apiPath,
              baseApiUrl: baseUri.toString(),
              metadata: metadata,
            );
          }
        }
      }
    } finally {
      client.stop();
    }

    final List<ServiceCandidate> results = discovered.values.toList()
      ..sort(
        (ServiceCandidate a, ServiceCandidate b) => a.instanceName
            .toLowerCase()
            .compareTo(b.instanceName.toLowerCase()),
      );
    return results;
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

  Future<List<T>> _lookupRecords<T>(Stream<T> stream, Duration timeout) async {
    return stream
        .timeout(
          timeout,
          onTimeout: (EventSink<T> sink) {
            sink.close();
          },
        )
        .toList();
  }
}
