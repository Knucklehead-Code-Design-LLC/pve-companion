import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/services.dart';

import '../../../core/api/proxmox_session.dart';
import '../../../core/presentation/pve_apple_ui.dart';
import '../../../core/presentation/pve_data_visualization.dart';
import '../../../core/presentation/pve_value_format.dart';
import '../../guests/domain/pve_guest.dart';
import '../../node_operations/domain/pve_node_details.dart';
import '../../node_operations/presentation/node_detail_sheet.dart';
import '../application/cluster_overview_controller.dart';
import '../domain/cluster_overview_snapshot.dart';
import '../domain/datacenter_health.dart';
import '../domain/datacenter_health_evaluator.dart';
import 'cluster_load_state_view.dart';
import 'datacenter_dashboard_visuals.dart';
import 'node_inventory_insights.dart';

class ClusterNodesPage extends StatefulWidget {
  const ClusterNodesPage({
    super.key,
    required this.controller,
    required this.onRefresh,
    this.showsSliverNavigationBar = true,
    this.navigationLeading,
    this.navigationTrailing,
    this.session,
    this.onNodeOperation,
    this.onViewGuests,
    this.onViewTasks,
  });

  final ClusterOverviewController controller;
  final Future<void> Function() onRefresh;
  final bool showsSliverNavigationBar;
  final Widget? navigationLeading;
  final Widget? navigationTrailing;
  final ProxmoxSession? session;
  final Future<void> Function()? onNodeOperation;
  final VoidCallback? onViewGuests;
  final VoidCallback? onViewTasks;

  @override
  State<ClusterNodesPage> createState() => _ClusterNodesPageState();
}

