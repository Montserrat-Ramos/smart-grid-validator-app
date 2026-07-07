/*
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../core/utils/file_saver.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/page_frame.dart';
import '../../validation/domain/entities/validation_result.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({this.initialValidationId, super.key});
  final String? initialValidationId;

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  String? selectedId;

  @override
  void initState() {
    super.initState();
    selectedId = widget.initialValidationId;
  }
  String statusFilter = 'all';
  bool exporting = false;

  Future<void> _export(ValidationResult validation, String format) async {
    if (validation.status != 'COMPLETED') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solo las validaciones completadas pueden exportarse.')),
      );
      return;
    }
    setState(() => exporting = true);
    try {
      final file = await ref.read(exportValidationProvider).execute(validation.id, format);
      await saveDownloadedFile(file);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reporte ${format.toUpperCase()} generado correctamente.')),
        );
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => exporting = false);
    }
  }

  Future<void> _share(ValidationResult validation) async {
    final text = 'Smart Grid Validator · ${validation.graphName}\n'
        '${validation.anomalyCount} anomalías · '
        '${validation.rulesPassed}/${validation.rulesEvaluated} reglas cumplidas\n'
        '${validation.createdAt.toLocal()}';
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Resumen copiado al portapapeles.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(validationsFutureProvider);
    final desktop = MediaQuery.sizeOf(context).width >= 700;
    return PageFrame(
      title: 'Reportes',
      subtitle: 'Genera y comparte informes de validación de tu sistema.',
      actions: desktop
          ? [
              IconButton(
                tooltip: 'Notificaciones',
                onPressed: () => context.go('/history'),
                icon: const Icon(Icons.notifications_none),
              ),
            ]
          : const [],
      child: state.when(
        loading: () => const LoadingPanel(),
        error: (error, _) => ErrorPanel(
          error: error,
          onRetry: () => ref.invalidate(validationsFutureProvider),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyPanel(message: 'Aún no existen validaciones para generar reportes.');
          }
          final sorted = [...items]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          final filtered = statusFilter == 'all'
              ? sorted
              : sorted.where((item) => item.status.toLowerCase() == statusFilter).toList();
          final available = filtered.isEmpty ? sorted : filtered;
          if (selectedId == null || !available.any((item) => item.id == selectedId)) {
            selectedId = available.first.id;
          }
          final selected = available.firstWhere((item) => item.id == selectedId);
          return _ReportsContent(
            items: available,
            selected: selected,
            statusFilter: statusFilter,
            exporting: exporting,
            onStatusChanged: (value) => setState(() {
              statusFilter = value;
              selectedId = null;
            }),
            onSelected: (value) => setState(() => selectedId = value),
            onRefresh: () => ref.invalidate(validationsFutureProvider),
            onExportPdf: () => _export(selected, 'PDF'),
            onExportJson: () => _export(selected, 'JSON'),
            onShare: () => _share(selected),
          );
        },
      ),
    );
  }
}

class _ReportsContent extends StatelessWidget {
  const _ReportsContent({
    required this.items,
    required this.selected,
    required this.statusFilter,
    required this.exporting,
    required this.onSelected,
    required this.onStatusChanged,
    required this.onRefresh,
    required this.onExportPdf,
    required this.onExportJson,
    required this.onShare,
  });

  final List<ValidationResult> items;
  final ValidationResult selected;
  final String statusFilter;
  final bool exporting;
  final ValueChanged<String> onSelected;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onRefresh;
  final VoidCallback onExportPdf;
  final VoidCallback onExportJson;
  final VoidCallback onShare;

  void _showAllAnomalies(BuildContext context, ValidationResult validation) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Anomalías · ${validation.graphName}'),
        content: SizedBox(
          width: 720,
          height: 480,
          child: validation.anomalies.isEmpty
              ? const EmptyPanel(message: 'No se detectaron anomalías.', icon: Icons.check_circle_outline)
              : ListView.separated(
                  itemCount: validation.anomalies.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (_, index) => _AnomalyMobileCard(item: validation.anomalies[index]),
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 700;
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: mobile
                ? Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: selected.id,
                        decoration: const InputDecoration(labelText: 'Ejecución de validación'),
                        items: items
                            .map(
                              (item) => DropdownMenuItem(
                                value: item.id,
                                child: Text(item.graphName, overflow: TextOverflow.ellipsis),
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
                            child: DropdownButtonFormField<String>(
                              initialValue: statusFilter,
                              decoration: const InputDecoration(labelText: 'Estado del reporte'),
                              items: const [
                                DropdownMenuItem(value: 'all', child: Text('Todos los estados')),
                                DropdownMenuItem(value: 'completed', child: Text('Completados')),
                                DropdownMenuItem(value: 'failed', child: Text('Fallidos')),
                                DropdownMenuItem(value: 'cancelled', child: Text('Cancelados')),
                              ],
                              onChanged: (value) {
                                if (value != null) onStatusChanged(value);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton.filledTonal(
                            onPressed: onRefresh,
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: selected.id,
                          decoration: const InputDecoration(labelText: 'Ejecución de validación'),
                          items: items
                              .map(
                                (item) => DropdownMenuItem(
                                  value: item.id,
                                  child: Text(item.graphName, overflow: TextOverflow.ellipsis),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) onSelected(value);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          initialValue: statusFilter,
                          decoration: const InputDecoration(labelText: 'Estado del reporte'),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('Todos los estados')),
                            DropdownMenuItem(value: 'completed', child: Text('Completados')),
                            DropdownMenuItem(value: 'failed', child: Text('Fallidos')),
                            DropdownMenuItem(value: 'cancelled', child: Text('Cancelados')),
                          ],
                          onChanged: (value) {
                            if (value != null) onStatusChanged(value);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      OutlinedButton.icon(
                        onPressed: onRefresh,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Actualizar datos'),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1050 ? 4 : 2;
            final gap = 12.0;
            final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
            final metrics = [
              MetricCard(label: 'Nodos analizados', value: '${selected.nodesAnalyzed}', icon: Icons.hub_outlined, accent: AppColors.primary, compact: mobile),
              MetricCard(label: 'Conexiones analizadas', value: '${selected.edgesAnalyzed}', icon: Icons.link, accent: AppColors.green, compact: mobile),
              MetricCard(label: 'Anomalías detectadas', value: '${selected.anomalyCount}', icon: Icons.warning_amber_rounded, accent: AppColors.warning, compact: mobile),
              MetricCard(label: 'Reglas aplicadas', value: '${selected.rulesEvaluated}', icon: Icons.verified_user_outlined, accent: AppColors.purple, compact: mobile),
            ];
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: metrics.map((metric) => SizedBox(width: width, child: metric)).toList(),
            );
          },
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 980;
            final donut = SectionCard(
              title: 'Severidad de anomalías',
              action: TextButton(
                onPressed: () => _showAllAnomalies(context, selected),
                child: const Text('Ver todas las anomalías'),
              ),
              child: SizedBox(
                height: 220,
                child: _SeverityChart(validation: selected),
              ),
            );
            final trend = SectionCard(
              title: 'Anomalías en el tiempo',
              action: const StatusBadge(label: 'Últimos 7 días', color: AppColors.primary),
              child: SizedBox(
                height: 220,
                child: _TrendChart(values: items.take(7).toList().reversed.toList()),
              ),
            );
            final preview = SectionCard(
              title: 'Vista previa del reporte',
              child: SizedBox(
                height: 220,
                child: _ReportPreview(validation: selected, onOpen: onExportPdf),
              ),
            );
            if (!desktop) {
              return Column(
                children: [
                  donut,
                  const SizedBox(height: 14),
                  trend,
                  const SizedBox(height: 14),
                  preview,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 4, child: donut),
                const SizedBox(width: 14),
                Expanded(flex: 6, child: trend),
                const SizedBox(width: 14),
                Expanded(flex: 4, child: preview),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        _AnomalyTable(validation: selected),
        const SizedBox(height: 14),
        _ReportActions(
          exporting: exporting,
          onPdf: onExportPdf,
          onJson: onExportJson,
          onShare: onShare,
          onHistory: () => context.go('/history'),
        ),
      ],
    );
  }
}

class _SeverityChart extends StatelessWidget {
  const _SeverityChart({required this.validation});

  final ValidationResult validation;

  @override
  Widget build(BuildContext context) {
    final severity = validation.severityCounts;
    final counts = <String, int>{
      'Críticas': severity['CRITICAL'] ?? 0,
      'Altas': severity['HIGH'] ?? 0,
      'Medias': severity['MEDIUM'] ?? 0,
      'Bajas': severity['LOW'] ?? 0,
    };
    final values = counts.values.toList();
    final totalFromSeverity = values.fold<int>(0, (sum, value) => sum + value);
    final total = validation.anomalyCount > 0
        ? validation.anomalyCount
        : totalFromSeverity;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 300;
        final chart = CustomPaint(
          painter: _DonutPainter(values),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$total',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
                ),
                const Text(
                  'Total anomalías',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                ),
              ],
            ),
          ),
        );
        final legend = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendCount(label: 'Críticas', value: counts['Críticas']!, color: AppColors.danger),
            _LegendCount(label: 'Altas', value: counts['Altas']!, color: const Color(0xFFFF7A26)),
            _LegendCount(label: 'Medias', value: counts['Medias']!, color: AppColors.warning),
            _LegendCount(label: 'Bajas', value: counts['Bajas']!, color: AppColors.green),
          ],
        );

        if (compact) {
          return Column(
            children: [
              Expanded(child: chart),
              legend,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: chart),
            const SizedBox(width: 10),
            Expanded(child: legend),
          ],
        );
      },
    );
  }
}

class _LegendCount extends StatelessWidget {
  const _LegendCount({required this.label, required this.value, required this.color});
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 7),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 11))),
            Text('$value', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          ],
        ),
      );
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.values);
  final List<int> values;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<int>(0, (sum, value) => sum + value);
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: math.min(size.width, size.height) * .32,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.butt;

    paint.color = AppColors.border.withValues(alpha: .65);
    canvas.drawArc(rect, 0, math.pi * 2, false, paint);
    if (total == 0) return;

    final colors = [
      AppColors.danger,
      const Color(0xFFFF7A26),
      AppColors.warning,
      AppColors.green,
    ];
    var start = -math.pi / 2;
    for (var index = 0; index < values.length; index++) {
      final value = values[index];
      if (value <= 0) continue;
      final sweep = math.pi * 2 * value / total;
      paint.color = colors[index];
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) => oldDelegate.values != values;
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.values});
  final List<ValidationResult> values;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _LinePainter(values.map((item) => item.anomalyCount.toDouble()).toList()),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(25, 12, 12, 8),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: values
                  .map(
                    (item) => Text(
                      DateFormat('dd/MM').format(item.createdAt.toLocal()),
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 9),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      );
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.values);
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()..color = AppColors.border.withValues(alpha: .55)..strokeWidth = 1;
    for (var i = 1; i <= 4; i++) {
      final y = 18 + (size.height - 52) * i / 5;
      canvas.drawLine(Offset(20, y), Offset(size.width - 10, y), grid);
    }
    if (values.isEmpty) return;
    final maxValue = math.max(
      1.0,
      values.reduce((first, second) => math.max(first, second).toDouble()),
    ).toDouble();
    final path = Path();
    final pointPaint = Paint()..color = AppColors.primary;
    for (var index = 0; index < values.length; index++) {
      final x = 24 + (size.width - 42) * (values.length == 1 ? .5 : index / (values.length - 1));
      final y = size.height - 42 - (size.height - 75) * values[index] / maxValue;
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 4, pointPaint);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.primary
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _LinePainter oldDelegate) => oldDelegate.values != values;
}

class _ReportPreview extends StatelessWidget {
  const _ReportPreview({required this.validation, required this.onOpen});
  final ValidationResult validation;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AppColors.border),
          image: const DecorationImage(
            image: AssetImage('assets/images/background_network.png'),
            fit: BoxFit.cover,
            opacity: .23,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.hub, color: AppColors.green),
                SizedBox(width: 7),
                Text('SMART GRID', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              ],
            ),
            const Spacer(),
            const Text('Reporte de\nvalidación', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20, height: 1.1)),
            const SizedBox(height: 8),
            Text(validation.graphName, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
            const SizedBox(height: 3),
            Text(DateFormat('dd MMM yyyy, hh:mm a').format(validation.createdAt.toLocal()), style: const TextStyle(color: AppColors.textMuted, fontSize: 9)),
            const Spacer(),
            OutlinedButton(
              onPressed: onOpen,
              child: const Text('Ver reporte completo'),
            ),
          ],
        ),
      );
}

class _AnomalyTable extends StatelessWidget {
  const _AnomalyTable({required this.validation});
  final ValidationResult validation;

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 700;
    return SectionCard(
      title: 'Top anomalías detectadas',
      child: validation.anomalies.isEmpty
          ? ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                validation.anomalyCount > 0
                    ? Icons.sync_problem_outlined
                    : Icons.check_circle,
                color: validation.anomalyCount > 0
                    ? AppColors.warning
                    : AppColors.green,
              ),
              title: Text(
                validation.anomalyCount > 0
                    ? 'Se detectaron ${validation.anomalyCount} anomalías, pero el detalle aún no está disponible.'
                    : 'La validación no contiene anomalías.',
              ),
              subtitle: validation.anomalyCount > 0
                  ? const Text('Pulsa “Actualizar datos” para volver a consultar el detalle.')
                  : null,
            )
          : mobile
              ? Column(
                  children: validation.anomalies.map((item) => _AnomalyMobileCard(item: item)).toList(),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStatePropertyAll(AppColors.surfaceAlt),
                    columns: const [
                      DataColumn(label: Text('Severidad')),
                      DataColumn(label: Text('Regla')),
                      DataColumn(label: Text('Descripción')),
                      DataColumn(label: Text('Nodo(s)')),
                      DataColumn(label: Text('Detectado el')),
                    ],
                    rows: validation.anomalies
                        .map(
                          (item) => DataRow(
                            cells: [
                              DataCell(StatusBadge(label: _severityLabel(item.severity), color: _severityColor(item.severity))),
                              DataCell(Text(item.ruleCode)),
                              DataCell(SizedBox(width: 360, child: Text(item.description))),
                              DataCell(Text(item.nodeIds.join(', '))),
                              DataCell(Text(DateFormat('dd/MM/yyyy, hh:mm a').format(validation.createdAt.toLocal()))),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ),
    );
  }

  static String _severityLabel(String value) {
    final normalized = value.toLowerCase();
    if (normalized.contains('critical')) return 'Crítica';
    if (normalized.contains('high')) return 'Alta';
    if (normalized.contains('low')) return 'Baja';
    return 'Media';
  }

  static Color _severityColor(String value) {
    final normalized = value.toLowerCase();
    if (normalized.contains('critical')) return AppColors.danger;
    if (normalized.contains('high')) return const Color(0xFFFF7A26);
    if (normalized.contains('low')) return AppColors.green;
    return AppColors.warning;
  }
}

class _AnomalyMobileCard extends StatelessWidget {
  const _AnomalyMobileCard({required this.item});
  final Anomaly item;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${item.ruleCode} · ${item.title}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(item.description, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _ReportActions extends StatelessWidget {
  const _ReportActions({
    required this.exporting,
    required this.onPdf,
    required this.onJson,
    required this.onShare,
    required this.onHistory,
  });
  final bool exporting;
  final VoidCallback onPdf;
  final VoidCallback onJson;
  final VoidCallback onShare;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final mobile = constraints.maxWidth < 700;
          final buttons = [
            FilledButton.icon(
              onPressed: exporting ? null : onPdf,
              icon: const Icon(Icons.download_outlined),
              label: const Text('Exportar PDF'),
            ),
            OutlinedButton.icon(
              onPressed: exporting ? null : onJson,
              icon: const Icon(Icons.code),
              label: const Text('Exportar JSON'),
            ),
            OutlinedButton.icon(
              onPressed: exporting ? null : onShare,
              icon: const Icon(Icons.share_outlined),
              label: const Text('Compartir reporte'),
            ),
            TextButton.icon(
              onPressed: onHistory,
              icon: const Icon(Icons.history),
              label: const Text('Ver historial'),
            ),
          ];
          if (mobile) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: buttons
                  .map((button) => Padding(padding: const EdgeInsets.only(bottom: 9), child: button))
                  .toList(),
            );
          }
          return Row(
            children: buttons.map((button) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 5), child: button))).toList(),
          );
        },
      );
}
*/
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/file_saver.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/page_frame.dart';
import '../../validation/domain/entities/validation_result.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({
    this.initialValidationId,
    super.key,
  });

  final String? initialValidationId;

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  String? selectedId;
  String statusFilter = 'all';
  bool exporting = false;

  @override
  void initState() {
    super.initState();
    selectedId = widget.initialValidationId;
  }

  Future<void> _export(
      ValidationResult validation,
      String format,
      ) async {
    if (validation.status.toUpperCase() != 'COMPLETED') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Solo las validaciones completadas pueden exportarse.',
          ),
        ),
      );
      return;
    }

    setState(() => exporting = true);

    try {
      final file = await ref
          .read(exportValidationProvider)
          .execute(validation.id, format);

      await saveDownloadedFile(file);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reporte ${format.toUpperCase()} generado correctamente.',
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
        setState(() => exporting = false);
      }
    }
  }

  Future<void> _share(ValidationResult validation) async {
    final text = 'Smart Grid Validator · ${validation.graphName}\n'
        '${validation.anomalyCount} anomalías · '
        '${validation.rulesPassed}/${validation.rulesEvaluated} '
        'reglas cumplidas\n'
        '${validation.createdAt.toLocal()}';

    await Clipboard.setData(ClipboardData(text: text));

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Resumen copiado al portapapeles.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(validationsFutureProvider);
    final showHeaderActions = MediaQuery.sizeOf(context).width >= 600;

    return PageFrame(
      title: 'Reportes',
      subtitle:
      'Genera y comparte informes de validación de tu sistema.',
      actions: showHeaderActions
          ? [
        IconButton(
          tooltip: 'Notificaciones',
          onPressed: () => context.go('/history'),
          icon: const Icon(Icons.notifications_none),
        ),
      ]
          : const [],
      child: state.when(
        loading: () => const LoadingPanel(),
        error: (error, _) => ErrorPanel(
          error: error,
          onRetry: () => ref.invalidate(
            validationsFutureProvider,
          ),
        ),
        data: (rawItems) {
          final items = _deduplicateValidations(rawItems);

          if (items.isEmpty) {
            return const EmptyPanel(
              message:
              'Aún no existen validaciones para generar reportes.',
            );
          }

          final sorted = [...items]
            ..sort(
                  (a, b) => b.createdAt.compareTo(a.createdAt),
            );

          final statusFiltered = statusFilter == 'all'
              ? sorted
              : sorted
              .where(
                (item) =>
            item.status.toLowerCase() == statusFilter,
          )
              .toList();

          // Si el filtro no tiene resultados, conservamos el listado
          // general para que la pantalla nunca quede en un estado inválido.
          final available =
          statusFiltered.isEmpty ? sorted : statusFiltered;

          final selectedStillExists = selectedId != null &&
              available.any((item) => item.id == selectedId);

          final effectiveSelectedId = selectedStillExists
              ? selectedId!
              : available.first.id;

          final selected = available.firstWhere(
                (item) => item.id == effectiveSelectedId,
          );

          // No modificar el estado directamente durante build.
          if (selectedId != effectiveSelectedId) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || selectedId == effectiveSelectedId) {
                return;
              }

              setState(() {
                selectedId = effectiveSelectedId;
              });
            });
          }

          return _ReportsContent(
            items: available,
            selected: selected,
            statusFilter: statusFilter,
            exporting: exporting,
            onStatusChanged: (value) {
              setState(() {
                statusFilter = value;
                selectedId = null;
              });
            },
            onSelected: (value) {
              setState(() => selectedId = value);
            },
            onRefresh: () {
              ref.invalidate(validationsFutureProvider);
            },
            onExportPdf: () => _export(selected, 'PDF'),
            onExportJson: () => _export(selected, 'JSON'),
            onShare: () => _share(selected),
          );
        },
      ),
    );
  }
}

