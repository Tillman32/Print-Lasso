import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:print_lasso/core/service/print_lasso_api_client.dart';
import 'package:print_lasso/core/service/print_lasso_models.dart';
import 'package:print_lasso/core/service/service_config.dart';
import 'package:print_lasso/features/settings/settings.dart';

void main() {
  testWidgets('Settings printers section discovers and adds printer', (
    WidgetTester tester,
  ) async {
    final _FakePrintLassoApiClient fakeApiClient = _FakePrintLassoApiClient();

    final ServiceConfig serviceConfig = ServiceConfig(
      instanceName: 'Test Service',
      host: '127.0.0.1',
      port: 9000,
      apiPath: '/api/v1',
      baseApiUrl: 'http://127.0.0.1:9000/api/v1',
      lastSeenAt: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          activeService: serviceConfig,
          apiClientFactory: (_) => fakeApiClient,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Printers'), findsOneWidget);
    expect(find.text('No printers have been added yet.'), findsOneWidget);

    await tester.tap(find.text('Discover Printers'));
    await tester.pumpAndSettle();

    expect(find.text('Bench Printer'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(fakeApiClient.addedPrinters.length, 1);
    expect(fakeApiClient.addedPrinters.first.serialNumber, 'SN-1000');
    expect(find.text('No printers have been added yet.'), findsNothing);
    expect(find.text('Added'), findsOneWidget);
  });
}

class _FakePrintLassoApiClient extends PrintLassoApiClient {
  _FakePrintLassoApiClient() : super(baseApiUrl: 'http://localhost/api/v1');

  final List<DiscoveredPrinter> _discoveries = <DiscoveredPrinter>[
    const DiscoveredPrinter(
      serialNumber: 'SN-1000',
      name: 'Bench Printer',
      model: 'X1C',
      ipAddress: '192.168.1.22',
      port: 80,
      brand: 'Bambu',
    ),
  ];

  final List<PrinterRecord> addedPrinters = <PrinterRecord>[];

  @override
  void dispose() {}

  @override
  Future<DiscoverResponse> discoverPrinters({bool includeAll = false}) async {
    return DiscoverResponse(count: _discoveries.length, printers: _discoveries);
  }

  @override
  Future<List<PrinterRecord>> listPrinters() async {
    return List<PrinterRecord>.from(addedPrinters);
  }

  @override
  Future<PrinterRecord> addPrinter(AddPrinterRequest payload) async {
    final bool exists = addedPrinters.any(
      (PrinterRecord printer) => printer.serialNumber == payload.serialNumber,
    );
    if (exists) {
      throw const PrintLassoApiException(
        'Printer with this serial number already exists',
        statusCode: 409,
      );
    }

    final DateTime now = DateTime.now().toUtc();
    final PrinterRecord created = PrinterRecord(
      id: addedPrinters.length + 1,
      serialNumber: payload.serialNumber,
      name: payload.name,
      model: payload.model,
      ipAddress: payload.ipAddress,
      port: payload.port,
      cameraUrl: payload.cameraUrl,
      createdAt: now,
      updatedAt: now,
    );
    addedPrinters.add(created);
    return created;
  }
}
