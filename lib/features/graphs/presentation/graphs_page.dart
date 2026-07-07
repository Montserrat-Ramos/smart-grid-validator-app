/*
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/page_frame.dart';
import '../../validation/domain/entities/validation_result.dart';
import '../domain/entities/smart_grid_graph.dart';
import 'graph_painter.dart';
import 'upload_graph_dialog.dart';

class GraphsPage extends ConsumerStatefulWidget {
  const GraphsPage({this.openUpload = false, super.key});

  final bool openUpload;

  @override
  ConsumerState<GraphsPage> createState() => _GraphsPageState();
}

class _GraphsPageState extends ConsumerState<GraphsPage> {
  String? selectedId;
  Future<SmartGridGraph>? graphFuture;
  GridNode? selectedNode;
  final searchController = TextEditingController();
  final Set<String> typeFilters = <String>{};

  @override
  void initState() {
    super.initState();
    if (widget.openUpload) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) upload();
      });
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> deleteSelected() async {
    if (selectedId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Eliminar grafo'),
        content: const Text('El grafo dejará de aparecer en la aplicación. Esta acción no puede deshacerse.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(graphRepositoryProvider).delete(selectedId!);
      setState(() {
        selectedId = null;
        graphFuture = null;
        selectedNode = null;
      });
      ref.invalidate(graphsFutureProvider);
      ref.invalidate(dashboardFutureProvider);
      ref.invalidate(validationsFutureProvider);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> configureFilters() async {
    const types = ['Generator', 'ExternalGrid', 'Transformer', 'Bus', 'Meter', 'Load', 'Storage'];
    final selected = Set<String>.from(typeFilters);
    final result = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Filtrar tipos de nodo'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: types.map((type) => CheckboxListTile(
                  value: selected.contains(type),
                  title: Text(type),
                  onChanged: (value) => setDialogState(() {
                    if (value == true) selected.add(type); else selected.remove(type);
                  }),
                )).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => setDialogState(selected.clear), child: const Text('Limpiar')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, selected), child: const Text('Aplicar')),
          ],
        ),
      ),
    );
    if (result != null) setState(() { typeFilters..clear()..addAll(result); });
  }

  void selectGraph(String id) {
    setState(() {
      selectedId = id;
      selectedNode = null;
      graphFuture = ref.read(getGraphProvider).execute(id);
    });
  }

  Future<void> upload() async {
    final id = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const UploadGraphDialog(),
    );
    if (id != null) selectGraph(id);
  }

  @override
  Widget build(BuildContext context) {
    final graphs = ref.watch(graphsFutureProvider);
    return PageFrame(
      title: 'Grafos',
      subtitle: 'Visualiza y explora la topología de la red eléctrica.',
      actions: [
        FilledButton.icon(
          onPressed: upload,
          icon: const Icon(Icons.upload_file_outlined),
          label: const Text('Cargar nuevo JSON'),
        ),
      ],
      child: graphs.when(
        loading: () => const LoadingPanel(),
        error: (error, _) => ErrorPanel(
          error: error,
          onRetry: () => ref.invalidate(graphsFutureProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return EmptyPanel(
              message: 'Carga el primer grafo JSON para visualizar la topología.',
              icon: Icons.hub_outlined,
            );
          }
          selectedId ??= items.first.id;
          graphFuture ??= ref.read(getGraphProvider).execute(selectedId!);
          return Column(
            children: [
              _GraphToolbar(
                items: items,
                selectedId: selectedId!,
                searchController: searchController,
                filterCount: typeFilters.length,
                onSearchChanged: (_) => setState(() {}),
                onFilters: configureFilters,
                onSelected: selectGraph,
                onValidate: () => context.go('/validation?graphId=$selectedId'),
                onDelete: deleteSelected,
              ),
              const SizedBox(height: 14),
              FutureBuilder<SmartGridGraph>(
                future: graphFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Card(
                      child: SizedBox(height: 580, child: LoadingPanel(message: 'Construyendo grafo…')),
                    );
                  }
                  if (snapshot.hasError || snapshot.data == null) {
                    return ErrorPanel(
                      error: snapshot.error ?? 'No se encontró el grafo.',
                      onRetry: () => selectGraph(selectedId!),
                    );
                  }
                  return _GraphWorkspace(
                    graph: snapshot.data!,
                    selectedNode: selectedNode,
                    onNodeSelected: (node) => setState(() => selectedNode = node),
                    query: searchController.text,
                    typeFilters: typeFilters,
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GraphToolbar extends StatelessWidget {
  const _GraphToolbar({
    required this.items,
    required this.selectedId,
    required this.searchController,
    required this.filterCount,
    required this.onSearchChanged,
    required this.onFilters,
    required this.onSelected,
    required this.onValidate,
    required this.onDelete,
  });

  final List<GraphSummary> items;
  final String selectedId;
  final TextEditingController searchController;
  final int filterCount;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onFilters;
  final ValueChanged<String> onSelected;
  final VoidCallback onValidate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 700;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: mobile
            ? Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedId,
                    decoration: const InputDecoration(labelText: 'Seleccionar grafo'),
                    items: items
                        .map(
                          (item) => DropdownMenuItem(
                            value: item.id,
                            child: Text(item.name, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) onSelected(value);
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          onChanged: onSearchChanged,
                          decoration: const InputDecoration(
                            hintText: 'Buscar nodo o conexión…',
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filledTonal(
                        tooltip: 'Filtros',
                        onPressed: onFilters,
                        icon: Badge(
                          isLabelVisible: filterCount > 0,
                          label: Text('$filterCount'),
                          child: const Icon(Icons.filter_alt_outlined),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : Row(
                children: [
                  SizedBox(
                    width: 250,
                    child: DropdownButtonFormField<String>(
                      initialValue: selectedId,
                      decoration: const InputDecoration(labelText: 'Seleccionar grafo'),
                      items: items
                          .map(
                            (item) => DropdownMenuItem(
                              value: item.id,
                              child: Text(item.name, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) onSelected(value);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: searchController,
                      onChanged: onSearchChanged,
                      decoration: const InputDecoration(
                        hintText: 'Buscar nodo o conexión…',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: onFilters,
                    icon: const Icon(Icons.filter_alt_outlined),
                    label: Text(filterCount == 0 ? 'Filtros' : 'Filtros ($filterCount)'),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<String>(
                    tooltip: 'Más acciones',
                    onSelected: (value) { if (value == 'delete') onDelete(); },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'delete', child: Text('Eliminar grafo')),
                    ],
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: onValidate,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Validar'),
                  ),
                ],
              ),
      ),
    );
  }
}

class _GraphWorkspace extends ConsumerWidget {
  const _GraphWorkspace({
    required this.graph,
    required this.selectedNode,
    required this.onNodeSelected,
    required this.query,
    required this.typeFilters,
  });

  final SmartGridGraph graph;
  final GridNode? selectedNode;
  final ValueChanged<GridNode> onNodeSelected;
  final String query;
  final Set<String> typeFilters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 1100;
    final validations =
        ref.watch(validationsFutureProvider).asData?.value ?? const <ValidationResult>[];
    final related = validations.where((item) => item.graphId == graph.id).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final latest = related.isEmpty ? null : related.first;
    final anomalousIds = latest?.anomalies.expand((item) => item.nodeIds).toSet() ?? <String>{};
    final activeNode = selectedNode ?? _preferredNode(graph.nodes);
    final normalizedQuery = query.trim().toLowerCase();
    final highlightedIds = graph.nodes.where((node) {
      final matchesQuery = normalizedQuery.isEmpty ||
          node.id.toLowerCase().contains(normalizedQuery) ||
          node.label.toLowerCase().contains(normalizedQuery) ||
          node.attributes.values.any((value) => '$value'.toLowerCase().contains(normalizedQuery));
      final matchesType = typeFilters.isEmpty || typeFilters.contains(node.type);
      return matchesQuery && matchesType;
    }).map((node) => node.id).toSet();
    final hasActiveFilter = normalizedQuery.isNotEmpty || typeFilters.isNotEmpty;
    final historyItems = related.where((validation) =>
        validation.anomalies.any((anomaly) => activeNode != null && anomaly.nodeIds.contains(activeNode.id))).toList();

    void showNodeHistory() {
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text('Historial del nodo ${activeNode?.id ?? ''}'),
          content: SizedBox(
            width: 640,
            height: 420,
            child: historyItems.isEmpty
                ? const EmptyPanel(message: 'Este nodo no aparece en anomalías anteriores.')
                : ListView.separated(
                    itemCount: historyItems.length,
                    separatorBuilder: (_, __) => const Divider(),
                    itemBuilder: (_, index) {
                      final item = historyItems[index];
                      final findings = item.anomalies.where((a) => a.nodeIds.contains(activeNode!.id)).toList();
                      return ListTile(
                        leading: const Icon(Icons.history, color: AppColors.primary),
                        title: Text(item.graphName),
                        subtitle: Text('${findings.length} hallazgo(s) · ${item.createdAt.toLocal()}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.pop(dialogContext);
                          context.go('/reports?validationId=${item.id}');
                        },
                      );
                    },
                  ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cerrar'))],
        ),
      );
    }

    return Column(
      children: [
        Card(
          child: SizedBox(
            height: desktop ? 600 : 660,
            child: desktop
                ? Row(
                    children: [
                      SizedBox(width: 185, child: _LegendPanel(graph: graph)),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: GraphCanvas(
                          graph: graph,
                          anomalousNodeIds: anomalousIds,
                          highlightedNodeIds: hasActiveFilter ? highlightedIds : const <String>{},
                          selectedNodeId: activeNode?.id,
                          onNodeSelected: onNodeSelected,
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      SizedBox(
                        width: 310,
                        child: _NodeDetailsPanel(node: activeNode, graph: graph, anomalousIds: anomalousIds, onHistory: showNodeHistory),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Expanded(
                        child: GraphCanvas(
                          graph: graph,
                          anomalousNodeIds: anomalousIds,
                          highlightedNodeIds: hasActiveFilter ? highlightedIds : const <String>{},
                          selectedNodeId: activeNode?.id,
                          onNodeSelected: onNodeSelected,
                        ),
                      ),
                      const Divider(height: 1),
                      SizedBox(
                        height: 150,
                        child: _NodeDetailsPanel(
                          node: activeNode,
                          graph: graph,
                          anomalousIds: anomalousIds,
                          compact: true,
                          onHistory: showNodeHistory,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 14),
        _GraphStats(graph: graph, anomalies: anomalousIds.length),
      ],
    );
  }

  static GridNode? _preferredNode(List<GridNode> nodes) {
    if (nodes.isEmpty) return null;
    for (final node in nodes) {
      if (node.type.toLowerCase() == 'transformer') return node;
    }
    return nodes.first;
  }
}

class _LegendPanel extends StatelessWidget {
  const _LegendPanel({required this.graph});
  final SmartGridGraph graph;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Leyenda', style: TextStyle(fontWeight: FontWeight.w600)),
            const Divider(height: 24),
            ...graph.nodes.map((node) => node.type).toSet().take(8).map(
              (type) => _LegendDot(color: _typeColor(type), label: _typeLabel(type)),
            ),
            const SizedBox(height: 18),
            const Text(
              'Estados de conexión',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 10),
            const _LegendLine(color: AppColors.green, label: 'Normal'),
            const _LegendLine(color: AppColors.warning, label: 'Advertencia'),
            const _LegendLine(color: AppColors.danger, label: 'Crítico'),
            const _LegendLine(color: AppColors.textDim, label: 'Desconectado', dashed: true),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: AppColors.primary, size: 17),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Haz clic en un nodo para consultar sus detalles.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  static Color _typeColor(String type) {
    switch (type.toLowerCase()) {
      case 'generator': return AppColors.green;
      case 'externalgrid': return AppColors.purple;
      case 'transformer': return AppColors.primary;
      case 'bus': return AppColors.cyan;
      case 'meter': return AppColors.green;
      case 'load': return AppColors.warning;
      case 'storage': return const Color(0xFFB5D34B);
      default: return AppColors.textMuted;
    }
  }

  static String _typeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'generator': return 'Generador';
      case 'externalgrid': return 'Red externa';
      case 'transformer': return 'Transformador';
      case 'bus': return 'Bus';
      case 'meter': return 'Medidor';
      case 'load': return 'Carga';
      case 'storage': return 'Almacenamiento';
      default: return type;
    }
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 9),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      );
}

class _LegendLine extends StatelessWidget {
  const _LegendLine({required this.color, required this.label, this.dashed = false});
  final Color color;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            SizedBox(
              width: 26,
              child: Divider(color: color, thickness: 2),
            ),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      );
}

class _NodeDetailsPanel extends StatelessWidget {
  const _NodeDetailsPanel({
    required this.node,
    required this.graph,
    required this.anomalousIds,
    required this.onHistory,
    this.compact = false,
  });

  final GridNode? node;
  final SmartGridGraph graph;
  final Set<String> anomalousIds;
  final VoidCallback onHistory;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (node == null) {
      return const Center(
        child: Text('Selecciona un nodo.', style: TextStyle(color: AppColors.textMuted)),
      );
    }
    final anomalous = anomalousIds.contains(node!.id);
    final connections = graph.edges.where(
      (edge) => edge.source == node!.id || edge.target == node!.id,
    );
    if (compact) {
      return Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: (anomalous ? AppColors.danger : AppColors.primary).withValues(alpha: .18),
              child: Text(node!.id, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${node!.id} · ${_label(node!.type)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 5),
                  Text(
                    '${connections.length} conexiones · ${anomalous ? 'Anomalía activa' : 'Estado normal'}',
                    style: TextStyle(
                      color: anomalous ? AppColors.danger : AppColors.green,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Detalles del nodo', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 18),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withValues(alpha: .16),
                child: Text(node!.id.substring(0, 1)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(node!.id, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600)),
                    Text(_label(node!.type), style: const TextStyle(color: AppColors.textMuted)),
                  ],
                ),
              ),
              StatusBadge(
                label: anomalous ? 'Anomalía' : 'Normal',
                color: anomalous ? AppColors.danger : AppColors.green,
              ),
            ],
          ),
          const Divider(height: 28),
          _DetailRow(label: 'ID del nodo', value: node!.id),
          _DetailRow(label: 'Tipo', value: _label(node!.type)),
          ...node!.attributes.entries.take(5).map(
                (entry) => _DetailRow(label: _attributeLabel(entry.key), value: '${entry.value}'),
              ),
          const SizedBox(height: 15),
          Text('Conexiones (${connections.length})', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ...connections.take(4).map((edge) {
            final other = edge.source == node!.id ? edge.target : edge.source;
            return Container(
              margin: const EdgeInsets.only(bottom: 7),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link, size: 15, color: AppColors.green),
                  const SizedBox(width: 7),
                  Expanded(child: Text(other, style: const TextStyle(fontSize: 11))),
                  Text(edge.relation, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                ],
              ),
            );
          }),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onHistory,
              icon: const Icon(Icons.history),
              label: const Text('Ver historial del nodo'),
            ),
          ),
        ],
      ),
    );
  }

  static String _label(String type) {
    switch (type.toLowerCase()) {
      case 'externalgrid':
        return 'Red externa';
      case 'generator':
        return 'Generador';
      case 'bus':
        return 'Bus';
      case 'transformer':
        return 'Transformador';
      case 'meter':
        return 'Medidor';
      case 'load':
        return 'Carga';
      case 'storage':
        return 'Almacenamiento';
      default:
        return type;
    }
  }

  static String _attributeLabel(String value) {
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
        .join(' ');
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11))),
            Flexible(child: Text(value, textAlign: TextAlign.right, style: const TextStyle(fontSize: 11))),
          ],
        ),
      );
}

class _GraphStats extends StatelessWidget {
  const _GraphStats({required this.graph, required this.anomalies});
  final SmartGridGraph graph;
  final int anomalies;

  @override
  Widget build(BuildContext context) {
    int count(String type) => graph.nodes.where((node) => node.type.toLowerCase() == type).length;
    final items = [
      ('Nodos totales', '${graph.nodeCount}', Icons.hub_outlined, AppColors.text),
      ('Generadores', '${count('generator')}', Icons.bolt, AppColors.green),
      ('Red externa', '${count('externalgrid')}', Icons.public, AppColors.purple),
      ('Transformadores', '${count('transformer')}', Icons.electrical_services, AppColors.primary),
      ('Buses', '${count('bus')}', Icons.device_hub, AppColors.cyan),
      ('Medidores', '${count('meter')}', Icons.speed, AppColors.green),
      ('Cargas', '${count('load')}', Icons.home, AppColors.warning),
      ('Almacenamiento', '${count('storage')}', Icons.battery_charging_full, Color(0xFFB5D34B)),
      ('Conexiones', '${graph.edgeCount}', Icons.link, AppColors.textMuted),
      ('Anomalías activas', '$anomalies', Icons.warning_amber_rounded, AppColors.danger),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final mobile = constraints.maxWidth < 700;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: items.map((item) {
                final columns = mobile ? 2 : constraints.maxWidth >= 1200 ? 5 : 4;
                final itemWidth = (constraints.maxWidth - 10 * (columns - 1)) / columns;
                return SizedBox(
                  width: itemWidth,
                  child: Row(
                    children: [
                      Icon(item.$3, color: item.$4, size: 23),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.$1, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                          Text(item.$2, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }
}
*/
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/page_frame.dart';
import '../../validation/domain/entities/validation_result.dart';
import '../domain/entities/smart_grid_graph.dart';
import 'graph_painter.dart';
import 'upload_graph_dialog.dart';