class _ClusterNodesPageState extends State<ClusterNodesPage> {
  final TextEditingController _searchController = TextEditingController();
  _NodeFilter _filter = _NodeFilter.all;
  _NodeInventorySort _sort = _NodeInventorySort.attention;
  String? _selectedNodeName;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ClusterOverviewSnapshot? snapshot = widget.controller.snapshot;
    return PvePrimaryScrollView(
      title: 'Nodes',
      showsSliverNavigationBar: widget.showsSliverNavigationBar,
      navigationLeading: widget.navigationLeading,
      navigationTrailing: widget.navigationTrailing,
      onRefresh: widget.onRefresh,
      slivers: <Widget>[
        if (snapshot == null)
          SliverFillRemaining(
            hasScrollBody: false,
            child: ClusterLoadStateView(
              controller: widget.controller,
              loadingLabel: 'Loading nodes',
              onRetry: widget.onRefresh,
            ),
          )
        else
          PveCenteredSliver(
            maxWidth: 1100,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: _buildContent(context, snapshot),
          ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, ClusterOverviewSnapshot snapshot) {
    final bool usesDesktopInspector =
        Theme.of(context).platform == TargetPlatform.macOS &&
        PveAppleLayout.usesWidePresentation(context);
    final DatacenterHealth health = DatacenterHealthEvaluator.evaluate(
      snapshot,
    );
    final List<DatacenterNodeHealth> nodes = List<DatacenterNodeHealth>.of(
      health.nodes,
    )..sort(_compareNodes);
    final String searchQuery = _searchController.text.trim().toLowerCase();
    final List<DatacenterNodeHealth> visibleNodes = nodes
        .where(
          (DatacenterNodeHealth node) =>
              _filter == _NodeFilter.all ||
              node.state != DatacenterHealthState.healthy,
        )
        .where(
          (DatacenterNodeHealth node) =>
              searchQuery.isEmpty ||
              node.node.name.toLowerCase().contains(searchQuery),
        )
        .toList(growable: false);
    final int onlineCount = nodes
        .where((DatacenterNodeHealth node) => node.node.isOnline)
        .length;
    final int attentionCount = nodes
        .where(
          (DatacenterNodeHealth node) =>
              node.state != DatacenterHealthState.healthy,
        )
        .length;
    final List<DatacenterNodeHealth> nodesWithCpuCores = nodes
        .where((DatacenterNodeHealth node) => node.node.cpuCores != null)
        .toList(growable: false);
    final int? totalCores = nodesWithCpuCores.isEmpty
        ? null
        : nodesWithCpuCores.fold<int>(
            0,
            (int total, DatacenterNodeHealth node) =>
                total + node.node.cpuCores!,
          );
    final bool canOpenNodeOperations =
        widget.session != null && widget.onNodeOperation != null;
    final Widget search = CupertinoSearchTextField(
      controller: _searchController,
      placeholder: 'Search nodes',
      onChanged: (_) => setState(() {}),
      onSubmitted: (_) => setState(() {}),
    );
    final Widget filter = PveSlidingSegmentedControl<_NodeFilter>(
      key: const ValueKey<String>('node-status-filter'),
      groupValue: _filter,
      semanticLabels: const <_NodeFilter, String>{
        _NodeFilter.all: 'All nodes',
        _NodeFilter.attention: 'Nodes needing attention',
      },
      children: const <_NodeFilter, Widget>{
        _NodeFilter.all: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('All'),
        ),
        _NodeFilter.attention: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('Attention'),
        ),
      },
      onValueChanged: (_NodeFilter? value) {
        if (value != null) {
          setState(() => _filter = value);
        }
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (widget.controller.errorMessage != null) ...<Widget>[
          ClusterRefreshFailureBanner(
            message: widget.controller.errorMessage!,
            onRetry: widget.onRefresh,
          ),
          const SizedBox(height: 12),
        ],
        PveMetricStrip(
          items: <PveMetricStripItem>[
            PveMetricStripItem(
              label: 'Nodes',
              value: '${nodes.length}',
              icon: CupertinoIcons.rectangle_stack,
              scope: 'Reported by this server',
            ),
            PveMetricStripItem(
              label: 'Online',
              value: '$onlineCount',
              icon: CupertinoIcons.check_mark_circled_solid,
              color: PveAppleColors.success(context),
              scope: 'Currently reported online',
            ),
            PveMetricStripItem(
              label: 'Attention',
              value: '$attentionCount',
              icon: CupertinoIcons.exclamationmark_triangle_fill,
              color: attentionCount == 0
                  ? PveAppleColors.success(context)
                  : PveAppleColors.warning(context),
              scope: 'Derived from the latest health report',
            ),
            PveMetricStripItem(
              label: 'CPU cores reported',
              value: totalCores == null ? '—' : '$totalCores',
              icon: CupertinoIcons.speedometer,
              color: totalCores == null
                  ? PveAppleColors.secondaryLabel(context)
                  : null,
              scope: totalCores == null
                  ? 'No nodes report CPU cores'
                  : '${nodesWithCpuCores.length} of ${nodes.length} nodes report cores',
            ),
          ],
        ),
        const SizedBox(height: 20),
        const PveSectionTitle(title: 'Node inventory'),
        const SizedBox(height: 12),
        PveWideControlBar(primary: search, secondary: filter),
        Align(
          alignment: Alignment.centerRight,
          child: CupertinoButton(
            key: const ValueKey<String>('node-inventory-sort'),
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            onPressed: () => _showSortPicker(context),
            child: Text('Sort: ${_sort.label}'),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _nodeInventoryCountLabel(
            visibleCount: visibleNodes.length,
            totalCount: nodes.length,
          ),
          key: const ValueKey<String>('node-inventory-result-count'),
          style: PveAppleText.secondary(context),
        ),
        const SizedBox(height: 16),
        if (nodes.isEmpty)
          const PveInsetGroup(
            padding: EdgeInsets.all(20),
            child: Text('No nodes were reported by this server.'),
          )
        else if (visibleNodes.isEmpty)
          PveInsetGroup(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: <Widget>[
                Icon(
                  CupertinoIcons.check_mark_circled,
                  size: 30,
                  color: PveAppleColors.success(context),
                ),
                const SizedBox(height: 10),
                Text(
                  searchQuery.isEmpty
                      ? 'No nodes need attention'
                      : 'No matching nodes',
                  style: PveAppleText.title3(context),
                ),
              ],
            ),
          )
        else
          _buildNodeInventory(
            snapshot: snapshot,
            visibleNodes: visibleNodes,
            canOpenNodeOperations: canOpenNodeOperations,
            usesDesktopInspector: usesDesktopInspector,
          ),
        const SizedBox(height: 24),
        const PveSectionTitle(title: 'Cluster analysis'),
        const SizedBox(height: 12),
        NodeInventoryInsights(health: health),
      ],
    );
  }

