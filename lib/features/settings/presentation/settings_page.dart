import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../../core/widgets/page_frame.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _initialized = false;
  bool _saving = false;
  bool darkMode = true;
  bool pushNotifications = true;
  bool emailSummary = true;
  bool completedReports = true;
  bool criticalAlerts = true;
  bool dailySummary = false;
  bool biometric = false;
  bool twoFactorPreference = false;
  String language = 'es';
  String timezone = 'America/Mexico_City';
  String dateFormat = 'dd MMM yyyy';
  String timeFormat = '24h';
  Uint8List? avatarBytes;

  final maxFileController = TextEditingController(text: '10');
  final maxNodesController = TextEditingController(text: '5000');
  final maxConnectionsController = TextEditingController(text: '50');
  final timeoutController = TextEditingController(text: '20');
  final retentionController = TextEditingController(text: '30');
  final automaticValidationController = TextEditingController(text: '15');

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  @override
  void dispose() {
    maxFileController.dispose();
    maxNodesController.dispose();
    maxConnectionsController.dispose();
    timeoutController.dispose();
    retentionController.dispose();
    automaticValidationController.dispose();
    super.dispose();
  }

  Future<void> _loadAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString('sgv_profile_avatar');
    if (encoded != null && mounted) {
      setState(() => avatarBytes = base64Decode(encoded));
    }
  }

  void _applySettings(Map<String, dynamic> data) {
    if (_initialized) return;
    _initialized = true;
    final notifications = Map<String, dynamic>.from(
      data['notifications'] as Map? ?? const <String, dynamic>{},
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        darkMode = (data['theme'] ?? 'dark') == 'dark';
        language = (data['language'] ?? 'es').toString();
        timezone = (data['timezone'] ?? 'America/Mexico_City').toString();
        dateFormat = (data['dateFormat'] ?? 'dd MMM yyyy').toString();
        timeFormat = (data['timeFormat'] ?? '24h').toString();
        pushNotifications = notifications['system'] as bool? ?? true;
        emailSummary = notifications['emailSummary'] as bool? ?? true;
        completedReports = notifications['reports'] as bool? ?? true;
        dailySummary = notifications['dailySummary'] as bool? ?? false;
        criticalAlerts = notifications['criticalImmediate'] as bool? ?? true;
        biometric = data['biometricPreference'] as bool? ?? false;
        twoFactorPreference = data['twoFactorPreference'] as bool? ?? false;
        maxFileController.text = '${data['maxFileMb'] ?? 10}';
        maxNodesController.text = '${data['maxNodes'] ?? 5000}';
        maxConnectionsController.text = '${data['maxConnectionsPerNode'] ?? 50}';
        timeoutController.text = '${data['validationTimeoutMinutes'] ?? 20}';
        retentionController.text = '${data['retentionDays'] ?? 30}';
        automaticValidationController.text = '${data['automaticValidationMinutes'] ?? 15}';
      });
      ref.read(themeModeProvider.notifier).state = darkMode ? ThemeMode.dark : ThemeMode.light;
    });
  }

  Map<String, dynamic> _settingsPayload() => {
        'theme': darkMode ? 'dark' : 'light',
        'language': language,
        'timezone': timezone,
        'dateFormat': dateFormat,
        'timeFormat': timeFormat,
        'notifications': {
          'system': pushNotifications,
          'emailSummary': emailSummary,
          'reports': completedReports,
          'dailySummary': dailySummary,
          'criticalImmediate': criticalAlerts,
        },
        'biometricPreference': biometric,
        'twoFactorPreference': twoFactorPreference,
        'maxFileMb': int.tryParse(maxFileController.text) ?? 10,
        'maxNodes': int.tryParse(maxNodesController.text) ?? 5000,
        'maxConnectionsPerNode': int.tryParse(maxConnectionsController.text) ?? 50,
        'validationTimeoutMinutes': int.tryParse(timeoutController.text) ?? 20,
        'retentionDays': int.tryParse(retentionController.text) ?? 30,
        'automaticValidationMinutes': int.tryParse(automaticValidationController.text) ?? 15,
      };

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).putJson('/settings', {'settings': _settingsPayload()});
      ref.invalidate(settingsFutureProvider);
      ref.read(themeModeProvider.notifier).state = darkMode ? ThemeMode.dark : ThemeMode.light;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuración guardada correctamente.')),
        );
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    final bytes = result?.files.single.bytes;
    if (bytes == null) return;
    if (bytes.length > 2 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('La fotografía debe pesar menos de 2 MB.')),
        );
      }
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sgv_profile_avatar', base64Encode(bytes));
    if (mounted) setState(() => avatarBytes = bytes);
  }

  Future<void> _editProfile() async {
    final user = ref.read(authControllerProvider).user;
    if (user == null || user.isGuest) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El perfil temporal de invitado no puede editarse.')),
      );
      return;
    }
    final name = TextEditingController(text: user.fullName);
    final email = TextEditingController(text: user.email);
    final key = GlobalKey<FormState>();
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Editar perfil'),
        content: SizedBox(
          width: 430,
          child: Form(
            key: key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Nombre completo'),
                  validator: (value) => (value ?? '').trim().length < 2 ? 'Nombre no válido.' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Correo electrónico'),
                  validator: (value) => !(value ?? '').contains('@') ? 'Correo no válido.' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (key.currentState?.validate() != true) return;
              Navigator.pop(dialogContext, (name.text.trim(), email.text.trim()));
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    name.dispose();
    email.dispose();
    if (result == null || !mounted) return;
    try {
      await ref.read(authControllerProvider.notifier).updateProfile(result.$1, result.$2);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil actualizado.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _changePassword() async {
    final user = ref.read(authControllerProvider).user;
    if (user?.isGuest == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El modo invitado no utiliza contraseña.')),
      );
      return;
    }
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final key = GlobalKey<FormState>();
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Cambiar contraseña'),
        content: SizedBox(
          width: 430,
          child: Form(
            key: key,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(controller: current, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña actual')),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: next,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Nueva contraseña'),
                    validator: (value) => (value ?? '').length < 8 ? 'Mínimo 8 caracteres.' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirm,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Confirmar contraseña'),
                    validator: (value) => value != next.text ? 'Las contraseñas no coinciden.' : null,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (key.currentState?.validate() != true || current.text.isEmpty) return;
              Navigator.pop(dialogContext, (current.text, next.text));
            },
            child: const Text('Actualizar'),
          ),
        ],
      ),
    );
    current.dispose();
    next.dispose();
    confirm.dispose();
    if (result == null || !mounted) return;
    try {
      await ref.read(authControllerProvider.notifier).changePassword(result.$1, result.$2);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _showSessions() async {
    ref.invalidate(sessionsFutureProvider);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Sesiones registradas'),
        content: SizedBox(
          width: 620,
          height: 400,
          child: Consumer(
            builder: (context, ref, _) => ref.watch(sessionsFutureProvider).when(
                  loading: () => const LoadingPanel(),
                  error: (error, _) => ErrorPanel(
                    error: error,
                    onRetry: () => ref.invalidate(sessionsFutureProvider),
                  ),
                  data: (items) => items.isEmpty
                      ? const EmptyPanel(message: 'No hay sesiones registradas.')
                      : ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            final revoked = item['revoked_at'] != null;
                            return ListTile(
                              leading: Icon(
                                revoked ? Icons.devices_other_outlined : Icons.devices_outlined,
                                color: revoked ? AppColors.textDim : AppColors.green,
                              ),
                              title: Text('Sesión ${index + 1}'),
                              subtitle: Text(
                                'Creada: ${item['created_at'] ?? '—'}\n'
                                'Expira: ${item['expires_at'] ?? '—'}',
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                              ),
                              trailing: StatusBadge(
                                label: revoked ? 'Revocada' : 'Activa',
                                color: revoked ? AppColors.textDim : AppColors.green,
                              ),
                            );
                          },
                        ),
                ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  Future<void> _revokeAllSessions() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Cerrar todas las sesiones'),
        content: const Text('Se revocarán todos los refresh tokens y volverás a la pantalla de acceso.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Revocar sesiones')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(authControllerProvider.notifier).revokeAllSessions();
    await ref.read(authControllerProvider.notifier).logout();
  }

  void _restoreDefaults() {
    setState(() {
      darkMode = true;
      language = 'es';
      timezone = 'America/Mexico_City';
      dateFormat = 'dd MMM yyyy';
      timeFormat = '24h';
      pushNotifications = true;
      emailSummary = true;
      completedReports = true;
      criticalAlerts = true;
      dailySummary = false;
      biometric = false;
      twoFactorPreference = false;
      maxFileController.text = '10';
      maxNodesController.text = '5000';
      maxConnectionsController.text = '50';
      timeoutController.text = '20';
      retentionController.text = '30';
      automaticValidationController.text = '15';
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsFutureProvider);
    settings.whenData(_applySettings);
    final user = ref.watch(authControllerProvider).user;
    final mobile = MediaQuery.sizeOf(context).width < 700;

    return PageFrame(
      title: 'Configuración',
      subtitle: 'Personaliza tu experiencia y administra los parámetros del sistema.',
      child: settings.when(
        loading: () => const LoadingPanel(message: 'Cargando configuración…'),
        error: (error, _) => ErrorPanel(
          error: error,
          onRetry: () {
            _initialized = false;
            ref.invalidate(settingsFutureProvider);
          },
        ),
        data: (_) => Column(
          children: [
            if (!mobile) const _SettingsTabs(),
            if (!mobile) const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final desktop = constraints.maxWidth >= 1050;
                final cards = <Widget>[
                  _ProfileCard(
                    name: user?.fullName ?? 'Usuario',
                    email: user?.email ?? '',
                    role: user?.role ?? 'ANALYST',
                    avatarBytes: avatarBytes,
                    onPhoto: _pickAvatar,
                    onEdit: _editProfile,
                  ),
                  _PreferencesCard(
                    darkMode: darkMode,
                    language: language,
                    timezone: timezone,
                    dateFormat: dateFormat,
                    timeFormat: timeFormat,
                    onDarkChanged: (value) => setState(() => darkMode = value),
                    onLanguage: (value) => setState(() => language = value),
                    onTimezone: (value) => setState(() => timezone = value),
                    onDateFormat: (value) => setState(() => dateFormat = value),
                    onTimeFormat: (value) => setState(() => timeFormat = value),
                  ),
                  _NotificationsCard(
                    push: pushNotifications,
                    email: emailSummary,
                    completed: completedReports,
                    critical: criticalAlerts,
                    daily: dailySummary,
                    onPush: (value) => setState(() => pushNotifications = value),
                    onEmail: (value) => setState(() => emailSummary = value),
                    onCompleted: (value) => setState(() => completedReports = value),
                    onCritical: (value) => setState(() => criticalAlerts = value),
                    onDaily: (value) => setState(() => dailySummary = value),
                  ),
                  _SessionCard(onSessions: _showSessions, onRevokeAll: _revokeAllSessions),
                  _SecurityCard(
                    biometric: biometric,
                    twoFactor: twoFactorPreference,
                    onBiometric: (value) => setState(() => biometric = value),
                    onTwoFactor: (value) => setState(() => twoFactorPreference = value),
                    onChangePassword: _changePassword,
                    onDevices: _showSessions,
                  ),
                  _SystemParametersCard(
                    maxFile: maxFileController,
                    maxNodes: maxNodesController,
                    maxConnections: maxConnectionsController,
                    timeout: timeoutController,
                    retention: retentionController,
                    automaticValidation: automaticValidationController,
                    onRestore: _restoreDefaults,
                  ),
                ];
                if (!desktop) {
                  return Column(
                    children: cards
                        .map((card) => Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: card,
                            ))
                        .toList(),
                  );
                }
                const gap = 14.0;
                final width = (constraints.maxWidth - gap * 2) / 3;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: cards.map((card) => SizedBox(width: width, child: card)).toList(),
                );
              },
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Guardando…' : 'Guardar cambios'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTabs extends StatelessWidget {
  const _SettingsTabs();
  @override
  Widget build(BuildContext context) => Card(
        child: SizedBox(
          height: 47,
          child: Row(
            children: const [
              _Tab(label: 'Perfil', selected: true),
              _Tab(label: 'Apariencia'),
              _Tab(label: 'Notificaciones'),
              _Tab(label: 'Seguridad'),
              _Tab(label: 'Reglas de archivos'),
              _Tab(label: 'Parámetros del sistema'),
            ],
          ),
        ),
      );
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, this.selected = false});
  final String label;
  final bool selected;
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          alignment: Alignment.center,
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withValues(alpha: .55) : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: selected ? Colors.white : AppColors.textMuted)),
        ),
      );
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.name,
    required this.email,
    required this.role,
    required this.avatarBytes,
    required this.onPhoto,
    required this.onEdit,
  });
  final String name;
  final String email;
  final String role;
  final Uint8List? avatarBytes;
  final VoidCallback onPhoto;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => SectionCard(
        title: 'Información del perfil',
        child: Column(
          children: [
            CircleAvatar(
              radius: 46,
              backgroundColor: AppColors.green.withValues(alpha: .45),
              backgroundImage: avatarBytes == null ? null : MemoryImage(avatarBytes!),
              child: avatarBytes == null
                  ? Text(name.isEmpty ? 'U' : name.substring(0, 1).toUpperCase(),
                      style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w600))
                  : null,
            ),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: onPhoto, child: const Text('Cambiar foto')),
            const SizedBox(height: 12),
            _InfoLine(icon: Icons.person_outline, label: 'Nombre', value: name),
            _InfoLine(icon: Icons.mail_outline, label: 'Correo electrónico', value: email),
            _InfoLine(icon: Icons.badge_outlined, label: 'Rol', value: role),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar perfil'),
              ),
            ),
          ],
        ),
      );
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: AppColors.textMuted, size: 19),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                  const SizedBox(height: 2),
                  Text(value, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _PreferencesCard extends StatelessWidget {
  const _PreferencesCard({
    required this.darkMode,
    required this.language,
    required this.timezone,
    required this.dateFormat,
    required this.timeFormat,
    required this.onDarkChanged,
    required this.onLanguage,
    required this.onTimezone,
    required this.onDateFormat,
    required this.onTimeFormat,
  });
  final bool darkMode;
  final String language;
  final String timezone;
  final String dateFormat;
  final String timeFormat;
  final ValueChanged<bool> onDarkChanged;
  final ValueChanged<String> onLanguage;
  final ValueChanged<String> onTimezone;
  final ValueChanged<String> onDateFormat;
  final ValueChanged<String> onTimeFormat;

  @override
  Widget build(BuildContext context) => SectionCard(
        title: 'Preferencias',
        child: Column(
          children: [
            _SettingsDropdown(
              icon: Icons.language,
              label: 'Idioma',
              value: language,
              items: const {'es': 'Español', 'en': 'English'},
              onChanged: onLanguage,
            ),
            _SettingsDropdown(
              icon: Icons.public,
              label: 'Zona horaria',
              value: timezone,
              items: const {
                'America/Mexico_City': '(GMT-06:00) Ciudad de México',
                'America/Cancun': '(GMT-05:00) Cancún',
                'UTC': 'UTC',
              },
              onChanged: onTimezone,
            ),
            _SettingsDropdown(
              icon: Icons.calendar_today_outlined,
              label: 'Formato de fecha',
              value: dateFormat,
              items: const {
                'dd MMM yyyy': '15 jul 2026',
                'dd/MM/yyyy': '15/07/2026',
                'yyyy-MM-dd': '2026-07-15',
              },
              onChanged: onDateFormat,
            ),
            _SettingsDropdown(
              icon: Icons.schedule_outlined,
              label: 'Formato de hora',
              value: timeFormat,
              items: const {'24h': '24 horas (15:45)', '12h': '12 horas (03:45 PM)'},
              onChanged: onTimeFormat,
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.dark_mode_outlined, color: AppColors.primary),
              title: const Text('Tema oscuro', style: TextStyle(fontSize: 12)),
              value: darkMode,
              onChanged: onDarkChanged,
            ),
          ],
        ),
      );
}