List<ValidationResult> _deduplicateValidations(
    Iterable<ValidationResult> items,
    ) {
  final uniqueById = <String, ValidationResult>{};

  for (final item in items) {
    final id = item.id.trim();
    if (id.isEmpty) continue;

    final current = uniqueById[id];

    // Si por error llegan dos ejecuciones con el mismo ID,
    // se conserva la más reciente.
    if (current == null ||
        item.createdAt.isAfter(current.createdAt)) {
      uniqueById[id] = item;
    }
  }

  return uniqueById.values.toList(growable: false);
}

class _ReportsContent extends StatelessWidget {
  const _ReportsContent({
    required this.items,
    required this.selected,
    required this.statusFilter,
    required this.exporting,
    required this.onSelected,
    required this.onStatusChanged,
    required this.onRefresh,
    required this.onExportPdf,
    required this.onExportJson,
    required this.onShare,
  });

  final List<ValidationResult> items;
  final ValidationResult selected;
  final String statusFilter;
  final bool exporting;
  final ValueChanged<String> onSelected;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onRefresh;
  final VoidCallback onExportPdf;
  final VoidCallback onExportJson;
  final VoidCallback onShare;

  void _showAllAnomalies(
      BuildContext context,
      ValidationResult validation,
      ) {
    final screen = MediaQuery.sizeOf(context);
    final dialogWidth = math.max(
      220.0,
      math.min(720.0, screen.width - 32),
    );
    final dialogHeight = math.max(
      180.0,
      math.min(480.0, screen.height - 190),
    );

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 20,
        ),
        backgroundColor: AppColors.surface,
        title: Text(
          'Anomalías · ${validation.graphName}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        content: SizedBox(
          width: dialogWidth,
          height: dialogHeight,
          child: validation.anomalies.isEmpty
              ? const EmptyPanel(
            message: 'No se detectaron anomalías.',
            icon: Icons.check_circle_outline,
          )
              : ListView.separated(
            itemCount: validation.anomalies.length,
            separatorBuilder: (_, __) =>
            const SizedBox(height: 8),
            itemBuilder: (_, index) {
              return _AnomalyMobileCard(
                item: validation.anomalies[index],
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReportsToolbar(
          items: items,
          selectedId: selected.id,
          statusFilter: statusFilter,
          onSelected: onSelected,
          onStatusChanged: onStatusChanged,
          onRefresh: onRefresh,
        ),
        const SizedBox(height: 14),
        _MetricsGrid(selected: selected),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final desktop = constraints.maxWidth >= 1080;

            final donut = SectionCard(
              title: 'Severidad de anomalías',
              action: TextButton(
                onPressed: () {
                  _showAllAnomalies(context, selected);
                },
                child: Text(
                  constraints.maxWidth < 430
                      ? 'Ver todas'
                      : 'Ver todas las anomalías',
                ),
              ),
              child: SizedBox(
                height: constraints.maxWidth < 430 ? 280 : 230,
                child: _SeverityChart(validation: selected),
              ),
            );

            final trend = SectionCard(
              title: 'Anomalías en el tiempo',
              action: const StatusBadge(
                label: 'Últimos 7 días',
                color: AppColors.primary,
              ),
              child: SizedBox(
                height: 230,
                child: _TrendChart(
                  values: items
                      .take(7)
                      .toList()
                      .reversed
                      .toList(),
                ),
              ),
            );

            final preview = SectionCard(
              title: 'Vista previa del reporte',
              child: SizedBox(
                height: 230,
                child: _ReportPreview(
                  validation: selected,
                  onOpen: onExportPdf,
                ),
              ),
            );

            if (!desktop) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  donut,
                  const SizedBox(height: 14),
                  trend,
                  const SizedBox(height: 14),
                  preview,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 4, child: donut),
                const SizedBox(width: 14),
                Expanded(flex: 6, child: trend),
                const SizedBox(width: 14),
                Expanded(flex: 4, child: preview),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        _AnomalyTable(validation: selected),
        const SizedBox(height: 14),
        _ReportActions(
          exporting: exporting,
          onPdf: onExportPdf,
          onJson: onExportJson,
          onShare: onShare,
          onHistory: () => context.go('/history'),
        ),
      ],
    );
  }
}

