int _asInt(dynamic value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return const <String, dynamic>{};
}

List<String> _asStringList(dynamic value) {
  if (value is! List) return const <String>[];
  return value.where((item) => item != null).map((item) => item.toString()).toList();
}

class Anomaly {
  const Anomaly({
    required this.id,
    required this.ruleCode,
    required this.severity,
    required this.title,
    required this.description,
    required this.nodeIds,
    this.edgeIds = const [],
    this.details = const {},
  });

  final String id;
  final String ruleCode;
  final String severity;
  final String title;
  final String description;
  final List<String> nodeIds;
  final List<String> edgeIds;
  final Map<String, dynamic> details;

  factory Anomaly.fromJson(Map<String, dynamic> json) => Anomaly(
        id: (json['id'] ?? '').toString(),
        ruleCode: (json['ruleCode'] ?? json['rule_code'] ?? 'SIN-REGLA').toString(),
        severity: (json['severity'] ?? 'MEDIUM').toString().toUpperCase(),
        title: (json['title'] ?? 'Anomalía estructural').toString(),
        description: (json['description'] ?? 'No se proporcionó descripción.').toString(),
        nodeIds: _asStringList(
          json['nodeIds'] ?? json['node_ids'] ?? json['affectedNodeIds'],
        ),
        edgeIds: _asStringList(
          json['edgeIds'] ?? json['edge_ids'] ?? json['affectedEdgeIds'],
        ),
        details: _asMap(json['details'] ?? json['evidence']),
      );
}

class ValidationResult {
  const ValidationResult({
    required this.id,
    required this.graphId,
    required this.graphName,
    required this.status,
    required this.nodesAnalyzed,
    required this.edgesAnalyzed,
    required this.rulesEvaluated,
    required this.rulesPassed,
    required this.anomalyCount,
    required this.anomalies,
    required this.createdAt,
    this.progress = 100,
    this.stage = 'COMPLETED',
    this.completedAt,
    this.ruleSetVersion = '1.0.0',
    this.errorMessage,
    this.metrics = const {},
  });

  final String id;
  final String graphId;
  final String graphName;
  final String status;
  final String stage;
  final String ruleSetVersion;
  final int nodesAnalyzed;
  final int edgesAnalyzed;
  final int rulesEvaluated;
  final int rulesPassed;
  final int anomalyCount;
  final int progress;
  final List<Anomaly> anomalies;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? errorMessage;
  final Map<String, dynamic> metrics;

  bool get isTerminal => const {'COMPLETED', 'FAILED', 'CANCELLED'}.contains(status);

  Map<String, int> get severityCounts {
    final result = <String, int>{
      'CRITICAL': 0,
      'HIGH': 0,
      'MEDIUM': 0,
      'LOW': 0,
    };

    if (anomalies.isNotEmpty) {
      for (final item in anomalies) {
        final key = item.severity.toUpperCase();
        result[key] = (result[key] ?? 0) + 1;
      }
      return result;
    }

    final raw = metrics['severityCounts'];
    if (raw is Map) {
      for (final entry in raw.entries) {
        final key = entry.key.toString().toUpperCase();
        result[key] = _asInt(entry.value);
      }
    }
    final classified = result.values.fold<int>(0, (sum, value) => sum + value);
    if (classified < anomalyCount) {
      result['MEDIUM'] = (result['MEDIUM'] ?? 0) + anomalyCount - classified;
    }
    return result;
  }

  ValidationResult copyWith({
    List<Anomaly>? anomalies,
    int? anomalyCount,
    Map<String, dynamic>? metrics,
  }) {
    return ValidationResult(
      id: id,
      graphId: graphId,
      graphName: graphName,
      status: status,
      nodesAnalyzed: nodesAnalyzed,
      edgesAnalyzed: edgesAnalyzed,
      rulesEvaluated: rulesEvaluated,
      rulesPassed: rulesPassed,
      anomalyCount: anomalyCount ?? this.anomalyCount,
      anomalies: anomalies ?? this.anomalies,
      createdAt: createdAt,
      progress: progress,
      stage: stage,
      completedAt: completedAt,
      ruleSetVersion: ruleSetVersion,
      errorMessage: errorMessage,
      metrics: metrics ?? this.metrics,
    );
  }

  factory ValidationResult.fromJson(Map<String, dynamic> json) {
    final metrics = _asMap(json['metrics']);
    final anomalies = (json['anomalies'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((item) => Anomaly.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    final explicitCount = json['anomalyCount'] ?? json['anomaly_count'];
    final metricCount = metrics['anomalyCount'] ?? metrics['anomalies'];

    return ValidationResult(
      id: (json['id'] ?? '').toString(),
      graphId: (json['graphId'] ?? json['graph_id'] ?? '').toString(),
      graphName: (json['graphName'] ?? json['graph_name'] ?? 'Grafo').toString(),
      status: (json['status'] ?? 'QUEUED').toString().toUpperCase(),
      progress: _asInt(json['progress']),
      stage: (json['stage'] ?? json['status'] ?? 'QUEUED').toString().toUpperCase(),
      nodesAnalyzed: _asInt(metrics['nodesAnalyzed'] ?? json['nodes_analyzed']),
      edgesAnalyzed: _asInt(metrics['edgesAnalyzed'] ?? json['edges_analyzed']),
      rulesEvaluated: _asInt(metrics['rulesEvaluated'] ?? json['rules_evaluated']),
      rulesPassed: _asInt(metrics['rulesPassed'] ?? json['rules_passed']),
      anomalyCount: _asInt(explicitCount ?? metricCount, anomalies.length),
      anomalies: anomalies,
      createdAt: DateTime.tryParse(
            (json['createdAt'] ?? json['created_at'] ?? '').toString(),
          ) ??
          DateTime.now(),
      completedAt: DateTime.tryParse(
        (json['completedAt'] ?? json['completed_at'] ?? '').toString(),
      ),
      ruleSetVersion: (json['ruleSetVersion'] ?? '1.0.0').toString(),
      errorMessage: (json['errorMessage'] ?? json['error_message'])?.toString(),
      metrics: metrics,
    );
  }
}

class ValidationRule {
  const ValidationRule({
    required this.code,
    required this.name,
    required this.description,
    required this.defaultSeverity,
    required this.profiles,
    required this.active,
  });

  final String code;
  final String name;
  final String description;
  final String defaultSeverity;
  final List<String> profiles;
  final bool active;

  factory ValidationRule.fromJson(Map<String, dynamic> json) => ValidationRule(
        code: (json['code'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        description: (json['description'] ?? '').toString(),
        defaultSeverity: (json['defaultSeverity'] ?? 'MEDIUM').toString(),
        profiles: _asStringList(json['profiles']),
        active: json['active'] as bool? ?? true,
      );
}
