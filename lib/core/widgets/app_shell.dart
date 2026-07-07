import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers.dart';
import '../theme/app_theme.dart';
import 'brand.dart';

class AppShell extends ConsumerWidget {
  const AppShell({
    required this.currentPath,
    required this.child,
    super.key,
  });

  final String currentPath;
  final Widget child;

  static const destinations = <_Destination>[
    _Destination('/dashboard', 'Dashboard', 'Inicio', Icons.home_outlined, Icons.home),
    _Destination('/graphs', 'Grafos', 'Grafos', Icons.hub_outlined, Icons.hub),
    _Destination(
      '/validation',
      'Validación',
      'Validación',
      Icons.verified_user_outlined,
      Icons.verified_user,
    ),
    _Destination(
      '/reports',
      'Reportes',
      'Reportes',
      Icons.description_outlined,
      Icons.description,
    ),
    _Destination(
      '/history',
      'Historial',
      'Historial',
      Icons.history_outlined,
      Icons.history,
    ),
    _Destination(
      '/settings',
      'Configuración',
      'Más',
      Icons.settings_outlined,
      Icons.more_horiz,
    ),
  ];

  int get desktopSelectedIndex {
    final index = destinations.indexWhere((item) => currentPath.startsWith(item.path));
    return index < 0 ? 0 : index;
  }

  int get mobileSelectedIndex {
    if (currentPath.startsWith('/dashboard')) return 0;
    if (currentPath.startsWith('/graphs')) return 1;
    if (currentPath.startsWith('/validation')) return 2;
    if (currentPath.startsWith('/reports') || currentPath.startsWith('/history')) return 3;
    return 4;
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Cerrar sesión'),
        content: const Text('¿Deseas finalizar la sesión actual?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).logout();
    }
  }