class _ReportsToolbar extends StatelessWidget {
  const _ReportsToolbar({
    required this.items,
    required this.selectedId,
    required this.statusFilter,
    required this.onSelected,
    required this.onStatusChanged,
    required this.onRefresh,
  });

  final List<ValidationResult> items;
  final String selectedId;
  final String statusFilter;
  final ValueChanged<String> onSelected;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final uniqueItems = _deduplicateValidations(items);
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

            if (width >= 900) {
              return Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _ValidationDropdown(
                      items: uniqueItems,
                      selectedId: safeSelectedId,
                      onSelected: onSelected,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: _StatusDropdown(
                      value: statusFilter,
                      onChanged: onStatusChanged,
                    ),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualizar datos'),
                  ),
                ],
              );
            }

            if (width >= 440) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ValidationDropdown(
                    items: uniqueItems,
                    selectedId: safeSelectedId,
                    onSelected: onSelected,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _StatusDropdown(
                          value: statusFilter,
                          onChanged: onStatusChanged,
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton.filledTonal(
                        tooltip: 'Actualizar datos',
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
                _ValidationDropdown(
                  items: uniqueItems,
                  selectedId: safeSelectedId,
                  onSelected: onSelected,
                ),
                const SizedBox(height: 10),
                _StatusDropdown(
                  value: statusFilter,
                  onChanged: onStatusChanged,
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Actualizar datos'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ValidationDropdown extends StatelessWidget {
  const _ValidationDropdown({
    required this.items,
    required this.selectedId,
    required this.onSelected,
  });

  final List<ValidationResult> items;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      key: ValueKey(
        'validation-$selectedId-${items.length}',
      ),
      initialValue: selectedId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Ejecución de validación',
      ),
      selectedItemBuilder: (context) {
        return items.map((item) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Text(
              item.graphName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList();
      },
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item.id,
          child: Text(
            item.graphName,
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

class _StatusDropdown extends StatelessWidget {
  const _StatusDropdown({
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  static const _items = <(String, String)>[
    ('all', 'Todos los estados'),
    ('completed', 'Completados'),
    ('failed', 'Fallidos'),
    ('cancelled', 'Cancelados'),
  ];

  @override
  Widget build(BuildContext context) {
    final safeValue = _items.any((item) => item.$1 == value)
        ? value
        : 'all';

    return DropdownButtonFormField<String>(
      key: ValueKey('status-$safeValue'),
      initialValue: safeValue,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Estado del reporte',
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

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.selected});

  final ValidationResult selected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;

        final columns = availableWidth >= 1050
            ? 4
            : availableWidth >= 520
            ? 2
            : 1;

        final compact = availableWidth < 700;
        const gap = 12.0;
        final itemWidth =
            (availableWidth - gap * (columns - 1)) / columns;

        final metrics = <Widget>[
          MetricCard(
            label: 'Nodos analizados',
            value: '${selected.nodesAnalyzed}',
            icon: Icons.hub_outlined,
            accent: AppColors.primary,
            compact: compact,
          ),
          MetricCard(
            label: 'Conexiones analizadas',
            value: '${selected.edgesAnalyzed}',
            icon: Icons.link,
            accent: AppColors.green,
            compact: compact,
          ),
          MetricCard(
            label: 'Anomalías detectadas',
            value: '${selected.anomalyCount}',
            icon: Icons.warning_amber_rounded,
            accent: AppColors.warning,
            compact: compact,
          ),
          MetricCard(
            label: 'Reglas aplicadas',
            value: '${selected.rulesEvaluated}',
            icon: Icons.verified_user_outlined,
            accent: AppColors.purple,
            compact: compact,
          ),
        ];

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: metrics.map((metric) {
            return SizedBox(
              width: itemWidth,
              child: metric,
            );
          }).toList(),
        );
      },
    );
  }
}

class _SeverityChart extends StatelessWidget {
  const _SeverityChart({required this.validation});

  final ValidationResult validation;

  @override
  Widget build(BuildContext context) {
    final severity = validation.severityCounts;

    final counts = <String, int>{
      'Críticas': severity['CRITICAL'] ?? 0,
      'Altas': severity['HIGH'] ?? 0,
      'Medias': severity['MEDIUM'] ?? 0,
      'Bajas': severity['LOW'] ?? 0,
    };

    final values = counts.values.toList();
    final totalFromSeverity =
    values.fold<int>(0, (sum, value) => sum + value);

    final total = validation.anomalyCount > 0
        ? validation.anomalyCount
        : totalFromSeverity;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;

        final chart = CustomPaint(
          painter: _DonutPainter(values),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$total',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Text(
                  'Total anomalías',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        );

        final legend = Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendCount(
              label: 'Críticas',
              value: counts['Críticas']!,
              color: AppColors.danger,
            ),
            _LegendCount(
              label: 'Altas',
              value: counts['Altas']!,
              color: const Color(0xFFFF7A26),
            ),
            _LegendCount(
              label: 'Medias',
              value: counts['Medias']!,
              color: AppColors.warning,
            ),
            _LegendCount(
              label: 'Bajas',
              value: counts['Bajas']!,
              color: AppColors.green,
            ),
          ],
        );

        if (compact) {
          return Column(
            children: [
              Expanded(child: chart),
              const SizedBox(height: 6),
              legend,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: chart),
            const SizedBox(width: 10),
            Expanded(child: legend),
          ],
        );
      },
    );
  }
}

