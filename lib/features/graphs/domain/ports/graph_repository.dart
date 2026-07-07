import 'dart:typed_data';
import '../entities/smart_grid_graph.dart';

abstract interface class GraphRepository {
  Future<List<GraphSummary>> list();
  Future<SmartGridGraph> get(String id);
  Future<SmartGridGraph> importJson(Map<String, dynamic> payload);
  Future<SmartGridGraph> importFile(String filename, Uint8List bytes);
  Future<List<PublicDataset>> listDatasets();
  Future<SmartGridGraph> importDataset(String id);
  Future<void> delete(String id);
}