  Widget _buildNodeInventory({
    required ClusterOverviewSnapshot snapshot,
    required List<DatacenterNodeHealth> visibleNodes,
    required bool canOpenNodeOperations,
    required bool usesDesktopInspector,
  }) {
    final DatacenterNodeHealth selectedNode = visibleNodes.firstWhere(
      (DatacenterNodeHealth node) => node.node.name == _selectedNodeName,
      orElse: () => visibleNodes.first,
    );
    final Widget cards = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool twoColumns = constraints.maxWidth >= 760;
        final double width = twoColumns
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: visibleNodes
              .map(
                (DatacenterNodeHealth node) => SizedBox(
                  width: width,
                  child: _NodeDetailCard(
                    node: node,
                    selected:
                        usesDesktopInspector &&
                        node.node.name == selectedNode.node.name,
                    onTap: usesDesktopInspector
                        ? () =>
                              setState(() => _selectedNodeName = node.node.name)
                        : canOpenNodeOperations
                        ? () => _showNode(node)
                        : null,
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
    if (!usesDesktopInspector) return cards;
    return PveInspectorLayout(
      primary: cards,
      inspector: _NodeInventoryInspector(
        node: selectedNode,
        snapshot: snapshot,
        onOpenDetails: canOpenNodeOperations
            ? () => _showNode(selectedNode)
            : null,
        onViewGuests: widget.onViewGuests,
        onViewTasks: widget.onViewTasks,
      ),
    );
  }

  Future<void> _showNode(DatacenterNodeHealth node) async {
    final ProxmoxSession? session = widget.session;
    final Future<void> Function()? onNodeOperation = widget.onNodeOperation;
    if (session == null || onNodeOperation == null) {
      return;
    }
    await showNodeDetailSheet(
      context,
      seed: PveNodeDetailsSeed(
        node.node,
        hostedGuestCount: widget.controller.snapshot!.guests
            .where((PveGuest guest) => guest.node == node.node.name)
            .length,
        runningHostedGuestCount: widget.controller.snapshot!.guests
            .where(
              (PveGuest guest) =>
                  guest.node == node.node.name && guest.isRunning,
            )
            .length,
        clusterOnlineNodeCount: widget.controller.snapshot!.nodes
            .where((ClusterNode clusterNode) => clusterNode.isOnline)
            .length,
        recentTaskCount: widget.controller.snapshot!.tasks
            .where((ClusterTask task) => task.node == node.node.name)
            .length,
      ),
      session: session,
      onNodeOperation: onNodeOperation,
    );
  }

  int _compareNodes(DatacenterNodeHealth left, DatacenterNodeHealth right) {
    final int result = switch (_sort) {
      _NodeInventorySort.attention => _attentionRank(
        left,
      ).compareTo(_attentionRank(right)),
      _NodeInventorySort.name => left.node.name.compareTo(right.node.name),
      _NodeInventorySort.uptime => (right.node.uptimeSeconds ?? -1).compareTo(
        left.node.uptimeSeconds ?? -1,
      ),
      _NodeInventorySort.resource => _nodeResourceUse(
        right,
      ).compareTo(_nodeResourceUse(left)),
    };
    return result == 0 ? left.node.name.compareTo(right.node.name) : result;
  }

  int _attentionRank(DatacenterNodeHealth node) {
    if (!node.node.isOnline) {
      return 0;
    }
    return switch (node.state) {
      DatacenterHealthState.critical => 1,
      DatacenterHealthState.warning => 2,
      DatacenterHealthState.healthy => 3,
    };
  }

  String _nodeInventoryCountLabel({
    required int visibleCount,
    required int totalCount,
  }) {
    final String noun = totalCount == 1 ? 'node' : 'nodes';
    if (visibleCount == totalCount) {
      return 'Showing all $totalCount $noun';
    }
    return 'Showing $visibleCount of $totalCount $noun';
  }

  double _nodeResourceUse(DatacenterNodeHealth node) =>
      node.cpu?.progressFraction ?? node.memory?.progressFraction ?? -1;

  Future<void> _showSortPicker(BuildContext context) async {
    final _NodeInventorySort? sort =
        await showCupertinoModalPopup<_NodeInventorySort>(
          context: context,
          builder: (BuildContext popupContext) => CupertinoActionSheet(
            title: const Text('Sort node inventory'),
            actions: _NodeInventorySort.values
                .map(
                  (_NodeInventorySort value) => CupertinoActionSheetAction(
                    isDefaultAction: value == _sort,
                    onPressed: () => Navigator.of(popupContext).pop(value),
                    child: Text(value.label),
                  ),
                )
                .toList(growable: false),
            cancelButton: CupertinoActionSheetAction(
              onPressed: () => Navigator.of(popupContext).pop(),
              child: const Text('Cancel'),
            ),
          ),
        );
    if (sort != null && mounted) {
      setState(() => _sort = sort);
    }
  }
}

class _NodeDetailCard extends StatelessWidget {
  const _NodeDetailCard({
    required this.node,
    required this.onTap,
    this.selected = false,
  });

  final DatacenterNodeHealth node;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final DatacenterDashboardTone tone = node.node.isOnline
        ? dashboardToneForHealth(node.state)
        : DatacenterDashboardTone.critical;
    final Color accent = dashboardToneColor(context, tone);
    return Semantics(
      selected: selected,
      label: '${node.node.name}, ${_statusLabel(node)} node',
      child: PveInsetGroup(
        key: ValueKey<String>('node-inventory-${node.node.name}'),
        onTap: onTap,
        padding: const EdgeInsets.all(18),
        color: selected
            ? PveAppleColors.primary(context).withValues(alpha: 0.09)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SizedBox.square(
                    dimension: 34,
                    child: Icon(
                      CupertinoIcons.rectangle_stack,
                      size: 19,
                      color: accent,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(node.node.name, style: PveAppleText.title3(context)),
                      Text(
                        '${_cpuCoreLabel(node.node.cpuCores)} · '
                        '${formatPveUptime(node.node.uptimeSeconds)} uptime',
                        style: PveAppleText.caption(context),
                      ),
                    ],
                  ),
                ),
                Text(
                  _statusLabel(node),
                  style: PveAppleText.caption(
                    context,
                  ).copyWith(color: accent, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _PressureRow(label: 'CPU', pressure: node.cpu, useBytes: false),
            const SizedBox(height: 14),
            _PressureRow(label: 'Memory', pressure: node.memory),
            const SizedBox(height: 14),
            _PressureRow(label: 'Root disk', pressure: node.rootDisk),
          ],
        ),
      ),
    );
  }
}

class _NodeInventoryInspector extends StatefulWidget {
  const _NodeInventoryInspector({
    required this.node,
    required this.snapshot,
    this.onOpenDetails,
    this.onViewGuests,
    this.onViewTasks,
  });

