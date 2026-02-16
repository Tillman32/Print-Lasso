import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:print_lasso/core/service/print_lasso_api_client.dart';
import 'package:print_lasso/core/service/print_lasso_models.dart';
import 'package:print_lasso/core/service/service_config.dart';
import 'package:print_lasso/features/printers/printers.dart';

void main() {
  testWidgets('Printers page opens camera view and toggles play/stop', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1200));
    final _FakePrintersApiClient fakeApiClient = _FakePrintersApiClient();

    await tester.pumpWidget(
      MaterialApp(
        home: PrintersPage(
          activeService: _testServiceConfig(),
          apiClientFactory: (_) => fakeApiClient,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Printers'), findsOneWidget);
    expect(find.text('Bench Printer'), findsOneWidget);

    await tester.tap(find.text('Bench Printer'));
    await tester.pumpAndSettle();

    expect(find.text('Play Feed'), findsOneWidget);
    expect(find.text('Stop Feed'), findsNothing);

    await tester.ensureVisible(find.text('Play Feed'));
    await tester.tap(find.text('Play Feed'));
    await tester.pumpAndSettle();

    expect(find.text('Stop Feed'), findsOneWidget);
    expect(find.text('Play Feed'), findsNothing);

    await tester.ensureVisible(find.text('Stop Feed'));
    await tester.tap(find.text('Stop Feed'));
    await tester.pumpAndSettle();

    expect(find.text('Play Feed'), findsOneWidget);
    expect(find.text('Feed stopped'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('Printer camera settings builds and saves RTSP URL', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1400));
    final _FakePrintersApiClient fakeApiClient = _FakePrintersApiClient();

    await tester.pumpWidget(
      MaterialApp(
        home: PrintersPage(
          activeService: _testServiceConfig(),
          apiClientFactory: (_) => fakeApiClient,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bench Printer'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('access_code_field')),
      '35d8a29f',
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('save_camera_settings_button')),
    );
    await tester.pumpAndSettle();

    expect(fakeApiClient.lastEditRequest, isNotNull);
    expect(fakeApiClient.lastEditRequest!.serialNumber, 'SN-1000');
    expect(
      fakeApiClient.lastEditRequest!.cameraUrl,
      'rtsps://bblp:35d8a29f@192.168.1.22:322/streaming/live/1',
    );
    expect(find.text('Camera settings saved.'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });
}

ServiceConfig _testServiceConfig() {
  return ServiceConfig(
    instanceName: 'Test Service',
    host: '127.0.0.1',
    port: 9000,
    apiPath: '/api/v1',
    baseApiUrl: 'http://127.0.0.1:9000/api/v1',
    lastSeenAt: DateTime.now(),
  );
}

class _FakePrintersApiClient extends PrintLassoApiClient {
  _FakePrintersApiClient() : super(baseApiUrl: 'http://localhost/api/v1');

  UpdatePrinterRequest? lastEditRequest;

  @override
  void dispose() {}

  @override
  Future<List<PrinterRecord>> listPrinters() async {
    final DateTime now = DateTime.now().toUtc();
    return <PrinterRecord>[
      PrinterRecord(
        id: 1,
        serialNumber: 'SN-1000',
        name: 'Bench Printer',
        model: 'X1C',
        ipAddress: '192.168.1.22',
        port: 80,
        cameraUrl: 'http://192.168.1.22/webcam/?action=stream',
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }

  @override
  Future<PrinterRecord> editPrinter(UpdatePrinterRequest payload) async {
    lastEditRequest = payload;
    final DateTime now = DateTime.now().toUtc();
    return PrinterRecord(
      id: 1,
      serialNumber: payload.serialNumber,
      name: 'Bench Printer',
      model: 'X1C',
      ipAddress: '192.168.1.22',
      port: 80,
      cameraUrl: payload.cameraUrl,
      createdAt: now,
      updatedAt: now,
    );
  }
}
