import 'package:flutter/foundation.dart';

class AppConfig {
  static const _configuredApiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Dirección predeterminada por plataforma para desarrollo local.
  ///
  /// Android Emulator accede al host mediante 10.0.2.2. Web y Windows usan
  /// localhost. Para un teléfono físico o producción se debe pasar
  /// --dart-define=API_BASE_URL=https://servidor/api/v1.
  static String get apiBaseUrl {
    if (_configuredApiBaseUrl.isNotEmpty) return _configuredApiBaseUrl;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://192.168.1.14:8000/api/v1';
    }
    return 'http://localhost:8000/api/v1';
  }
}
