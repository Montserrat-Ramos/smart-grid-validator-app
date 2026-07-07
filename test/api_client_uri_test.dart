import 'package:flutter_test/flutter_test.dart';
import 'package:smart_grid_validator/core/network/api_client.dart';

void main() {
  group('ApiClient.resolveUri', () {
    test('no duplica el prefijo cuando el backend devuelve /api/v1', () {
      final client = ApiClient();
      final uri = client.resolveUri('/api/v1/reports/report-1/download');

      expect(
        uri.toString(),
        'http://localhost:8000/api/v1/reports/report-1/download',
      );
    });

    test('agrega una ruta relativa al API_BASE_URL', () {
      final client = ApiClient();
      final uri = client.resolveUri('/reports/report-1/download');

      expect(
        uri.toString(),
        'http://localhost:8000/api/v1/reports/report-1/download',
      );
    });

    test('conserva una URL completa', () {
      final client = ApiClient();
      final uri = client.resolveUri(
        'https://api.example.com/api/v1/reports/report-1/download',
      );

      expect(
        uri.toString(),
        'https://api.example.com/api/v1/reports/report-1/download',
      );
    });
  });
}
