import 'dart:ui';

import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import 'dashboard_screen.dart';
import 'modules_screen.dart';
import 'timetable_screen.dart';

enum ShellTab { dashboard, timetable, modules }

enum ShellModuleKind {
  notes,
  homework,
  bulletins,
  notifications,
  scolarites,
  absences,
}

class MainShell extends StatefulWidget {
  final ShellTab initialTab;
  final ShellModuleKind? initialModule;

  const MainShell({
    super.key,
    this.initialTab = ShellTab.dashboard,
    this.initialModule,
  });

  static ShellModuleKind? moduleFromRoute(String? routeName) {
    switch (routeName) {
      case '/notes':
        return ShellModuleKind.notes;
      case '/homework':
        return ShellModuleKind.homework;
      case '/bulletins':
        return ShellModuleKind.bulletins;
      case '/notifications':
        return ShellModuleKind.notifications;
      case '/scolarites':
        return ShellModuleKind.scolarites;
      case '/absences':
        return ShellModuleKind.absences;
      default:
        return null;
    }
  }

  static ShellTab tabFromRoute(String? routeName) {
    if (routeName == '/timetable') return ShellTab.timetable;
    if (moduleFromRoute(routeName) != null) return ShellTab.modules;
    return ShellTab.dashboard;
  }

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index;
  ShellModuleKind? _activeModule;

  @override
  void initState() {
    super.initState();
    _index = widget.initialTab.index;
    _activeModule = widget.initialModule;
  }

  ModuleKind _toModuleKind(ShellModuleKind kind) {
    switch (kind) {
      case ShellModuleKind.notes:
        return ModuleKind.notes;
      case ShellModuleKind.homework:
        return ModuleKind.homework;
      case ShellModuleKind.bulletins:
        return ModuleKind.bulletins;
      case ShellModuleKind.notifications:
        return ModuleKind.notifications;
      case ShellModuleKind.scolarites:
        return ModuleKind.scolarites;
      case ShellModuleKind.absences:
        return ModuleKind.absences;
    }
  }

  String _modulesTitle(BuildContext context) {
    final m = _activeModule;
    if (m == null) return 'Modules';
    switch (m) {
      case ShellModuleKind.notes:
        return 'Notes';
      case ShellModuleKind.homework:
        return 'Devoirs';
      case ShellModuleKind.bulletins:
        return 'Bulletins';
      case ShellModuleKind.notifications:
        return 'Notifications';
      case ShellModuleKind.scolarites:
        return 'Scolarités';
      case ShellModuleKind.absences:
        return 'Absences';
    }
  }

  void _selectTab(int idx) {
    if (idx == _index) return;
    setState(() {
      _index = idx;
    });
  }

  void _openProfile(BuildContext context) {
    Navigator.of(context).pushNamed('/profile');
  }

  @override
  Widget build(BuildContext context) {
    final tab = ShellTab.values[_index];

    Widget body;
    if (tab == ShellTab.dashboard) {
      body = const DashboardScreen();
    } else if (tab == ShellTab.timetable) {
      body = const TimetableScreen(includeScaffold: false);
    } else {
      final module = _activeModule ?? ShellModuleKind.notes;
      body = ModulesScreen(
        key: ValueKey<String>('module:${module.name}'),
        kind: _toModuleKind(module),
        includeScaffold: false,
      );
    }

    final title = tab == ShellTab.dashboard
        ? 'Tableau de bord'
        : (tab == ShellTab.timetable
              ? 'Emploi du temps'
              : _modulesTitle(context));

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      extendBody: true,
      appBar: _FuturisticShellAppBar(
        title: title,
        showModulePicker: tab == ShellTab.modules,
        activeModule: _activeModule,
        onModuleChanged: (m) {
          setState(() {
            _activeModule = m;
          });
        },
        onProfile: () => _openProfile(context),
      ),
      body: SafeArea(bottom: false, child: body),
      bottomNavigationBar: _FuturisticBottomBar(
        index: _index,
        onChanged: _selectTab,
      ),
    );
  }
}

class _FuturisticShellAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String title;
  final bool showModulePicker;
  final ShellModuleKind? activeModule;
  final ValueChanged<ShellModuleKind> onModuleChanged;
  final VoidCallback onProfile;

  const _FuturisticShellAppBar({
    required this.title,
    required this.showModulePicker,
    required this.activeModule,
    required this.onModuleChanged,
    required this.onProfile,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.white.withOpacity(0.65),
          elevation: 0,
          title: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (showModulePicker)
                _ModulePicker(active: activeModule, onChanged: onModuleChanged),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Profil',
              onPressed: onProfile,
              icon: const Icon(Icons.person_outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModulePicker extends StatelessWidget {
  final ShellModuleKind? active;
  final ValueChanged<ShellModuleKind> onChanged;

  const _ModulePicker({required this.active, required this.onChanged});

  String _label(ShellModuleKind k) {
    switch (k) {
      case ShellModuleKind.notes:
        return 'Notes';
      case ShellModuleKind.homework:
        return 'Devoirs';
      case ShellModuleKind.bulletins:
        return 'Bulletins';
      case ShellModuleKind.notifications:
        return 'Notif.';
      case ShellModuleKind.scolarites:
        return 'Scolarités';
      case ShellModuleKind.absences:
        return 'Absences';
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ShellModuleKind.values;
    final value = active ?? ShellModuleKind.notes;

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.7)),
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withOpacity(0.14),
            AppTheme.primaryColor.withOpacity(0.06),
          ],
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ShellModuleKind>(
          value: value,
          icon: const Icon(Icons.expand_more, size: 18),
          items: items
              .map(
                (k) => DropdownMenuItem(
                  value: k,
                  child: Text(
                    _label(k),
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
              .toList(growable: false),
          onChanged: (k) {
            if (k == null) return;
            onChanged(k);
          },
        ),
      ),
    );
  }
}

class _FuturisticBottomBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;

  const _FuturisticBottomBar({required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.lg,
          0,
          AppTheme.lg,
          AppTheme.lg,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 60 + (bottomInset > 0 ? 6 : 0),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.70),
                border: Border.all(color: Colors.white.withOpacity(0.6)),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withOpacity(0.16),
                    blurRadius: 22,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _NavItem(
                    selected: index == 0,
                    icon: Icons.dashboard_outlined,
                    label: 'Accueil',
                    onTap: () => onChanged(0),
                  ),
                  _NavItem(
                    selected: index == 1,
                    icon: Icons.calendar_month_outlined,
                    label: 'Temps',
                    onTap: () => onChanged(1),
                  ),
                  _NavItem(
                    selected: index == 2,
                    icon: Icons.grid_view_rounded,
                    label: 'Modules',
                    onTap: () => onChanged(2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _NavItem({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppTheme.textPrimaryColor;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: selected
                ? LinearGradient(
                    colors: [
                      AppTheme.primaryColor,
                      AppTheme.primaryColor.withOpacity(0.78),
                    ],
                  )
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: fg),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
