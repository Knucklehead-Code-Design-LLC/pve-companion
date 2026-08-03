import 'package:flutter/cupertino.dart';

import '../../../core/api/proxmox_session.dart';
import '../../../core/presentation/pve_apple_ui.dart';
import '../../../core/presentation/pve_modal_sheet.dart';
import '../../cluster_overview/domain/cluster_overview_snapshot.dart';
import '../application/cluster_administration_controller.dart';
import '../data/proxmox_cluster_administration_repository.dart';
import '../domain/pve_cluster_administration.dart';

Future<void> showClusterAdministrationSheet(
  BuildContext context, {
  required ProxmoxSession session,
  required ClusterOverviewSnapshot overview,
  required VoidCallback onViewNodes,
}) {
  return showPveModalSheet<void>(
    context: context,
    scrollableBuilder:
        (BuildContext sheetContext, ScrollController scrollController) =>
            _ClusterAdministrationSheet(
              session: session,
              overview: overview,
              scrollController: scrollController,
              onViewNodes: onViewNodes,
            ),
  );
}

class _ClusterAdministrationSheet extends StatefulWidget {
  const _ClusterAdministrationSheet({
    required this.session,
    required this.overview,
    required this.scrollController,
    required this.onViewNodes,
  });

  final ProxmoxSession session;
  final ClusterOverviewSnapshot overview;
  final ScrollController scrollController;
  final VoidCallback onViewNodes;

  @override
  State<_ClusterAdministrationSheet> createState() =>
      _ClusterAdministrationSheetState();
}

class _ClusterAdministrationSheetState
    extends State<_ClusterAdministrationSheet> {
  late final ClusterAdministrationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ClusterAdministrationController(
      repository: ProxmoxClusterAdministrationRepository(),
      session: widget.session,
      overview: widget.overview,
    );
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: PveAppleColors.page(context),
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Cluster Administration'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PveIconAction(
              icon: CupertinoIcons.refresh,
              label: 'Refresh cluster administration',
              onPressed: _controller.load,
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? child) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: _buildContent(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return switch (_controller.state) {
      ClusterAdministrationLoadState.loading => const PveLoadingState(
        label: 'Loading cluster administration',
      ),
      ClusterAdministrationLoadState.failed => PveEmptyState(
        icon: CupertinoIcons.shield_lefthalf_fill,
        title: 'Cluster data unavailable',
        message:
            _controller.errorMessage ??
            'Cluster administration data could not be loaded.',
        actionLabel: 'Try Again',
        onAction: _controller.load,
        destructive: true,
      ),
      ClusterAdministrationLoadState.ready => _ClusterAdministrationContent(
        snapshot: _controller.snapshot!,
        scrollController: widget.scrollController,
        onViewNodes: _viewNodes,
      ),
    };
  }

  void _viewNodes() {
    Navigator.of(context).pop();
    widget.onViewNodes();
  }
}

class _ClusterAdministrationContent extends StatelessWidget {
  const _ClusterAdministrationContent({
    required this.snapshot,
    required this.scrollController,
    required this.onViewNodes,
  });

  final PveClusterAdministrationSnapshot snapshot;
  final ScrollController scrollController;
  final VoidCallback onViewNodes;

