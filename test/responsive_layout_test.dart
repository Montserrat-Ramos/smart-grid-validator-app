import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_grid_validator/core/network/api_client.dart';
import 'package:smart_grid_validator/core/providers.dart';
import 'package:smart_grid_validator/core/widgets/app_shell.dart';
import 'package:smart_grid_validator/features/auth/application/auth_controller.dart';
import 'package:smart_grid_validator/features/auth/domain/entities/auth_session.dart';
import 'package:smart_grid_validator/features/auth/domain/entities/auth_user.dart';
import 'package:smart_grid_validator/features/auth/domain/ports/auth_repository.dart';
import 'package:smart_grid_validator/features/auth/presentation/login_page.dart';
import 'package:smart_grid_validator/features/dashboard/domain/entities/dashboard_summary.dart';
import 'package:smart_grid_validator/features/dashboard/presentation/dashboard_page.dart';
import 'package:smart_grid_validator/features/graphs/application/graph_use_cases.dart';
import 'package:smart_grid_validator/features/graphs/domain/entities/smart_grid_graph.dart';
import 'package:smart_grid_validator/features/graphs/domain/ports/graph_repository.dart';
import 'package:smart_grid_validator/features/graphs/presentation/graphs_page.dart';
import 'package:smart_grid_validator/features/reports/presentation/history_page.dart';
import 'package:smart_grid_validator/features/reports/presentation/reports_page.dart';
import 'package:smart_grid_validator/features/settings/presentation/settings_page.dart';
import 'package:smart_grid_validator/features/validation/domain/entities/validation_result.dart';
import 'package:smart_grid_validator/features/validation/domain/ports/validation_repository.dart';
import 'package:smart_grid_validator/features/validation/presentation/validation_page.dart';

const _user = AuthUser(
  id: 'u1',
  email: 'admin@smartgrid.local',
  fullName: 'Montserrat Administrador',
  role: 'ADMIN',
  isActive: true,
);

final _graph = SmartGridGraph(
  id: 'g1',
  name: 'IEEE 14-bus',
  nodeCount: 4,
  edgeCount: 3,
  createdAt: DateTime.utc(2026, 7, 7),
  modelProfile: 'IEEE_BUS_BRANCH',
  sourceFormat: 'PANDAPOWER_JSON',
  nodes: const [
    GridNode(id: 'BUS_1', type: 'Bus', label: 'Bus 1', attributes: {'vnKv': 135.0, 'vmPu': 1.02}),
    GridNode(id: 'BUS_2', type: 'Bus', label: 'Bus 2', attributes: {'vnKv': 135.0, 'vmPu': 1.01}),
    GridNode(id: 'GEN_1', type: 'Generator', label: 'Generator 1', attributes: {'pMw': 40.0}),
    GridNode(id: 'LOAD_1', type: 'Load', label: 'Load 1', attributes: {'pMw': 20.0}),
  ],
  edges: const [
    GridEdge(id: 'E1', source: 'GEN_1', target: 'BUS_1', relation: 'connectedTo', attributes: {}),
    GridEdge(id: 'E2', source: 'BUS_1', target: 'BUS_2', relation: 'line', attributes: {}),
    GridEdge(id: 'E3', source: 'BUS_2', target: 'LOAD_1', relation: 'supplies', attributes: {}),
  ],
);

final _validation = ValidationResult(
  id: 'v1',
  graphId: 'g1',
  graphName: 'IEEE 14-bus',
  status: 'COMPLETED',
  progress: 100,
  stage: 'COMPLETED',
  nodesAnalyzed: 14,
  edgesAnalyzed: 20,
  rulesEvaluated: 4,
  rulesPassed: 3,
  anomalyCount: 1,
  anomalies: const [
    Anomaly(
      id: 'a1',
      ruleCode: 'R-011',
      severity: 'HIGH',
      title: 'Tensión fuera de rango',
      description: 'El bus BUS_3 está fuera del rango permitido.',
      nodeIds: ['BUS_3'],
    ),
  ],
  createdAt: DateTime.utc(2026, 7, 7, 12),
  completedAt: DateTime.utc(2026, 7, 7, 12, 1),
  metrics: const {
    'nodesAnalyzed': 14,
    'edgesAnalyzed': 20,
    'rulesEvaluated': 4,
    'rulesPassed': 3,
    'severityCounts': {'HIGH': 1},
  },
);

class _AuthRepository implements AuthRepository {
  final session = const AuthSession(accessToken: 'token', refreshToken: 'refresh', expiresIn: 900, user: _user);
  @override Future<void> changePassword(String currentPassword, String newPassword) async {}
  @override Future<void> clearSession() async {}
  @override Future<void> forgotPassword(String email) async {}
  @override Future<AuthSession> guest([String displayName = 'Invitado']) async => session;
  @override Future<AuthSession> login(String email, String password) async => session;
  @override Future<void> logout() async {}
  @override Future<AuthSession> refresh() async => session;
  @override Future<AuthSession> register(String name, String email, String password) async => session;
  @override Future<void> revokeAllSessions() async {}
  @override Future<AuthSession?> restore() async => session;
  @override Future<AuthUser> updateProfile(String name, String email) async => _user;
}

