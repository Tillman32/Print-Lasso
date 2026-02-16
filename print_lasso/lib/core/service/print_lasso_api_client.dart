import 'package:dio/dio.dart';

import 'print_lasso_models.dart';

class PrintLassoApiException implements Exception {
  const PrintLassoApiException(this.message, {this.statusCode, this.cause});

  final String message;
  final int? statusCode;
  final Object? cause;

  @override
  String toString() => message;
}

class PrintLassoApiClient {
  PrintLassoApiClient({
    required String baseApiUrl,
    Duration timeout = const Duration(seconds: 5),
  }) : _dio = Dio(
         BaseOptions(
           baseUrl: baseApiUrl,
           connectTimeout: timeout,
           receiveTimeout: timeout,
           sendTimeout: timeout,
           responseType: ResponseType.json,
         ),
       );

  final Dio _dio;

  void dispose() {
    _dio.close(force: true);
  }

  Future<ServiceStatus> getStatus() async {
    final Map<String, dynamic> responseJson = await _getJson('/status');
    return ServiceStatus.fromJson(responseJson);
  }

  Future<DiscoverResponse> discoverPrinters({bool includeAll = false}) async {
    final Map<String, dynamic> responseJson = await _postJson(
      '/discover',
      queryParameters: <String, dynamic>{'include_all': includeAll},
    );
    return DiscoverResponse.fromJson(responseJson);
  }

  Future<PrinterRecord> addPrinter(AddPrinterRequest payload) async {
    final Map<String, dynamic> responseJson = await _postJson(
      '/printer/add',
      data: payload.toJson(),
    );
    return PrinterRecord.fromJson(responseJson);
  }

  Future<PrinterRecord> editPrinter(UpdatePrinterRequest payload) async {
    final Map<String, dynamic> responseJson = await _putJson(
      '/printer/edit',
      data: payload.toJson(),
    );
    return PrinterRecord.fromJson(responseJson);
  }

  Future<RemovePrinterResponse> removePrinter(String serialNumber) async {
    final Map<String, dynamic> responseJson = await _deleteJson(
      '/printer/remove',
      data: <String, dynamic>{'serial_number': serialNumber},
    );
    return RemovePrinterResponse.fromJson(responseJson);
  }

  Future<PrinterRecord> viewPrinter(String serialNumber) async {
    final Map<String, dynamic> responseJson = await _getJson(
      '/printer/view',
      queryParameters: <String, dynamic>{'serial_number': serialNumber},
    );
    return PrinterRecord.fromJson(responseJson);
  }

  Future<Map<String, dynamic>> _getJson(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
      );
      return _asJsonMap(response.data);
    } on DioException catch (error) {
      throw _mapDioError(error);
    }
  }

  Future<Map<String, dynamic>> _postJson(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        path,
        data: data,
        queryParameters: queryParameters,
      );
      return _asJsonMap(response.data);
    } on DioException catch (error) {
      throw _mapDioError(error);
    }
  }

  Future<Map<String, dynamic>> _putJson(String path, {Object? data}) async {
    try {
      final Response<dynamic> response = await _dio.put<dynamic>(
        path,
        data: data,
      );
      return _asJsonMap(response.data);
    } on DioException catch (error) {
      throw _mapDioError(error);
    }
  }

  Future<Map<String, dynamic>> _deleteJson(String path, {Object? data}) async {
    try {
      final Response<dynamic> response = await _dio.delete<dynamic>(
        path,
        data: data,
      );
      return _asJsonMap(response.data);
    } on DioException catch (error) {
      throw _mapDioError(error);
    }
  }

  Map<String, dynamic> _asJsonMap(Object? data) {
    if (data is Map<String, dynamic>) {
      return data;
    }
    if (data is Map) {
      return data.cast<String, dynamic>();
    }
    throw const PrintLassoApiException('Unexpected response format');
  }

  PrintLassoApiException _mapDioError(DioException error) {
    final int? statusCode = error.response?.statusCode;
    final Object? responseData = error.response?.data;

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return const PrintLassoApiException('Request timed out');
    }

    if (responseData is Map && responseData['detail'] is String) {
      return PrintLassoApiException(
        responseData['detail'] as String,
        statusCode: statusCode,
        cause: error,
      );
    }

    if (statusCode != null) {
      return PrintLassoApiException(
        'Request failed with status $statusCode',
        statusCode: statusCode,
        cause: error,
      );
    }

    return PrintLassoApiException(
      'Unable to connect to Print Lasso service',
      cause: error,
    );
  }
}
