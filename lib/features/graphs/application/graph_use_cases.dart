import 'dart:typed_data';
import '../domain/entities/smart_grid_graph.dart';
import '../domain/ports/graph_repository.dart';

class ListGraphs { const ListGraphs(this.repository); final GraphRepository repository; Future<List<GraphSummary>> execute()=>repository.list(); }
class GetGraph { const GetGraph(this.repository); final GraphRepository repository; Future<SmartGridGraph> execute(String id)=>repository.get(id); }
class ImportGraph { const ImportGraph(this.repository); final GraphRepository repository; Future<SmartGridGraph> execute(Map<String,dynamic> payload)=>repository.importJson(payload); Future<SmartGridGraph> file(String name,Uint8List bytes)=>repository.importFile(name,bytes); }
class ListDatasets { const ListDatasets(this.repository); final GraphRepository repository; Future<List<PublicDataset>> execute()=>repository.listDatasets(); }
class ImportDataset { const ImportDataset(this.repository); final GraphRepository repository; Future<SmartGridGraph> execute(String id)=>repository.importDataset(id); }
