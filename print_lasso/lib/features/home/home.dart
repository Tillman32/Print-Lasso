import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/service/print_lasso_api_client.dart';
import '../../core/service/print_lasso_models.dart';
import '../../core/service/service_candidate.dart';
import '../../core/service/service_config.dart';
import '../../core/service/service_config_repository.dart';
import '../../core/service/service_discovery_client.dart';
import '../../core/widgets/app_drawer.dart';
import '../settings/settings.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.discoveryClient = const ServiceDiscoveryClient(),
    this.configRepository = const ServiceConfigRepository(),
    this.autoInitialize = true,
  });

  final ServiceDiscoveryClient discoveryClient;
  final ServiceConfigRepository configRepository;
  final bool autoInitialize;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _manualAddressController =
      TextEditingController();

  PrintLassoApiClient? _apiClient;
  ServiceConfig? _activeService;
  List<ServiceCandidate> _discoveredServices = <ServiceCandidate>[];
  List<DiscoveredPrinter> _printers = <DiscoveredPrinter>[];
  String? _errorMessage;
  bool _isBootstrapping = true;
  bool _isDiscoveringServices = false;
  bool _isConnectingService = false;
  bool _isDiscoveringPrinters = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoInitialize) {
      _bootstrap();
    } else {
      _isBootstrapping = false;
    }
  }

  @override
  void dispose() {
    _manualAddressController.dispose();
    _apiClient?.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final ServiceConfig? savedConfig = await widget.configRepository.load();

    if (savedConfig != null) {
      final bool connected = await _connectToService(
        savedConfig.toCandidate(),
        persist: true,
        clearPrinters: false,
        showErrors: false,
      );

      if (!connected) {
        await widget.configRepository.clear();
      }
    }

    if (_activeService == null) {
      await _scanForServices();
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _isBootstrapping = false;
    });
  }

  Future<void> _scanForServices() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _isDiscoveringServices = true;
      _errorMessage = null;
      _discoveredServices = <ServiceCandidate>[];
    });

    try {
      final List<ServiceCandidate> candidates = await widget.discoveryClient
          .discover();
      final List<ServiceCandidate> healthyCandidates = <ServiceCandidate>[];

      for (final ServiceCandidate candidate in candidates) {
        final bool isHealthy = await _isHealthyService(candidate);
        if (isHealthy) {
          healthyCandidates.add(candidate);
        }
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _discoveredServices = healthyCandidates;
        if (healthyCandidates.isEmpty && _activeService == null) {
          _errorMessage =
              'No local Print Lasso services found. Try manual address.';
        }
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Failed to scan local network for services.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isDiscoveringServices = false;
        });
      }
    }
  }

  Future<bool> _isHealthyService(ServiceCandidate candidate) async {
    final PrintLassoApiClient probeClient = PrintLassoApiClient(
      baseApiUrl: candidate.baseApiUrl,
      timeout: const Duration(seconds: 2),
    );

    try {
      final ServiceStatus status = await probeClient.getStatus();
      return status.status.toLowerCase() == 'ok';
    } on PrintLassoApiException {
      return false;
    } finally {
      probeClient.dispose();
    }
  }

  Future<void> _connectManually() async {
    try {
      final ServiceCandidate candidate = _manualInputToCandidate(
        _manualAddressController.text,
      );
      await _connectToService(candidate);
    } on FormatException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
      });
    }
  }

  Future<bool> _connectToService(
    ServiceCandidate candidate, {
    bool persist = true,
    bool clearPrinters = true,
    bool showErrors = true,
  }) async {
    if (!mounted) {
      return false;
    }
    setState(() {
      _isConnectingService = true;
      _errorMessage = null;
    });

    final PrintLassoApiClient nextClient = PrintLassoApiClient(
      baseApiUrl: candidate.baseApiUrl,
      timeout: const Duration(seconds: 3),
    );

    try {
      final ServiceStatus status = await nextClient.getStatus();
      if (status.status.toLowerCase() != 'ok') {
        throw const PrintLassoApiException('Service health check failed');
      }

      _apiClient?.dispose();
      _apiClient = nextClient;

      final ServiceConfig config = ServiceConfig.fromCandidate(candidate);
      if (persist) {
        await widget.configRepository.save(config);
      }

      if (!mounted) {
        return true;
      }
      setState(() {
        _activeService = config;
        if (clearPrinters) {
          _printers = <DiscoveredPrinter>[];
        }
      });
      return true;
    } on PrintLassoApiException catch (error) {
      nextClient.dispose();
      if (!mounted) {
        return false;
      }
      if (showErrors) {
        setState(() {
          _errorMessage = error.message;
        });
      }
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isConnectingService = false;
        });
      }
    }
  }

  Future<void> _discoverPrintersFromService() async {
    final PrintLassoApiClient? apiClient = _apiClient;
    if (apiClient == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'No Print Lasso service is connected.';
      });
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _isDiscoveringPrinters = true;
      _errorMessage = null;
    });

    try {
      DiscoverResponse response = await apiClient.discoverPrinters();
      if (response.printers.isEmpty) {
        response = await apiClient.discoverPrinters(includeAll: true);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _printers = response.printers;
      });
    } on PrintLassoApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isDiscoveringPrinters = false;
        });
      }
    }
  }

  Future<void> _forgetService() async {
    _apiClient?.dispose();
    _apiClient = null;
    await widget.configRepository.clear();

    if (!mounted) {
      return;
    }
    setState(() {
      _activeService = null;
      _printers = <DiscoveredPrinter>[];
      _errorMessage = null;
    });
  }

  ServiceCandidate _manualInputToCandidate(String rawInput) {
    String value = rawInput.trim();
    if (value.isEmpty) {
      throw const FormatException('Enter a host or URL to connect manually.');
    }

    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'http://$value';
    }

    final Uri parsed = Uri.parse(value);
    if (parsed.host.isEmpty) {
      throw const FormatException('Manual address is invalid.');
    }

    final int resolvedPort = parsed.hasPort
        ? parsed.port
        : (parsed.scheme == 'https' ? 443 : 9000);
    final String apiPath = _normalizeApiPath(
      parsed.path.isEmpty || parsed.path == '/'
          ? Constants.defaultApiPath
          : parsed.path,
    );
    final Uri baseUri = Uri(
      scheme: parsed.scheme,
      host: parsed.host,
      port: resolvedPort,
      path: apiPath,
    );

    return ServiceCandidate(
      instanceName: 'Manual ${parsed.host}',
      host: parsed.host,
      port: resolvedPort,
      apiPath: apiPath,
      baseApiUrl: baseUri.toString(),
    );
  }

  String _normalizeApiPath(String path) {
    final String withLeadingSlash = path.startsWith('/') ? path : '/$path';
    final String normalized = withLeadingSlash.endsWith('/')
        ? withLeadingSlash.substring(0, withLeadingSlash.length - 1)
        : withLeadingSlash;
    return normalized.isEmpty ? Constants.defaultApiPath : normalized;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text(Constants.appTitle)),
      drawer: AppDrawer(
        onSettings: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext context) =>
                  SettingsPage(activeService: _activeService),
            ),
          );
        },
      ),
      body: _isBootstrapping
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(Constants.defaultPadding),
              children: <Widget>[
                if (_errorMessage != null) ...<Widget>[
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 12),
                ],
                _ConnectionCard(
                  activeService: _activeService,
                  isConnecting: _isConnectingService,
                  onScan: _isDiscoveringServices ? null : _scanForServices,
                  onForget: _activeService == null ? null : _forgetService,
                  onDiscoverPrinters:
                      _activeService == null || _isDiscoveringPrinters
                      ? null
                      : _discoverPrintersFromService,
                ),
                const SizedBox(height: 16),
                _ManualConnectCard(
                  controller: _manualAddressController,
                  onConnect: _isConnectingService ? null : _connectManually,
                ),
                const SizedBox(height: 16),
                _DiscoveredServicesCard(
                  services: _discoveredServices,
                  isDiscovering: _isDiscoveringServices,
                  onConnect: _isConnectingService ? null : _connectToService,
                ),
                const SizedBox(height: 16),
                _DiscoveredPrintersCard(
                  printers: _printers,
                  isLoading: _isDiscoveringPrinters,
                ),
              ],
            ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.activeService,
    required this.isConnecting,
    required this.onScan,
    required this.onForget,
    required this.onDiscoverPrinters,
  });

  final ServiceConfig? activeService;
  final bool isConnecting;
  final VoidCallback? onScan;
  final VoidCallback? onForget;
  final VoidCallback? onDiscoverPrinters;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Constants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Service Connection',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (activeService != null) ...<Widget>[
              Text(activeService!.instanceName),
              const SizedBox(height: 4),
              Text(activeService!.baseApiUrl),
              const SizedBox(height: 4),
              Text(
                'Last seen: ${activeService!.lastSeenAt.toLocal()}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else
              const Text('No saved service yet.'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                ElevatedButton(
                  onPressed: onScan,
                  child: const Text('Find Local Service'),
                ),
                ElevatedButton(
                  onPressed: onDiscoverPrinters,
                  child: isConnecting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Discover Printers'),
                ),
                OutlinedButton(
                  onPressed: onForget,
                  child: const Text('Forget Service'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualConnectCard extends StatelessWidget {
  const _ManualConnectCard({required this.controller, required this.onConnect});

  final TextEditingController controller;
  final VoidCallback? onConnect;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Constants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Manual Service Address',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText:
                    '192.168.1.10:9000 or http://192.168.1.10:9000/api/v1',
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: onConnect,
              child: const Text('Connect Manually'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoveredServicesCard extends StatelessWidget {
  const _DiscoveredServicesCard({
    required this.services,
    required this.isDiscovering,
    required this.onConnect,
  });

  final List<ServiceCandidate> services;
  final bool isDiscovering;
  final Future<void> Function(ServiceCandidate service)? onConnect;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Constants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Discovered Local Services',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (isDiscovering)
              const Center(child: CircularProgressIndicator())
            else if (services.isEmpty)
              const Text('No healthy services discovered yet.')
            else
              ...services.map(
                (ServiceCandidate service) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(service.instanceName),
                  subtitle: Text(
                    '${service.baseApiUrl}\n${service.host}:${service.port}',
                  ),
                  isThreeLine: true,
                  trailing: TextButton(
                    onPressed: onConnect == null
                        ? null
                        : () => onConnect!(service),
                    child: const Text('Connect'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DiscoveredPrintersCard extends StatelessWidget {
  const _DiscoveredPrintersCard({
    required this.printers,
    required this.isLoading,
  });

  final List<DiscoveredPrinter> printers;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Constants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Service Printer Discovery',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (printers.isEmpty)
              const Text('No printers discovered yet.')
            else
              ...printers.map(
                (DiscoveredPrinter printer) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.print),
                  title: Text(
                    printer.name.isEmpty ? printer.serialNumber : printer.name,
                  ),
                  subtitle: Text(
                    'SN: ${printer.serialNumber}\n'
                    'Model: ${printer.model.isEmpty ? "-" : printer.model}\n'
                    'IP: ${printer.ipAddress}  Port: ${printer.port ?? 0}',
                  ),
                  isThreeLine: true,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
