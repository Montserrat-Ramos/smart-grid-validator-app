import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/entities/smart_grid_graph.dart';

class GraphCanvas extends StatefulWidget {
  const GraphCanvas({
    required this.graph,
    this.anomalousNodeIds = const {},
    this.highlightedNodeIds = const {},
    this.selectedNodeId,
    this.onNodeSelected,
    this.showToolbar = true,
    super.key,
  });

  final SmartGridGraph graph;
  final Set<String> anomalousNodeIds;
  final Set<String> highlightedNodeIds;
  final String? selectedNodeId;
  final ValueChanged<GridNode>? onNodeSelected;
  final bool showToolbar;

  @override
  State<GraphCanvas> createState() => _GraphCanvasState();
}

class _GraphCanvasState extends State<GraphCanvas> {
  final TransformationController _controller = TransformationController();

  @override
  void didUpdateWidget(covariant GraphCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.graph.id != widget.graph.id) {
      _controller.value = Matrix4.identity();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _zoom(double factor) {
    final current = _controller.value.getMaxScaleOnAxis();
    final next = (current * factor).clamp(.18, 4.5).toDouble();
    _controller.value = Matrix4.identity()..scale(next);
  }

  void _fit(GraphScene scene, Size viewport) {
    final factor = math.min(
      viewport.width / scene.size.width,
      viewport.height / scene.size.height,
    ).clamp(.18, 1.0).toDouble();
    _controller.value = Matrix4.identity()..scale(factor);
  }

  @override
  Widget build(BuildContext context) {
    final scene = GraphLayout.calculate(widget.graph);
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewport = Size(constraints.maxWidth, constraints.maxHeight);
        return Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                transformationController: _controller,
                minScale: .12,
                maxScale: 4.5,
                constrained: false,
                boundaryMargin: const EdgeInsets.all(260),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    if (widget.onNodeSelected == null) return;
                    GridNode? nearest;
                    var nearestDistance = double.infinity;
                    final hitRadius = widget.graph.nodeCount > 120 ? 30.0 : 42.0;
                    for (final node in widget.graph.nodes) {
                      final position = scene.positions[node.id];
                      if (position == null) continue;
                      final distance = (details.localPosition - position).distance;
                      if (distance < hitRadius && distance < nearestDistance) {
                        nearest = node;
                        nearestDistance = distance;
                      }
                    }
                    if (nearest != null) widget.onNodeSelected!(nearest);
                  },
                  child: SizedBox(
                    width: scene.size.width,
                    height: scene.size.height,
                    child: CustomPaint(
                      painter: _GridPainter(
                        widget.graph,
                        scene.positions,
                        widget.anomalousNodeIds,
                        widget.highlightedNodeIds,
                        widget.selectedNodeId,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.showToolbar)
              Positioned(
                left: 14,
                top: 14,
                child: Column(
                  children: [
                    _ToolButton(
                      icon: Icons.center_focus_strong,
                      active: true,
                      tooltip: 'Ajustar a pantalla',
                      onPressed: () => _fit(scene, viewport),
                    ),
                    const SizedBox(height: 8),
                    _ToolButton(icon: Icons.zoom_in, tooltip: 'Acercar', onPressed: () => _zoom(1.25)),
                    const SizedBox(height: 8),
                    _ToolButton(icon: Icons.zoom_out, tooltip: 'Alejar', onPressed: () => _zoom(.80)),
                    const SizedBox(height: 8),
                    _ToolButton(
                      icon: Icons.restart_alt,
                      tooltip: 'Restablecer',
                      onPressed: () => _controller.value = Matrix4.identity(),
                    ),
                  ],
                ),
              ),
            Positioned(
              right: 14,
              bottom: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt.withValues(alpha: .92),
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${widget.graph.nodeCount} nodos · ${widget.graph.edgeCount} relaciones',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({required this.icon, required this.onPressed, required this.tooltip, this.active = false});
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;
  final bool active;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: active ? AppColors.primary.withValues(alpha: .85) : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(7),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(7),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                border: Border.all(color: active ? AppColors.primary : AppColors.border),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, size: 21),
            ),
          ),
        ),
      );
}

class GraphScene {
  const GraphScene(this.size, this.positions);
  final Size size;
  final Map<String, Offset> positions;
}

class GraphLayout {
  static GraphScene calculate(SmartGridGraph graph) {
    if (graph.nodes.isEmpty) return const GraphScene(Size(900, 620), {});
    if (graph.modelProfile == 'SGV_SIMPLIFIED' && graph.nodeCount <= 80) {
      return _byDomainLevels(graph);
    }
    return _byConnectivityLevels(graph);
  }

