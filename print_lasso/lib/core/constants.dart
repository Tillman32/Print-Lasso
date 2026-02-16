class Constants {
  // Private constructor to prevent instantiation
  Constants._();

  // App Information
  static const String appTitle = 'Print Lasso';
  static const String appVersion = '1.0.0';

  // API & Network
  static const String defaultApiPath = '/api/v1';
  static const String mdnsServiceType = '_print-lasso._tcp.local.';
  static const String mdnsServiceTypeNoTrailingDot = '_print-lasso._tcp.local';
  static const Duration requestTimeout = Duration(seconds: 30);
  static const String go2rtcBaseUrl = String.fromEnvironment(
    'GO2RTC_BASE_URL',
    defaultValue: '',
  );

  // UI Constants
  static const double defaultPadding = 16.0;
  static const double defaultBorderRadius = 8.0;
  static const double defaultElevation = 2.0;

  // Storage Keys
  static const String prefKeyThemeMode = 'theme_mode';
  static const String prefKeyLanguage = 'language';
  static const String prefKeyFirstLaunch = 'first_launch';

  // Error Messages
  static const String errorGeneric = 'Something went wrong. Please try again.';
  static const String errorNetwork =
      'Network error. Please check your connection.';
  static const String errorTimeout = 'Request timeout. Please try again.';
}
