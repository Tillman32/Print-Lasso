int? parseIntOrNull(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

class ServiceStatus {
  const ServiceStatus({required this.status});

  final String status;

  factory ServiceStatus.fromJson(Map<String, dynamic> json) {
    return ServiceStatus(status: json['status'] as String? ?? '');
  }
}

class DiscoveredPrinter {
  const DiscoveredPrinter({
    required this.serialNumber,
    required this.name,
    required this.model,
    required this.ipAddress,
    required this.port,
    this.brand,
  });

  final String serialNumber;
  final String name;
  final String model;
  final String ipAddress;
  final int? port;
  final String? brand;

  factory DiscoveredPrinter.fromJson(Map<String, dynamic> json) {
    return DiscoveredPrinter(
      serialNumber: json['serial_number'] as String? ?? '',
      name: json['name'] as String? ?? '',
      model: json['model'] as String? ?? '',
      ipAddress: json['ip_address'] as String? ?? '',
      port: parseIntOrNull(json['port']),
      brand: json['brand'] as String?,
    );
  }
}

class DiscoverResponse {
  const DiscoverResponse({required this.count, required this.printers});

  final int count;
  final List<DiscoveredPrinter> printers;

  factory DiscoverResponse.fromJson(Map<String, dynamic> json) {
    final List<dynamic> rawPrinters = json['printers'] as List<dynamic>? ?? [];
    return DiscoverResponse(
      count: json['count'] as int? ?? rawPrinters.length,
      printers: rawPrinters
          .whereType<Map>()
          .map(
            (Map printer) =>
                DiscoveredPrinter.fromJson(printer.cast<String, dynamic>()),
          )
          .toList(),
    );
  }
}

class PrinterRecord {
  const PrinterRecord({
    required this.id,
    required this.serialNumber,
    required this.name,
    required this.model,
    required this.ipAddress,
    required this.port,
    required this.cameraUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String serialNumber;
  final String name;
  final String? model;
  final String? ipAddress;
  final int port;
  final String? cameraUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory PrinterRecord.fromJson(Map<String, dynamic> json) {
    return PrinterRecord(
      id: json['id'] as int? ?? 0,
      serialNumber: json['serial_number'] as String? ?? '',
      name: json['name'] as String? ?? '',
      model: json['model'] as String?,
      ipAddress: json['ip_address'] as String?,
      port: parseIntOrNull(json['port']) ?? 0,
      cameraUrl: json['camera_url'] as String?,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          DateTime.tryParse(json['updated_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class AddPrinterRequest {
  const AddPrinterRequest({
    required this.serialNumber,
    required this.name,
    this.model,
    this.ipAddress,
    this.port = 0,
    this.cameraUrl,
  });

  final String serialNumber;
  final String name;
  final String? model;
  final String? ipAddress;
  final int port;
  final String? cameraUrl;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'serial_number': serialNumber,
      'name': name,
      'model': model,
      'ip_address': ipAddress,
      'port': port,
      'camera_url': cameraUrl,
    };
  }
}

class UpdatePrinterRequest {
  const UpdatePrinterRequest({
    required this.serialNumber,
    this.name,
    this.model,
    this.ipAddress,
    this.port,
    this.cameraUrl,
  });

  final String serialNumber;
  final String? name;
  final String? model;
  final String? ipAddress;
  final int? port;
  final String? cameraUrl;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'serial_number': serialNumber,
      if (name != null) 'name': name,
      if (model != null) 'model': model,
      if (ipAddress != null) 'ip_address': ipAddress,
      if (port != null) 'port': port,
      if (cameraUrl != null) 'camera_url': cameraUrl,
    };
  }
}

class RemovePrinterResponse {
  const RemovePrinterResponse({
    required this.status,
    required this.serialNumber,
  });

  final String status;
  final String serialNumber;

  factory RemovePrinterResponse.fromJson(Map<String, dynamic> json) {
    return RemovePrinterResponse(
      status: json['status'] as String? ?? '',
      serialNumber: json['serial_number'] as String? ?? '',
    );
  }
}
