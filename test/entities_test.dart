import 'package:flutter_test/flutter_test.dart';
import 'package:smart_grid_validator/features/graphs/domain/entities/smart_grid_graph.dart';
import 'package:smart_grid_validator/features/validation/domain/entities/validation_result.dart';

void main() {
  test('interpreta un grafo IEEE recibido por la API', () {
    final graph = SmartGridGraph.fromJson({
      'id': 'g1',
      'name': 'IEEE 14-bus',
      'nodeCount': 2,
      'edgeCount': 1,
      'createdAt': '2026-07-07T00:00:00Z',
      'modelProfile': 'IEEE_BUS_BRANCH',
      'sourceFormat': 'PANDAPOWER_JSON',
      'nodes': [
        {
          'id': 'BUS_1',
          'type': 'Bus',
          'label': 'Bus 1',
          'attributes': {'vnKv': 135},
        },
        {
          'id': 'GEN_1',
          'type': 'Generator',
          'label': 'Generator 1',
          'attributes': {},
        },
      ],
      'edges': [
        {
          'id': 'E1',
          'source': 'GEN_1',
          'target': 'BUS_1',
          'relation': 'connectedTo',
          'attributes': {},
        },
      ],
    });

    expect(graph.modelProfile, 'IEEE_BUS_BRANCH');
    expect(graph.nodes.length, 2);
    expect(graph.edges.single.target, 'BUS_1');
  });

  test('interpreta progreso y anomalías de una validación', () {
    final result = ValidationResult.fromJson({
      'id': 'v1',
      'graphId': 'g1',
      'graphName': 'IEEE 14-bus',
      'status': 'COMPLETED',
      'progress': 100,
      'stage': 'COMPLETED',
      'anomalyCount': 1,
      'createdAt': '2026-07-07T00:00:00Z',
      'metrics': {
        'nodesAnalyzed': 14,
        'edgesAnalyzed': 20,
        'rulesEvaluated': 4,
        'rulesPassed': 3,
      },
      'anomalies': [
        {
          'id': 'a1',
          'ruleCode': 'R-011',
          'severity': 'HIGH',
          'title': 'Tensión fuera de rango',
          'description': 'El bus está fuera del rango.',
          'nodeIds': ['BUS_3'],
          'edgeIds': [],
          'details': {},
        },
      ],
    });

    expect(result.isTerminal, isTrue);
    expect(result.nodesAnalyzed, 14);
    expect(result.anomalies.single.ruleCode, 'R-011');
  });

  test('interpreta aliases del contrato de anomalías y severidad del resumen', () {
    final result = ValidationResult.fromJson({
      'id': 'v-alias',
      'graphId': 'g-alias',
      'graphName': 'Red con anomalías',
      'status': 'COMPLETED',
      'anomalyCount': 2,
      'createdAt': '2026-07-07T00:00:00Z',
      'metrics': {
        'rulesEvaluated': 4,
        'rulesPassed': 2,
        'severityCounts': {'CRITICAL': 1, 'HIGH': 1},
      },
      'anomalies': [
        {
          'id': 'a1',
          'ruleCode': 'R-004',
          'severity': 'critical',
          'title': 'Conexión directa',
          'description': 'G1 está conectado con M1.',
          'affectedNodeIds': ['G1', 'M1'],
          'affectedEdgeIds': ['E1'],
          'evidence': {'sourceType': 'Generator'},
        },
        {
          'id': 'a2',
          'rule_code': 'R-005',
          'severity': 'HIGH',
          'title': 'Sin salida',
          'description': 'T1 no tiene salida.',
          'node_ids': ['T1'],
          'edge_ids': [],
        },
      ],
    });

    expect(result.anomalies, hasLength(2));
    expect(result.anomalies.first.severity, 'CRITICAL');
    expect(result.anomalies.first.nodeIds, ['G1', 'M1']);
    expect(result.anomalies.first.edgeIds, ['E1']);
    expect(result.severityCounts['CRITICAL'], 1);
    expect(result.severityCounts['HIGH'], 1);
  });

  test('usa severityCounts cuando el listado trae resumen sin detalle', () {
    final result = ValidationResult.fromJson({
      'id': 'v-summary',
      'graphId': 'g1',
      'status': 'COMPLETED',
      'anomalyCount': 7,
      'createdAt': '2026-07-07T00:00:00Z',
      'metrics': {
        'severityCounts': {
          'CRITICAL': 2,
          'HIGH': 3,
          'MEDIUM': 2,
          'LOW': 0,
        },
      },
      'anomalies': [],
    });

    expect(result.anomalyCount, 7);
    expect(result.severityCounts['CRITICAL'], 2);
    expect(result.severityCounts['HIGH'], 3);
    expect(result.severityCounts['MEDIUM'], 2);
  });
}