class GraphsPage extends ConsumerStatefulWidget {
  const GraphsPage({this.openUpload = false, super.key});

  final bool openUpload;

  @override
  ConsumerState<GraphsPage> createState() => _GraphsPageState();
}

class _GraphsPageState extends ConsumerState<GraphsPage> {
  String? selectedId;
  Future<SmartGridGraph>? graphFuture;
  GridNode? selectedNode;

  final searchController = TextEditingController();
  final Set<String> typeFilters = <String>{};

  @override
  void initState() {
    super.initState();

    if (widget.openUpload) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) upload();
      });
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> deleteSelected() async {
    final id = selectedId;
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 24,
        ),
        backgroundColor: AppColors.surface,
        title: const Text('Eliminar grafo'),
        content: const Text(
          'El grafo dejará de aparecer en la aplicación. '
              'Esta acción no puede deshacerse.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(graphRepositoryProvider).delete(id);

      if (!mounted) return;

      setState(() {
        selectedId = null;
        graphFuture = null;
        selectedNode = null;
      });

      ref.invalidate(graphsFutureProvider);
      ref.invalidate(dashboardFutureProvider);
      ref.invalidate(validationsFutureProvider);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  Future<void> configureFilters() async {
    const types = [
      'Generator',
      'ExternalGrid',
      'Transformer',
      'Bus',
      'Meter',
      'Load',
      'Storage',
    ];

    final selected = Set<String>.from(typeFilters);

    final result = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            scrollable: true,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            backgroundColor: AppColors.surface,
            title: const Text('Filtrar tipos de nodo'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: types.map((type) {
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: selected.contains(type),
                    title: Text(type),
                    onChanged: (value) {
                      setDialogState(() {
                        if (value == true) {
                          selected.add(type);
                        } else {
                          selected.remove(type);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setDialogState(selected.clear);
                },
                child: const Text('Limpiar'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(dialogContext, selected);
                },
                child: const Text('Aplicar'),
              ),
            ],
          );
        },
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      typeFilters
        ..clear()
        ..addAll(result);
    });
  }

  void selectGraph(String id) {
    if (id.isEmpty) return;

    setState(() {
      selectedId = id;
      selectedNode = null;
      graphFuture = ref.read(getGraphProvider).execute(id);
    });
  }

  Future<void> upload() async {
    final id = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const UploadGraphDialog(),
    );

    if (id == null || id.isEmpty || !mounted) return;

    ref.invalidate(graphsFutureProvider);
    ref.invalidate(dashboardFutureProvider);
    selectGraph(id);
  }

  @override
  Widget build(BuildContext context) {
    final graphs = ref.watch(graphsFutureProvider);

    return PageFrame(
      title: 'Grafos',
      subtitle: 'Visualiza y explora la topología de la red eléctrica.',
      actions: [
        FilledButton.icon(
          onPressed: upload,
          icon: const Icon(Icons.upload_file_outlined),
          label: const Text('Cargar nuevo JSON'),
        ),
      ],
      child: graphs.when(
        loading: () => const LoadingPanel(),
        error: (error, _) => ErrorPanel(
          error: error,
          onRetry: () => ref.invalidate(graphsFutureProvider),
        ),
        data: (rawItems) {
          // Evita que DropdownButtonFormField reciba dos opciones con el mismo ID.
          final items = _deduplicateGraphs(rawItems);

          if (items.isEmpty) {
            return const EmptyPanel(
              message:
              'Carga el primer grafo JSON para visualizar la topología.',
              icon: Icons.hub_outlined,
            );
          }

          final selectedStillExists = selectedId != null &&
              items.any((item) => item.id == selectedId);

          final effectiveSelectedId = selectedStillExists
              ? selectedId!
              : items.first.id;

          final effectiveFuture =
          selectedStillExists && graphFuture != null
              ? graphFuture!
              : ref
              .read(getGraphProvider)
              .execute(effectiveSelectedId);

          // Sincroniza el estado después del build. No se llama setState
          // directamente durante la construcción del widget.
          if (selectedId != effectiveSelectedId || graphFuture == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;

              if (selectedId == effectiveSelectedId &&
                  graphFuture != null) {
                return;
              }

              setState(() {
                selectedId = effectiveSelectedId;
                graphFuture = effectiveFuture;
                selectedNode = null;
              });
            });
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _GraphToolbar(
                items: items,
                selectedId: effectiveSelectedId,
                searchController: searchController,
                filterCount: typeFilters.length,
                onSearchChanged: (_) => setState(() {}),
                onFilters: configureFilters,
                onSelected: selectGraph,
                onValidate: () {
                  context.go(
                    '/validation?graphId=$effectiveSelectedId',
                  );
                },
                onDelete: deleteSelected,
              ),
              const SizedBox(height: 14),
              FutureBuilder<SmartGridGraph>(
                key: ValueKey(effectiveSelectedId),
                future: effectiveFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState !=
                      ConnectionState.done) {
                    return Card(
                      child: SizedBox(
                        height: _loadingHeight(context),
                        child: const LoadingPanel(
                          message: 'Construyendo grafo…',
                        ),
                      ),
                    );
                  }

                  if (snapshot.hasError || snapshot.data == null) {
                    return ErrorPanel(
                      error: snapshot.error ??
                          'No se encontró el grafo.',
                      onRetry: () {
                        selectGraph(effectiveSelectedId);
                      },
                    );
                  }

                  return _GraphWorkspace(
                    graph: snapshot.data!,
                    selectedNode: selectedNode,
                    onNodeSelected: (node) {
                      setState(() => selectedNode = node);
                    },
                    query: searchController.text,
                    typeFilters: typeFilters,
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  static double _loadingHeight(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return (size.height * .55).clamp(320.0, 580.0).toDouble();
  }
}

List<GraphSummary> _deduplicateGraphs(
    Iterable<GraphSummary> items,
    ) {
  final uniqueById = <String, GraphSummary>{};

  for (final item in items) {
    if (item.id.trim().isEmpty) continue;
    uniqueById.putIfAbsent(item.id, () => item);
  }

  return uniqueById.values.toList(growable: false);
}

class _GraphToolbar extends StatelessWidget {
  const _GraphToolbar({
    required this.items,
    required this.selectedId,
    required this.searchController,
    required this.filterCount,
    required this.onSearchChanged,
    required this.onFilters,
    required this.onSelected,
    required this.onValidate,
    required this.onDelete,
  });

  final List<GraphSummary> items;
  final String selectedId;
  final TextEditingController searchController;
  final int filterCount;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onFilters;
  final ValueChanged<String> onSelected;
  final VoidCallback onValidate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final uniqueItems = _deduplicateGraphs(items);

    final safeSelectedId =
    uniqueItems.any((item) => item.id == selectedId)
        ? selectedId
        : uniqueItems.first.id;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;

            if (width >= 1050) {
              return _buildWide(
                context,
                uniqueItems,
                safeSelectedId,
              );
            }

            return _buildCompact(
              context,
              uniqueItems,
              safeSelectedId,
              veryCompact: width < 430,
            );
          },
        ),
      ),
    );
  }

  Widget _buildWide(
      BuildContext context,
      List<GraphSummary> uniqueItems,
      String safeSelectedId,
      ) {
    return Row(
      children: [
        SizedBox(
          width: 260,
          child: _GraphSelector(
            items: uniqueItems,
            selectedId: safeSelectedId,
            onSelected: onSelected,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: _SearchField(
          controller: searchController,
          onChanged: onSearchChanged,
        )),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: onFilters,
          icon: const Icon(Icons.filter_alt_outlined),
          label: Text(
            filterCount == 0
                ? 'Filtros'
                : 'Filtros ($filterCount)',
          ),
        ),
        const SizedBox(width: 8),
        _DeleteMenu(onDelete: onDelete),
        const SizedBox(width: 8),
        FilledButton.icon(
          onPressed: onValidate,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Validar'),
        ),
      ],
    );
  }

  Widget _buildCompact(
      BuildContext context,
      List<GraphSummary> uniqueItems,
      String safeSelectedId, {
        required bool veryCompact,
      }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GraphSelector(
          items: uniqueItems,
          selectedId: safeSelectedId,
          onSelected: onSelected,
        ),
        const SizedBox(height: 10),
        _SearchField(
          controller: searchController,
          onChanged: onSearchChanged,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            if (!veryCompact)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onFilters,
                  icon: Badge(
                    isLabelVisible: filterCount > 0,
                    label: Text('$filterCount'),
                    child: const Icon(
                      Icons.filter_alt_outlined,
                    ),
                  ),
                  label: const Text('Filtros'),
                ),
              )
            else
              IconButton.filledTonal(
                tooltip: filterCount == 0
                    ? 'Filtros'
                    : 'Filtros ($filterCount)',
                onPressed: onFilters,
                icon: Badge(
                  isLabelVisible: filterCount > 0,
                  label: Text('$filterCount'),
                  child: const Icon(
                    Icons.filter_alt_outlined,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.icon(
                onPressed: onValidate,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Validar'),
              ),
            ),
            const SizedBox(width: 8),
            _DeleteMenu(onDelete: onDelete),
          ],
        ),
      ],
    );
  }
}