  static GraphScene _byDomainLevels(SmartGridGraph graph) {
    final byLevel = <int, List<GridNode>>{};
    for (final node in graph.nodes) {
      byLevel.putIfAbsent(_domainLevel(node.type), () => []).add(node);
    }
    final levels = byLevel.keys.toList()..sort();
    final maxInLevel = byLevel.values.fold<int>(1, (value, nodes) => math.max(value, nodes.length));
    final width = math.max(900.0, maxInLevel * 115.0 + 220.0);
    final height = math.max(620.0, levels.length * 125.0 + 150.0);
    final positions = <String, Offset>{};
    for (var li = 0; li < levels.length; li++) {
      final nodes = byLevel[levels[li]]!..sort((a, b) => a.id.compareTo(b.id));
      final y = levels.length == 1 ? height / 2 : 75 + li * ((height - 150) / (levels.length - 1));
      _spread(nodes, y, width, positions);
    }
    return GraphScene(Size(width, height), positions);
  }

  static GraphScene _byConnectivityLevels(SmartGridGraph graph) {
    final nodeIds = graph.nodes.map((node) => node.id).toSet();
    final adjacency = <String, Set<String>>{for (final id in nodeIds) id: <String>{}};
    for (final edge in graph.edges) {
      if (nodeIds.contains(edge.source) && nodeIds.contains(edge.target)) {
        adjacency[edge.source]!.add(edge.target);
        adjacency[edge.target]!.add(edge.source);
      }
    }
    final roots = graph.nodes
        .where((node) => const {'externalgrid', 'generator'}.contains(node.type.toLowerCase()))
        .map((node) => node.id)
        .toList();
    if (roots.isEmpty) roots.add(graph.nodes.first.id);
    final level = <String, int>{};
    var componentOffset = 0;

    void traverse(String root) {
      final queue = Queue<String>()..add(root);
      level[root] = componentOffset;
      var maxFound = componentOffset;
      while (queue.isNotEmpty) {
        final current = queue.removeFirst();
        final currentLevel = level[current]!;
        maxFound = math.max(maxFound, currentLevel);
        final neighbors = adjacency[current]!.toList()..sort();
        for (final neighbor in neighbors) {
          if (level.containsKey(neighbor)) continue;
          level[neighbor] = currentLevel + 1;
          queue.add(neighbor);
        }
      }
      componentOffset = maxFound + 2;
    }

    for (final root in roots) {
      if (!level.containsKey(root)) traverse(root);
    }
    for (final node in graph.nodes) {
      if (!level.containsKey(node.id)) traverse(node.id);
    }

    final groups = <int, List<GridNode>>{};
    for (final node in graph.nodes) {
      groups.putIfAbsent(level[node.id]!, () => []).add(node);
    }
    final ordered = groups.keys.toList()..sort();
    final maxInLevel = groups.values.fold<int>(1, (value, nodes) => math.max(value, nodes.length));
    final horizontalSpacing = graph.nodeCount > 150 ? 78.0 : 105.0;
    final verticalSpacing = graph.nodeCount > 150 ? 88.0 : 112.0;
    final width = math.max(1000.0, maxInLevel * horizontalSpacing + 240.0);
    final height = math.max(680.0, ordered.length * verticalSpacing + 170.0);
    final positions = <String, Offset>{};
    for (var index = 0; index < ordered.length; index++) {
      final nodes = groups[ordered[index]]!..sort((a, b) => a.id.compareTo(b.id));
      final y = 80 + index * verticalSpacing;
      _spread(nodes, y, width, positions, horizontalPadding: 110);
    }
    return GraphScene(Size(width, height), positions);
  }

  static void _spread(
    List<GridNode> nodes,
    double y,
    double width,
    Map<String, Offset> positions, {
    double horizontalPadding = 120,
  }) {
    final usable = width - horizontalPadding * 2;
    final gap = nodes.length <= 1 ? 0.0 : usable / (nodes.length - 1);
    for (var i = 0; i < nodes.length; i++) {
      final x = nodes.length == 1 ? width / 2 : horizontalPadding + gap * i;
      positions[nodes[i].id] = Offset(x, y);
    }
  }

  static int _domainLevel(String type) {
    switch (type.toLowerCase()) {
      case 'externalgrid':
      case 'generator':
        return 0;
      case 'bus':
      case 'transformer':
        return 1;
      case 'meter':
        return 2;
      case 'load':
      case 'storage':
      case 'carga':
        return 3;
      default:
        return 4;
    }
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.graph, this.positions, this.anomalousNodeIds, this.highlightedNodeIds, this.selectedNodeId);
  final SmartGridGraph graph;
  final Map<String, Offset> positions;
  final Set<String> anomalousNodeIds;
  final Set<String> highlightedNodeIds;
  final String? selectedNodeId;

