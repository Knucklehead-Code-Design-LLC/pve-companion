import 'package:flutter/cupertino.dart';

import '../../../core/presentation/pve_apple_ui.dart';
import '../../cluster_overview/application/cluster_overview_controller.dart';
import '../../cluster_overview/domain/cluster_overview_snapshot.dart';
import '../../cluster_overview/presentation/cluster_overview_format.dart';
import '../../cluster_overview/presentation/datacenter_dashboard_visuals.dart';
import 'task_activity_insights.dart';

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
    final bool usesExpandedPresentation =
        PveAppleLayout.usesExpandedPresentation(context);
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
              usesExpandedPresentation: usesExpandedPresentation,
            ),
          ),
      ],
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<ClusterTask> tasks, {
    required bool usesExpandedPresentation,
  }) {
    final List<ClusterTask> orderedTasks = List<ClusterTask>.of(tasks)
      ..sort(_compareTaskRecency);
    final List<ClusterTask> visibleTasks = orderedTasks
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
      key: const ValueKey<String>('task-state-filter'),
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
        ),
        if (usesExpandedPresentation) ...<Widget>[
          const SizedBox(height: 16),
          TaskActivityInsights(tasks: orderedTasks),
          const SizedBox(height: 24),
        ] else
          const SizedBox(height: 20),
        PveWideControlBar(
          primary: Text('Recent activity', style: PveAppleText.title2(context)),
          secondary: filter,
        ),
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
        else if (usesExpandedPresentation)
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
        if (!usesExpandedPresentation) ...<Widget>[
          const SizedBox(height: 24),
          Text('Activity analysis', style: PveAppleText.title2(context)),
          const SizedBox(height: 12),
          TaskActivityInsights(tasks: orderedTasks),
        ],
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
                  '${formatPveDateTime(task.startedAt)} · '
                  '${_taskDurationLabel(task)}',
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
      subtitle: Text(
        '${task.user} · ${formatPveDateTime(task.startedAt)} · '
        '${_taskDurationLabel(task)}',
      ),
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

int _compareTaskRecency(ClusterTask left, ClusterTask right) {
  final DateTime? leftTime = left.startedAt;
  final DateTime? rightTime = right.startedAt;
  if (leftTime == null && rightTime == null) {
    return 0;
  }
  if (leftTime == null) {
    return 1;
  }
  if (rightTime == null) {
    return -1;
  }
  return rightTime.compareTo(leftTime);
}

String _taskDurationLabel(ClusterTask task) {
  final DateTime? startedAt = task.startedAt;
  final DateTime? endedAt = task.endedAt;
  if (endedAt == null) {
    return task.isRunning ? 'In progress' : 'Duration unavailable';
  }
  if (startedAt == null || endedAt.isBefore(startedAt)) {
    return 'Duration unavailable';
  }
  final Duration duration = endedAt.difference(startedAt);
  if (duration.inHours > 0) {
    return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
  }
  if (duration.inMinutes > 0) {
    return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
  }
  return '${duration.inSeconds}s';
}
