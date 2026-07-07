import '../../../validation/domain/entities/validation_result.dart';

class DashboardSummary {
  const DashboardSummary({
    required this.graphsLoaded,
    required this.validationsCompleted,
    required this.anomaliesDetected,
    required this.latestValidation,
    required this.recentValidations,
    this.systemStatus = 'OPERATIONAL',
  });
  final int graphsLoaded;
  final int validationsCompleted;
  final int anomaliesDetected;
  final ValidationResult? latestValidation;
  final List<ValidationResult> recentValidations;
  final String systemStatus;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) => DashboardSummary(
        graphsLoaded: json['graphsLoaded'] as int? ?? json['graphs_loaded'] as int? ?? 0,
        validationsCompleted: json['validationsCompleted'] as int? ?? json['validations_completed'] as int? ?? 0,
        anomaliesDetected: json['anomaliesDetected'] as int? ?? json['anomalies_detected'] as int? ?? 0,
        latestValidation: (json['latestValidation'] ?? json['latest_validation']) == null
            ? null
            : ValidationResult.fromJson(Map<String,dynamic>.from((json['latestValidation'] ?? json['latest_validation']) as Map)),
        recentValidations: ((json['recentValidations'] ?? json['recent_validations']) as List<dynamic>? ?? const [])
            .map((item) => ValidationResult.fromJson(Map<String,dynamic>.from(item as Map)))
            .toList(),
        systemStatus: (json['systemStatus'] ?? 'OPERATIONAL').toString(),
      );
}
