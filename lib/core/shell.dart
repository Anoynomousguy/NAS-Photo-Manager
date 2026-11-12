import 'dart:async';

import 'package:flutter/material.dart';

import '../modules/manifest.dart';
import '../screens/settings_screen.dart';
import '../screens/tutorial_screen.dart';
import '../services/webdav_service.dart';
import '../theme.dart';
import 'app_config.dart';
import 'auth_context.dart';
import 'loading_skeleton.dart';
import 'module.dart';
import 'route_guard.dart';

class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.webdavService,
    required this.themeController,
  });

  final WebdavService webdavService;
  final ThemeController themeController;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  String? _currentId;
  final Set<String> _visited = <String>{};
  Timer? _revealTimer;
  bool _opening = true;

  @override
  void initState() {
    super.initState();
    _startRevealTimer();
  }

  @override
  void dispose() {
    _revealTimer?.cancel();
    super.dispose();
  }

  List<ModuleDefinition> _allowedModules(AuthContext auth) {
    return appModules
        .where(
          (ModuleDefinition module) =>
              module.showInNav && auth.canAccess(module.requiredRole),
        )
        .toList(growable: false);
  }

  void _startRevealTimer() {
    _revealTimer?.cancel();
    _revealTimer = Timer(AppConfig.moduleRevealDuration, () {
      if (!mounted) return;
      setState(() => _opening = false);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AuthContext auth = AuthScope.of(context);
    final List<ModuleDefinition> allowed = _allowedModules(auth);
    if (allowed.isEmpty) {
      _currentId = null;
      return;
    }
    final bool currentStillAllowed = allowed.any(
      (ModuleDefinition module) => module.id == _currentId,
    );
    if (!currentStillAllowed) {
      _currentId = allowed.first.id;
    }
    _visited.add(_currentId!);
  }

  void _selectModule(ModuleDefinition module) {
    final AuthContext auth = AuthScope.of(context);
    if (!RouteGuard.canAccess(auth, module)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(RouteGuard.denialMessage(auth, module))),
      );
      return;
    }
    if (_currentId == module.id) return;
    setState(() {
      _currentId = module.id;
      _visited.add(module.id);
      _opening = true;
    });
    _startRevealTimer();
  }

  void _openModuleByPath(String path) {
    for (final ModuleDefinition module in appModules) {
      if (module.path == path) {
        _selectModule(module);
        return;
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('That module is not registered.')),
    );
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(webdavService: widget.webdavService),
      ),
    );
  }

  Future<void> _openTutorial() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TutorialScreen(
          themeController: widget.themeController,
          onOpenSettings: _openSettings,
          onOpenHelp: () {
            Navigator.of(context).pop();
            _openModuleByPath('/help');
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AuthContext auth = AuthScope.of(context);
    final List<ModuleDefinition> allowed = _allowedModules(auth);

    if (allowed.isEmpty) {
      return Scaffold(body: _NoModules(role: auth.role));
    }

    final ModuleDefinition current = allowed.firstWhere(
      (ModuleDefinition module) => module.id == _currentId,
      orElse: () => allowed.first,
    );
    final Set<String> activeIds = <String>{..._visited, current.id};
    final List<ModuleDefinition> mounted = allowed
        .where((ModuleDefinition module) => activeIds.contains(module.id))
        .toList(growable: false);

    final ModuleContext moduleContext = ModuleContext(
      webdavService: widget.webdavService,
      themeController: widget.themeController,
      auth: auth,
      openModule: _openModuleByPath,
      openSettings: _openSettings,
      openTutorial: _openTutorial,
    );

    final int navIndex = allowed.indexWhere(
      (ModuleDefinition module) => module.id == current.id,
    );

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          for (final ModuleDefinition module in mounted)
            _ModuleStage(
              key: ValueKey<String>('stage-${module.id}'),
              selected: module.id == current.id,
              child: module.builder(context, moduleContext),
            ),
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_opening,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: _opening
                    ? ModuleSkeleton(
                        key: ValueKey<String>('skeleton-${current.id}'),
                        title: current.title,
                      )
                    : const SizedBox.shrink(
                        key: ValueKey<String>('module-ready'),
                      ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: allowed.length <= 1
          ? null
          : _ModuleNavigationBar(
              allowed: allowed,
              selectedIndex: navIndex < 0 ? 0 : navIndex,
              onSelect: _selectModule,
            ),
    );
  }
}

class _ModuleStage extends StatelessWidget {
  const _ModuleStage({
    super.key,
    required this.selected,
    required this.child,
  });

  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !selected,
      child: ExcludeSemantics(
        excluding: !selected,
        child: AnimatedOpacity(
          opacity: selected ? 1 : 0,
          duration: const Duration(milliseconds: 230),
          curve: Curves.easeOutCubic,
          child: AnimatedSlide(
            offset: selected ? Offset.zero : const Offset(0.015, 0),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            child: TickerMode(
              enabled: selected,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _ModuleNavigationBar extends StatelessWidget {
  const _ModuleNavigationBar({
    required this.allowed,
    required this.selectedIndex,
    required this.onSelect,
  });

  final List<ModuleDefinition> allowed;
  final int selectedIndex;
  final ValueChanged<ModuleDefinition> onSelect;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        border: Border(
          top: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.75),
          ),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.055),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: NavigationBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        selectedIndex: selectedIndex,
        onDestinationSelected: (int index) {
          if (index >= 0 && index < allowed.length) {
            onSelect(allowed[index]);
          }
        },
        destinations: allowed
            .map(
              (ModuleDefinition module) => NavigationDestination(
                icon: Icon(module.icon),
                selectedIcon: Icon(module.selectedIcon ?? module.icon),
                label: module.label,
                tooltip: module.title,
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _NoModules extends StatelessWidget {
  const _NoModules({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final OneDriveTokens tokens = OneDriveTokens.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.extension_off_outlined,
                size: 40,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No modules available',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'The ${role.label} role has no manifest modules it can open. '
              'Ask an administrator to review the module roles.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: tokens.secondaryText,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