class _SettingsDropdown extends StatelessWidget {
  const _SettingsDropdown({
    required this.icon,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final IconData icon;
  final String label;
  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Icon(icon, color: AppColors.textMuted, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: items.containsKey(value) ? value : items.keys.first,
                isExpanded: true,
                decoration: InputDecoration(labelText: label, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                items: items.entries
                    .map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value, overflow: TextOverflow.ellipsis)))
                    .toList(),
                onChanged: (selected) {
                  if (selected != null) onChanged(selected);
                },
              ),
            ),
          ],
        ),
      );
}

class _NotificationsCard extends StatelessWidget {
  const _NotificationsCard({
    required this.push,
    required this.email,
    required this.completed,
    required this.critical,
    required this.daily,
    required this.onPush,
    required this.onEmail,
    required this.onCompleted,
    required this.onCritical,
    required this.onDaily,
  });
  final bool push, email, completed, critical, daily;
  final ValueChanged<bool> onPush, onEmail, onCompleted, onCritical, onDaily;
  @override
  Widget build(BuildContext context) => SectionCard(
        title: 'Preferencias de notificaciones',
        child: Column(
          children: [
            _ToggleRow(label: 'Notificaciones del sistema', value: push, onChanged: onPush),
            _ToggleRow(label: 'Resumen por correo', value: email, onChanged: onEmail),
            _ToggleRow(label: 'Correo para reportes completados', value: completed, onChanged: onCompleted),
            _ToggleRow(label: 'Resumen diario', value: daily, onChanged: onDaily),
            _ToggleRow(label: 'Alertas críticas inmediatas', value: critical, onChanged: onCritical),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: AppColors.primary, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Las preferencias se conservan en el backend. La entrega de correos y push requiere configurar un proveedor externo.',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({required this.label, required this.value, required this.onChanged});
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(label, style: const TextStyle(fontSize: 11)),
        value: value,
        onChanged: onChanged,
      );
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.onSessions, required this.onRevokeAll});
  final VoidCallback onSessions;
  final VoidCallback onRevokeAll;
  @override
  Widget build(BuildContext context) => SectionCard(
        title: 'Seguridad de sesión',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Sesiones activas y revocadas', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onSessions,
                icon: const Icon(Icons.devices_outlined),
                label: const Text('Ver sesiones'),
              ),
            ),
            const SizedBox(height: 12),
            const Row(
              children: [
                Icon(Icons.circle, size: 9, color: AppColors.green),
                SizedBox(width: 7),
                Expanded(child: Text('Sesión actual protegida con JWT', style: TextStyle(fontSize: 11))),
              ],
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                ),
                onPressed: onRevokeAll,
                child: const Text('Cerrar todas las sesiones'),
              ),
            ),
          ],
        ),
      );
}

