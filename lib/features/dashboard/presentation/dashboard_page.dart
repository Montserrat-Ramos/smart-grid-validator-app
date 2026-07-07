/*
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/page_frame.dart';
import '../../dashboard/domain/entities/dashboard_summary.dart';
import '../../validation/domain/entities/validation_result.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardFutureProvider);
    final desktop = MediaQuery.sizeOf(context).width >= 700;
    return PageFrame(
      title: 'Dashboard',
      subtitle: 'Resumen general de tu sistema',
      actions: desktop
          ? [
              IconButton(
                tooltip: 'Notificaciones',
                onPressed: () => context.go('/history'),
                icon: const Icon(Icons.notifications_none_rounded),
              ),
              const CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.purple,
                child: Text('M'),
              ),
            ]
          : const [],
      child: state.when(
        loading: () => const LoadingPanel(),
        error: (error, _) => ErrorPanel(
          error: error,
          onRetry: () => ref.invalidate(dashboardFutureProvider),
        ),
        data: (summary) => _DashboardContent(summary: summary),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.summary});
  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final latest = summary.latestValidation;
    final width = MediaQuery.sizeOf(context).width;
    final mobile = width < 700;

    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1120 ? 4 : 2;
            final gap = mobile ? 12.0 : 16.0;
            final itemWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
            final cards = [
              MetricCard(
                label: 'Grafos cargados',
                value: '${summary.graphsLoaded}',
                icon: Icons.hub_outlined,
                accent: AppColors.primary,
                compact: mobile,
              ),
              MetricCard(
                label: 'Validaciones realizadas',
                value: '${summary.validationsCompleted}',
                icon: Icons.verified_user_outlined,
                accent: AppColors.green,
                compact: mobile,
              ),
              MetricCard(
                label: 'Anomalías detectadas',
                value: '${summary.anomaliesDetected}',
                icon: Icons.warning_amber_rounded,
                accent: AppColors.warning,
                compact: mobile,
              ),
              MetricCard(
                label: 'Última validación',
                value: latest == null ? 'Sin datos' : _timeAgo(latest.createdAt),
                icon: Icons.schedule_outlined,
                accent: AppColors.textMuted,
                compact: mobile,
              ),
            ];
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: cards.map((card) => SizedBox(width: itemWidth, child: card)).toList(),
            );
          },
        ),
        const SizedBox(height: 17),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= 900) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 5, child: _LatestValidationCard(item: latest)),
                  const SizedBox(width: 17),
                  Expanded(
                    flex: 8,
                    child: _RecentAnomaliesCard(validations: summary.recentValidations),
                  ),
                ],
              );
            }
            return Column(
              children: [
                _LatestValidationCard(item: latest),
                const SizedBox(height: 15),
                _RecentAnomaliesCard(validations: summary.recentValidations),
              ],
            );
          },
        ),
        const SizedBox(height: 17),
        _QuickActions(mobile: mobile),
        const SizedBox(height: 17),
        const _SystemStatusBanner(),
      ],
    );
  }

  static String _timeAgo(DateTime value) {
    final difference = DateTime.now().difference(value.toLocal());
    if (difference.inMinutes < 1) return 'Ahora';
    if (difference.inMinutes < 60) return 'Hace ${difference.inMinutes} min';
    if (difference.inHours < 24) return 'Hace ${difference.inHours} h';
    return 'Hace ${difference.inDays} días';
  }
}

class _LatestValidationCard extends StatelessWidget {
  const _LatestValidationCard({required this.item});
  final ValidationResult? item;

  @override
  Widget build(BuildContext context) => SectionCard(
        title: 'Última validación',
        action: item == null
            ? null
            : const StatusBadge(label: 'Completada', color: AppColors.green),
        child: item == null
            ? const SizedBox(
                height: 150,
                child: Center(
                  child: Text(
                    'Aún no existen validaciones.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item!.graphName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    DateFormat('dd MMM yyyy, hh:mm a').format(item!.createdAt.toLocal()),
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  const Divider(height: 28),
                  Row(
                    children: [
                      Expanded(child: _MiniValue(label: 'Nodos', value: '${item!.nodesAnalyzed}')),
                      Expanded(
                        child: _MiniValue(label: 'Relaciones', value: '${item!.edgesAnalyzed}'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => context.go('/reports'),
                      child: const Text('Ver detalles'),
                    ),
                  ),
                ],
              ),
      );
}

class _MiniValue extends StatelessWidget {
  const _MiniValue({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500)),
        ],
      );
}

class _RecentAnomaliesCard extends StatelessWidget {
  const _RecentAnomaliesCard({required this.validations});
  final List<ValidationResult> validations;

  @override
  Widget build(BuildContext context) {
    final anomalies = <_DashboardAnomaly>[];
    for (final validation in validations) {
      for (final anomaly in validation.anomalies) {
        anomalies.add(
          _DashboardAnomaly(
            title: anomaly.title,
            createdAt: validation.createdAt,
            severity: anomaly.severity,
          ),
        );
      }
    }

    return SectionCard(
      title: 'Anomalías recientes',
      action: TextButton(
        onPressed: () => context.go('/reports'),
        child: const Text('Ver todas las anomalías'),
      ),
      child: anomalies.isEmpty
          ? const SizedBox(
              height: 150,
              child: Center(
                child: Text(
                  'No se han detectado anomalías recientes.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            )
          : Column(
              children: anomalies.take(4).map((item) {
                final color = _severityColor(item.severity);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('dd MMM, hh:mm a').format(item.createdAt.toLocal()),
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  static Color _severityColor(String severity) {
    final value = severity.toLowerCase();
    if (value.contains('critical') || value.contains('critica') || value.contains('crítica')) {
      return AppColors.danger;
    }
    if (value.contains('high') || value.contains('alta')) return AppColors.warning;
    return const Color(0xFFF6C945);
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.mobile});
  final bool mobile;

  @override
  Widget build(BuildContext context) => SectionCard(
        title: 'Acciones rápidas',
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 950 ? 4 : mobile ? 3 : 2;
            final gap = 12.0;
            final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
            final actions = [
              _ActionButton(
                label: 'Cargar JSON',
                caption: 'Importa tu archivo de red',
                icon: Icons.upload_file_outlined,
                color: AppColors.primary,
                onTap: () => context.go('/graphs?upload=true'),
              ),
              _ActionButton(
                label: 'Ver grafo',
                caption: 'Visualiza tu red eléctrica',
                icon: Icons.hub_outlined,
                color: AppColors.textMuted,
                onTap: () => context.go('/graphs'),
              ),
              _ActionButton(
                label: 'Validar',
                caption: 'Ejecuta validación automática',
                icon: Icons.play_arrow_rounded,
                color: AppColors.green,
                onTap: () => context.go('/validation'),
              ),
              if (columns != 3)
                _ActionButton(
                  label: 'Ver reportes',
                  caption: 'Consulta resultados',
                  icon: Icons.description_outlined,
                  color: AppColors.textMuted,
                  onTap: () => context.go('/reports'),
                ),
            ];
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: actions.map((item) => SizedBox(width: width, child: item)).toList(),
            );
          },
        ),
      );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.caption,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String caption;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: color.withValues(alpha: color == AppColors.textMuted ? .03 : .17),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 86),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: .55)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(height: 7),
                Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 3),
                Text(
                  caption,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      );
}

class _SystemStatusBanner extends StatelessWidget {
  const _SystemStatusBanner();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppColors.border),
          image: const DecorationImage(
            image: AssetImage('assets/images/background_network.png'),
            fit: BoxFit.cover,
            alignment: Alignment.bottomRight,
            opacity: .22,
          ),
        ),
        child: const Row(
          children: [
            Icon(Icons.shield_outlined, color: AppColors.green, size: 36),
            SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sistema en buen estado',
                    style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'No se requieren acciones inmediatas.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _DashboardAnomaly {
  const _DashboardAnomaly({
    required this.title,
    required this.createdAt,
    required this.severity,
  });

  final String title;
  final DateTime createdAt;
  final String severity;
}
*/
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/page_frame.dart';
import '../../dashboard/domain/entities/dashboard_summary.dart';
import '../../validation/domain/entities/validation_result.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardFutureProvider);
    final width = MediaQuery.sizeOf(context).width;
    final showHeaderActions = width >= 600;

    return PageFrame(
      title: 'Dashboard',
      subtitle: 'Resumen general de tu sistema',
      actions: showHeaderActions
          ? [
        IconButton(
          tooltip: 'Notificaciones',
          onPressed: () => context.go('/history'),
          icon: const Icon(Icons.notifications_none_rounded),
        ),
        const CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.purple,
          child: Text('M'),
        ),
      ]
          : const [],
      child: state.when(
        loading: () => const LoadingPanel(),
        error: (error, _) => ErrorPanel(
          error: error,
          onRetry: () => ref.invalidate(dashboardFutureProvider),
        ),
        data: (summary) => _DashboardContent(summary: summary),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final latest = summary.latestValidation;

    // IMPORTANTE:
    // Este Column vive dentro del scroll de PageFrame. Por eso debe medir solo
    // lo que ocupa su contenido y nunca intentar tomar una altura infinita.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MetricsGrid(summary: summary, latest: latest),
        const SizedBox(height: 17),
        LayoutBuilder(
          builder: (context, constraints) {
            final twoColumns = constraints.maxWidth >= 900;

            if (!twoColumns) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _LatestValidationCard(item: latest),
                  const SizedBox(height: 15),
                  _RecentAnomaliesCard(
                    validations: summary.recentValidations,
                  ),
                ],
              );
            }

            // No usar CrossAxisAlignment.stretch aquí.
            // El Row recibe altura ilimitada porque PageFrame es desplazable.
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: _LatestValidationCard(item: latest),
                ),
                const SizedBox(width: 17),
                Expanded(
                  flex: 8,
                  child: _RecentAnomaliesCard(
                    validations: summary.recentValidations,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 17),
        const _QuickActions(),
        const SizedBox(height: 17),
        const _SystemStatusBanner(),
      ],
    );
  }

  static String _timeAgo(DateTime value) {
    final difference = DateTime.now().difference(value.toLocal());

    if (difference.inMinutes < 1) return 'Ahora';
    if (difference.inMinutes < 60) {
      return 'Hace ${difference.inMinutes} min';
    }
    if (difference.inHours < 24) {
      return 'Hace ${difference.inHours} h';
    }
    return 'Hace ${difference.inDays} días';
  }
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({
    required this.summary,
    required this.latest,
  });

  final DashboardSummary summary;
  final ValidationResult? latest;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;

        final columns = availableWidth >= 1120
            ? 4
            : availableWidth >= 540
            ? 2
            : 1;

        final compact = availableWidth < 700;
        final gap = compact ? 12.0 : 16.0;
        final itemWidth =
            (availableWidth - (gap * (columns - 1))) / columns;

        final cards = <Widget>[
          MetricCard(
            label: 'Grafos cargados',
            value: '${summary.graphsLoaded}',
            icon: Icons.hub_outlined,
            accent: AppColors.primary,
            compact: compact,
          ),
          MetricCard(
            label: 'Validaciones realizadas',
            value: '${summary.validationsCompleted}',
            icon: Icons.verified_user_outlined,
            accent: AppColors.green,
            compact: compact,
          ),
          MetricCard(
            label: 'Anomalías detectadas',
            value: '${summary.anomaliesDetected}',
            icon: Icons.warning_amber_rounded,
            accent: AppColors.warning,
            compact: compact,
          ),
          MetricCard(
            label: 'Última validación',
            value: latest == null
                ? 'Sin datos'
                : _DashboardContent._timeAgo(latest!.createdAt),
            icon: Icons.schedule_outlined,
            accent: AppColors.textMuted,
            compact: compact,
          ),
        ];

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: cards
              .map(
                (card) => SizedBox(
              width: itemWidth,
              child: card,
            ),
          )
              .toList(),
        );
      },
    );
  }
}