class _GraphSelector extends StatelessWidget {
  const _GraphSelector({
    required this.items,
    required this.selectedId,
    required this.onSelected,
  });

  final List<GraphSummary> items;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      // Fuerza a reconstruir el estado interno cuando cambia la selección.
      key: ValueKey(
        'graph-selector-$selectedId-${items.length}',
      ),
      initialValue: selectedId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Seleccionar grafo',
      ),
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item.id,
          child: Text(
            item.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null && value != selectedId) {
          onSelected(value);
        }
      },
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: const InputDecoration(
        hintText: 'Buscar nodo o conexión…',
        prefixIcon: Icon(Icons.search),
      ),
    );
  }
}

class _DeleteMenu extends StatelessWidget {
  const _DeleteMenu({required this.onDelete});

  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Más acciones',
      onSelected: (value) {
        if (value == 'delete') onDelete();
      },
      itemBuilder: (_) => const [
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline),
              SizedBox(width: 10),
              Text('Eliminar grafo'),
            ],
          ),
        ),
      ],
    );
  }
}

class _GraphWorkspace extends ConsumerWidget {
  const _GraphWorkspace({
    required this.graph,
    required this.selectedNode,
    required this.onNodeSelected,
    required this.query,
    required this.typeFilters,
  });

  final SmartGridGraph graph;
  final GridNode? selectedNode;
  final ValueChanged<GridNode> onNodeSelected;
  final String query;
  final Set<String> typeFilters;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final validations =
        ref.watch(validationsFutureProvider).asData?.value ??
            const <ValidationResult>[];

