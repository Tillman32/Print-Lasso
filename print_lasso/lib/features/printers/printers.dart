import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/service/print_lasso_api_client.dart';
import '../../core/service/print_lasso_models.dart';
import '../../core/service/service_config.dart';
import '../../core/widgets/app_drawer.dart';
import '../settings/settings.dart';

class PrintersPage extends StatefulWidget {
  const PrintersPage({
    super.key,
    required this.activeService,
    this.apiClientFactory,
  });

  final ServiceConfig? activeService;
  final PrintLassoApiClient Function(String baseApiUrl)? apiClientFactory;

  @override
  State<PrintersPage> createState() => _PrintersPageState();
}

class _PrintersPageState extends State<PrintersPage> {
  PrintLassoApiClient? _apiClient;
  List<PrinterRecord> _addedPrinters = <PrinterRecord>[];
  String? _errorMessage;
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
            ? 'This service does not support printer listing yet. Update the Print Lasso service.'
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

  Future<void> _openPrinter(PrinterRecord printer) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => PrinterCameraPage(
          printer: printer,
          activeService: widget.activeService,
          apiClientFactory: widget.apiClientFactory,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ServiceConfig? activeService = widget.activeService;

    return Scaffold(
      appBar: AppBar(title: const Text('Printers')),
      drawer: AppDrawer(
        onHome: () => Navigator.of(
          context,
        ).popUntil((Route<dynamic> route) => route.isFirst),
        onSettings: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (BuildContext context) =>
                  SettingsPage(activeService: activeService),
            ),
          );
        },
      ),
      body: ListView(
        padding: const EdgeInsets.all(Constants.defaultPadding),
        children: <Widget>[
          if (_errorMessage != null) ...<Widget>[
            Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
          ],
          if (activeService == null)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(Constants.defaultPadding),
                child: Text(
                  'Connect to a Print Lasso service from Home to view added printers.',
                ),
              ),
            )
          else ...<Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Constants.defaultPadding),
                child: Row(
                  children: <Widget>[
                    ElevatedButton(
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
            Card(
              child: Padding(
                padding: const EdgeInsets.all(Constants.defaultPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Added Printers',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_isLoadingAdded)
                      const Center(child: CircularProgressIndicator())
                    else if (_addedPrinters.isEmpty)
                      const Text('No printers have been added yet.')
                    else
                      ..._addedPrinters.map(
                        (PrinterRecord printer) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                          ),
                          title: Text(printer.name),
                          subtitle: Text(
                            'SN: ${printer.serialNumber}\n'
                            'Model: ${printer.model ?? '-'}\n'
                            'IP: ${printer.ipAddress ?? '-'}  Port: ${printer.port}',
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openPrinter(printer),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class PrinterCameraPage extends StatefulWidget {
  const PrinterCameraPage({
    super.key,
    required this.printer,
    required this.activeService,
    this.apiClientFactory,
  });

  final PrinterRecord printer;
  final ServiceConfig? activeService;
  final PrintLassoApiClient Function(String baseApiUrl)? apiClientFactory;

  @override
  State<PrinterCameraPage> createState() => _PrinterCameraPageState();
}

class _PrinterCameraPageState extends State<PrinterCameraPage> {
  late PrinterRecord _printer;
  final TextEditingController _accessCodeController = TextEditingController();
  PrintLassoApiClient? _apiClient;
  bool _isStreaming = false;
  bool _isSaving = false;
  String? _settingsErrorMessage;
  String? _settingsSuccessMessage;

  @override
  void initState() {
    super.initState();
    _printer = widget.printer;

    final String? existingAccessCode = _extractBambuAccessCode(
      _printer.cameraUrl,
    );
    if (existingAccessCode != null) {
      _accessCodeController.text = existingAccessCode;
    }

    final ServiceConfig? activeService = widget.activeService;
    if (activeService != null) {
      _apiClient =
          widget.apiClientFactory?.call(activeService.baseApiUrl) ??
          PrintLassoApiClient(
            baseApiUrl: activeService.baseApiUrl,
            timeout: const Duration(seconds: 30),
          );
    }
  }

  @override
  void dispose() {
    _accessCodeController.dispose();
    _apiClient?.dispose();
    super.dispose();
  }

  String? _extractBambuAccessCode(String? cameraUrl) {
    if (cameraUrl == null || cameraUrl.isEmpty) {
      return null;
    }
    final Uri? parsed = Uri.tryParse(cameraUrl);
    if (parsed == null) {
      return null;
    }
    if (!(parsed.scheme == 'rtsp' || parsed.scheme == 'rtsps')) {
      return null;
    }
    final String userInfo = parsed.userInfo;
    if (!userInfo.startsWith('bblp:')) {
      return null;
    }
    final int separatorIndex = userInfo.indexOf(':');
    if (separatorIndex < 0 || separatorIndex + 1 >= userInfo.length) {
      return null;
    }
    return userInfo.substring(separatorIndex + 1);
  }

  String? get _cameraUrl {
    final String? generatedBambuUrl = _buildBambuRtspUrlFromInput();
    if (generatedBambuUrl != null) {
      return generatedBambuUrl;
    }

    if (_printer.cameraUrl != null && _printer.cameraUrl!.isNotEmpty) {
      return _printer.cameraUrl;
    }
    final String? ipAddress = _printer.ipAddress;
    if (ipAddress == null || ipAddress.isEmpty) {
      return null;
    }

    final int? port = _printer.port > 0 ? _printer.port : null;
    return Uri(
      scheme: 'http',
      host: ipAddress,
      port: port,
      path: '/webcam/?action=stream',
    ).toString();
  }

  String? _buildBambuRtspUrlFromInput() {
    final String accessCode = _accessCodeController.text.trim();
    final String? ipAddress = _printer.ipAddress?.trim();
    if (accessCode.isEmpty || ipAddress == null || ipAddress.isEmpty) {
      return null;
    }
    return Uri(
      scheme: 'rtsps',
      userInfo: 'bblp:$accessCode',
      host: ipAddress,
      port: 322,
      path: '/streaming/live/1',
    ).toString();
  }

  bool _isRtspUrl(String? url) {
    if (url == null || url.isEmpty) {
      return false;
    }
    final Uri? parsed = Uri.tryParse(url);
    if (parsed == null) {
      return false;
    }
    return parsed.scheme == 'rtsp' || parsed.scheme == 'rtsps';
  }

  String? _toGo2RtcMjpegUrl(String? sourceUrl) {
    if (sourceUrl == null || sourceUrl.isEmpty) {
      return null;
    }
    final String go2rtcBaseUrl = _go2rtcBaseUrl;
    if (go2rtcBaseUrl.isEmpty) {
      return null;
    }
    final Uri? baseUri = Uri.tryParse(go2rtcBaseUrl);
    if (baseUri == null ||
        !(baseUri.scheme == 'http' || baseUri.scheme == 'https')) {
      return null;
    }

    final String normalizedPath = baseUri.path.endsWith('/')
        ? baseUri.path.substring(0, baseUri.path.length - 1)
        : baseUri.path;
    return baseUri
        .replace(
          path: '$normalizedPath/api/stream.mjpeg',
          queryParameters: <String, String>{'src': sourceUrl},
        )
        .toString();
  }

  String get _go2rtcBaseUrl {
    final String configured = Constants.go2rtcBaseUrl.trim();
    if (configured.isNotEmpty) {
      return configured;
    }
    final String? host = widget.activeService?.host.trim();
    if (host != null && host.isNotEmpty) {
      return Uri(scheme: 'http', host: host, port: 1984).toString();
    }
    return '';
  }

  String? get _resolvedFeedUrl {
    final String? cameraUrl = _cameraUrl;
    if (!_isRtspUrl(cameraUrl)) {
      return cameraUrl;
    }
    return _toGo2RtcMjpegUrl(cameraUrl);
  }

  Future<void> _saveCameraSettings() async {
    final PrintLassoApiClient? apiClient = _apiClient;
    if (apiClient == null) {
      setState(() {
        _settingsErrorMessage = 'Connect to a Print Lasso service first.';
        _settingsSuccessMessage = null;
      });
      return;
    }

    final String? generatedBambuUrl = _buildBambuRtspUrlFromInput();
    if (generatedBambuUrl == null) {
      setState(() {
        _settingsErrorMessage =
            'Enter the printer access code to configure the camera.';
        _settingsSuccessMessage = null;
      });
      return;
    }
    if (_printer.ipAddress == null || _printer.ipAddress!.trim().isEmpty) {
      setState(() {
        _settingsErrorMessage =
            'Cannot configure camera because printer IP is missing.';
        _settingsSuccessMessage = null;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _settingsErrorMessage = null;
      _settingsSuccessMessage = null;
    });

    try {
      final PrinterRecord updated = await apiClient.editPrinter(
        UpdatePrinterRequest(
          serialNumber: _printer.serialNumber,
          cameraUrl: generatedBambuUrl,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _printer = updated;
        _settingsSuccessMessage = 'Camera settings saved.';
      });
    } on PrintLassoApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _settingsErrorMessage = error.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _toggleStreaming() {
    setState(() {
      _isStreaming = !_isStreaming;
    });
  }

  @override
  Widget build(BuildContext context) {
    final String? cameraUrl = _cameraUrl;
    final bool isRtspCameraUrl = _isRtspUrl(cameraUrl);
    final String? resolvedFeedUrl = _resolvedFeedUrl;
    final String relayBaseUrl = _go2rtcBaseUrl;

    return Scaffold(
      appBar: AppBar(title: Text(_printer.name)),
      body: ListView(
        padding: const EdgeInsets.all(Constants.defaultPadding),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Constants.defaultPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _printer.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('SN: ${_printer.serialNumber}'),
                  const SizedBox(height: 12),
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: DecoratedBox(
                        decoration: const BoxDecoration(color: Colors.black87),
                        child: _buildFeed(
                          cameraUrl: cameraUrl,
                          resolvedFeedUrl: resolvedFeedUrl,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _toggleStreaming,
                    icon: Icon(_isStreaming ? Icons.stop : Icons.play_arrow),
                    label: Text(_isStreaming ? 'Stop Feed' : 'Play Feed'),
                  ),
                  if (isRtspCameraUrl && relayBaseUrl.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'RTSP feed will be relayed through go2rtc automatically.',
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(Constants.defaultPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Camera Settings',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: const ValueKey<String>('access_code_field'),
                    controller: _accessCodeController,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Printer Access Code',
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 8),
                  if (relayBaseUrl.isNotEmpty)
                    Text(
                      'Relay endpoint: $relayBaseUrl',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (relayBaseUrl.isEmpty)
                    const Text(
                      'Relay endpoint is not configured. Set GO2RTC_BASE_URL at app startup.',
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      ElevatedButton(
                        key: const ValueKey<String>(
                          'save_camera_settings_button',
                        ),
                        onPressed: _isSaving ? null : _saveCameraSettings,
                        child: _isSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Save Camera Settings'),
                      ),
                    ],
                  ),
                  if (_settingsErrorMessage != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      _settingsErrorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                  if (_settingsSuccessMessage != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      _settingsSuccessMessage!,
                      style: const TextStyle(color: Colors.green),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeed({
    required String? cameraUrl,
    required String? resolvedFeedUrl,
  }) {
    if (!_isStreaming) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.videocam_off, color: Colors.white70, size: 44),
            SizedBox(height: 8),
            Text('Feed stopped', style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }

    if (cameraUrl == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.warning_amber, color: Colors.orangeAccent, size: 44),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'No camera URL configured for this printer.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    if (_isRtspUrl(cameraUrl) && resolvedFeedUrl == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Live relay is unavailable.\nStart go2rtc and make sure it is reachable at ${_go2rtcBaseUrl.isEmpty ? "<not configured>" : _go2rtcBaseUrl}.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Image.network(
      resolvedFeedUrl ?? cameraUrl,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (BuildContext context, Object error, StackTrace? _) {
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.signal_wifi_connected_no_internet_4,
                color: Colors.redAccent,
                size: 44,
              ),
              SizedBox(height: 8),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Unable to load camera feed.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
      loadingBuilder:
          (
            BuildContext context,
            Widget child,
            ImageChunkEvent? loadingProgress,
          ) {
            if (loadingProgress == null) {
              return child;
            }
            return const Center(child: CircularProgressIndicator());
          },
    );
  }
}
