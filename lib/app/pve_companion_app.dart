import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/presentation/pve_apple_ui.dart';
import '../features/connection_profiles/application/connection_profiles_controller.dart';
import '../features/connection_profiles/presentation/connection_profiles_screen.dart';
import 'pve_companion_about.dart';
import 'pve_companion_controller.dart';
import 'pve_companion_theme.dart';
import 'pve_workspace.dart';
import 'workspace/workspace_deep_link.dart';

class PveCompanionApp extends StatefulWidget {
  const PveCompanionApp({super.key, required this.controller});

  final PveCompanionController controller;

  @override
  State<PveCompanionApp> createState() => _PveCompanionAppState();
}

class _PveCompanionAppState extends State<PveCompanionApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _handleInitialDeepLink();
    unawaited(widget.controller.initialize());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Future<bool> didPushRouteInformation(
    RouteInformation routeInformation,
  ) async {
    return _handleDeepLink(routeInformation.uri);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.controller.refreshNotificationState());
    }
  }

  void _handleInitialDeepLink() {
    final route = WidgetsBinding.instance.platformDispatcher.defaultRouteName;
    if (route == Navigator.defaultRouteName) {
      return;
    }
    final uri = Uri.tryParse(route);
    if (uri != null) {
      _handleDeepLink(uri);
    }
  }

  bool _handleDeepLink(Uri uri) {
    final section = workspaceSectionFromDeepLink(uri);
    if (section == null) {
      return false;
    }
    widget.controller.openWorkspaceSection(section);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PVE Companion',
      debugShowCheckedModeBanner: false,
      theme: PveCompanionTheme.light(),
      darkTheme: PveCompanionTheme.dark(),
      themeMode: ThemeMode.system,
      initialRoute: Navigator.defaultRouteName,
      builder: (BuildContext context, Widget? child) {
        return CupertinoTheme(
          data: PveCompanionTheme.cupertino(
            MediaQuery.platformBrightnessOf(context),
          ),
          child: child!,
        );
      },
      home: AnimatedBuilder(
        animation: widget.controller,
        builder: (BuildContext context, Widget? child) {
          final profiles = widget.controller.connectionProfiles;
          switch (profiles.loadState) {
            case ConnectionProfilesLoadState.loading:
              return CupertinoPageScaffold(
                backgroundColor: PveAppleColors.page(context),
                child: const PveLoadingState(label: 'Loading saved servers'),
              );
            case ConnectionProfilesLoadState.failed:
              return _ConnectionProfileLoadFailure(
                message:
                    profiles.errorMessage ??
                    'Saved server profiles could not be read.',
                onRetry: widget.controller.initialize,
              );
            case ConnectionProfilesLoadState.ready:
              if (profiles.profiles.isEmpty) {
                return ConnectionProfilesWelcomeScreen(
                  controller: widget.controller,
                  onAbout: () => showPveCompanionAboutDialog(context),
                );
              }
              return PveWorkspace(controller: widget.controller);
          }
        },
      ),
    );
  }
}

class _ConnectionProfileLoadFailure extends StatelessWidget {
  const _ConnectionProfileLoadFailure({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: PveAppleColors.page(context),
      child: PveEmptyState(
        icon: CupertinoIcons.exclamationmark_triangle,
        title: 'Saved servers are unavailable',
        message: message,
        actionLabel: 'Try Again',
        onAction: onRetry,
        destructive: true,
      ),
    );
  }
}
