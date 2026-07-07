/*
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/file_saver.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/page_frame.dart';
import '../../validation/domain/entities/validation_result.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  final _searchController = TextEditingController();
  String _status = 'all';
  DateTimeRange? _range;
  int _page = 0;
  int _pageSize = 10;
  String? _busyId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _selectRange() async {
    final now = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _range ?? DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now),
      helpText: 'Filtrar historial por fecha',
    );
    if (selected != null) setState(() { _range = selected; _page = 0; });
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() {
      _status = 'all';
      _range = null;
      _page = 0;
    });
  }

  Future<void> _export(ValidationResult item, String format) async {
    if (item.status != 'COMPLETED') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solo las validaciones completadas pueden exportarse.')),
      );
      return;
    }
    setState(() => _busyId = item.id);
    try {
      final file = await ref.read(exportValidationProvider).execute(item.id, format);
      await saveDownloadedFile(file);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Reporte ${format.toUpperCase()} descargado.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _delete(ValidationResult item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Eliminar validación'),
        content: Text('¿Deseas eliminar la ejecución de “${item.graphName}”?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busyId = item.id);
    try {
      await ref.read(validationRepositoryProvider).delete(item.id);
      ref.invalidate(validationsFutureProvider);
      ref.invalidate(dashboardFutureProvider);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(validationsFutureProvider);
    return PageFrame(
      title: 'Historial',
      subtitle: 'Consulta, filtra y exporta las validaciones realizadas.',
      child: state.when(
        loading: () => const LoadingPanel(),
        error: (error, _) => ErrorPanel(error: error, onRetry: () => ref.invalidate(validationsFutureProvider)),
        data: (items) {
          final query = _searchController.text.trim().toLowerCase();
          final filtered = items.where((item) {
            final matchesSearch = query.isEmpty || item.graphName.toLowerCase().contains(query) || item.id.toLowerCase().contains(query);
            final matchesStatus = switch (_status) {
              'clean' => item.status == 'COMPLETED' && item.anomalyCount == 0,
              'issues' => item.status == 'COMPLETED' && item.anomalyCount > 0,
              'failed' => item.status == 'FAILED',
              'cancelled' => item.status == 'CANCELLED',
              _ => true,
            };
            final local = item.createdAt.toLocal();
            final matchesRange = _range == null ||
                (!local.isBefore(DateTime(_range!.start.year, _range!.start.month, _range!.start.day)) &&
                    !local.isAfter(DateTime(_range!.end.year, _range!.end.month, _range!.end.day, 23, 59, 59)));
            return matchesSearch && matchesStatus && matchesRange;
          }).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          final totalPages = filtered.isEmpty ? 1 : (filtered.length / _pageSize).ceil();
          if (_page >= totalPages) _page = totalPages - 1;
          final start = (_page * _pageSize).clamp(0, filtered.length);
          final end = (start + _pageSize).clamp(0, filtered.length);
          final visible = filtered.sublist(start, end);

          return Column(
            children: [
              _HistoryFilters(
                controller: _searchController,
                status: _status,
                range: _range,
                onSearchChanged: (_) => setState(() => _page = 0),
                onStatusChanged: (value) => setState(() { _status = value; _page = 0; }),
                onDateRange: _selectRange,
                onClear: _clearFilters,
              ),
              const SizedBox(height: 14),
              if (filtered.isEmpty)
                const EmptyPanel(message: 'No se encontraron validaciones con los filtros seleccionados.')
              else
                _HistoryResults(
                  items: visible,
                  total: filtered.length,
                  start: start,
                  page: _page,
                  totalPages: totalPages,
                  pageSize: _pageSize,
                  busyId: _busyId,
                  onPageSize: (value) => setState(() { _pageSize = value; _page = 0; }),
                  onPrevious: _page > 0 ? () => setState(() => _page--) : null,
                  onNext: _page + 1 < totalPages ? () => setState(() => _page++) : null,
                  onView: (item) => context.go('/reports?validationId=${item.id}'),
                  onPdf: (item) => _export(item, 'PDF'),
                  onJson: (item) => _export(item, 'JSON'),
                  onDelete: _delete,
                  onRefresh: () => ref.invalidate(validationsFutureProvider),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _HistoryFilters extends StatelessWidget {
  const _HistoryFilters({
    required this.controller,
    required this.status,
    required this.range,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onDateRange,
    required this.onClear,
  });
  final TextEditingController controller;
  final String status;
  final DateTimeRange? range;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onDateRange;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 700;
    final search = TextField(
      controller: controller,
      onChanged: onSearchChanged,
      decoration: const InputDecoration(hintText: 'Buscar por archivo o identificador…', prefixIcon: Icon(Icons.search)),
    );
    final statusField = DropdownButtonFormField<String>(
      value: status,
      decoration: const InputDecoration(labelText: 'Estado'),
      items: const [
        DropdownMenuItem(value: 'all', child: Text('Todos los estados')),
        DropdownMenuItem(value: 'clean', child: Text('Sin anomalías')),
        DropdownMenuItem(value: 'issues', child: Text('Con anomalías')),
        DropdownMenuItem(value: 'failed', child: Text('Fallidas')),
        DropdownMenuItem(value: 'cancelled', child: Text('Canceladas')),
      ],
      onChanged: (value) { if (value != null) onStatusChanged(value); },
    );
    final dateLabel = range == null
        ? 'Últimos 30 días'
        : '${DateFormat('dd/MM/yyyy').format(range!.start)} – ${DateFormat('dd/MM/yyyy').format(range!.end)}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: mobile
            ? Column(
                children: [
                  search,
                  const SizedBox(height: 10),
                  statusField,
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton.icon(onPressed: onDateRange, icon: const Icon(Icons.calendar_today_outlined), label: Text(dateLabel, overflow: TextOverflow.ellipsis))),
                      const SizedBox(width: 8),
                      IconButton.outlined(tooltip: 'Limpiar filtros', onPressed: onClear, icon: const Icon(Icons.filter_alt_off_outlined)),
                    ],
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(flex: 5, child: search),
                  const SizedBox(width: 14),
                  Expanded(flex: 2, child: statusField),
                  const SizedBox(width: 14),
                  Expanded(flex: 3, child: OutlinedButton.icon(onPressed: onDateRange, icon: const Icon(Icons.calendar_today_outlined), label: Text(dateLabel, overflow: TextOverflow.ellipsis))),
                  const SizedBox(width: 14),
                  OutlinedButton.icon(onPressed: onClear, icon: const Icon(Icons.filter_alt_off_outlined), label: const Text('Limpiar')),
                ],
              ),
      ),
    );
  }
}

class _HistoryResults extends StatelessWidget {
  const _HistoryResults({
    required this.items,
    required this.total,
    required this.start,
    required this.page,
    required this.totalPages,
    required this.pageSize,
    required this.busyId,
    required this.onPageSize,
    required this.onPrevious,
    required this.onNext,
    required this.onView,
    required this.onPdf,
    required this.onJson,
    required this.onDelete,
    required this.onRefresh,
  });
  final List<ValidationResult> items;
  final int total, start, page, totalPages, pageSize;
  final String? busyId;
  final ValueChanged<int> onPageSize;
  final VoidCallback? onPrevious, onNext;
  final ValueChanged<ValidationResult> onView, onPdf, onJson, onDelete;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 700;
    if (mobile) {
      return Column(
        children: [
          ...items.map((item) => _HistoryMobileCard(
                item: item,
                busy: busyId == item.id,
                onView: () => onView(item),
                onPdf: () => onPdf(item),
                onDelete: () => onDelete(item),
              )),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: OutlinedButton.icon(onPressed: onRefresh, icon: const Icon(Icons.refresh), label: const Text('Actualizar'))),
              const SizedBox(width: 8),
              IconButton.outlined(onPressed: onPrevious, icon: const Icon(Icons.chevron_left)),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('${page + 1}/$totalPages')),
              IconButton.outlined(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
            ],
          ),
        ],
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: const WidgetStatePropertyAll(AppColors.surfaceAlt),
                columns: const [
                  DataColumn(label: Text('Fecha y hora')),
                  DataColumn(label: Text('Archivo')),
                  DataColumn(label: Text('Estado')),
                  DataColumn(label: Text('Nodos')),
                  DataColumn(label: Text('Conexiones')),
                  DataColumn(label: Text('Anomalías')),
                  DataColumn(label: Text('Reglas')),
                  DataColumn(label: Text('Acciones')),
                ],
                rows: items.map((item) => DataRow(cells: [
                  DataCell(Text(DateFormat('dd/MM/yyyy, hh:mm a').format(item.createdAt.toLocal()))),
                  DataCell(SizedBox(width: 210, child: Text(item.graphName, overflow: TextOverflow.ellipsis))),
                  DataCell(_statusBadge(item)),
                  DataCell(Text('${item.nodesAnalyzed}')),
                  DataCell(Text('${item.edgesAnalyzed}')),
                  DataCell(Text('${item.anomalyCount}', style: TextStyle(color: item.anomalyCount == 0 ? AppColors.green : AppColors.danger))),
                  DataCell(Text('${item.rulesPassed}/${item.rulesEvaluated}')),
                  DataCell(busyId == item.id
                      ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(tooltip: 'Ver reporte', onPressed: () => onView(item), icon: const Icon(Icons.visibility_outlined, size: 19)),
                          PopupMenuButton<String>(
                            tooltip: 'Más acciones',
                            onSelected: (value) {
                              if (value == 'pdf') onPdf(item);
                              if (value == 'json') onJson(item);
                              if (value == 'delete') onDelete(item);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'pdf', child: Text('Descargar PDF')),
                              PopupMenuItem(value: 'json', child: Text('Descargar JSON')),
                              PopupMenuDivider(),
                              PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                            ],
                          ),
                        ])),
                ])).toList(),
              ),
            ),
            const Divider(),
            Row(
              children: [
                Expanded(child: Text('Mostrando ${start + 1} a ${start + items.length} de $total resultados', style: const TextStyle(color: AppColors.textMuted, fontSize: 11))),
                DropdownButton<int>(
                  value: pageSize,
                  items: const [10, 25, 50].map((value) => DropdownMenuItem(value: value, child: Text('$value por página'))).toList(),
                  onChanged: (value) { if (value != null) onPageSize(value); },
                ),
                IconButton(onPressed: onPrevious, icon: const Icon(Icons.chevron_left)),
                StatusBadge(label: '${page + 1}', color: AppColors.primary),
                IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
                IconButton(tooltip: 'Actualizar', onPressed: onRefresh, icon: const Icon(Icons.refresh)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _statusBadge(ValidationResult item) {
    if (item.status == 'FAILED') return const StatusBadge(label: 'Fallida', color: AppColors.danger);
    if (item.status == 'CANCELLED') return const StatusBadge(label: 'Cancelada', color: AppColors.textDim);
    return StatusBadge(
      label: item.anomalyCount == 0 ? 'Completada' : 'Con observaciones',
      color: item.anomalyCount == 0 ? AppColors.green : AppColors.warning,
    );
  }
}

class _HistoryMobileCard extends StatelessWidget {
  const _HistoryMobileCard({required this.item, required this.busy, required this.onView, required this.onPdf, required this.onDelete});
  final ValidationResult item;
  final bool busy;
  final VoidCallback onView, onPdf, onDelete;
  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          onTap: busy ? null : onView,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                busy
                    ? const SizedBox.square(dimension: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.description_outlined, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.graphName, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(DateFormat('dd MMM yyyy, hh:mm a').format(item.createdAt.toLocal()), style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                    const SizedBox(height: 8),
                    StatusBadge(
                      label: item.status == 'FAILED'
                          ? 'Fallida'
                          : item.anomalyCount == 0
                              ? 'Sin anomalías'
                              : '${item.anomalyCount} ${item.anomalyCount == 1 ? 'anomalía' : 'anomalías'}',
                      color: item.status == 'FAILED'
                          ? AppColors.danger
                          : item.anomalyCount == 0
                              ? AppColors.green
                              : item.anomalyCount > 2 ? AppColors.danger : AppColors.warning,
                    ),
                  ]),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'view') onView();
                    if (value == 'pdf') onPdf();
                    if (value == 'delete') onDelete();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'view', child: Text('Ver reporte')),
                    PopupMenuItem(value: 'pdf', child: Text('Descargar PDF')),
                    PopupMenuDivider(),
                    PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}
*/
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/file_saver.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/page_frame.dart';
import '../../validation/domain/entities/validation_result.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  final _searchController = TextEditingController();

  String _status = 'all';
  DateTimeRange? _range;
  int _page = 0;
  int _pageSize = 10;
  String? _busyId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _selectRange() async {
    final now = DateTime.now();

    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _range ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          ),
      helpText: 'Filtrar historial por fecha',
    );

    if (selected == null || !mounted) return;

    setState(() {
      _range = selected;
      _page = 0;
    });
  }

  void _clearFilters() {
    _searchController.clear();

    setState(() {
      _status = 'all';
      _range = null;
      _page = 0;
    });
  }

  Future<void> _export(
      ValidationResult item,
      String format,
      ) async {
    if (item.status.toUpperCase() != 'COMPLETED') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Solo las validaciones completadas pueden exportarse.',
          ),
        ),
      );
      return;
    }

    setState(() => _busyId = item.id);

    try {
      final file = await ref
          .read(exportValidationProvider)
          .execute(item.id, format);

      await saveDownloadedFile(file);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reporte ${format.toUpperCase()} descargado.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      if (mounted) {
        setState(() => _busyId = null);
      }
    }
  }

  Future<void> _delete(ValidationResult item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 24,
        ),
        backgroundColor: AppColors.surface,
        title: const Text('Eliminar validación'),
        content: Text(
          '¿Deseas eliminar la ejecución de “${item.graphName}”?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              false,
            ),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              true,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _busyId = item.id);

    try {
      await ref
          .read(validationRepositoryProvider)
          .delete(item.id);

      ref.invalidate(validationsFutureProvider);
      ref.invalidate(dashboardFutureProvider);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      if (mounted) {
        setState(() => _busyId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(validationsFutureProvider);

    return PageFrame(
      title: 'Historial',
      subtitle:
      'Consulta, filtra y exporta las validaciones realizadas.',
      child: state.when(
        loading: () => const LoadingPanel(),
        error: (error, _) => ErrorPanel(
          error: error,
          onRetry: () {
            ref.invalidate(validationsFutureProvider);
          },
        ),
        data: (items) {
          final query =
          _searchController.text.trim().toLowerCase();

          final filtered = items.where((item) {
            final matchesSearch = query.isEmpty ||
                item.graphName.toLowerCase().contains(query) ||
                item.id.toLowerCase().contains(query);

            final normalizedStatus =
            item.status.toUpperCase();

            final matchesStatus = switch (_status) {
              'clean' =>
              normalizedStatus == 'COMPLETED' &&
                  item.anomalyCount == 0,
              'issues' =>
              normalizedStatus == 'COMPLETED' &&
                  item.anomalyCount > 0,
              'failed' => normalizedStatus == 'FAILED',
              'cancelled' => normalizedStatus == 'CANCELLED',
              _ => true,
            };

            final local = item.createdAt.toLocal();

            final matchesRange = _range == null ||
                (!local.isBefore(
                  DateTime(
                    _range!.start.year,
                    _range!.start.month,
                    _range!.start.day,
                  ),
                ) &&
                    !local.isAfter(
                      DateTime(
                        _range!.end.year,
                        _range!.end.month,
                        _range!.end.day,
                        23,
                        59,
                        59,
                      ),
                    ));

            return matchesSearch &&
                matchesStatus &&
                matchesRange;
          }).toList()
            ..sort(
                  (a, b) => b.createdAt.compareTo(a.createdAt),
            );

          final totalPages = filtered.isEmpty
              ? 1
              : (filtered.length / _pageSize).ceil();

          final effectivePage =
          _page.clamp(0, totalPages - 1);

          if (effectivePage != _page) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || _page == effectivePage) return;

              setState(() => _page = effectivePage);
            });
          }

          final start =
          (effectivePage * _pageSize).clamp(
            0,
            filtered.length,
          );

          final end = (start + _pageSize).clamp(
            0,
            filtered.length,
          );

          final visible = filtered.sublist(start, end);

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _HistoryFilters(
                controller: _searchController,
                status: _status,
                range: _range,
                onSearchChanged: (_) {
                  setState(() => _page = 0);
                },
                onStatusChanged: (value) {
                  setState(() {
                    _status = value;
                    _page = 0;
                  });
                },
                onDateRange: _selectRange,
                onClear: _clearFilters,
              ),
              const SizedBox(height: 14),
              if (filtered.isEmpty)
                const EmptyPanel(
                  message:
                  'No se encontraron validaciones con los filtros seleccionados.',
                )
              else
                _HistoryResults(
                  items: visible,
                  total: filtered.length,
                  start: start,
                  page: effectivePage,
                  totalPages: totalPages,
                  pageSize: _pageSize,
                  busyId: _busyId,
                  onPageSize: (value) {
                    setState(() {
                      _pageSize = value;
                      _page = 0;
                    });
                  },
                  onPrevious: effectivePage > 0
                      ? () {
                    setState(() => _page--);
                  }
                      : null,
                  onNext:
                  effectivePage + 1 < totalPages
                      ? () {
                    setState(() => _page++);
                  }
                      : null,
                  onView: (item) {
                    context.go(
                      '/reports?validationId=${item.id}',
                    );
                  },
                  onPdf: (item) => _export(item, 'PDF'),
                  onJson: (item) => _export(item, 'JSON'),
                  onDelete: _delete,
                  onRefresh: () {
                    ref.invalidate(
                      validationsFutureProvider,
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

class _HistoryFilters extends StatelessWidget {
  const _HistoryFilters({
    required this.controller,
    required this.status,
    required this.range,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onDateRange,
    required this.onClear,
  });

  final TextEditingController controller;
  final String status;
  final DateTimeRange? range;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onDateRange;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final dateLabel = range == null
        ? 'Últimos 30 días'
        : '${DateFormat('dd/MM/yyyy').format(range!.start)} – '
        '${DateFormat('dd/MM/yyyy').format(range!.end)}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;

            final search = _HistorySearchField(
              controller: controller,
              onChanged: onSearchChanged,
            );

            final statusField = _HistoryStatusDropdown(
              value: status,
              onChanged: onStatusChanged,
            );

            final dateButton = OutlinedButton.icon(
              onPressed: onDateRange,
              icon: const Icon(
                Icons.calendar_today_outlined,
              ),
              label: Text(
                dateLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );

            if (width >= 1020) {
              return Row(
                children: [
                  Expanded(flex: 5, child: search),
                  const SizedBox(width: 14),
                  Expanded(flex: 2, child: statusField),
                  const SizedBox(width: 14),
                  Expanded(flex: 3, child: dateButton),
                  const SizedBox(width: 14),
                  OutlinedButton.icon(
                    onPressed: onClear,
                    icon: const Icon(
                      Icons.filter_alt_off_outlined,
                    ),
                    label: const Text('Limpiar'),
                  ),
                ],
              );
            }

            if (width >= 620) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                CrossAxisAlignment.stretch,
                children: [
                  search,
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: statusField),
                      const SizedBox(width: 10),
                      Expanded(child: dateButton),
                      const SizedBox(width: 10),
                      IconButton.outlined(
                        tooltip: 'Limpiar filtros',
                        onPressed: onClear,
                        icon: const Icon(
                          Icons.filter_alt_off_outlined,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }

            if (width >= 390) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                CrossAxisAlignment.stretch,
                children: [
                  search,
                  const SizedBox(height: 10),
                  statusField,
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: dateButton),
                      const SizedBox(width: 8),
                      IconButton.outlined(
                        tooltip: 'Limpiar filtros',
                        onPressed: onClear,
                        icon: const Icon(
                          Icons.filter_alt_off_outlined,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
              CrossAxisAlignment.stretch,
              children: [
                search,
                const SizedBox(height: 10),
                statusField,
                const SizedBox(height: 10),
                dateButton,
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: onClear,
                  icon: const Icon(
                    Icons.filter_alt_off_outlined,
                  ),
                  label: const Text('Limpiar filtros'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HistorySearchField extends StatelessWidget {
  const _HistorySearchField({
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
        hintText: 'Buscar por archivo o identificador…',
        prefixIcon: Icon(Icons.search),
      ),
    );
  }
}

class _HistoryStatusDropdown extends StatelessWidget {
  const _HistoryStatusDropdown({
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  static const _items = <(String, String)>[
    ('all', 'Todos los estados'),
    ('clean', 'Sin anomalías'),
    ('issues', 'Con anomalías'),
    ('failed', 'Fallidas'),
    ('cancelled', 'Canceladas'),
  ];

  @override
  Widget build(BuildContext context) {
    final safeValue = _items.any((item) => item.$1 == value)
        ? value
        : 'all';

    return DropdownButtonFormField<String>(
      key: ValueKey('history-status-$safeValue'),
      initialValue: safeValue,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Estado',
      ),
      selectedItemBuilder: (context) {
        return _items.map((item) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Text(
              item.$2,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList();
      },
      items: _items.map((item) {
        return DropdownMenuItem<String>(
          value: item.$1,
          child: Text(
            item.$2,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (newValue) {
        if (newValue != null && newValue != safeValue) {
          onChanged(newValue);
        }
      },
    );
  }
}

class _HistoryResults extends StatelessWidget {
  const _HistoryResults({
    required this.items,
    required this.total,
    required this.start,
    required this.page,
    required this.totalPages,
    required this.pageSize,
    required this.busyId,
    required this.onPageSize,
    required this.onPrevious,
    required this.onNext,
    required this.onView,
    required this.onPdf,
    required this.onJson,
    required this.onDelete,
    required this.onRefresh,
  });

  final List<ValidationResult> items;
  final int total;
  final int start;
  final int page;
  final int totalPages;
  final int pageSize;
  final String? busyId;
  final ValueChanged<int> onPageSize;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<ValidationResult> onView;
  final ValueChanged<ValidationResult> onPdf;
  final ValueChanged<ValidationResult> onJson;
  final ValueChanged<ValidationResult> onDelete;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 820) {
          return _HistoryResponsiveCards(
            items: items,
            total: total,
            start: start,
            page: page,
            totalPages: totalPages,
            pageSize: pageSize,
            busyId: busyId,
            onPageSize: onPageSize,
            onPrevious: onPrevious,
            onNext: onNext,
            onView: onView,
            onPdf: onPdf,
            onJson: onJson,
            onDelete: onDelete,
            onRefresh: onRefresh,
          );
        }

        return _HistoryDesktopTable(
          items: items,
          total: total,
          start: start,
          page: page,
          totalPages: totalPages,
          pageSize: pageSize,
          busyId: busyId,
          onPageSize: onPageSize,
          onPrevious: onPrevious,
          onNext: onNext,
          onView: onView,
          onPdf: onPdf,
          onJson: onJson,
          onDelete: onDelete,
          onRefresh: onRefresh,
        );
      },
    );
  }

  static Widget statusBadge(ValidationResult item) {
    final normalized = item.status.toUpperCase();

    if (normalized == 'FAILED') {
      return const StatusBadge(
        label: 'Fallida',
        color: AppColors.danger,
      );
    }

    if (normalized == 'CANCELLED') {
      return const StatusBadge(
        label: 'Cancelada',
        color: AppColors.textDim,
      );
    }

    return StatusBadge(
      label: item.anomalyCount == 0
          ? 'Completada'
          : 'Con observaciones',
      color: item.anomalyCount == 0
          ? AppColors.green
          : AppColors.warning,
    );
  }
}

class _HistoryResponsiveCards extends StatelessWidget {
  const _HistoryResponsiveCards({
    required this.items,
    required this.total,
    required this.start,
    required this.page,
    required this.totalPages,
    required this.pageSize,
    required this.busyId,
    required this.onPageSize,
    required this.onPrevious,
    required this.onNext,
    required this.onView,
    required this.onPdf,
    required this.onJson,
    required this.onDelete,
    required this.onRefresh,
  });

  final List<ValidationResult> items;
  final int total;
  final int start;
  final int page;
  final int totalPages;
  final int pageSize;
  final String? busyId;
  final ValueChanged<int> onPageSize;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<ValidationResult> onView;
  final ValueChanged<ValidationResult> onPdf;
  final ValueChanged<ValidationResult> onJson;
  final ValueChanged<ValidationResult> onDelete;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...items.map(
              (item) => _HistoryMobileCard(
            item: item,
            busy: busyId == item.id,
            onView: () => onView(item),
            onPdf: () => onPdf(item),
            onJson: () => onJson(item),
            onDelete: () => onDelete(item),
          ),
        ),
        const SizedBox(height: 8),
        _ResponsivePagination(
          total: total,
          start: start,
          visibleCount: items.length,
          page: page,
          totalPages: totalPages,
          pageSize: pageSize,
          onPageSize: onPageSize,
          onPrevious: onPrevious,
          onNext: onNext,
          onRefresh: onRefresh,
        ),
      ],
    );
  }
}

class _HistoryDesktopTable extends StatelessWidget {
  const _HistoryDesktopTable({
    required this.items,
    required this.total,
    required this.start,
    required this.page,
    required this.totalPages,
    required this.pageSize,
    required this.busyId,
    required this.onPageSize,
    required this.onPrevious,
    required this.onNext,
    required this.onView,
    required this.onPdf,
    required this.onJson,
    required this.onDelete,
    required this.onRefresh,
  });

  final List<ValidationResult> items;
  final int total;
  final int start;
  final int page;
  final int totalPages;
  final int pageSize;
  final String? busyId;
  final ValueChanged<int> onPageSize;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final ValueChanged<ValidationResult> onView;
  final ValueChanged<ValidationResult> onPdf;
  final ValueChanged<ValidationResult> onJson;
  final ValueChanged<ValidationResult> onDelete;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor:
                const WidgetStatePropertyAll(
                  AppColors.surfaceAlt,
                ),
                columns: const [
                  DataColumn(label: Text('Fecha y hora')),
                  DataColumn(label: Text('Archivo')),
                  DataColumn(label: Text('Estado')),
                  DataColumn(label: Text('Nodos')),
                  DataColumn(label: Text('Conexiones')),
                  DataColumn(label: Text('Anomalías')),
                  DataColumn(label: Text('Reglas')),
                  DataColumn(label: Text('Acciones')),
                ],
                rows: items.map((item) {
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          DateFormat('dd/MM/yyyy, hh:mm a')
                              .format(
                            item.createdAt.toLocal(),
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 210,
                          child: Text(
                            item.graphName,
                            maxLines: 1,
                            overflow:
                            TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(
                        _HistoryResults.statusBadge(item),
                      ),
                      DataCell(
                        Text('${item.nodesAnalyzed}'),
                      ),
                      DataCell(
                        Text('${item.edgesAnalyzed}'),
                      ),
                      DataCell(
                        Text(
                          '${item.anomalyCount}',
                          style: TextStyle(
                            color: item.anomalyCount == 0
                                ? AppColors.green
                                : AppColors.danger,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          '${item.rulesPassed}/'
                              '${item.rulesEvaluated}',
                        ),
                      ),
                      DataCell(
                        busyId == item.id
                            ? const SizedBox.square(
                          dimension: 20,
                          child:
                          CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                            : Row(
                          mainAxisSize:
                          MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Ver reporte',
                              onPressed: () =>
                                  onView(item),
                              icon: const Icon(
                                Icons
                                    .visibility_outlined,
                                size: 19,
                              ),
                            ),
                            PopupMenuButton<String>(
                              tooltip: 'Más acciones',
                              onSelected: (value) {
                                if (value == 'pdf') {
                                  onPdf(item);
                                }
                                if (value == 'json') {
                                  onJson(item);
                                }
                                if (value == 'delete') {
                                  onDelete(item);
                                }
                              },
                              itemBuilder: (_) =>
                              const [
                                PopupMenuItem(
                                  value: 'pdf',
                                  child: Text(
                                    'Descargar PDF',
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'json',
                                  child: Text(
                                    'Descargar JSON',
                                  ),
                                ),
                                PopupMenuDivider(),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(
                                    'Eliminar',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
            const Divider(),
            _ResponsivePagination(
              total: total,
              start: start,
              visibleCount: items.length,
              page: page,
              totalPages: totalPages,
              pageSize: pageSize,
              onPageSize: onPageSize,
              onPrevious: onPrevious,
              onNext: onNext,
              onRefresh: onRefresh,
            ),
          ],
        ),
      ),
    );
  }
}

class _ResponsivePagination extends StatelessWidget {
  const _ResponsivePagination({
    required this.total,
    required this.start,
    required this.visibleCount,
    required this.page,
    required this.totalPages,
    required this.pageSize,
    required this.onPageSize,
    required this.onPrevious,
    required this.onNext,
    required this.onRefresh,
  });

  final int total;
  final int start;
  final int visibleCount;
  final int page;
  final int totalPages;
  final int pageSize;
  final ValueChanged<int> onPageSize;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final firstVisible = total == 0 ? 0 : start + 1;
    final lastVisible = start + visibleCount;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final summary = Text(
          'Mostrando $firstVisible a $lastVisible '
              'de $total resultados',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
          ),
        );

        final navigation = Wrap(
          spacing: 4,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            IconButton.outlined(
              tooltip: 'Página anterior',
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 42),
              child: Text(
                '${page + 1}/$totalPages',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            IconButton.outlined(
              tooltip: 'Página siguiente',
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        );

        Widget pageSizeField({double? fieldWidth}) {
          final field = _PageSizeDropdown(
            value: pageSize,
            onChanged: onPageSize,
          );

          if (fieldWidth == null) {
            return field;
          }

          return SizedBox(
            width: fieldWidth,
            child: field,
          );
        }

        if (width >= 900) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: summary),
              const SizedBox(width: 16),

              // DropdownButtonFormField con isExpanded necesita
              // un ancho horizontal finito dentro de un Row.
              pageSizeField(fieldWidth: 190),
              const SizedBox(width: 12),

              navigation,
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Actualizar',
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          );
        }

        if (width >= 520) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              summary,
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  pageSizeField(
                    fieldWidth: width >= 700 ? 220 : 190,
                  ),
                  navigation,
                  IconButton.outlined(
                    tooltip: 'Actualizar',
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ],
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            summary,
            const SizedBox(height: 10),
            pageSizeField(),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                navigation,
                IconButton.outlined(
                  tooltip: 'Actualizar',
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _PageSizeDropdown extends StatelessWidget {
  const _PageSizeDropdown({
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  static const _sizes = [10, 25, 50];

  @override
  Widget build(BuildContext context) {
    final safeValue =
    _sizes.contains(value) ? value : _sizes.first;

    return DropdownButtonFormField<int>(
      key: ValueKey('history-page-size-$safeValue'),
      initialValue: safeValue,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Resultados por página',
        isDense: true,
      ),
      selectedItemBuilder: (context) {
        return _sizes.map((size) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '$size por página',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList();
      },
      items: _sizes.map((size) {
        return DropdownMenuItem<int>(
          value: size,
          child: Text('$size por página'),
        );
      }).toList(),
      onChanged: (newValue) {
        if (newValue != null && newValue != safeValue) {
          onChanged(newValue);
        }
      },
    );
  }
}

class _HistoryMobileCard extends StatelessWidget {
  const _HistoryMobileCard({
    required this.item,
    required this.busy,
    required this.onView,
    required this.onPdf,
    required this.onJson,
    required this.onDelete,
  });

  final ValidationResult item;
  final bool busy;
  final VoidCallback onView;
  final VoidCallback onPdf;
  final VoidCallback onJson;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final normalizedStatus = item.status.toUpperCase();

    final badgeLabel = normalizedStatus == 'FAILED'
        ? 'Fallida'
        : normalizedStatus == 'CANCELLED'
        ? 'Cancelada'
        : item.anomalyCount == 0
        ? 'Sin anomalías'
        : '${item.anomalyCount} '
        '${item.anomalyCount == 1 ? 'anomalía' : 'anomalías'}';

    final badgeColor = normalizedStatus == 'FAILED'
        ? AppColors.danger
        : normalizedStatus == 'CANCELLED'
        ? AppColors.textDim
        : item.anomalyCount == 0
        ? AppColors.green
        : item.anomalyCount > 2
        ? AppColors.danger
        : AppColors.warning;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: busy ? null : onView,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final veryCompact =
                  constraints.maxWidth < 340;

              final leading = busy
                  ? const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
                  : const Icon(
                Icons.description_outlined,
                color: AppColors.primary,
              );

              final content = Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    item.graphName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('dd MMM yyyy, hh:mm a')
                        .format(item.createdAt.toLocal()),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 8),
                  StatusBadge(
                    label: badgeLabel,
                    color: badgeColor,
                  ),
                ],
              );

              final menu = PopupMenuButton<String>(
                enabled: !busy,
                tooltip: 'Más acciones',
                onSelected: (value) {
                  if (value == 'view') onView();
                  if (value == 'pdf') onPdf();
                  if (value == 'json') onJson();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'view',
                    child: Text('Ver reporte'),
                  ),
                  PopupMenuItem(
                    value: 'pdf',
                    child: Text('Descargar PDF'),
                  ),
                  PopupMenuItem(
                    value: 'json',
                    child: Text('Descargar JSON'),
                  ),
                  PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Eliminar'),
                  ),
                ],
              );

              if (veryCompact) {
                return Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        leading,
                        const SizedBox(width: 10),
                        Expanded(child: content),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: menu,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  leading,
                  const SizedBox(width: 12),
                  Expanded(child: content),
                  menu,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