  final DatacenterNodeHealth node;
  final ClusterOverviewSnapshot snapshot;
  final VoidCallback? onOpenDetails;
  final VoidCallback? onViewGuests;
  final VoidCallback? onViewTasks;

  @override
  State<_NodeInventoryInspector> createState() =>
      _NodeInventoryInspectorState();
}

class _NodeInventoryInspectorState extends State<_NodeInventoryInspector> {
  String? _copiedLabel;

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) setState(() => _copiedLabel = label);
  }

  @override
  Widget build(BuildContext context) {
    final ClusterNode node = widget.node.node;
    final List<PveGuest> hostedGuests = widget.snapshot.guests
        .where((PveGuest guest) => guest.node == node.name)
        .toList(growable: false);
    final int runningGuests = hostedGuests
        .where((PveGuest guest) => guest.isRunning)
        .length;
    final List<ClusterTask> recentTasks = widget.snapshot.tasks
        .where((ClusterTask task) => task.node == node.name)
        .toList(growable: false);
    return CupertinoContextMenu(
      actions: <Widget>[
        CupertinoContextMenuAction(
          child: const Text('Copy node name'),
          onPressed: () {
            Navigator.of(context).pop();
            _copy(node.name, 'Node name');
          },
        ),
      ],
      child: PveInsetGroup(
        key: ValueKey<String>('desktop-node-inspector-${node.name}'),
        padding: const EdgeInsets.all(18),
        semanticLabel: 'Node inspector for ${node.name}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Selected node', style: PveAppleText.caption(context)),
            const SizedBox(height: 4),
            Text(node.name, style: PveAppleText.title2(context)),
            const SizedBox(height: 6),
            Text(
              _statusLabel(widget.node),
              style: PveAppleText.secondary(context),
            ),
            if (hostedGuests.isNotEmpty && widget.onViewGuests != null)
              CupertinoButton.tinted(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                alignment: Alignment.centerLeft,
                onPressed: widget.onViewGuests,
                child: Text('View ${hostedGuests.length} hosted guests'),
              ),
            if (recentTasks.isNotEmpty && widget.onViewTasks != null)
              CupertinoButton.tinted(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                alignment: Alignment.centerLeft,
                onPressed: widget.onViewTasks,
                child: Text('View ${recentTasks.length} node tasks'),
              ),
            const SizedBox(height: 18),
            _NodeInspectorValue(
              label: 'Hosted guests',
              value: '${hostedGuests.length}',
            ),
            _NodeInspectorValue(
              label: 'Running guests',
              value: '$runningGuests',
            ),
            _NodeInspectorValue(
              label: 'Recent tasks',
              value: '${recentTasks.length}',
            ),
            _NodeInspectorValue(
              label: 'CPU cores',
              value: node.cpuCores == null
                  ? 'Not reported'
                  : '${node.cpuCores}',
            ),
            _NodeInspectorValue(
              label: 'Uptime',
              value: formatPveUptime(node.uptimeSeconds),
            ),
            if (hostedGuests.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Text('Hosted guests', style: PveAppleText.title3(context)),
              const SizedBox(height: 6),
              for (final PveGuest guest in hostedGuests.take(5))
                Text(
                  '${guest.title} · ${guest.isRunning ? 'Running' : _statusLabelForGuest(guest.status)}',
                  style: PveAppleText.caption(context),
                ),
            ],
            if (recentTasks.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Text('Recent activity', style: PveAppleText.title3(context)),
              const SizedBox(height: 6),
              for (final ClusterTask task in recentTasks.take(3))
                Text(
                  '${task.type} · ${task.user}',
                  style: PveAppleText.caption(context),
                ),
            ],
            const SizedBox(height: 12),
            if (widget.onOpenDetails != null)
              CupertinoButton.filled(
                onPressed: widget.onOpenDetails,
                child: const Text('Open operational details'),
              ),
            CupertinoButton(
              onPressed: () => _copy(node.name, 'Node name'),
              child: Text(
                _copiedLabel == 'Node name'
                    ? 'Node name copied'
                    : 'Copy node name',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NodeInspectorValue extends StatelessWidget {
  const _NodeInspectorValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: <Widget>[
        Expanded(child: Text(label, style: PveAppleText.caption(context))),
        Text(value, style: PveAppleText.body(context)),
      ],
    ),
  );
}

class _PressureRow extends StatelessWidget {
  const _PressureRow({
    required this.label,
    required this.pressure,
    this.useBytes = true,
  });

  final String label;
  final DatacenterPressureMetric? pressure;
  final bool useBytes;

  @override
  Widget build(BuildContext context) {
    final DatacenterDashboardTone tone = dashboardToneForPressure(pressure);
    final Color accent = dashboardToneColor(context, tone);
    final String value = datacenterPressureValueLabel(
      pressure,
      includeByteTotals: useBytes,
    );
    return PveResourceMeter(
      label: label,
      value: value,
      progress: pressure?.progressFraction,
      color: accent,
    );
  }
}

enum _NodeFilter { all, attention }

enum _NodeInventorySort {
  attention('Attention'),
  name('Name'),
  uptime('Uptime'),
  resource('Resource use');

  const _NodeInventorySort(this.label);

  final String label;
}

String _statusLabel(DatacenterNodeHealth node) {
  if (!node.node.isOnline) {
    return 'Offline';
  }
  return switch (node.state) {
    DatacenterHealthState.healthy => 'Online',
    DatacenterHealthState.warning => 'Attention',
    DatacenterHealthState.critical => 'Critical',
  };
}

String _statusLabelForGuest(String status) {
  if (status.isEmpty) return 'Unknown';
  return '${status[0].toUpperCase()}${status.substring(1)}';
}

String _cpuCoreLabel(int? cpuCores) =>
    cpuCores == null ? 'CPU cores not reported' : '$cpuCores cores';