class _LatestValidationCard extends StatelessWidget {
  const _LatestValidationCard({required this.item});

  final ValidationResult? item;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Última validación',
      action: item == null
          ? null
          : const StatusBadge(
        label: 'Completada',
        color: AppColors.green,
      ),
      child: item == null
          ? const SizedBox(
        height: 150,
        child: Center(
          child: Text(
            'Aún no existen validaciones.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      )
          : Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item!.graphName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            DateFormat('dd MMM yyyy, hh:mm a')
                .format(item!.createdAt.toLocal()),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
            ),
          ),
          const Divider(height: 28),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 290) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _MiniValue(
                      label: 'Nodos',
                      value: '${item!.nodesAnalyzed}',
                    ),
                    const SizedBox(height: 14),
                    _MiniValue(
                      label: 'Relaciones',
                      value: '${item!.edgesAnalyzed}',
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: _MiniValue(
                      label: 'Nodos',
                      value: '${item!.nodesAnalyzed}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MiniValue(
                      label: 'Relaciones',
                      value: '${item!.edgesAnalyzed}',
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => context.go('/reports'),
              child: const Text('Ver detalles'),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniValue extends StatelessWidget {
  const _MiniValue({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _RecentAnomaliesCard extends StatelessWidget {
  const _RecentAnomaliesCard({
    required this.validations,
  });

  final List<ValidationResult> validations;

  @override
  Widget build(BuildContext context) {
    final anomalies = <_DashboardAnomaly>[];

    for (final validation in validations) {
      for (final anomaly in validation.anomalies) {
        anomalies.add(
          _DashboardAnomaly(
            title: anomaly.title,
            createdAt: validation.createdAt,
            severity: anomaly.severity,
          ),
        );
      }
    }

    anomalies.sort(
          (a, b) => b.createdAt.compareTo(a.createdAt),
    );

    return SectionCard(
      title: 'Anomalías recientes',
      action: TextButton(
        onPressed: () => context.go('/reports'),
        child: const Text('Ver todas'),
      ),
      child: anomalies.isEmpty
          ? const SizedBox(
        height: 150,
        child: Center(
          child: Text(
            'No se han detectado anomalías recientes.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      )
          : Column(
        mainAxisSize: MainAxisSize.min,
        children: anomalies.take(4).map((item) {
          return _AnomalyRow(item: item);
        }).toList(),
      ),
    );
  }

  static Color severityColor(String severity) {
    final value = severity.toLowerCase();

    if (value.contains('critical') ||
        value.contains('critica') ||
        value.contains('crítica')) {
      return AppColors.danger;
    }

    if (value.contains('high') || value.contains('alta')) {
      return AppColors.warning;
    }

    return const Color(0xFFF6C945);
  }
}

class _AnomalyRow extends StatelessWidget {
  const _AnomalyRow({required this.item});

  final _DashboardAnomaly item;

  @override
  Widget build(BuildContext context) {
    final color = _RecentAnomaliesCard.severityColor(item.severity);
    final date = DateFormat(
      'dd MMM, hh:mm a',
    ).format(item.createdAt.toLocal());

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;

          return Row(
            crossAxisAlignment:
            compact ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              Container(
                width: 9,
                height: 9,
                margin: compact
                    ? const EdgeInsets.only(top: 5)
                    : EdgeInsets.zero,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: compact
                    ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      date,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                )
                    : Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        date,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Acciones rápidas',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;

          final columns = availableWidth >= 950
              ? 4
              : availableWidth >= 520
              ? 2
              : 1;

          const gap = 12.0;
          final itemWidth =
              (availableWidth - (gap * (columns - 1))) / columns;

          final actions = <Widget>[
            _ActionButton(
              label: 'Cargar JSON',
              caption: 'Importa tu archivo de red',
              icon: Icons.upload_file_outlined,
              color: AppColors.primary,
              onTap: () => context.go('/graphs?upload=true'),
            ),
            _ActionButton(
              label: 'Ver grafo',
              caption: 'Visualiza tu red eléctrica',
              icon: Icons.hub_outlined,
              color: AppColors.textMuted,
              onTap: () => context.go('/graphs'),
            ),
            _ActionButton(
              label: 'Validar',
              caption: 'Ejecuta validación automática',
              icon: Icons.play_arrow_rounded,
              color: AppColors.green,
              onTap: () => context.go('/validation'),
            ),
            _ActionButton(
              label: 'Ver reportes',
              caption: 'Consulta resultados',
              icon: Icons.description_outlined,
              color: AppColors.textMuted,
              onTap: () => context.go('/reports'),
            ),
          ];

          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: actions
                .map(
                  (action) => SizedBox(
                width: itemWidth,
                child: action,
              ),
            )
                .toList(),
          );
        },
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.caption,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String caption;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(
        alpha: color == AppColors.textMuted ? .03 : .17,
      ),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 94),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: color.withValues(alpha: .55),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 7),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 3),
              Text(
                caption,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SystemStatusBanner extends StatelessWidget {
  const _SystemStatusBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.border),
        image: const DecorationImage(
          image: AssetImage(
            'assets/images/background_network.png',
          ),
          fit: BoxFit.cover,
          alignment: Alignment.bottomRight,
          opacity: .22,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 360;

          if (compact) {
            return const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.shield_outlined,
                  color: AppColors.green,
                  size: 34,
                ),
                SizedBox(height: 10),
                Text(
                  'Sistema en buen estado',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'No se requieren acciones inmediatas.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            );
          }

          return const Row(
            children: [
              Icon(
                Icons.shield_outlined,
                color: AppColors.green,
                size: 36,
              ),
              SizedBox(width: 15),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sistema en buen estado',
                      style: TextStyle(
                        color: AppColors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'No se requieren acciones inmediatas.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DashboardAnomaly {
  const _DashboardAnomaly({
    required this.title,
    required this.createdAt,
    required this.severity,
  });

  final String title;
  final DateTime createdAt;
  final String severity;
}