  @override
  Widget build(BuildContext context) {
    final PveClusterStatus? status = snapshot.clusterStatus;
    final int onlineNodes = snapshot.overview.nodes
        .where((ClusterNode node) => node.isOnline)
        .length;
    final int haIssueCount = snapshot.haResources
        .where((PveHaResourceStatus resource) => _hasHaIssue(resource))
        .length;
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: 32),
      children: <Widget>[
        Text('Cluster posture', style: PveAppleText.title2(context)),
        const SizedBox(height: 6),
        Text(
          'Audit quorum, membership, HA state, and safe configuration context. Destructive cluster topology and network changes remain in Proxmox’s full administration UI.',
          style: PveAppleText.secondary(context),
        ),
        const SizedBox(height: 18),
        PveMetricStrip(
          items: <PveMetricStripItem>[
            PveMetricStripItem(
              label: 'Nodes',
              value: '$onlineNodes/${snapshot.overview.nodes.length}',
              icon: CupertinoIcons.rectangle_stack,
              color: onlineNodes == snapshot.overview.nodes.length
                  ? PveAppleColors.success(context)
                  : PveAppleColors.destructive(context),
            ),
            PveMetricStripItem(
              label: 'Quorum',
              value: _quorumLabel(status?.quorate),
              icon: CupertinoIcons.check_mark_circled,
              color: _quorumColor(context, status?.quorate),
            ),
            PveMetricStripItem(
              label: 'HA services',
              value: '${snapshot.haResources.length}',
              icon: CupertinoIcons.shield,
            ),
            PveMetricStripItem(
              label: 'HA attention',
              value: '$haIssueCount',
              icon: CupertinoIcons.exclamationmark_triangle_fill,
              color: haIssueCount == 0
                  ? PveAppleColors.success(context)
                  : PveAppleColors.warning(context),
            ),
          ],
        ),
        const SizedBox(height: 24),
        PveSectionHeader(
          title: 'Membership & quorum',
          actionLabel: 'View Nodes',
          actionSemanticsLabel: 'View operational node controls',
          onAction: onViewNodes,
        ),
        _ClusterStatusCard(status: status),
        const SizedBox(height: 24),
        const PveSectionTitle(title: 'High availability'),
        const SizedBox(height: 8),
        _HaResourcesCard(resources: snapshot.haResources),
        const SizedBox(height: 24),
        const PveSectionTitle(title: 'Datacenter options'),
        const SizedBox(height: 8),
        _ClusterOptionsCard(options: snapshot.options),
        const SizedBox(height: 24),
        PveInsetGroup(
          color: PveAppleColors.warning(context).withValues(alpha: 0.08),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                CupertinoIcons.lock_shield,
                size: 19,
                color: PveAppleColors.warning(context),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'For safety, PVE Companion does not alter cluster membership, quorum, storage definitions, or network topology. Use the guarded node and guest controls for day-to-day operations, and use Proxmox for topology changes.',
                  style: PveAppleText.secondary(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ClusterStatusCard extends StatelessWidget {
  const _ClusterStatusCard({required this.status});

  final PveClusterStatus? status;

  @override
  Widget build(BuildContext context) {
    if (status == null) {
      return const PveInsetGroup(
        padding: EdgeInsets.all(16),
        child: Text(
          'Cluster status was not reported by this Proxmox account. Grant Audit permissions to inspect quorum and membership.',
        ),
      );
    }
    final PveClusterStatus reportedStatus = status!;
    final List<PveClusterMember> members = reportedStatus.members;
    return PveInsetGroup(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          if (reportedStatus.name != null)
            PveListRow(
              title: const Text('Cluster'),
              trailing: Text(
                reportedStatus.name!,
                style: PveAppleText.secondary(context),
              ),
            ),
          if (reportedStatus.name != null)
            const PveRowSeparator(leadingIndent: 16),
          PveListRow(
            title: const Text('Quorum'),
            trailing: PveStatusPill(
              label: _quorumLabel(reportedStatus.quorate),
              color: _quorumColor(context, reportedStatus.quorate),
            ),
          ),
          if (members.isNotEmpty) const PveRowSeparator(leadingIndent: 16),
          for (int index = 0; index < members.length; index++) ...<Widget>[
            PveListRow(
              leading: Icon(
                members[index].online == false
                    ? CupertinoIcons.xmark_circle_fill
                    : CupertinoIcons.check_mark_circled_solid,
                color: members[index].online == false
                    ? PveAppleColors.destructive(context)
                    : PveAppleColors.success(context),
              ),
              title: Text(members[index].name),
              subtitle: Text(_memberSubtitle(members[index])),
              trailing: members[index].local
                  ? PveStatusPill(
                      label: 'Local',
                      color: PveAppleColors.primary(context),
                    )
                  : null,
            ),
            if (index < members.length - 1) const PveRowSeparator(),
          ],
        ],
      ),
    );
  }
}

class _HaResourcesCard extends StatelessWidget {
  const _HaResourcesCard({required this.resources});

  final List<PveHaResourceStatus> resources;

  @override
  Widget build(BuildContext context) {
    if (resources.isEmpty) {
      return const PveInsetGroup(
        padding: EdgeInsets.all(16),
        child: Text('No high-availability service state was reported.'),
      );
    }
    return PveInsetGroup(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          for (int index = 0; index < resources.length; index++) ...<Widget>[
            PveListRow(
              leading: Icon(
                _hasHaIssue(resources[index])
                    ? CupertinoIcons.exclamationmark_triangle_fill
                    : CupertinoIcons.check_mark_circled_solid,
                color: _hasHaIssue(resources[index])
                    ? PveAppleColors.warning(context)
                    : PveAppleColors.success(context),
              ),
              title: Text(resources[index].service),
              subtitle: Text(_haSubtitle(resources[index])),
              trailing: PveStatusPill(
                label: resources[index].state,
                color: _hasHaIssue(resources[index])
                    ? PveAppleColors.warning(context)
                    : PveAppleColors.success(context),
              ),
            ),
            if (index < resources.length - 1) const PveRowSeparator(),
          ],
        ],
      ),
    );
  }
}