  @override
  void paint(Canvas canvas, Size size) {
    if (graph.nodes.isEmpty) return;
    final dense = graph.nodeCount > 100;
    final hasHighlight = highlightedNodeIds.isNotEmpty;
    for (final edge in graph.edges) {
      final start = positions[edge.source];
      final end = positions[edge.target];
      if (start == null || end == null) continue;
      final anomalous = anomalousNodeIds.contains(edge.source) || anomalousNodeIds.contains(edge.target);
      final highlighted = highlightedNodeIds.contains(edge.source) || highlightedNodeIds.contains(edge.target);
      final paint = Paint()
        ..color = anomalous
            ? AppColors.danger
            : hasHighlight && !highlighted
                ? AppColors.textDim.withValues(alpha: .18)
                : highlighted
                    ? AppColors.cyan
                    : AppColors.text.withValues(alpha: dense ? .36 : .72)
        ..strokeWidth = anomalous ? 2.8 : highlighted ? 2.4 : dense ? .8 : 1.6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(start, end, paint);
      if (!dense || anomalous || highlighted) _drawArrow(canvas, start, end, paint.color, dense ? 22 : 30);
    }

    for (final node in graph.nodes) {
      final position = positions[node.id];
      if (position == null) continue;
      final anomalous = anomalousNodeIds.contains(node.id);
      final selected = selectedNodeId == node.id;
      final highlighted = highlightedNodeIds.contains(node.id);
      final dimmed = hasHighlight && !highlighted && !selected && !anomalous;
      final color = anomalous ? AppColors.danger : _colorFor(node.type);
      final radius = dense ? 18.0 : 28.0;
      if (selected || highlighted) {
        canvas.drawCircle(position, radius + 10, Paint()..color = (highlighted ? AppColors.cyan : color).withValues(alpha: .18));
      }
      canvas.drawCircle(position, radius + 2, Paint()..color = AppColors.surfaceAlt.withValues(alpha: dimmed ? .35 : 1));
      canvas.drawCircle(
        position,
        radius,
        Paint()
          ..color = color.withValues(alpha: dimmed ? .25 : 1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected || highlighted ? 4 : dense ? 2 : 3,
      );
      final icon = _iconFor(node.type);
      final iconPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontSize: dense ? 16 : 24,
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            color: color.withValues(alpha: dimmed ? .25 : 1),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      iconPainter.paint(canvas, position - Offset(iconPainter.width / 2, iconPainter.height / 2));

      final showLabel = !dense || selected || anomalous || highlighted;
      if (showLabel) {
        final label = TextPainter(
          text: TextSpan(
            children: [
              TextSpan(text: '${node.id}\n', style: const TextStyle(color: AppColors.text, fontSize: 11, fontWeight: FontWeight.w600)),
              TextSpan(text: _typeLabel(node.type), style: const TextStyle(color: AppColors.textMuted, fontSize: 9)),
            ],
          ),
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 115);
        label.paint(canvas, position + Offset(-label.width / 2, radius + 7));
      }
    }
  }

  void _drawArrow(Canvas canvas, Offset start, Offset end, Color color, double margin) {
    final vector = end - start;
    final length = vector.distance;
    if (length < margin * 2) return;
    final unit = vector / length;
    final tip = end - unit * margin;
    final normal = Offset(-unit.dy, unit.dx);
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo((tip - unit * 7 + normal * 3.5).dx, (tip - unit * 7 + normal * 3.5).dy)
      ..lineTo((tip - unit * 7 - normal * 3.5).dx, (tip - unit * 7 - normal * 3.5).dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  Color _colorFor(String type) {
    switch (type.toLowerCase()) {
      case 'externalgrid': return AppColors.purple;
      case 'generator': return AppColors.green;
      case 'transformer': return AppColors.primary;
      case 'bus': return AppColors.cyan;
      case 'meter': return AppColors.green;
      case 'load':
      case 'carga': return AppColors.warning;
      case 'storage': return const Color(0xFFB5D34B);
      default: return AppColors.textMuted;
    }
  }

  IconData _iconFor(String type) {
    switch (type.toLowerCase()) {
      case 'externalgrid': return Icons.public;
      case 'generator': return Icons.bolt;
      case 'transformer': return Icons.electrical_services;
      case 'bus': return Icons.device_hub;
      case 'meter': return Icons.speed;
      case 'load':
      case 'carga': return Icons.home;
      case 'storage': return Icons.battery_charging_full;
      default: return Icons.circle;
    }
  }

  String _typeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'externalgrid': return 'Red externa';
      case 'generator': return 'Generador';
      case 'transformer': return 'Transformador';
      case 'bus': return 'Bus';
      case 'meter': return 'Medidor';
      case 'load':
      case 'carga': return 'Carga';
      case 'storage': return 'Almacenamiento';
      default: return type;
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter oldDelegate) =>
      oldDelegate.graph != graph ||
      oldDelegate.anomalousNodeIds != anomalousNodeIds ||
      oldDelegate.highlightedNodeIds != highlightedNodeIds ||
      oldDelegate.selectedNodeId != selectedNodeId;
}
