import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/page_frame.dart';
import '../../graphs/domain/entities/smart_grid_graph.dart';
import '../domain/entities/validation_result.dart';

class ValidationPage extends ConsumerStatefulWidget {
  const ValidationPage({this.graphId, super.key});
  final String? graphId;

  @override
  ConsumerState<ValidationPage> createState() => _ValidationPageState();
}

class _ValidationPageState extends ConsumerState<ValidationPage> {
  String? selectedGraphId;
  final Set<String> selectedRuleCodes = <String>{};
  String? rulesInitializedForGraph;
  ValidationResult? current;
  ValidationResult? result;
  Object? error;
  bool running = false;
  bool cancellationPending = false;
  bool pollingPaused = false;
  bool disposed = false;

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }

  List<ValidationRule> _applicableRules(GraphSummary graph, List<ValidationRule> rules) {
    return rules.where((rule) =>
        rule.active &&
        (rule.profiles.contains('ALL') || rule.profiles.contains(graph.modelProfile))).toList();
  }

  void _initializeRules(GraphSummary graph, List<ValidationRule> rules) {
    if (rulesInitializedForGraph == graph.id) return;
    rulesInitializedForGraph = graph.id;
    final applicable = _applicableRules(graph, rules);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        selectedRuleCodes
          ..clear()
          ..addAll(applicable.map((rule) => rule.code));
      });
    });
  }

  Future<void> run() async {
    final graphId = selectedGraphId;
    if (graphId == null || running || selectedRuleCodes.isEmpty) return;
    setState(() {
      running = true;
      cancellationPending = false;
      pollingPaused = false;
      error = null;
      result = null;
      current = null;
    });
    try {
      var validation = await ref.read(startValidationProvider).execute(
            graphId,
            selectedRules: selectedRuleCodes.toList()..sort(),
          );
      if (!mounted || disposed) return;
      setState(() => current = validation);
      var attempt = 0;
      while (!validation.isTerminal && !disposed) {
        while (pollingPaused && !disposed) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
        if (disposed) return;
        await Future<void>.delayed(Duration(seconds: attempt < 10 ? 1 : 3));
        if (disposed) return;
        validation = await ref.read(getValidationProvider).execute(validation.id);
        if (!mounted) return;
        setState(() => current = validation);
        attempt++;
      }
      if (!mounted || disposed) return;
      ref.invalidate(validationsFutureProvider);
      ref.invalidate(dashboardFutureProvider);
      setState(() {
        result = validation;
        running = false;
        cancellationPending = false;
        if (validation.status == 'FAILED') {
          error = validation.errorMessage ?? 'La validación finalizó con error.';
        }
      });
    } catch (exception) {
      if (!mounted || disposed) return;
      setState(() {
        error = exception;
        running = false;
        cancellationPending = false;
      });
    }
  }

  Future<void> cancel() async {
    final validation = current;
    if (validation == null || validation.isTerminal || cancellationPending) return;
    setState(() => cancellationPending = true);
    try {
      final updated = await ref.read(cancelValidationProvider).execute(validation.id);
      if (mounted) setState(() => current = updated);
    } catch (exception) {
      if (mounted) {
        setState(() => cancellationPending = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$exception')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final graphsState = ref.watch(graphsFutureProvider);
    final rulesState = ref.watch(rulesFutureProvider);
    return PageFrame(
      title: 'Validación',
      subtitle: 'Valida tus modelos de red eléctrica con análisis topológico y reglas de negocio.',
      actions: [
        OutlinedButton.icon(
          onPressed: running ? null : () => context.go('/graphs?upload=true'),
          icon: const Icon(Icons.upload_file_outlined),
          label: const Text('Cargar nuevo JSON'),
        ),
      ],
      child: graphsState.when(
        loading: () => const LoadingPanel(),
        error: (value, _) => ErrorPanel(error: value, onRetry: () => ref.invalidate(graphsFutureProvider)),
        data: (graphs) {
          if (graphs.isEmpty) {
            return EmptyPanel(
              message: 'Primero debes cargar un grafo o importar un caso IEEE.',
              icon: Icons.hub_outlined,
            );
          }
          selectedGraphId ??= widget.graphId ?? graphs.first.id;
          final selectedGraph = graphs.firstWhere(
            (item) => item.id == selectedGraphId,
            orElse: () => graphs.first,
          );
          return rulesState.when(
            loading: () => const LoadingPanel(message: 'Cargando reglas de validación…'),
            error: (value, _) => ErrorPanel(error: value, onRetry: () => ref.invalidate(rulesFutureProvider)),
            data: (allRules) {
              final rules = _applicableRules(selectedGraph, allRules);
              _initializeRules(selectedGraph, allRules);
              return Column(
                children: [
                  _StepHeader(running: running, completed: result?.status == 'COMPLETED'),
                  const SizedBox(height: 16),
                  _GraphSelector(
                    graphs: graphs,
                    selectedId: selectedGraphId!,
                    running: running,
                    onChanged: (value) => setState(() {
                      selectedGraphId = value;
                      rulesInitializedForGraph = null;
                      selectedRuleCodes.clear();
                      current = null;
                      result = null;
                      error = null;
                    }),
                    onRun: run,
                  ),
                  const SizedBox(height: 16),
                  if (running)
                    _ProgressWorkspace(
                      validation: current,
                      graph: selectedGraph,
                      rules: rules,
                      cancelling: cancellationPending,
                      paused: pollingPaused,
                      onPause: () => setState(() => pollingPaused = !pollingPaused),
                      onCancel: cancel,
                    )
                  else if (error != null)
                    ErrorPanel(error: error!, onRetry: run)
                  else if (result != null && result!.status != 'CANCELLED')
                    _ResultPanel(result: result!, onRunAgain: run)
                  else
                    _ReadyWorkspace(
                      rules: rules,
                      selected: selectedRuleCodes,
                      onToggle: (code, enabled) => setState(() {
                        if (enabled) {
                          selectedRuleCodes.add(code);
                        } else {
                          selectedRuleCodes.remove(code);
                        }
                      }),
                      onSelectAll: () => setState(() {
                        selectedRuleCodes
                          ..clear()
                          ..addAll(rules.map((rule) => rule.code));
                      }),
                      onClear: () => setState(selectedRuleCodes.clear),
                      onRun: run,
                      cancelled: result?.status == 'CANCELLED',
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _GraphSelector extends StatelessWidget {
  const _GraphSelector({
    required this.graphs,
    required this.selectedId,
    required this.running,
    required this.onChanged,
    required this.onRun,
  });
  final List<GraphSummary> graphs;
  final String selectedId;
  final bool running;
  final ValueChanged<String> onChanged;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 700;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: mobile
            ? Column(
                children: [
                  _dropdown(),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: running ? null : onRun,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Ejecutar validación'),
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(child: _dropdown()),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: running ? null : onRun,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Ejecutar validación'),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _dropdown() => DropdownButtonFormField<String>(
        value: selectedId,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Grafo a validar'),
        items: graphs
            .map((item) => DropdownMenuItem(
                  value: item.id,
                  child: Text(
                    '${item.name} · ${item.nodeCount} nodos · ${item.modelProfile}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ))
            .toList(),
        onChanged: running ? null : (value) { if (value != null) onChanged(value); },
      );
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.running, required this.completed});
  final bool running;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 700;
    final active = completed ? 4 : running ? 3 : 2;
    const labels = ['Cargar archivo', 'Configurar reglas', 'Procesando', 'Resultados'];
    return Card(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: mobile ? 8 : 28, vertical: 18),
        child: Row(
          children: List.generate(labels.length, (index) {
            final number = index + 1;
            final done = number < active || completed;
            final selected = number == active;
            return Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: mobile ? 15 : 18,
                          backgroundColor: done
                              ? AppColors.green
                              : selected
                                  ? AppColors.primary
                                  : AppColors.surfaceSoft,
                          child: done
                              ? const Icon(Icons.check, size: 17, color: Colors.white)
                              : Text('$number', style: TextStyle(fontSize: mobile ? 10 : 12)),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          mobile ? labels[index] : '$number. ${labels[index]}',
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: mobile ? 8 : 11,
                            color: selected ? AppColors.primary : AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (index < labels.length - 1 && !mobile)
                    Expanded(
                      child: Container(
                        height: 2,
                        margin: const EdgeInsets.fromLTRB(6, 0, 6, 22),
                        color: number < active ? AppColors.green : AppColors.border,
                      ),
                    ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _ProgressWorkspace extends StatelessWidget {
  const _ProgressWorkspace({
    required this.validation,
    required this.graph,
    required this.rules,
    required this.cancelling,
    required this.paused,
    required this.onPause,
    required this.onCancel,
  });
  final ValidationResult? validation;
  final GraphSummary graph;
  final List<ValidationRule> rules;
  final bool cancelling;
  final bool paused;
  final VoidCallback onPause;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final progress = validation?.progress ?? 0;
    final desktop = MediaQuery.sizeOf(context).width >= 900;
    final progressCard = SectionCard(
      title: 'Progreso de validación',
      child: Column(
        children: [
          SizedBox(
            width: 210,
            height: 210,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: progress / 100,
                    strokeWidth: 15,
                    backgroundColor: AppColors.surfaceSoft,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$progress%', style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w600)),
                    const Text('Validación en progreso', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _ProgressStep(label: 'Cargando y validando archivo', done: progress >= 10, active: progress < 10),
          _ProgressStep(label: 'Construyendo grafo', done: progress >= 30, active: progress >= 10 && progress < 30),
          _ProgressStep(label: 'Aplicando reglas', done: progress >= 55, active: progress >= 30 && progress < 55),
          _ProgressStep(label: 'Analizando inconsistencias', done: progress >= 80, active: progress >= 55 && progress < 80),
          _ProgressStep(label: 'Generando resumen', done: progress >= 100, active: progress >= 80 && progress < 100),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(8)),
            child: Text(
              'Procesando ${graph.name}\n${graph.nodeCount} nodos · ${graph.edgeCount} relaciones · ${graph.modelProfile}',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4),
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final pauseButton = OutlinedButton.icon(
                onPressed: cancelling ? null : onPause,
                icon: Icon(paused ? Icons.play_arrow_rounded : Icons.pause_circle_outline),
                label: Text(paused ? 'Reanudar seguimiento' : 'Pausar seguimiento'),
              );
              final cancelButton = OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                ),
                onPressed: cancelling ? null : onCancel,
                icon: cancelling
                    ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.close),
                label: Text(cancelling ? 'Cancelando…' : 'Cancelar validación'),
              );
              if (constraints.maxWidth < 310) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [pauseButton, const SizedBox(height: 8), cancelButton],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [pauseButton, const SizedBox(height: 8), cancelButton],
              );
            },
          ),
        ],
      ),
    );

    final rulesCard = SectionCard(
      title: 'Reglas de validación',
      action: StatusBadge(label: '${rules.length} reglas', color: AppColors.primary),
      child: Column(
        children: rules.map((rule) {
          final index = rules.indexOf(rule);
          final threshold = rules.isEmpty ? 100 : ((index + 1) / rules.length * 70 + 25).round();
          final value = progress >= threshold ? 1.0 : progress <= 30 ? 0.0 : ((progress - 30) / (threshold - 30)).clamp(0.0, 1.0).toDouble();
          return _RuleProgress(label: '${rule.code} · ${rule.name}', value: value);
        }).toList(),
      ),
    );

    if (!desktop) {
      return Column(children: [progressCard, const SizedBox(height: 14), rulesCard]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 340, child: progressCard),
        const SizedBox(width: 16),
        Expanded(child: rulesCard),
      ],
    );
  }
}

class _ProgressStep extends StatelessWidget {
  const _ProgressStep({required this.label, this.done = false, this.active = false});
  final String label;
  final bool done;
  final bool active;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            CircleAvatar(
              radius: 11,
              backgroundColor: done ? AppColors.green : active ? AppColors.primary : AppColors.surfaceSoft,
              child: done
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : active
                      ? const SizedBox(width: 11, height: 11, child: CircularProgressIndicator(strokeWidth: 2))
                      : null,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
            Text(
              done ? 'Completado' : active ? 'En progreso' : 'Pendiente',
              style: TextStyle(color: done ? AppColors.green : active ? AppColors.primary : AppColors.textMuted, fontSize: 10),
            ),
          ],
        ),
      );
}

class _RuleProgress extends StatelessWidget {
  const _RuleProgress({required this.label, required this.value});
  final String label;
  final double value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Icon(value >= 1 ? Icons.check_circle : value > 0 ? Icons.autorenew : Icons.schedule,
                color: value >= 1 ? AppColors.green : value > 0 ? AppColors.primary : AppColors.textMuted, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
            const SizedBox(width: 8),
            SizedBox(
              width: 100,
              child: LinearProgressIndicator(value: value, backgroundColor: AppColors.surfaceSoft, minHeight: 5),
            ),
            const SizedBox(width: 8),
            SizedBox(width: 34, child: Text('${(value * 100).round()}%', style: const TextStyle(fontSize: 10))),
          ],
        ),
      );
}

class _ReadyWorkspace extends StatelessWidget {
  const _ReadyWorkspace({
    required this.rules,
    required this.selected,
    required this.onToggle,
    required this.onSelectAll,
    required this.onClear,
    required this.onRun,
    required this.cancelled,
  });
  final List<ValidationRule> rules;
  final Set<String> selected;
  final void Function(String code, bool enabled) onToggle;
  final VoidCallback onSelectAll, onClear, onRun;
  final bool cancelled;

  @override
  Widget build(BuildContext context) => SectionCard(
        title: 'Reglas aplicables al modelo',
        action: Wrap(
          spacing: 6,
          children: [
            TextButton(onPressed: onSelectAll, child: const Text('Todas')),
            TextButton(onPressed: onClear, child: const Text('Ninguna')),
          ],
        ),
        child: Column(
          children: [
            if (cancelled)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: .10),
                  border: Border.all(color: AppColors.warning.withValues(alpha: .35)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('La validación anterior fue cancelada. Puedes iniciar una nueva ejecución.'),
              ),
            ...rules.map((rule) => CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: selected.contains(rule.code),
                  onChanged: (value) => onToggle(rule.code, value == true),
                  secondary: Icon(_severityIcon(rule.defaultSeverity), color: _severityColor(rule.defaultSeverity)),
                  title: Text('${rule.code} · ${rule.name}', style: const TextStyle(fontSize: 13)),
                  subtitle: Text(rule.description, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                )),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: selected.isEmpty ? null : onRun,
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text('Iniciar validación (${selected.length} reglas)'),
              ),
            ),
          ],
        ),
      );

  static IconData _severityIcon(String severity) {
    if (severity == 'CRITICAL') return Icons.error_outline;
    if (severity == 'HIGH') return Icons.warning_amber_rounded;
    return Icons.info_outline;
  }

  static Color _severityColor(String severity) {
    if (severity == 'CRITICAL') return AppColors.danger;
    if (severity == 'HIGH') return AppColors.warning;
    return AppColors.primary;
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({required this.result, required this.onRunAgain});
  final ValidationResult result;
  final VoidCallback onRunAgain;

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 700;
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = mobile ? 2 : 4;
            final gap = 12.0;
            final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
            final metrics = [
              MetricCard(label: 'Nodos', value: '${result.nodesAnalyzed}', icon: Icons.hub_outlined, accent: AppColors.primary, compact: mobile),
              MetricCard(label: 'Relaciones', value: '${result.edgesAnalyzed}', icon: Icons.link, accent: AppColors.green, compact: mobile),
              MetricCard(label: 'Anomalías', value: '${result.anomalyCount}', icon: Icons.warning_amber_rounded, accent: result.anomalyCount == 0 ? AppColors.green : AppColors.danger, compact: mobile),
              MetricCard(label: 'Reglas cumplidas', value: '${result.rulesPassed}/${result.rulesEvaluated}', icon: Icons.verified_user_outlined, accent: AppColors.green, compact: mobile),
            ];
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: metrics.map((metric) => SizedBox(width: width, child: metric)).toList(),
            );
          },
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Anomalías detectadas',
          action: TextButton(
            onPressed: () => context.go('/reports?validationId=${result.id}'),
            child: const Text('Ver reporte completo'),
          ),
          child: result.anomalies.isEmpty
              ? const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.check_circle, color: AppColors.green),
                  title: Text('No se detectaron inconsistencias estructurales.'),
                )
              : Column(
                  children: result.anomalies.map((item) => Container(
                        margin: const EdgeInsets.only(bottom: 9),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            StatusBadge(label: item.severity, color: item.severity == 'CRITICAL' ? AppColors.danger : AppColors.warning),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('${item.ruleCode} · ${item.title}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                const SizedBox(height: 3),
                                Text(item.description, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                                if (item.nodeIds.isNotEmpty) ...[
                                  const SizedBox(height: 5),
                                  Text('Nodos: ${item.nodeIds.join(', ')}', style: const TextStyle(color: AppColors.cyan, fontSize: 10)),
                                ],
                              ]),
                            ),
                          ],
                        ),
                      )).toList(),
                ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, constraints) {
          final buttons = [
            OutlinedButton.icon(onPressed: onRunAgain, icon: const Icon(Icons.refresh), label: const Text('Validar nuevamente')),
            FilledButton.icon(onPressed: () => context.go('/reports?validationId=${result.id}'), icon: const Icon(Icons.description_outlined), label: const Text('Ver reportes')),
          ];
          if (constraints.maxWidth < 620) {
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [buttons[0], const SizedBox(height: 10), buttons[1]]);
          }
          return Row(children: [Expanded(child: buttons[0]), const SizedBox(width: 12), Expanded(child: buttons[1])]);
        }),
      ],
    );
  }
}