class _LegendCount extends StatelessWidget {
  const _LegendCount({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.values);

  final List<int> values;

  @override
  void paint(Canvas canvas, Size size) {
    final total =
    values.fold<int>(0, (sum, value) => sum + value);

    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: math.min(size.width, size.height) * .32,
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.butt;

    paint.color = AppColors.border.withValues(alpha: .65);
    canvas.drawArc(rect, 0, math.pi * 2, false, paint);

    if (total == 0) return;

    final colors = [
      AppColors.danger,
      const Color(0xFFFF7A26),
      AppColors.warning,
      AppColors.green,
    ];

    var start = -math.pi / 2;

    for (var index = 0; index < values.length; index++) {
      final value = values[index];
      if (value <= 0) continue;

      final sweep = math.pi * 2 * value / total;
      paint.color = colors[index];

      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.values != values;
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.values});

  final List<ValidationResult> values;

  @override
  Widget build(BuildContext context) {
    final chartValues =
    values.map((item) => item.anomalyCount.toDouble()).toList();

    return CustomPaint(
      painter: _LinePainter(chartValues),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(25, 12, 12, 8),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: values.isEmpty
              ? const Text(
            'Sin datos disponibles',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
            ),
          )
              : Row(
            children: values.map((item) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      DateFormat('dd/MM').format(
                        item.createdAt.toLocal(),
                      ),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter(this.values);

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = AppColors.border.withValues(alpha: .55)
      ..strokeWidth = 1;

    for (var index = 1; index <= 4; index++) {
      final y = 18 + (size.height - 52) * index / 5;
      canvas.drawLine(
        Offset(20, y),
        Offset(size.width - 10, y),
        grid,
      );
    }

    if (values.isEmpty) return;

    final maxValue = math.max(
      1.0,
      values.reduce(
            (first, second) =>
            math.max(first, second).toDouble(),
      ),
    );

    final path = Path();
    final pointPaint = Paint()..color = AppColors.primary;

    for (var index = 0; index < values.length; index++) {
      final x = 24 +
          (size.width - 42) *
              (values.length == 1
                  ? .5
                  : index / (values.length - 1));

      final y = size.height -
          42 -
          (size.height - 75) * values[index] / maxValue;

      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }

      canvas.drawCircle(Offset(x, y), 4, pointPaint);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.primary
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _LinePainter oldDelegate) {
    return oldDelegate.values != values;
  }
}

class _ReportPreview extends StatelessWidget {
  const _ReportPreview({
    required this.validation,
    required this.onOpen,
  });

  final ValidationResult validation;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.border),
        image: const DecorationImage(
          image: AssetImage(
            'assets/images/background_network.png',
          ),
          fit: BoxFit.cover,
          opacity: .23,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.hub, color: AppColors.green),
              SizedBox(width: 7),
              Expanded(
                child: Text(
                  'SMART GRID',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          const Text(
            'Reporte de\nvalidación',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 20,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            validation.graphName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            DateFormat('dd MMM yyyy, hh:mm a').format(
              validation.createdAt.toLocal(),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 9,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onOpen,
              child: const Text(
                'Ver reporte completo',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnomalyTable extends StatelessWidget {
  const _AnomalyTable({required this.validation});

  final ValidationResult validation;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Top anomalías detectadas',
      child: validation.anomalies.isEmpty
          ? ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          validation.anomalyCount > 0
              ? Icons.sync_problem_outlined
              : Icons.check_circle,
          color: validation.anomalyCount > 0
              ? AppColors.warning
              : AppColors.green,
        ),
        title: Text(
          validation.anomalyCount > 0
              ? 'Se detectaron '
              '${validation.anomalyCount} anomalías, '
              'pero el detalle aún no está disponible.'
              : 'La validación no contiene anomalías.',
        ),
        subtitle: validation.anomalyCount > 0
            ? const Text(
          'Pulsa “Actualizar datos” para volver '
              'a consultar el detalle.',
        )
            : null,
      )
          : LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 760) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: validation.anomalies.map((item) {
                return _AnomalyMobileCard(item: item);
              }).toList(),
            );
          }

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor:
              const WidgetStatePropertyAll(
                AppColors.surfaceAlt,
              ),
              columns: const [
                DataColumn(label: Text('Severidad')),
                DataColumn(label: Text('Regla')),
                DataColumn(label: Text('Descripción')),
                DataColumn(label: Text('Nodo(s)')),
                DataColumn(label: Text('Detectado el')),
              ],
              rows: validation.anomalies.map((item) {
                return DataRow(
                  cells: [
                    DataCell(
                      StatusBadge(
                        label: _severityLabel(
                          item.severity,
                        ),
                        color: _severityColor(
                          item.severity,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        item.ruleCode,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 360,
                        child: Text(
                          item.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 180,
                        child: Text(
                          item.nodeIds.join(', '),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        DateFormat(
                          'dd/MM/yyyy, hh:mm a',
                        ).format(
                          validation.createdAt.toLocal(),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  static String _severityLabel(String value) {
    final normalized = value.toLowerCase();

    if (normalized.contains('critical')) return 'Crítica';
    if (normalized.contains('high')) return 'Alta';
    if (normalized.contains('low')) return 'Baja';

    return 'Media';
  }

  static Color _severityColor(String value) {
    final normalized = value.toLowerCase();

    if (normalized.contains('critical')) {
      return AppColors.danger;
    }

    if (normalized.contains('high')) {
      return const Color(0xFFFF7A26);
    }

    if (normalized.contains('low')) {
      return AppColors.green;
    }

    return AppColors.warning;
  }
}

class _AnomalyMobileCard extends StatelessWidget {
  const _AnomalyMobileCard({required this.item});

  final Anomaly item;

  @override
  Widget build(BuildContext context) {
    final severityLabel = _AnomalyTable._severityLabel(
      item.severity,
    );
    final severityColor = _AnomalyTable._severityColor(
      item.severity,
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final veryCompact = constraints.maxWidth < 330;

          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  StatusBadge(
                    label: severityLabel,
                    color: severityColor,
                  ),
                  Text(
                    item.ruleCode,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                item.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.description,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                ),
              ),
              if (item.nodeIds.isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(
                  'Nodos: ${item.nodeIds.join(', ')}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          );

          if (veryCompact) {
            return content;
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: severityColor,
              ),
              const SizedBox(width: 10),
              Expanded(child: content),
            ],
          );
        },
      ),
    );
  }
}

class _ReportActions extends StatelessWidget {
  const _ReportActions({
    required this.exporting,
    required this.onPdf,
    required this.onJson,
    required this.onShare,
    required this.onHistory,
  });

  final bool exporting;
  final VoidCallback onPdf;
  final VoidCallback onJson;
  final VoidCallback onShare;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final columns = width >= 1000
            ? 4
            : width >= 520
            ? 2
            : 1;

        const gap = 10.0;
        final itemWidth =
            (width - gap * (columns - 1)) / columns;

        final buttons = <Widget>[
          FilledButton.icon(
            onPressed: exporting ? null : onPdf,
            icon: exporting
                ? const SizedBox(
              width: 17,
              height: 17,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            )
                : const Icon(Icons.download_outlined),
            label: Text(
              exporting ? 'Exportando…' : 'Exportar PDF',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          OutlinedButton.icon(
            onPressed: exporting ? null : onJson,
            icon: const Icon(Icons.code),
            label: const Text(
              'Exportar JSON',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          OutlinedButton.icon(
            onPressed: exporting ? null : onShare,
            icon: const Icon(Icons.share_outlined),
            label: const Text(
              'Compartir reporte',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton.icon(
            onPressed: onHistory,
            icon: const Icon(Icons.history),
            label: const Text(
              'Ver historial',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ];

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: buttons.map((button) {
            return SizedBox(
              width: itemWidth,
              child: button,
            );
          }).toList(),
        );
      },
    );
  }
}