class _SecurityCard extends StatelessWidget {
  const _SecurityCard({
    required this.biometric,
    required this.twoFactor,
    required this.onBiometric,
    required this.onTwoFactor,
    required this.onChangePassword,
    required this.onDevices,
  });
  final bool biometric, twoFactor;
  final ValueChanged<bool> onBiometric, onTwoFactor;
  final VoidCallback onChangePassword, onDevices;
  @override
  Widget build(BuildContext context) => SectionCard(
        title: 'Seguridad y acceso',
        child: Column(
          children: [
            _ToggleRow(label: 'Preferencia biométrica', value: biometric, onChanged: onBiometric),
            const Divider(),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.shield_outlined, color: AppColors.green),
              title: const Text('Preferencia de segundo factor (2FA)', style: TextStyle(fontSize: 12)),
              subtitle: const Text('La activación real requiere integrar un proveedor TOTP.', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
              value: twoFactor,
              onChanged: onTwoFactor,
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.lock_outline),
              title: const Text('Cambiar contraseña', style: TextStyle(fontSize: 12)),
              subtitle: const Text('Revoca las sesiones al actualizarla', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
              trailing: const Icon(Icons.chevron_right),
              onTap: onChangePassword,
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.devices_outlined),
              title: const Text('Dispositivos y sesiones', style: TextStyle(fontSize: 12)),
              subtitle: const Text('Consulta accesos registrados', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
              trailing: const Icon(Icons.chevron_right),
              onTap: onDevices,
            ),
          ],
        ),
      );
}

