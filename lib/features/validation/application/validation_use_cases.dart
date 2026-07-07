import '../../../core/network/api_client.dart';
import '../domain/entities/validation_result.dart';
import '../domain/ports/validation_repository.dart';

class StartValidation { const StartValidation(this.repository); final ValidationRepository repository; Future<ValidationResult> execute(String graphId,{List<String> selectedRules=const []})=>repository.start(graphId,selectedRules:selectedRules); }
class RunValidation {
  const RunValidation(this.repository); final ValidationRepository repository;
  Future<ValidationResult> execute(String graphId,{List<String> selectedRules=const []})=>repository.run(graphId,selectedRules:selectedRules);
}
class ListValidations {
  const ListValidations(this.repository); final ValidationRepository repository;
  Future<List<ValidationResult>> execute({int limit=50,String? status,String? graphId})=>repository.list(limit:limit,status:status,graphId:graphId);
}
class GetValidation { const GetValidation(this.repository); final ValidationRepository repository; Future<ValidationResult> execute(String id)=>repository.get(id); }
class ListRules { const ListRules(this.repository); final ValidationRepository repository; Future<List<ValidationRule>> execute()=>repository.rules(); }
class CancelValidation { const CancelValidation(this.repository); final ValidationRepository repository; Future<ValidationResult> execute(String id)=>repository.cancel(id); }
class ExportValidation { const ExportValidation(this.repository); final ValidationRepository repository; Future<DownloadedFile> execute(String id,String format)=>repository.export(id,format); }
