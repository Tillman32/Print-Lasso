import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/service/print_lasso_api_client.dart';
import '../../core/service/print_lasso_models.dart';
import '../../core/service/service_config.dart';
import '../../core/widgets/app_drawer.dart';
import '../printers/printers.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.activeService,
    this.apiClientFactory,
  });

  final ServiceConfig? activeService;
  final PrintLassoApiClient Function(String baseApiUrl)? apiClientFactory;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  PrintLassoApiClient? _apiClient;
  List<DiscoveredPrinter> _discoveredPrinters = <DiscoveredPrinter>[];
  List<PrinterRecord> _addedPrinters = <PrinterRecord>[];
  final Set<String> _addingSerialNumbers = <String>{};
  String? _errorMessage;
  bool _isDiscovering = false;
  bool _isLoadingAdded = false;

  @override
  void initState() {
    super.initState();
    final ServiceConfig? activeService = widget.activeService;
    if (activeService != null) {
      _apiClient =
          widget.apiClientFactory?.call(activeService.baseApiUrl) ??
          PrintLassoApiClient(
            baseApiUrl: activeService.baseApiUrl,
            timeout: const Duration(seconds: 30),
          );
      _loadAddedPrinters();
    }
  }

  @override
  void dispose() {
    _apiClient?.dispose();
    super.dispose();
  }

  bool _isAdded(String serialNumber) {
    return _addedPrinters.any(
      (PrinterRecord printer) => printer.serialNumber == serialNumber,
    );
  }

  Future<void> _discoverPrinters() async {
    final PrintLassoApiClient? apiClient = _apiClient;
    if (apiClient == null) {
      return;
    }

    setState(() {
      _isDiscovering = true;
      _errorMessage = null;
    });

    try {
      final DiscoverResponse response = await apiClient.discoverPrinters();
      if (!mounted) {
        return;
      }
      setState(() {
        _discoveredPrinters = response.printers;
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
          _isDiscovering = false;
        });
      }
    }
  }

  Future<void> _loadAddedPrinters() async {
    final PrintLassoApiClient? apiClient = _apiClient;
    if (apiClient == null) {
      return;
    }

    setState(() {
      _isLoadingAdded = true;
      _errorMessage = null;
    });

    try {
      final List<PrinterRecord> printers = await apiClient.listPrinters();
      printers.sort((PrinterRecord a, PrinterRecord b) {
        return '${a.name} ${a.serialNumber}'.toLowerCase().compareTo(
          '${b.name} ${b.serialNumber}'.toLowerCase(),
        );
      });
      if (!mounted) {
        return;
      }
      setState(() {
        _addedPrinters = printers;
      });
    } on PrintLassoApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _addedPrinters = <PrinterRecord>[];
        _errorMessage = error.statusCode == 404
            ? 'This service does not support printer listing yet. Update the Print Lasso service to use Refresh Added.'
            : error.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingAdded = false;
        });
      }
    }
  }

  Future<void> _addPrinter(DiscoveredPrinter printer) async {
    final PrintLassoApiClient? apiClient = _apiClient;
    if (apiClient == null) {
      return;
    }

    setState(() {
      _addingSerialNumbers.add(printer.serialNumber);
      _errorMessage = null;
    });

    try {
      final PrinterRecord created = await apiClient.addPrinter(
        AddPrinterRequest(
          serialNumber: printer.serialNumber,
          name: printer.name.isEmpty ? printer.serialNumber : printer.name,
          model: printer.model.isEmpty ? null : printer.model,
          ipAddress: printer.ipAddress.isEmpty ? null : printer.ipAddress,
          port: printer.port ?? 0,
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _addedPrinters =
            <PrinterRecord>[
              ..._addedPrinters.where(
                (PrinterRecord item) =>
                    item.serialNumber != created.serialNumber,
              ),
              created,
            ]..sort((PrinterRecord a, PrinterRecord b) {
              return '${a.name} ${a.serialNumber}'.toLowerCase().compareTo(
                '${b.name} ${b.serialNumber}'.toLowerCase(),
              );
            });
      });
    } on PrintLassoApiException catch (error) {
      if (error.statusCode == 409) {
        await _loadAddedPrinters();
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _addingSerialNumbers.remove(printer.serialNumber);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ServiceConfig? activeService = widget.activeService;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      drawer: AppDrawer(
        onHome: () => Navigator.of(
          context,
        ).popUntil((Route<dynamic> route) => route.isFirst),
        onPrinters: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext context) =>
                  PrintersPage(activeService: activeService),
            ),
          );
        },
      ),
      body: ListView(
        padding: const EdgeInsets.all(Constants.defaultPadding),
        children: <Widget>[
          const Text(
            'Printers',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          if (_errorMessage != null) ...<Widget>[
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
          ],
          if (activeService == null)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(Constants.defaultPadding),
                child: Text(
                  'Connect to a Print Lasso service from Home to manage printers.',
                ),
              ),
            )
          else ...<Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Constants.defaultPadding),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    ElevatedButton(
                      onPressed: _isDiscovering ? null : _discoverPrinters,
                      child: _isDiscovering
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Discover Printers'),
                    ),
                    OutlinedButton(
                      onPressed: _isLoadingAdded ? null : _loadAddedPrinters,
                      child: _isLoadingAdded
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Refresh Added'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _DiscoveredPrintersSection(
              printers: _discoveredPrinters,
              addingSerialNumbers: _addingSerialNumbers,
              isPrinterAdded: _isAdded,
              onAdd: _addPrinter,
            ),
            const SizedBox(height: 16),
            _AddedPrintersSection(
              printers: _addedPrinters,
              isLoading: _isLoadingAdded,
            ),
          ],
        ],
      ),
    );
  }
}