class _SystemParametersCard extends StatelessWidget {
  const _SystemParametersCard({
    required this.maxFile,
    required this.maxNodes,
    required this.maxConnections,
    required this.timeout,
    required this.retention,
    required this.automaticValidation,
    required this.onRestore,
  });
  final TextEditingController maxFile, maxNodes, maxConnections, timeout, retention, automaticValidation;
  final VoidCallback onRestore;
  @override
  Widget build(BuildContext context) => SectionCard(
        title: 'Parámetros del sistema',
        child: Column(
          children: [
            _ParameterField(label: 'Tamaño máximo de archivo', controller: maxFile, suffix: 'MB'),
            _ParameterField(label: 'Máximo de nodos por grafo', controller: maxNodes),
            _ParameterField(label: 'Máximo de conexiones por nodo', controller: maxConnections),
            _ParameterField(label: 'Tiempo de espera de validación', controller: timeout, suffix: 'min'),
            _ParameterField(label: 'Retención de reportes', controller: retention, suffix: 'días'),
            _ParameterField(label: 'Validación automática', controller: automaticValidation, suffix: 'min'),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('URL de la API', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
            ),
            const SizedBox(height: 5),
            SelectableText(AppConfig.apiBaseUrl, style: const TextStyle(fontSize: 10, color: AppColors.cyan)),
            const SizedBox(height: 14),
            TextButton(onPressed: onRestore, child: const Text('Restaurar valores predeterminados')),
          ],
        ),
      );
}

class _ParameterField extends StatelessWidget {
  const _ParameterField({required this.label, required this.controller, this.suffix});
  final String label;
  final TextEditingController controller;
  final String? suffix;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 11))),
            SizedBox(
              width: 124,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  suffixText: suffix,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 10),
                ),
              ),
            ),
          ],
        ),
      );
}