    final related = validations
        .where((item) => item.graphId == graph.id)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final latest = related.isEmpty ? null : related.first;

    final anomalousIds =
        latest?.anomalies
            .expand((item) => item.nodeIds)
            .toSet() ??
            <String>{};

    final activeNode =
        selectedNode ?? _preferredNode(graph.nodes);

    final normalizedQuery = query.trim().toLowerCase();

    final highlightedIds = graph.nodes.where((node) {
      final matchesQuery = normalizedQuery.isEmpty ||
          node.id.toLowerCase().contains(normalizedQuery) ||
          node.label.toLowerCase().contains(normalizedQuery) ||
          node.attributes.values.any(
                (value) => '$value'
                .toLowerCase()
                .contains(normalizedQuery),
          );

      final matchesType =
          typeFilters.isEmpty || typeFilters.contains(node.type);

      return matchesQuery && matchesType;
    }).map((node) => node.id).toSet();

    final hasActiveFilter =
        normalizedQuery.isNotEmpty || typeFilters.isNotEmpty;

    final historyItems = related.where((validation) {
      return validation.anomalies.any((anomaly) {
        return activeNode != null &&
            anomaly.nodeIds.contains(activeNode.id);
      });
    }).toList();

    void showNodeHistory() {
      final size = MediaQuery.sizeOf(context);
      final dialogWidth = math.max(
        180.0,
        math.min(640.0, size.width - 32),
      );
      final dialogHeight = math.max(
        120.0,
        math.min(420.0, size.height - 190),
      );

      showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 20,
            ),
            backgroundColor: AppColors.surface,
            title: Text(
              'Historial del nodo ${activeNode?.id ?? ''}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            content: SizedBox(
              width: dialogWidth,
              height: dialogHeight,
              child: historyItems.isEmpty
                  ? const EmptyPanel(
                message:
                'Este nodo no aparece en anomalías anteriores.',
              )
                  : ListView.separated(
                itemCount: historyItems.length,
                separatorBuilder: (_, __) =>
                const Divider(),
                itemBuilder: (_, index) {
                  final item = historyItems[index];

                  final findings = item.anomalies
                      .where(
                        (anomaly) => anomaly.nodeIds
                        .contains(activeNode!.id),
                  )
                      .toList();

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.history,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      item.graphName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${findings.length} hallazgo(s) · '
                          '${item.createdAt.toLocal()}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing:
                    const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pop(dialogContext);
                      context.go(
                        '/reports?validationId=${item.id}',
                      );
                    },
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cerrar'),
              ),
            ],
          );
        },
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final viewport = MediaQuery.sizeOf(context);

        final desktop = width >= 1150;

        final canvasHeight = desktop
            ? (viewport.height * .68)
            .clamp(500.0, 720.0)
            .toDouble()
            : width >= 700
            ? (viewport.height * .56)
            .clamp(420.0, 620.0)
            .toDouble()
            : (width * .92)
            .clamp(340.0, 520.0)
            .toDouble();

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              clipBehavior: Clip.antiAlias,
              child: desktop
                  ? SizedBox(
                height: canvasHeight,
                child: Row(
                  children: [
                    SizedBox(
                      width: 190,
                      child: _LegendPanel(graph: graph),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: GraphCanvas(
                        graph: graph,
                        anomalousNodeIds: anomalousIds,
                        highlightedNodeIds: hasActiveFilter
                            ? highlightedIds
                            : const <String>{},
                        selectedNodeId: activeNode?.id,
                        onNodeSelected: onNodeSelected,
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    SizedBox(
                      width: 320,
                      child: _NodeDetailsPanel(
                        node: activeNode,
                        graph: graph,
                        anomalousIds: anomalousIds,
                        onHistory: showNodeHistory,
                      ),
                    ),
                  ],
                ),
              )
                  : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _CompactLegend(graph: graph),
                  const Divider(height: 1),
                  SizedBox(
                    height: canvasHeight,
                    width: double.infinity,
                    child: GraphCanvas(
                      graph: graph,
                      anomalousNodeIds: anomalousIds,
                      highlightedNodeIds: hasActiveFilter
                          ? highlightedIds
                          : const <String>{},
                      selectedNodeId: activeNode?.id,
                      onNodeSelected: onNodeSelected,
                    ),
                  ),
                  const Divider(height: 1),
                  _NodeDetailsPanel(
                    node: activeNode,
                    graph: graph,
                    anomalousIds: anomalousIds,
                    compact: true,
                    onHistory: showNodeHistory,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _GraphStats(
              graph: graph,
              anomalies: anomalousIds.length,
            ),
          ],
        );
      },
    );
  }

  static GridNode? _preferredNode(List<GridNode> nodes) {
    if (nodes.isEmpty) return null;

    for (final node in nodes) {
      if (node.type.toLowerCase() == 'transformer') {
        return node;
      }
    }

    return nodes.first;
  }
}