class _GraphRepository implements GraphRepository {
  @override Future<void> delete(String id) async {}
  @override Future<SmartGridGraph> get(String id) async => _graph;
  @override Future<SmartGridGraph> importDataset(String id) async => _graph;
  @override Future<SmartGridGraph> importFile(String filename, Uint8List bytes) async => _graph;
  @override Future<SmartGridGraph> importJson(Map<String, dynamic> payload) async => _graph;
  @override Future<List<GraphSummary>> list() async => [_graph];
  @override Future<List<PublicDataset>> listDatasets() async => const [
    PublicDataset(id: 'ieee14', name: 'IEEE 14-bus', nodeCount: 35, edgeCount: 41, modelProfile: 'IEEE_BUS_BRANCH'),
  ];
}

class _ValidationRepository implements ValidationRepository {
  @override Future<ValidationResult> cancel(String id) async => _validation;
  @override Future<void> delete(String id) async {}
  @override Future<DownloadedFile> export(String validationId, String format) async => DownloadedFile(bytes: Uint8List(0), filename: 'report.$format', contentType: 'application/octet-stream');
  @override Future<ValidationResult> get(String id) async => _validation;
  @override Future<List<ValidationResult>> list({int limit = 50, String? status, String? graphId}) async => [_validation];
  @override Future<List<ValidationRule>> rules() async => const [
    ValidationRule(code: 'R-011', name: 'Tensión de bus', description: 'La tensión debe permanecer en rango.', defaultSeverity: 'HIGH', profiles: ['IEEE_BUS_BRANCH'], active: true),
  ];
  @override Future<ValidationResult> run(String graphId, {List<String> selectedRules = const []}) async => _validation;
  @override Future<ValidationResult> start(String graphId, {List<String> selectedRules = const []}) async => _validation;
}

List<Override> _overrides() {
  final graphs = _GraphRepository();
  final validations = _ValidationRepository();
  return [
    authControllerProvider.overrideWith((ref) => AuthController(_AuthRepository(), ApiClient())),
    dashboardFutureProvider.overrideWith((ref) async => DashboardSummary(
      graphsLoaded: 1,
      validationsCompleted: 1,
      anomaliesDetected: 1,
      latestValidation: _validation,
      recentValidations: [_validation],
    )),
    graphRepositoryProvider.overrideWithValue(graphs),
    getGraphProvider.overrideWithValue(GetGraph(graphs)),
    graphsFutureProvider.overrideWith((ref) async => [_graph]),
    datasetsFutureProvider.overrideWith((ref) async => const [
      PublicDataset(id: 'ieee14', name: 'IEEE 14-bus', nodeCount: 35, edgeCount: 41, modelProfile: 'IEEE_BUS_BRANCH'),
    ]),
    validationRepositoryProvider.overrideWithValue(validations),
    validationsFutureProvider.overrideWith((ref) async => [_validation]),
    rulesFutureProvider.overrideWith((ref) async => validations.rules()),
    settingsFutureProvider.overrideWith((ref) async => const {
      'theme': 'dark',
      'language': 'es',
      'timezone': 'America/Mexico_City',
      'notifications': {'push': true, 'email': true, 'critical': true},
    }),
    sessionsFutureProvider.overrideWith((ref) async => const <Map<String, dynamic>>[]),
  ];
}

Future<void> _pumpAt(WidgetTester tester, Widget page, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides(),
      child: MaterialApp(theme: ThemeData.dark(useMaterial3: true), home: page),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final pages = <String, Widget>{
    'login': const LoginPage(),
    'dashboard': const DashboardPage(),
    'graphs': const GraphsPage(),
    'validation': const ValidationPage(),
    'reports': const ReportsPage(),
    'history': const HistoryPage(),
    'settings': const SettingsPage(),
    'shell-dashboard': const AppShell(currentPath: '/dashboard', child: DashboardPage()),
  };
  const sizes = [Size(360, 800), Size(768, 1024), Size(1440, 900)];

  for (final entry in pages.entries) {
    for (final size in sizes) {
      testWidgets('${entry.key} no desborda en ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
        final errors = <FlutterErrorDetails>[];
        final previous = FlutterError.onError;
        FlutterError.onError = errors.add;
        addTearDown(() {
          FlutterError.onError = previous;
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await _pumpAt(tester, entry.value, size);
        final overflows = errors.where((error) => error.exceptionAsString().contains('overflowed')).toList();
        expect(overflows, isEmpty, reason: overflows.map((e) => e.exceptionAsString()).join('\n'));
      });
    }
  }
}
