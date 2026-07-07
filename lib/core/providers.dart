import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'network/api_client.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/domain/ports/auth_repository.dart';
import '../features/auth/infrastructure/auth_api_repository.dart';
import '../features/auth/infrastructure/auth_local_storage.dart';
import '../features/dashboard/application/get_dashboard.dart';
import '../features/dashboard/domain/ports/dashboard_repository.dart';
import '../features/dashboard/infrastructure/dashboard_api_repository.dart';
import '../features/graphs/application/graph_use_cases.dart';
import '../features/graphs/domain/ports/graph_repository.dart';
import '../features/graphs/infrastructure/graph_api_repository.dart';
import '../features/validation/application/validation_use_cases.dart';
import '../features/validation/domain/ports/validation_repository.dart';
import '../features/validation/infrastructure/validation_api_repository.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final authLocalStorageProvider = Provider<AuthLocalStorage>(
  (ref) => AuthLocalStorage(),
);
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthApiRepository(
    ref.watch(apiClientProvider),
    ref.watch(authLocalStorageProvider),
  ),
);
final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    ref.watch(authRepositoryProvider),
    ref.watch(apiClientProvider),
  );
});

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardApiRepository(ref.watch(apiClientProvider)),
);
final getDashboardProvider = Provider<GetDashboard>(
  (ref) => GetDashboard(ref.watch(dashboardRepositoryProvider)),
);
final dashboardFutureProvider = FutureProvider((ref) {
  return ref.watch(getDashboardProvider).execute();
});

final graphRepositoryProvider = Provider<GraphRepository>(
  (ref) => GraphApiRepository(ref.watch(apiClientProvider)),
);
final listGraphsProvider = Provider<ListGraphs>(
  (ref) => ListGraphs(ref.watch(graphRepositoryProvider)),
);
final importGraphProvider = Provider<ImportGraph>(
  (ref) => ImportGraph(ref.watch(graphRepositoryProvider)),
);
final getGraphProvider = Provider<GetGraph>(
  (ref) => GetGraph(ref.watch(graphRepositoryProvider)),
);
final listDatasetsProvider = Provider<ListDatasets>((ref) => ListDatasets(ref.watch(graphRepositoryProvider)));
final importDatasetProvider = Provider<ImportDataset>((ref) => ImportDataset(ref.watch(graphRepositoryProvider)));
final datasetsFutureProvider = FutureProvider((ref) => ref.watch(listDatasetsProvider).execute());
final graphsFutureProvider = FutureProvider((ref) {
  return ref.watch(listGraphsProvider).execute();
});

final validationRepositoryProvider = Provider<ValidationRepository>(
  (ref) => ValidationApiRepository(ref.watch(apiClientProvider)),
);
final startValidationProvider = Provider<StartValidation>((ref) => StartValidation(ref.watch(validationRepositoryProvider)));
final runValidationProvider = Provider<RunValidation>(
  (ref) => RunValidation(ref.watch(validationRepositoryProvider)),
);
final listValidationsProvider = Provider<ListValidations>(
  (ref) => ListValidations(ref.watch(validationRepositoryProvider)),
);
final getValidationProvider = Provider<GetValidation>((ref) => GetValidation(ref.watch(validationRepositoryProvider)));
final listRulesProvider = Provider<ListRules>((ref) => ListRules(ref.watch(validationRepositoryProvider)));
final cancelValidationProvider = Provider<CancelValidation>((ref) => CancelValidation(ref.watch(validationRepositoryProvider)));
final exportValidationProvider = Provider<ExportValidation>((ref) => ExportValidation(ref.watch(validationRepositoryProvider)));
final rulesFutureProvider = FutureProvider((ref) => ref.watch(listRulesProvider).execute());
final validationsFutureProvider = FutureProvider((ref) {
  return ref.watch(listValidationsProvider).execute();
});

final settingsFutureProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final data = await ref.watch(apiClientProvider).getJson('/settings');
  return Map<String, dynamic>.from(data as Map);
});

final sessionsFutureProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final data = await ref.watch(apiClientProvider).getJson('/auth/sessions') as Map<String, dynamic>;
  return (data['items'] as List<dynamic>? ?? const [])
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList();
});

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);
