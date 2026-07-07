import '../../../core/network/api_client.dart';
import '../domain/entities/dashboard_summary.dart';
import '../domain/ports/dashboard_repository.dart';

class DashboardApiRepository implements DashboardRepository {
  const DashboardApiRepository(this.client);
  final ApiClient client;

  @override
  Future<DashboardSummary> getSummary() async {
    final data = await client.getJson('/dashboard') as Map<String, dynamic>;
    return DashboardSummary.fromJson(data);
  }
}
