import 'dart:async';

import 'package:flutter/material.dart';

import '../features/connection_profiles/application/connection_profiles_controller.dart';
import '../features/connection_profiles/presentation/connection_profiles_screen.dart';
import 'pve_companion_about.dart';
import 'pve_companion_controller.dart';
import 'pve_companion_theme.dart';
import 'pve_workspace.dart';

class PveCompanionApp extends StatefulWidget {
  const PveCompanionApp({super.key, required this.controller});

  final PveCompanionController controller;

  @override
  State<PveCompanionApp> createState() => _PveCompanionAppState();
}

class _PveCompanionAppState extends State<PveCompanionApp> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.controller.initialize());
  }

  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PVE Companion',
      debugShowCheckedModeBanner: false,
      theme: PveCompanionTheme.light(),
      darkTheme: PveCompanionTheme.dark(),
      themeMode: ThemeMode.system,
      home: AnimatedBuilder(
        animation: widget.controller,
        builder: (BuildContext context, Widget? child) {
          final ConnectionProfilesController profiles =
              widget.controller.connectionProfiles;
          switch (profiles.loadState) {
            case ConnectionProfilesLoadState.loading:
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
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
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.error_outline,
                  size: 42,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Unable to open saved servers',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => onRetry(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
