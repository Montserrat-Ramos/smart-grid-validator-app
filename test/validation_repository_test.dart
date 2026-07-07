import 'package:flutter_test/flutter_test.dart';
import 'package:smart_grid_validator/core/network/api_client.dart';
import 'package:smart_grid_validator/features/validation/infrastructure/validation_api_repository.dart';

class _FakeApiClient extends ApiClient {
  final calls = <String>[];

  @override
  Future<dynamic> getJson(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
    bool retryOnUnauthorized = true,
  }) async {
    calls.add('$path?${query ?? const {}}');
    if (path == '/validations') {
      return {
        'items': [
          {
            'id': 'v1',
            'graphId': 'g1',
            'graphName': 'Red con anomalías',
            'status': 'COMPLETED',
            'anomalyCount': 2,
            'createdAt': '2026-07-07T00:00:00Z',
            'metrics': {
              'rulesEvaluated': 4,
              'rulesPassed': 2,
              'severityCounts': {'CRITICAL': 1, 'HIGH': 1},
            },
            // Simula una API anterior que no hidrata el listado.
            'anomalies': [],
          },
        ],
      };
    }
    if (path == '/validations/v1') {
      return {
        'id': 'v1',
        'graphId': 'g1',
        'graphName': 'Red con anomalías',
        'status': 'COMPLETED',
        'anomalyCount': 2,
        'createdAt': '2026-07-07T00:00:00Z',
        'metrics': {
          'rulesEvaluated': 4,
          'rulesPassed': 2,
          'severityCounts': {'CRITICAL': 1, 'HIGH': 1},
        },
        // Simula también un detalle parcial para comprobar el segundo respaldo.
        'anomalies': [],
      };
    }
    if (path == '/validations/v1/anomalies') {
      return {
        'items': [
          {
            'id': 'a1',
            'ruleCode': 'R-004',
            'severity': 'CRITICAL',
            'title': 'Conexión directa',
            'description': 'G1 está conectado directamente a M1.',
            'affectedNodeIds': ['G1', 'M1'],
          },
          {
            'id': 'a2',
            'ruleCode': 'R-005',
            'severity': 'HIGH',
            'title': 'Transformador sin salida',
            'description': 'T1 no tiene salida.',
            'affectedNodeIds': ['T1'],
          },
        ],
        'totalItems': 2,
      };
    }
    throw StateError('Ruta no preparada: $path');
  }
}

void main() {
  test('hidrata anomalías cuando el listado solo contiene el contador', () async {
    final client = _FakeApiClient();
    final repository = ValidationApiRepository(client);

    final results = await repository.list();

    expect(results, hasLength(1));
    expect(results.single.anomalyCount, 2);
    expect(results.single.anomalies, hasLength(2));
    expect(results.single.anomalies.first.ruleCode, 'R-004');
    expect(
      client.calls.first,
      contains('includeAnomalies: true'),
    );
    expect(
      client.calls.any((call) => call.startsWith('/validations/v1/anomalies')),
      isTrue,
    );
  });
}
