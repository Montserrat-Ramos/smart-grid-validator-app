class GridNode {
  const GridNode({required this.id, required this.type, required this.label, required this.attributes});
  final String id;
  final String type;
  final String label;
  final Map<String, dynamic> attributes;
  factory GridNode.fromJson(Map<String, dynamic> json) => GridNode(
        id: json['id'].toString(), type: json['type'].toString(),
        label: (json['label'] ?? json['id']).toString(),
        attributes: Map<String, dynamic>.from(json['attributes'] as Map? ?? const {}),
      );
}

class GridEdge {
  const GridEdge({required this.id, required this.source, required this.target, required this.relation, required this.attributes});
  final String id;
  final String source;
  final String target;
  final String relation;
  final Map<String, dynamic> attributes;
  factory GridEdge.fromJson(Map<String, dynamic> json) => GridEdge(
        id: (json['id'] ?? '${json['source']}-${json['target']}').toString(),
        source: json['source'].toString(), target: json['target'].toString(),
        relation: (json['relation'] ?? 'connectedTo').toString(),
        attributes: Map<String, dynamic>.from(json['attributes'] as Map? ?? const {}),
      );
}

class GraphSummary {
  const GraphSummary({
    required this.id, required this.name, required this.nodeCount, required this.edgeCount,
    required this.createdAt, this.modelProfile = 'SGV_SIMPLIFIED', this.sourceFormat = 'SGV_JSON',
    this.sourceName, this.status = 'READY', this.metadata = const {},
  });
  final String id;
  final String name;
  final int nodeCount;
  final int edgeCount;
  final DateTime createdAt;
  final String modelProfile;
  final String sourceFormat;
  final String? sourceName;
  final String status;
  final Map<String, dynamic> metadata;

  factory GraphSummary.fromJson(Map<String, dynamic> json) => GraphSummary(
        id: json['id'].toString(), name: json['name'].toString(),
        nodeCount: json['nodeCount'] as int? ?? json['node_count'] as int? ?? 0,
        edgeCount: json['edgeCount'] as int? ?? json['edge_count'] as int? ?? 0,
        createdAt: DateTime.tryParse((json['createdAt'] ?? json['created_at'] ?? '').toString()) ?? DateTime.now(),
        modelProfile: (json['modelProfile'] ?? 'SGV_SIMPLIFIED').toString(),
        sourceFormat: (json['sourceFormat'] ?? 'SGV_JSON').toString(),
        sourceName: json['sourceName']?.toString(), status: (json['status'] ?? 'READY').toString(),
        metadata: Map<String, dynamic>.from(json['metadata'] as Map? ?? const {}),
      );
}

class SmartGridGraph extends GraphSummary {
  const SmartGridGraph({
    required super.id, required super.name, required super.nodeCount, required super.edgeCount,
    required super.createdAt, required this.nodes, required this.edges,
    super.modelProfile, super.sourceFormat, super.sourceName, super.status, super.metadata,
  });
  final List<GridNode> nodes;
  final List<GridEdge> edges;
  factory SmartGridGraph.fromJson(Map<String, dynamic> json) {
    final summary = GraphSummary.fromJson(json);
    return SmartGridGraph(
      id: summary.id, name: summary.name, nodeCount: summary.nodeCount, edgeCount: summary.edgeCount,
      createdAt: summary.createdAt, modelProfile: summary.modelProfile, sourceFormat: summary.sourceFormat,
      sourceName: summary.sourceName, status: summary.status, metadata: summary.metadata,
      nodes: (json['nodes'] as List<dynamic>? ?? const []).map((e) => GridNode.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
      edges: (json['edges'] as List<dynamic>? ?? const []).map((e) => GridEdge.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
    );
  }
}

class PublicDataset {
  const PublicDataset({required this.id, required this.name, required this.nodeCount, required this.edgeCount, required this.modelProfile, this.source});
  final String id; final String name; final int nodeCount; final int edgeCount; final String modelProfile; final Map<String,dynamic>? source;
  factory PublicDataset.fromJson(Map<String,dynamic> j) => PublicDataset(id:j['id'].toString(),name:j['name'].toString(),nodeCount:j['nodeCount'] as int? ?? 0,edgeCount:j['edgeCount'] as int? ?? 0,modelProfile:(j['modelProfile']??'IEEE_BUS_BRANCH').toString(),source:j['source'] is Map ? Map<String,dynamic>.from(j['source'] as Map) : null);
}
