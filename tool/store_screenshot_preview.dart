import 'package:flutter/material.dart';
import 'package:pve_companion/app/pve_companion_theme.dart';
import 'package:pve_companion/app/workspace/adaptive_workspace_content.dart';
import 'package:pve_companion/app/workspace/workspace_section.dart';
import 'package:pve_companion/core/api/proxmox_session.dart';
import 'package:pve_companion/features/cluster_overview/application/cluster_overview_controller.dart';
import 'package:pve_companion/features/cluster_overview/data/proxmox_cluster_overview_repository.dart';
import 'package:pve_companion/features/cluster_overview/domain/cluster_overview_snapshot.dart';
import 'package:pve_companion/features/cluster_overview/presentation/cluster_nodes_page.dart';
import 'package:pve_companion/features/cluster_overview/presentation/cluster_overview_page.dart';
import 'package:pve_companion/features/guests/presentation/guest_list_page.dart';
import 'package:pve_companion/features/storage/presentation/storage_page.dart';
import 'package:pve_companion/features/tasks/presentation/tasks_page.dart';

import 'support/datacenter_dashboard_preview_data.dart';

const String _sceneName = String.fromEnvironment(
  'SCREENSHOT_SCENE',
  defaultValue: 'overview',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final ClusterOverviewController controller = ClusterOverviewController(
    _PreviewClusterOverviewRepository(
      datacenterDashboardHealthyPreviewSnapshot(),
    ),
  );
  final _PreviewProxmoxSession session = _PreviewProxmoxSession();
  await controller.refresh(session);
  runApp(
    _StoreScreenshotApp(
      controller: controller,
      session: session,
      initialSection: _sectionFromName(_sceneName),
    ),
  );
}

WorkspaceSection _sectionFromName(String name) {
  return WorkspaceSection.values.firstWhere(
    (WorkspaceSection section) => section.name == name,
    orElse: () => WorkspaceSection.overview,
  );
}

class _StoreScreenshotApp extends StatefulWidget {
  const _StoreScreenshotApp({
    required this.controller,
    required this.session,
    required this.initialSection,
  });

  final ClusterOverviewController controller;
  final ProxmoxSession session;
  final WorkspaceSection initialSection;

  @override
  State<_StoreScreenshotApp> createState() => _StoreScreenshotAppState();
}

class _StoreScreenshotAppState extends State<_StoreScreenshotApp> {
  late WorkspaceSection _section = widget.initialSection;

  @override
  void dispose() {
    widget.controller.dispose();
    widget.session.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PVE Companion',
      debugShowCheckedModeBanner: false,
      theme: PveCompanionTheme.light(),
      home: Scaffold(
        appBar: AppBar(
          titleSpacing: 20,
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _BrandMark(),
              SizedBox(width: 12),
              Flexible(child: Text('Pennsylvania Lab')),
            ],
          ),
          actions: <Widget>[
            IconButton(
              onPressed: () {},
              tooltip: 'Refresh cluster',
              icon: const Icon(Icons.refresh),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: AdaptiveWorkspaceContent(
          section: _section,
          onSectionChanged: (WorkspaceSection section) {
            setState(() => _section = section);
          },
          pages: <Widget>[
            ClusterOverviewPage(
              controller: widget.controller,
              onRefresh: () async {},
              onViewGuests: () => _select(WorkspaceSection.guests),
              onViewNodes: () => _select(WorkspaceSection.nodes),
              onViewStorage: () => _select(WorkspaceSection.storage),
              onViewTasks: () => _select(WorkspaceSection.tasks),
            ),
            GuestListPage(
              overviewController: widget.controller,
              session: widget.session,
              onGuestPowerAction: () async {},
            ),
            ClusterNodesPage(controller: widget.controller),
            StoragePage(controller: widget.controller),
            TasksPage(controller: widget.controller),
          ],
        ),
      ),
    );
  }

  void _select(WorkspaceSection section) {
    setState(() => _section = section);
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.asset(
        'assets/brand/pve_companion_mark.png',
        width: 32,
        height: 32,
        excludeFromSemantics: true,
      ),
    );
  }
}

class _PreviewClusterOverviewRepository implements ClusterOverviewRepository {
  const _PreviewClusterOverviewRepository(this.snapshot);

  final ClusterOverviewSnapshot snapshot;

  @override
  Future<ClusterOverviewSnapshot> load(ProxmoxSession session) async {
    return snapshot;
  }
}

class _PreviewProxmoxSession implements ProxmoxSession {
  @override
  void close() {}

  @override
  Future<Object?> getData(
    String resource, {
    Map<String, String> query = const <String, String>{},
  }) {
    throw UnsupportedError('Store previews never make network requests.');
  }

  @override
  Future<Object?> postForm(
    String resource, {
    required Map<String, String> fields,
  }) {
    throw UnsupportedError('Store previews never make network requests.');
  }
}
