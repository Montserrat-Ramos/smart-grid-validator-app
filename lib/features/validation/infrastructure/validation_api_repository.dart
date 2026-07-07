import 'dart:async';
import 'dart:math';

import '../../../core/network/api_client.dart';
import '../domain/entities/validation_result.dart';
import '../domain/ports/validation_repository.dart';

class ValidationApiRepository implements ValidationRepository {
  const ValidationApiRepository(this.client);

  final ApiClient client;

  @override
  Future<ValidationResult> start(
    String graphId, {
    List<String> selectedRules = const [],
  }) async {
    final key = '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(999999)}';
    final data = await client.postJson(
      '/graphs/$graphId/validations',
      {
        'selectedRuleCodes': selectedRules,
        'options': {'includeMetrics': true},
      },
      extraHeaders: {'Idempotency-Key': key},
    );
    return _hydrate(ValidationResult.fromJson(Map<String, dynamic>.from(data as Map)));
  }

  @override
  Future<ValidationResult> run(
    String graphId, {
    List<String> selectedRules = const [],
  }) async {
    final created = await start(graphId, selectedRules: selectedRules);
    if (created.isTerminal) return created;

    var current = created;
    var delay = const Duration(seconds: 1);
    var attempts = 0;
    while (!current.isTerminal && attempts < 120) {
      await Future<void>.delayed(delay);
      current = await get(current.id);
      attempts++;
      if (attempts > 10) delay = const Duration(seconds: 3);
    }
    return current;
  }

  @override
  Future<List<ValidationResult>> list({
    int limit = 50,
    String? status,
    String? graphId,
  }) async {
    final query = <String, String>{
      'limit': '$limit',
      'includeAnomalies': 'true',
      if (status != null) 'status': status,
      if (graphId != null) 'graphId': graphId,
    };
    final data = await client.getJson('/validations', query: query);
    final items = data is List
        ? data
        : (Map<String, dynamic>.from(data as Map)['items'] as List<dynamic>? ?? const []);
    final summaries = items
        .whereType<Map>()
        .map((item) => ValidationResult.fromJson(Map<String, dynamic>.from(item)))
        .toList();

    // Compatibilidad con backends previos que devuelven el contador, pero omiten
    // el detalle en el listado. Solo hidratamos los elementos que lo necesitan.
    return Future.wait(
      summaries.map((item) async {
        if (item.anomalyCount == 0 || item.anomalies.isNotEmpty) return item;
        try {
          return await get(item.id);
        } catch (_) {
          return item;
        }
      }),
    );
  }

  @override
  Future<ValidationResult> get(String id) async {
    final data = await client.getJson('/validations/$id');
    return _hydrate(ValidationResult.fromJson(Map<String, dynamic>.from(data as Map)));
  }

  Future<ValidationResult> _hydrate(ValidationResult result) async {
    if (result.status != 'COMPLETED' ||
        result.anomalyCount == 0 ||
        result.anomalies.isNotEmpty) {
      return result;
    }

    final data = await client.getJson(
      '/validations/${result.id}/anomalies',
      query: const {'page': '1', 'pageSize': '200'},
    );
    final map = Map<String, dynamic>.from(data as Map);
    final anomalies = (map['items'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => Anomaly.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    return result.copyWith(
      anomalies: anomalies,
      anomalyCount: result.anomalyCount > 0 ? result.anomalyCount : anomalies.length,
    );
  }

  @override
  Future<List<ValidationRule>> rules() async {
    final data = await client.getJson('/rules') as Map<String, dynamic>;
    return (data['items'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => ValidationRule.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  @override
  Future<ValidationResult> cancel(String id) async {
    final data = await client.postJson('/validations/$id/cancel', const {});
    return ValidationResult.fromJson(Map<String, dynamic>.from(data as Map));
  }

  @override
  Future<void> delete(String id) => client.delete('/validations/$id');

  @override
  Future<DownloadedFile> export(String validationId, String format) async {
    final report = await client.postJson(
      '/validations/$validationId/reports',
      {'format': format.toUpperCase()},
    ) as Map<String, dynamic>;
    return client.download(
      report['downloadUrl'].toString(),
      fallbackName: 'smart-grid-validator-$validationId.${format.toLowerCase()}',
    );
  }
}
