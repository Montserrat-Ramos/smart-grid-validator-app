import '../../../../core/network/api_client.dart';
import '../entities/validation_result.dart';

abstract interface class ValidationRepository {
  Future<ValidationResult> start(String graphId, {List<String> selectedRules = const []});
  Future<ValidationResult> run(String graphId, {List<String> selectedRules = const []});
  Future<List<ValidationResult>> list({int limit = 50, String? status, String? graphId});
  Future<ValidationResult> get(String id);
  Future<List<ValidationRule>> rules();
  Future<ValidationResult> cancel(String id);
  Future<void> delete(String id);
  Future<DownloadedFile> export(String validationId, String format);
}
