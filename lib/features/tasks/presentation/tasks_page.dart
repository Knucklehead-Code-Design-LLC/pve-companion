import 'package:flutter/cupertino.dart';

import '../../../core/presentation/pve_apple_ui.dart';
import '../../cluster_overview/application/cluster_overview_controller.dart';
import '../../cluster_overview/domain/cluster_overview_snapshot.dart';
import '../../cluster_overview/presentation/cluster_overview_format.dart';
import '../../cluster_overview/presentation/datacenter_dashboard_visuals.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({
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
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  _TaskFilter _filter = _TaskFilter.all;

  @override
  Widget build(BuildContext context) {
    final bool usesIpadPresentation = PveAppleLayout.usesIpadPresentation(
      context,
    );
    final ClusterOverviewSnapshot? snapshot = widget.controller.snapshot;
    return PvePrimaryScrollView(
      title: 'Tasks',
      showsSliverNavigationBar: widget.showsSliverNavigationBar,
      navigationLeading: widget.navigationLeading,
      navigationTrailing: widget.navigationTrailing,
      onRefresh: widget.onRefresh,
      slivers: <Widget>[
        if (snapshot == null)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: PveLoadingState(label: 'Loading recent activity'),
          )
        else
          PveCenteredSliver(
            maxWidth: 980,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: _buildContent(
              context,
              snapshot.tasks,
              usesIpadPresentation: usesIpadPresentation,
            ),
          ),
      ],
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<ClusterTask> tasks, {
    required bool usesIpadPresentation,
  }) {
    final List<ClusterTask> visibleTasks = tasks
        .where(_matchesFilter)
        .toList(growable: false);
    final int runningCount = tasks
        .where((ClusterTask task) => task.state == ClusterTaskState.running)
        .length;
    final int failedCount = tasks
        .where((ClusterTask task) => task.state == ClusterTaskState.failed)
        .length;
    final int successfulCount = tasks
        .where((ClusterTask task) => task.state == ClusterTaskState.successful)
        .length;
    final Widget filter = PveSlidingSegmentedControl<_TaskFilter>(
      groupValue: _filter,
      children: const <_TaskFilter, Widget>{
        _TaskFilter.all: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('All'),
        ),
        _TaskFilter.running: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('Running'),
        ),
        _TaskFilter.failed: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('Failed'),
        ),
      },
      onValueChanged: (_TaskFilter? value) {
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
                label: 'Recent',
                value: '${tasks.length}',
                icon: CupertinoIcons.clock_fill,
              ),
              PveMetricStripItem(
                label: 'Running',
                value: '$runningCount',
                icon: CupertinoIcons.arrow_2_circlepath,
                color: PveAppleColors.warning(context),
              ),
              PveMetricStripItem(
                label: 'Successful',
                value: '$successfulCount',
                icon: CupertinoIcons.check_mark_circled_solid,
                color: PveAppleColors.success(context),
              ),
              PveMetricStripItem(
                label: 'Failed',
                value: '$failedCount',
                icon: CupertinoIcons.xmark_circle_fill,
                color: failedCount == 0
                    ? PveAppleColors.success(context)
                    : PveAppleColors.destructive(context),
              ),
            ],
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '${tasks.length} recent · $runningCount running · '
              '$failedCount failed',
              style: PveAppleText.caption(context),
            ),
          ),
        const SizedBox(height: 12),
        if (usesIpadPresentation)
          PveWideControlBar(
            primary: Text(
              'Recent activity',
              style: PveAppleText.title2(context),
            ),
            secondary: filter,
          )
        else
          filter,
        const SizedBox(height: 16),
        if (tasks.isEmpty)
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
                Text('No recent activity', style: PveAppleText.title3(context)),
              ],
            ),
          )
        else if (visibleTasks.isEmpty)
          PveInsetGroup(
            padding: const EdgeInsets.all(22),
            child: Text(
              'No tasks match this filter.',
              textAlign: TextAlign.center,
              style: PveAppleText.secondary(context),
            ),
          )
        else if (usesIpadPresentation)
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool twoColumns = constraints.maxWidth >= 700;
              final double cardWidth = twoColumns
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: visibleTasks
                    .map(
                      (ClusterTask task) => SizedBox(
                        width: cardWidth,
                        child: _TaskCard(task: task),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          )
        else
          CupertinoListSection.insetGrouped(
            margin: EdgeInsets.zero,
            children: visibleTasks
                .map((ClusterTask task) => _TaskRow(task: task))
                .toList(growable: false),
          ),
      ],
    );
  }

  bool _matchesFilter(ClusterTask task) => switch (_filter) {
    _TaskFilter.all => true,
    _TaskFilter.running => task.state == ClusterTaskState.running,
    _TaskFilter.failed => task.state == ClusterTaskState.failed,
  };
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task});

  final ClusterTask task;

  @override
  Widget build(BuildContext context) {
    final DatacenterDashboardTone tone = dashboardToneForTask(task);
    final Color accent = dashboardToneColor(context, tone);
    return PveInsetGroup(
      key: ValueKey<String>('ipad-task-card-${task.upid}'),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(10),
            ),
            child: SizedBox.square(
              dimension: 40,
              child: Icon(dashboardToneIcon(tone), size: 20, color: accent),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${task.type} on ${task.node}',
                  style: PveAppleText.title3(context),
                ),
                const SizedBox(height: 3),
                Text(task.user, style: PveAppleText.caption(context)),
                const SizedBox(height: 2),
                Text(
                  formatPveDateTime(task.startedAt),
                  style: PveAppleText.caption(context),
                ),
              ],
            ),
          ),
          Text(
            dashboardTaskStateLabel(task),
            style: PveAppleText.caption(
              context,
            ).copyWith(color: accent, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task});

  final ClusterTask task;

  @override
  Widget build(BuildContext context) {
    final DatacenterDashboardTone tone = dashboardToneForTask(task);
    final Color accent = dashboardToneColor(context, tone);
    return CupertinoListTile(
      leading: DecoratedBox(
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Icon(dashboardToneIcon(tone), size: 19, color: accent),
        ),
      ),
      title: Text('${task.type} on ${task.node}'),
      subtitle: Text('${task.user} · ${formatPveDateTime(task.startedAt)}'),
      additionalInfo: Text(
        dashboardTaskStateLabel(task),
        style: PveAppleText.caption(
          context,
        ).copyWith(color: accent, fontWeight: FontWeight.w600),
      ),
    );
  }
}

enum _TaskFilter { all, running, failed }
