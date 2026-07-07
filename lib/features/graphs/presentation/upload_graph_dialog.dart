import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../domain/entities/smart_grid_graph.dart';

class UploadGraphDialog extends ConsumerStatefulWidget {
  const UploadGraphDialog({super.key});

  @override
  ConsumerState<UploadGraphDialog> createState() => _UploadGraphDialogState();
}

class _UploadGraphDialogState extends ConsumerState<UploadGraphDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  Map<String, dynamic>? _payload;
  Uint8List? _bytes;
  String? _filename;
  int? _fileSize;
  String? _format;
  int _nodes = 0;
  int _edges = 0;
  String? _error;
  bool _saving = false;
  String? _selectedDatasetId;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;
    final file = result.files.single;
    try {
      final decoded = jsonDecode(utf8.decode(file.bytes!));
      if (decoded is! Map) {
        throw const FormatException('La raíz del JSON debe ser un objeto.');
      }
      final payload = Map<String, dynamic>.from(decoded);
      final preview = _inspect(payload);
      setState(() {
        _payload = payload;
        _bytes = file.bytes;
        _filename = file.name;
        _fileSize = file.size;
        _nodes = preview.$1;
        _edges = preview.$2;
        _format = preview.$3;
        _error = null;
      });
    } catch (exception) {
      setState(() {
        _clearFile();
        _error = 'Archivo inválido: $exception';
      });
    }
  }

  (int, int, String) _inspect(Map<String, dynamic> raw) {
    if (raw['_class'] == 'pandapowerNet' && raw['_object'] is Map) {
      final object = Map<String, dynamic>.from(raw['_object'] as Map);
      int countRows(dynamic table) {
        if (table is! Map) return 0;
        final encoded = table['_object'];
        if (encoded is String) {
          try {
            final parsed = jsonDecode(encoded);
            return parsed is Map && parsed['data'] is List
                ? (parsed['data'] as List).length
                : 0;
          } catch (_) {
            return 0;
          }
        }
        return 0;
      }

      final buses = countRows(object['bus']);
      final assets = ['gen', 'sgen', 'ext_grid', 'load', 'storage', 'trafo']
          .fold<int>(0, (sum, key) => sum + countRows(object[key]));
      final lines = countRows(object['line']);
      final transformers = countRows(object['trafo']);
      return (buses + assets, lines + (transformers * 2) + assets, 'pandapower JSON');
    }

    final source = raw['mpc'] is Map
        ? Map<String, dynamic>.from(raw['mpc'] as Map)
        : raw;
    if (source['bus'] is List && source['branch'] is List && source['gen'] is List) {
      return (
        (source['bus'] as List).length + (source['gen'] as List).length,
        (source['branch'] as List).length + (source['gen'] as List).length,
        'MATPOWER JSON',
      );
    }

    if (source['nodes'] is List && source['edges'] is List) {
      return (
        (source['nodes'] as List).length,
        (source['edges'] as List).length,
        (source['modelProfile'] ?? 'Smart Grid Validator JSON').toString(),
      );
    }

    if (source['bus'] is List &&
        ['line', 'trafo', 'load', 'ext_grid', 'gen', 'sgen']
            .any((key) => source[key] is List)) {
      final nodes = (source['bus'] as List).length +
          ['trafo', 'load', 'ext_grid', 'gen', 'sgen', 'storage']
              .fold<int>(0, (sum, key) => sum + (source[key] is List ? (source[key] as List).length : 0));
      final edges = (source['line'] is List ? (source['line'] as List).length : 0) +
          (source['trafo'] is List ? (source['trafo'] as List).length * 2 : 0) +
          ['load', 'ext_grid', 'gen', 'sgen', 'storage']
              .fold<int>(0, (sum, key) => sum + (source[key] is List ? (source[key] as List).length : 0));
      return (nodes, edges, 'pandapower por tablas');
    }

    throw const FormatException(
      'Formato no reconocido. Se admite SGV 1.0, MATPOWER JSON y pandapower JSON.',
    );
  }

  void _clearFile() {
    _payload = null;
    _bytes = null;
    _filename = null;
    _fileSize = null;
    _format = null;
    _nodes = 0;
    _edges = 0;
  }

  Future<void> _saveFile() async {
    if (_bytes == null || _filename == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final graph = await ref.read(importGraphProvider).file(_filename!, _bytes!);
      _finish(graph);
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = exception.toString();
      });
    }
  }

  Future<void> _saveDataset() async {
    if (_selectedDatasetId == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final graph = await ref.read(importDatasetProvider).execute(_selectedDatasetId!);
      _finish(graph);
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = exception.toString();
      });
    }
  }

  void _finish(SmartGridGraph graph) {
    ref.invalidate(graphsFutureProvider);
    ref.invalidate(dashboardFutureProvider);
    if (mounted) Navigator.of(context).pop(graph.id);
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 700;
    return AlertDialog(
      backgroundColor: AppColors.surface,
      insetPadding: EdgeInsets.all(mobile ? 10 : 40),
      titlePadding: const EdgeInsets.fromLTRB(22, 18, 12, 0),
      title: Row(
        children: [
          const Expanded(child: Text('Cargar red eléctrica')),
          IconButton(
            tooltip: 'Cerrar',
            onPressed: _saving ? null : () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
      content: SizedBox(
        width: mobile ? double.maxFinite : 650,
        height: mobile ? MediaQuery.sizeOf(context).height * .72 : 650,
        child: Column(
          children: [
            TabBar(
              controller: _tabs,
              tabs: const [
                Tab(text: 'Archivo JSON', icon: Icon(Icons.upload_file_outlined)),
                Tab(text: 'Casos IEEE', icon: Icon(Icons.electric_bolt_outlined)),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _FileTab(
                    saving: _saving,
                    filename: _filename,
                    fileSize: _fileSize,
                    format: _format,
                    nodes: _nodes,
                    edges: _edges,
                    error: _error,
                    onPick: _pickFile,
                    onClear: () => setState(() {
                      _clearFile();
                      _error = null;
                    }),
                    onProcess: _saveFile,
                  ),
                  _DatasetTab(
                    datasets: ref.watch(datasetsFutureProvider),
                    selectedId: _selectedDatasetId,
                    saving: _saving,
                    error: _error,
                    onSelect: (value) => setState(() {
                      _selectedDatasetId = value;
                      _error = null;
                    }),
                    onImport: _saveDataset,
                    onRetry: () => ref.invalidate(datasetsFutureProvider),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FileTab extends StatelessWidget {
  const _FileTab({
    required this.saving,
    required this.filename,
    required this.fileSize,
    required this.format,
    required this.nodes,
    required this.edges,
    required this.error,
    required this.onPick,
    required this.onClear,
    required this.onProcess,
  });

  final bool saving;
  final String? filename;
  final int? fileSize;
  final String? format;
  final int nodes;
  final int edges;
  final String? error;
  final VoidCallback onPick;
  final VoidCallback onClear;
  final VoidCallback onProcess;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: saving ? null : onPick,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.textDim),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_upload_outlined, size: 54, color: AppColors.textMuted),
                    const SizedBox(height: 12),
                    const Text(
                      'Arrastra tu archivo aquí\no selecciona uno',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted, fontSize: 17, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: saving ? null : onPick,
                      icon: const Icon(Icons.folder_open_outlined),
                      label: const Text('Seleccionar archivo'),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'SGV 1.0 · MATPOWER JSON · pandapower JSON',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textDim, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
            if (filename != null) ...[
              const SizedBox(height: 14),
              SectionCard(
                title: 'Archivo seleccionado',
                action: IconButton(
                  tooltip: 'Quitar archivo',
                  onPressed: saving ? null : onClear,
                  icon: const Icon(Icons.delete_outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(filename!, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      '${((fileSize ?? 0) / 1024).toStringAsFixed(1)} KB · ${format ?? 'JSON'}',
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SectionCard(
                title: 'Vista previa',
                child: Row(
                  children: [
                    Expanded(child: _FileMetric(label: 'Nodos', value: '$nodes')),
                    const SizedBox(width: 16),
                    Expanded(child: _FileMetric(label: 'Relaciones', value: '$edges')),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _ValidFileBanner(format: format ?? 'JSON'),
            ],
            if (error != null) ...[
              const SizedBox(height: 12),
              _ErrorBanner(error!),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: filename == null || saving ? null : onProcess,
                icon: saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.play_arrow_rounded),
                label: Text(saving ? 'Procesando…' : 'Procesar'),
              ),
            ),
          ],
        ),
      );
}

class _DatasetTab extends StatelessWidget {
  const _DatasetTab({
    required this.datasets,
    required this.selectedId,
    required this.saving,
    required this.error,
    required this.onSelect,
    required this.onImport,
    required this.onRetry,
  });

  final AsyncValue<List<PublicDataset>> datasets;
  final String? selectedId;
  final bool saving;
  final String? error;
  final ValueChanged<String> onSelect;
  final VoidCallback onImport;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => datasets.when(
        loading: () => const LoadingPanel(message: 'Consultando casos públicos IEEE…'),
        error: (value, _) => ErrorPanel(error: value, onRetry: onRetry),
        data: (items) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: .08),
                  border: Border.all(color: AppColors.primary.withValues(alpha: .28)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: AppColors.primary),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Son casos de referencia públicos convertidos desde pandapower. '
                        'Representan topologías eléctricas públicas de referencia reconocidas en investigación; no son telemetría SCADA en vivo ni revelan una red operativa.',
                        style: TextStyle(color: AppColors.textMuted, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _DatasetCard(
                    item: item,
                    selected: selectedId == item.id,
                    onTap: () => onSelect(item.id),
                  ),
                ),
              ),
              if (items.isEmpty)
                const EmptyPanel(
                  message: 'No hay datasets públicos instalados en el servidor.',
                  icon: Icons.dataset_outlined,
                ),
              if (error != null) ...[
                const SizedBox(height: 8),
                _ErrorBanner(error!),
              ],
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: selectedId == null || saving ? null : onImport,
                icon: saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.download_for_offline_outlined),
                label: Text(saving ? 'Importando…' : 'Importar caso seleccionado'),
              ),
            ],
          ),
        ),
      );
}

class _DatasetCard extends StatelessWidget {
  const _DatasetCard({required this.item, required this.selected, required this.onTap});
  final PublicDataset item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected
            ? AppColors.primary.withValues(alpha: .13)
            : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.border,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                Radio<String>(
                  value: item.id,
                  groupValue: selected ? item.id : null,
                  onChanged: (_) => onTap(),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 5),
                      Wrap(
                        spacing: 8,
                        runSpacing: 5,
                        children: [
                          StatusBadge(label: '${item.nodeCount} nodos', color: AppColors.primary),
                          StatusBadge(label: '${item.edgeCount} relaciones', color: AppColors.green),
                          StatusBadge(label: item.modelProfile, color: AppColors.purple),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _ValidFileBanner extends StatelessWidget {
  const _ValidFileBanner({required this.format});
  final String format;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppColors.green.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.green.withValues(alpha: .35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.verified_user_outlined, color: AppColors.green),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Archivo reconocido',
                      style: TextStyle(color: AppColors.green, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(
                    'Formato detectado: $format. El servidor volverá a validar todas las referencias y límites.',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.danger.withValues(alpha: .35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(color: AppColors.danger))),
          ],
        ),
      );
}

class _FileMetric extends StatelessWidget {
  const _FileMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
        ],
      );
}