class _ClusterOptionsCard extends StatelessWidget {
  const _ClusterOptionsCard({required this.options});

  final Map<String, String> options;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return const PveInsetGroup(
        padding: EdgeInsets.all(16),
        child: Text('No safe datacenter option values were reported.'),
      );
    }
    final List<MapEntry<String, String>> entries = options.entries.toList()
      ..sort(
        (MapEntry<String, String> left, MapEntry<String, String> right) =>
            left.key.compareTo(right.key),
      );
    return PveInsetGroup(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          for (int index = 0; index < entries.length; index++) ...<Widget>[
            PveListRow(
              title: Text(_optionLabel(entries[index].key)),
              trailing: Text(
                entries[index].value,
                style: PveAppleText.secondary(context),
              ),
            ),
            if (index < entries.length - 1)
              const PveRowSeparator(leadingIndent: 16),
          ],
        ],
      ),
    );
  }
}

bool _hasHaIssue(PveHaResourceStatus resource) {
  final String state = resource.state.toLowerCase();
  return state.contains('error') ||
      state.contains('fence') ||
      state.contains('stop');
}

String _quorumLabel(bool? quorate) => switch (quorate) {
  true => 'Quorate',
  false => 'No quorum',
  null => 'Not reported',
};

Color _quorumColor(BuildContext context, bool? quorate) => switch (quorate) {
  true => PveAppleColors.success(context),
  false => PveAppleColors.destructive(context),
  null => PveAppleColors.secondaryLabel(context),
};

String _memberSubtitle(PveClusterMember member) {
  final List<String> fragments = <String>[
    member.type,
    if (member.nodeId != null) 'ID ${member.nodeId}',
    if (member.address != null) member.address!,
  ];
  return fragments.join(' · ');
}

String _haSubtitle(PveHaResourceStatus resource) {
  final List<String> fragments = <String>[
    if (resource.node != null) resource.node!,
    if (resource.status != null) resource.status!,
  ];
  return fragments.isEmpty
      ? 'No further status reported'
      : fragments.join(' · ');
}

String _optionLabel(String option) => switch (option) {
  'max_workers' => 'Maximum workers',
  'console' => 'Default console',
  'keyboard' => 'Keyboard layout',
  'migration' => 'Migration network',
  'language' => 'Language',
  _ => option,
};
