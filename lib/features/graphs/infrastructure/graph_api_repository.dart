import 'dart:typed_data';
import '../../../core/network/api_client.dart';
import '../domain/entities/smart_grid_graph.dart';
import '../domain/ports/graph_repository.dart';

class GraphApiRepository implements GraphRepository {
  const GraphApiRepository(this.client); final ApiClient client;
  @override
  Future<List<GraphSummary>> list() async { final data=await client.getJson('/graphs'); final items=data is List ? data : (data['items'] as List<dynamic>? ?? const []); return items.map((e)=>GraphSummary.fromJson(Map<String,dynamic>.from(e as Map))).toList(); }
  @override
  Future<SmartGridGraph> get(String id) async => SmartGridGraph.fromJson(Map<String,dynamic>.from(await client.getJson('/graphs/$id/topology') as Map));
  @override
  Future<SmartGridGraph> importJson(Map<String,dynamic> payload) async => SmartGridGraph.fromJson(Map<String,dynamic>.from(await client.postJson('/graphs/import-json',payload) as Map));
  @override
  Future<SmartGridGraph> importFile(String filename,Uint8List bytes) async => SmartGridGraph.fromJson(Map<String,dynamic>.from(await client.postFile('/graphs/import',filename:filename,bytes:bytes) as Map));
  @override
  Future<List<PublicDataset>> listDatasets() async { final data=await client.getJson('/datasets') as Map<String,dynamic>; return (data['items'] as List<dynamic>? ?? const []).map((e)=>PublicDataset.fromJson(Map<String,dynamic>.from(e as Map))).toList(); }
  @override
  Future<SmartGridGraph> importDataset(String id) async => SmartGridGraph.fromJson(Map<String,dynamic>.from(await client.postJson('/datasets/$id/import',const {}) as Map));
  @override
  Future<void> delete(String id)=>client.delete('/graphs/$id');
}
