import 'package:flutter/cupertino.dart';

import '../../../core/presentation/pve_apple_ui.dart';
import '../application/cluster_overview_controller.dart';
import '../domain/cluster_overview_snapshot.dart';
import '../domain/datacenter_health.dart';
import '../domain/datacenter_health_evaluator.dart';
import 'cluster_overview_format.dart';
import 'datacenter_dashboard_visuals.dart';

class ClusterNodesPage extends StatefulWidget {
  const ClusterNodesPage({
    super.key,
    required this.controller,
    required this.onRefresh,
    this.showsSliverNavigationBar = true,
    this.navigationLeading,
    this.navigationTrailing,
  });

  final ClusterOverviewController controller;
  final Future<void> Function() onRefresh;
  final bool showsSliverNavigationBar;
  final Widget? navigationLeading;
  final Widget? navigationTrailing;

  @override
  State<ClusterNodesPage> createState() => _ClusterNodesPageState();
}

class _ClusterNodesPageState extends State<ClusterNodesPage> {
  final TextEditingController _searchController = TextEditingController();
  _NodeFilter _filter = _NodeFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool usesIpadPresentation = PveAppleLayout.usesIpadPresentation(
      context,
    );
    final ClusterOverviewSnapshot? snapshot = widget.controller.snapshot;
    return PvePrimaryScrollView(
      title: 'Nodes',
      showsSliverNavigationBar: widget.showsSliverNavigationBar,
      navigationLeading: widget.navigationLeading,
      navigationTrailing: widget.navigationTrailing,
      onRefresh: widget.onRefresh,
      slivers: <Widget>[
        if (snapshot == null)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: PveLoadingState(label: 'Loading nodes'),
          )
        else
          PveCenteredSliver(
            maxWidth: 1100,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: _buildContent(
              context,
              snapshot,
              usesIpadPresentation: usesIpadPresentation,
            ),
          ),
      ],
    );
  }

  Widget _buildContent(
    BuildContext context,
    ClusterOverviewSnapshot snapshot, {
    required bool usesIpadPresentation,
  }) {
    final List<DatacenterNodeHealth> nodes =
        List<DatacenterNodeHealth>.of(
          DatacenterHealthEvaluator.evaluate(snapshot).nodes,
        )..sort((DatacenterNodeHealth left, DatacenterNodeHealth right) {
          final int healthOrder = right.state.index.compareTo(left.state.index);
          return healthOrder != 0
              ? healthOrder
              : left.node.name.toLowerCase().compareTo(
                  right.node.name.toLowerCase(),
                );
        });
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
    final int totalCores = nodes.fold<int>(
      0,
      (int total, DatacenterNodeHealth node) =>
          total + (node.node.cpuCores ?? 0),
    );
    final Widget search = CupertinoSearchTextField(
      controller: _searchController,
      placeholder: 'Search nodes',
      onChanged: (_) => setState(() {}),
      onSubmitted: (_) => setState(() {}),
    );
    final Widget filter = PveSlidingSegmentedControl<_NodeFilter>(
      groupValue: _filter,
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
        if (usesIpadPresentation)
          PveMetricStrip(
            items: <PveMetricStripItem>[
              PveMetricStripItem(
                label: 'Nodes',
                value: '${nodes.length}',
                icon: CupertinoIcons.rectangle_stack,
              ),
              PveMetricStripItem(
                label: 'Online',
                value: '$onlineCount',
                icon: CupertinoIcons.check_mark_circled_solid,
                color: PveAppleColors.success(context),
              ),
              PveMetricStripItem(
                label: 'Attention',
                value: '$attentionCount',
                icon: CupertinoIcons.exclamationmark_triangle_fill,
                color: attentionCount == 0
                    ? PveAppleColors.success(context)
                    : PveAppleColors.warning(context),
              ),
              PveMetricStripItem(
                label: 'CPU cores',
                value: '$totalCores',
                icon: CupertinoIcons.speedometer,
              ),
            ],
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '$onlineCount/${nodes.length} online · '
              '$attentionCount '
              '${attentionCount == 1 ? 'needs' : 'need'} attention',
              style: PveAppleText.caption(context),
            ),
          ),
        const SizedBox(height: 12),
        PveWideControlBar(primary: search, secondary: filter),
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
          LayoutBuilder(
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
                        child: _NodeDetailCard(node: node),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
      ],
    );
  }
}

class _NodeDetailCard extends StatelessWidget {
  const _NodeDetailCard({required this.node});

  final DatacenterNodeHealth node;

  @override
  Widget build(BuildContext context) {
    final DatacenterDashboardTone tone = node.node.isOnline
        ? dashboardToneForHealth(node.state)
        : DatacenterDashboardTone.critical;
    final Color accent = dashboardToneColor(context, tone);
    return PveInsetGroup(
      padding: const EdgeInsets.all(18),
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
                      '${node.node.cpuCores ?? 0} cores · '
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
    );
  }
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
    final String value = _pressureValue(pressure, useBytes);
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text(label, style: PveAppleText.caption(context))),
            Text(
              value,
              style: PveAppleText.caption(context).copyWith(color: accent),
            ),
          ],
        ),
        const SizedBox(height: 6),
        PveProgressBar(value: pressure?.progressFraction, color: accent),
      ],
    );
  }
}

enum _NodeFilter { all, attention }

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

String _pressureValue(DatacenterPressureMetric? pressure, bool useBytes) {
  if (pressure == null) {
    return 'Not reported';
  }
  if (useBytes && pressure.hasByteTotals) {
    return '${formatPveBytes(pressure.usedBytes)} / '
        '${formatPveBytes(pressure.capacityBytes)}';
  }
  return formatPvePercent(pressure.fraction);
}