class _DiscoveredPrintersSection extends StatelessWidget {
  const _DiscoveredPrintersSection({
    required this.printers,
    required this.addingSerialNumbers,
    required this.isPrinterAdded,
    required this.onAdd,
  });

  final List<DiscoveredPrinter> printers;
  final Set<String> addingSerialNumbers;
  final bool Function(String serialNumber) isPrinterAdded;
  final Future<void> Function(DiscoveredPrinter printer) onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Constants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Discovered Printers',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (printers.isEmpty)
              const Text('No printers discovered yet.')
            else
              ...printers.map((DiscoveredPrinter printer) {
                final bool isAdded = isPrinterAdded(printer.serialNumber);
                final bool isAdding = addingSerialNumbers.contains(
                  printer.serialNumber,
                );

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.print),
                  title: Text(
                    printer.name.isEmpty ? printer.serialNumber : printer.name,
                  ),
                  subtitle: Text(
                    'SN: ${printer.serialNumber}\n'
                    'Model: ${printer.model.isEmpty ? '-' : printer.model}\n'
                    'IP: ${printer.ipAddress}  Port: ${printer.port ?? 0}',
                  ),
                  isThreeLine: true,
                  trailing: isAdded
                      ? const Chip(label: Text('Added'))
                      : ElevatedButton(
                          onPressed: isAdding ? null : () => onAdd(printer),
                          child: isAdding
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Add'),
                        ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _AddedPrintersSection extends StatelessWidget {
  const _AddedPrintersSection({
    required this.printers,
    required this.isLoading,
  });

  final List<PrinterRecord> printers;
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
              'Added Printers',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (printers.isEmpty)
              const Text('No printers have been added yet.')
            else
              ...printers.map(
                (PrinterRecord printer) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: Text(printer.name),
                  subtitle: Text(
                    'SN: ${printer.serialNumber}\n'
                    'Model: ${printer.model ?? '-'}\n'
                    'IP: ${printer.ipAddress ?? '-'}  Port: ${printer.port}',
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