class _CompactLegend extends StatelessWidget {
  const _CompactLegend({required this.graph});

  final SmartGridGraph graph;

  @override
  Widget build(BuildContext context) {
    final types = graph.nodes
        .map((node) => node.type)
        .toSet()
        .take(8)
        .toList();

    return SizedBox(
      height: 58,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        scrollDirection: Axis.horizontal,
        itemCount: types.length,
        separatorBuilder: (_, __) =>
        const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final type = types[index];

          return Chip(
            avatar: CircleAvatar(
              backgroundColor: _LegendPanel.typeColor(type),
              radius: 6,
            ),
            label: Text(
              _LegendPanel.typeLabel(type),
              style: const TextStyle(fontSize: 11),
            ),
          );
        },
      ),
    );
  }
}

class _LegendPanel extends StatelessWidget {
  const _LegendPanel({required this.graph});

  final SmartGridGraph graph;

  @override
  Widget build(BuildContext context) {
    final types =
    graph.nodes.map((node) => node.type).toSet().take(8);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Leyenda',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const Divider(height: 24),
            ...types.map(
                  (type) => _LegendDot(
                color: typeColor(type),
                label: typeLabel(type),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Estados de conexión',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 10),
            const _LegendLine(
              color: AppColors.green,
              label: 'Normal',
            ),
            const _LegendLine(
              color: AppColors.warning,
              label: 'Advertencia',
            ),
            const _LegendLine(
              color: AppColors.danger,
              label: 'Crítico',
            ),
            const _LegendLine(
              color: AppColors.textDim,
              label: 'Desconectado',
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: AppColors.primary,
                    size: 17,
                  ),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Haz clic en un nodo para consultar sus detalles.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color typeColor(String type) {
    switch (type.toLowerCase()) {
      case 'generator':
        return AppColors.green;
      case 'externalgrid':
        return AppColors.purple;
      case 'transformer':
        return AppColors.primary;
      case 'bus':
        return AppColors.cyan;
      case 'meter':
        return AppColors.green;
      case 'load':
        return AppColors.warning;
      case 'storage':
        return const Color(0xFFB5D34B);
      default:
        return AppColors.textMuted;
    }
  }

  static String typeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'generator':
        return 'Generador';
      case 'externalgrid':
        return 'Red externa';
      case 'transformer':
        return 'Transformador';
      case 'bus':
        return 'Bus';
      case 'meter':
        return 'Medidor';
      case 'load':
        return 'Carga';
      case 'storage':
        return 'Almacenamiento';
      default:
        return type;
    }
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendLine extends StatelessWidget {
  const _LegendLine({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Divider(
              color: color,
              thickness: 2,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _NodeDetailsPanel extends StatelessWidget {
  const _NodeDetailsPanel({
    required this.node,
    required this.graph,
    required this.anomalousIds,
    required this.onHistory,
    this.compact = false,
  });

  final GridNode? node;
  final SmartGridGraph graph;
  final Set<String> anomalousIds;
  final VoidCallback onHistory;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final currentNode = node;

    if (currentNode == null) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Text(
            'Selecciona un nodo.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    }

    final anomalous = anomalousIds.contains(currentNode.id);

    final connections = graph.edges
        .where(
          (edge) =>
      edge.source == currentNode.id ||
          edge.target == currentNode.id,
    )
        .toList();

    if (compact) {
      return _CompactNodeDetails(
        node: currentNode,
        connectionCount: connections.length,
        anomalous: anomalous,
        onHistory: onHistory,
      );
    }

    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Detalles del nodo',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor:
                AppColors.primary.withValues(alpha: .16),
                child: Text(_initial(currentNode.id)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentNode.id,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      label(currentNode.type),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              StatusBadge(
                label: anomalous ? 'Anomalía' : 'Normal',
                color: anomalous
                    ? AppColors.danger
                    : AppColors.green,
              ),
            ],
          ),
          const Divider(height: 28),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _DetailRow(
                    label: 'ID del nodo',
                    value: currentNode.id,
                  ),
                  _DetailRow(
                    label: 'Tipo',
                    value: label(currentNode.type),
                  ),
                  ...currentNode.attributes.entries.take(5).map(
                        (entry) => _DetailRow(
                      label: attributeLabel(entry.key),
                      value: '${entry.value}',
                    ),
                  ),
                  const SizedBox(height: 15),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Conexiones (${connections.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...connections.take(4).map((edge) {
                    final other =
                    edge.source == currentNode.id
                        ? edge.target
                        : edge.source;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 7),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.link,
                            size: 15,
                            color: AppColors.green,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              other,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                              const TextStyle(fontSize: 11),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              edge.relation,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onHistory,
            icon: const Icon(Icons.history),
            label: const Text('Ver historial del nodo'),
          ),
        ],
      ),
    );
  }

  static String _initial(String value) {
    final text = value.trim();
    return text.isEmpty ? '?' : text.substring(0, 1).toUpperCase();
  }

  static String label(String type) {
    switch (type.toLowerCase()) {
      case 'externalgrid':
        return 'Red externa';
      case 'generator':
        return 'Generador';
      case 'bus':
        return 'Bus';
      case 'transformer':
        return 'Transformador';
      case 'meter':
        return 'Medidor';
      case 'load':
        return 'Carga';
      case 'storage':
        return 'Almacenamiento';
      default:
        return type;
    }
  }

  static String attributeLabel(String value) {
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) => word.isEmpty
          ? word
          : '${word[0].toUpperCase()}${word.substring(1)}',
    )
        .join(' ');
  }
}

class _CompactNodeDetails extends StatelessWidget {
  const _CompactNodeDetails({
    required this.node,
    required this.connectionCount,
    required this.anomalous,
    required this.onHistory,
  });

  final GridNode node;
  final int connectionCount;
  final bool anomalous;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final veryCompact = constraints.maxWidth < 390;

          final identity = Row(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: (
                    anomalous
                        ? AppColors.danger
                        : AppColors.primary
                ).withValues(alpha: .18),
                child: Text(
                  _NodeDetailsPanel._initial(node.id),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${node.id} · '
                          '${_NodeDetailsPanel.label(node.type)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$connectionCount conexiones · '
                          '${anomalous ? 'Anomalía activa' : 'Estado normal'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: anomalous
                            ? AppColors.danger
                            : AppColors.green,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          if (veryCompact) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
              CrossAxisAlignment.stretch,
              children: [
                identity,
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onHistory,
                  icon: const Icon(Icons.history),
                  label: const Text('Historial'),
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: identity),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: 'Ver historial del nodo',
                onPressed: onHistory,
                icon: const Icon(Icons.history),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 250) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 3),
                SelectableText(
                  value,
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: SelectableText(
                  value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 11),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _GraphStats extends StatelessWidget {
  const _GraphStats({
    required this.graph,
    required this.anomalies,
  });

  final SmartGridGraph graph;
  final int anomalies;

  @override
  Widget build(BuildContext context) {
    int count(String type) {
      return graph.nodes
          .where(
            (node) => node.type.toLowerCase() == type,
      )
          .length;
    }

    final items = <(String, String, IconData, Color)>[
      (
      'Nodos totales',
      '${graph.nodeCount}',
      Icons.hub_outlined,
      AppColors.text,
      ),
      (
      'Generadores',
      '${count('generator')}',
      Icons.bolt,
      AppColors.green,
      ),
      (
      'Red externa',
      '${count('externalgrid')}',
      Icons.public,
      AppColors.purple,
      ),
      (
      'Transformadores',
      '${count('transformer')}',
      Icons.electrical_services,
      AppColors.primary,
      ),
      (
      'Buses',
      '${count('bus')}',
      Icons.device_hub,
      AppColors.cyan,
      ),
      (
      'Medidores',
      '${count('meter')}',
      Icons.speed,
      AppColors.green,
      ),
      (
      'Cargas',
      '${count('load')}',
      Icons.home,
      AppColors.warning,
      ),
      (
      'Almacenamiento',
      '${count('storage')}',
      Icons.battery_charging_full,
      const Color(0xFFB5D34B),
      ),
      (
      'Conexiones',
      '${graph.edgeCount}',
      Icons.link,
      AppColors.textMuted,
      ),
      (
      'Anomalías activas',
      '$anomalies',
      Icons.warning_amber_rounded,
      AppColors.danger,
      ),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;

            final columns = width >= 1200
                ? 5
                : width >= 850
                ? 4
                : width >= 600
                ? 3
                : width >= 360
                ? 2
                : 1;

            const gap = 10.0;
            final itemWidth =
                (width - gap * (columns - 1)) / columns;

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: items.map((item) {
                return SizedBox(
                  width: itemWidth,
                  child: Container(
                    constraints:
                    const BoxConstraints(minHeight: 58),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 7,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          item.$3,
                          color: item.$4,
                          size: 23,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.$1,
                                maxLines: 2,
                                overflow:
                                TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 10,
                                ),
                              ),
                              Text(
                                item.$2,
                                maxLines: 1,
                                overflow:
                                TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight:
                                  FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }
}