  Future<void> _showNotifications(BuildContext context, WidgetRef ref) async {
    final value = await ref.read(dashboardFutureProvider.future);
    if (!context.mounted) return;
    final items = value.recentValidations
        .expand((validation) => validation.anomalies.map((anomaly) => (validation, anomaly)))
        .take(12)
        .toList();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .68,
          child: Column(
            children: [
              const ListTile(
                leading: Icon(Icons.notifications_none_rounded, color: AppColors.primary),
                title: Text('Notificaciones'),
                subtitle: Text('Anomalías recientes de tus validaciones'),
              ),
              const Divider(height: 1),
              Expanded(
                child: items.isEmpty
                    ? const Center(child: Text('No hay anomalías recientes.', style: TextStyle(color: AppColors.textMuted)))
                    : ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, index) {
                          final entry = items[index];
                          return ListTile(
                            leading: Icon(
                              entry.$2.severity == 'CRITICAL' ? Icons.error_outline : Icons.warning_amber_rounded,
                              color: entry.$2.severity == 'CRITICAL' ? AppColors.danger : AppColors.warning,
                            ),
                            title: Text(entry.$2.title),
                            subtitle: Text('${entry.$1.graphName} · ${entry.$2.ruleCode}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              context.go('/reports?validationId=${entry.$1.id}');
                            },
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      context.go('/history');
                    },
                    icon: const Icon(Icons.history),
                    label: const Text('Ver historial completo'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _goMobile(BuildContext context, WidgetRef ref, int index) async {
    switch (index) {
      case 0:
        context.go('/dashboard');
        return;
      case 1:
        context.go('/graphs');
        return;
      case 2:
        context.go('/validation');
        return;
      case 3:
        context.go('/reports');
        return;
      default:
        await showModalBottomSheet<void>(
          context: context,
          backgroundColor: AppColors.surface,
          showDragHandle: true,
          builder: (sheetContext) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.history, color: AppColors.primary),
                    title: const Text('Historial'),
                    subtitle: const Text('Consulta y exporta validaciones anteriores.'),
                    onTap: () { Navigator.pop(sheetContext); context.go('/history'); },
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined, color: AppColors.primary),
                    title: const Text('Configuración'),
                    subtitle: const Text('Perfil, apariencia, seguridad y parámetros.'),
                    onTap: () { Navigator.pop(sheetContext); context.go('/settings'); },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.logout, color: AppColors.danger),
                    title: const Text('Cerrar sesión'),
                    onTap: () { Navigator.pop(sheetContext); _logout(context, ref); },
                  ),
                ],
              ),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final mobile = width < 700;
    final compactDesktop = width >= 700 && width < 1080;
    final auth = ref.watch(authControllerProvider);
    final user = auth.user;

    if (mobile) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          toolbarHeight: 72,
          automaticallyImplyLeading: false,
          titleSpacing: 18,
          title: const AppBrand(compact: true),
          actions: [
            Stack(
              alignment: Alignment.topRight,
              children: [
                IconButton(
                  tooltip: 'Notificaciones',
                  onPressed: () => _showNotifications(context, ref),
                  icon: const Icon(Icons.notifications_none_rounded, size: 28),
                ),
                Positioned(
                  top: 12,
                  right: 10,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
            PopupMenuButton<String>(
              tooltip: 'Cuenta',
              color: AppColors.surface,
              icon: CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primary.withValues(alpha: .24),
                child: Text(_initials(user?.fullName)),
              ),
              onSelected: (value) {
                if (value == 'settings') context.go('/settings');
                if (value == 'history') context.go('/history');
                if (value == 'logout') _logout(context, ref);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'history', child: Text('Historial')),
                PopupMenuItem(value: 'settings', child: Text('Configuración')),
                PopupMenuDivider(),
                PopupMenuItem(value: 'logout', child: Text('Cerrar sesión')),
              ],
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: child,
        bottomNavigationBar: NavigationBar(
          selectedIndex: mobileSelectedIndex,
          onDestinationSelected: (index) => _goMobile(context, ref, index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.hub_outlined),
              selectedIcon: Icon(Icons.hub),
              label: 'Grafos',
            ),
            NavigationDestination(
              icon: Icon(Icons.verified_user_outlined),
              selectedIcon: Icon(Icons.verified_user),
              label: 'Validación',
            ),
            NavigationDestination(
              icon: Icon(Icons.description_outlined),
              selectedIcon: Icon(Icons.description),
              label: 'Reportes',
            ),
            NavigationDestination(
              icon: Icon(Icons.more_horiz),
              selectedIcon: Icon(Icons.more_horiz),
              label: 'Más',
            ),
          ],
        ),
      );
    }

    if (compactDesktop) {
      return Scaffold(
        body: Row(
          children: [
            Container(
              width: 82,
              decoration: const BoxDecoration(
                color: AppColors.sidebar,
                border: Border(right: BorderSide(color: AppColors.borderSoft)),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: AppBrand(showText: false, logoSize: 48),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: NavigationRail(
                        backgroundColor: Colors.transparent,
                        labelType: NavigationRailLabelType.all,
                        selectedIndex: desktopSelectedIndex,
                        onDestinationSelected: (index) =>
                            context.go(destinations[index].path),
                        destinations: destinations
                            .map(
                              (item) => NavigationRailDestination(
                                icon: Icon(item.icon),
                                selectedIcon: Icon(item.selectedIcon),
                                label: Text(item.mobileLabel),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: IconButton(
                        tooltip: 'Cerrar sesión',
                        onPressed: () => _logout(context, ref),
                        icon: const Icon(Icons.logout),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          Container(
            width: 258,
            decoration: const BoxDecoration(
              color: AppColors.sidebar,
              border: Border(right: BorderSide(color: AppColors.borderSoft)),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(22, 22, 18, 20),
                    child: AppBrand(),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      itemCount: destinations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final item = destinations[index];
                        final selected = desktopSelectedIndex == index;
                        return _SidebarItem(
                          item: item,
                          selected: selected,
                          onTap: () => context.go(item.path),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: PopupMenuButton<String>(
                      color: AppColors.surface,
                      offset: const Offset(0, -120),
                      onSelected: (value) {
                        if (value == 'settings') context.go('/settings');
                        if (value == 'logout') _logout(context, ref);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'settings', child: Text('Configuración')),
                        PopupMenuItem(value: 'logout', child: Text('Cerrar sesión')),
                      ],
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.green.withValues(alpha: .35),
                            child: Text(_initials(user?.fullName)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?.fullName ?? 'Usuario',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  _roleLabel(user?.role),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  static String _initials(String? name) {
    final words = (name ?? 'Usuario')
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return 'U';
    if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
    return '${words.first[0]}${words.last[0]}'.toUpperCase();
  }

  static String _roleLabel(String? role) {
    if (role == null || role.isEmpty) return 'Usuario';
    if (role.toLowerCase() == 'admin') return 'Administrador';
    return role[0].toUpperCase() + role.substring(1);
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _Destination item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? AppColors.primary.withValues(alpha: .72) : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        child: InkWell(
          borderRadius: BorderRadius.circular(7),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(
                  selected ? item.selectedIcon : item.icon,
                  size: 22,
                  color: selected ? Colors.white : AppColors.textMuted,
                ),
                const SizedBox(width: 14),
                Text(
                  item.label,
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.textMuted,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _Destination {
  const _Destination(
    this.path,
    this.label,
    this.mobileLabel,
    this.icon,
    this.selectedIcon,
  );

  final String path;
  final String label;
  final String mobileLabel;
  final IconData icon;
  final IconData selectedIcon;
}
