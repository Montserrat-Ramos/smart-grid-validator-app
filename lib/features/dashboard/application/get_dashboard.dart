import '../domain/entities/dashboard_summary.dart';
import '../domain/ports/dashboard_repository.dart';

class GetDashboard {
  const GetDashboard(this.repository);
  final DashboardRepository repository;
  Future<DashboardSummary> execute() => repository.getSummary();
}
