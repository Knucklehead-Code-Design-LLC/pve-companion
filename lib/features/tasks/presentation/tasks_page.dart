import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import '../../../core/presentation/pve_apple_ui.dart';
import '../../../core/presentation/pve_modal_sheet.dart';
import '../../../core/presentation/pve_value_format.dart';
import '../../cluster_overview/application/cluster_overview_controller.dart';
import '../../cluster_overview/domain/cluster_overview_snapshot.dart';
import '../../cluster_overview/presentation/cluster_load_state_view.dart';
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
  _TaskDateFilter _dateFilter = _TaskDateFilter.all;
  _TaskSort _sort = _TaskSort.attention;
  String _query = '';
  String? _node;
  String? _operator;

  @override
  Widget build(BuildContext context) {
    final bool usesExpandedPresentation =
        PveAppleLayout.usesExpandedPresentation(context);
    final bool usesDesktopTaskTable =
        usesExpandedPresentation &&
        defaultTargetPlatform == TargetPlatform.macOS;
    final ClusterOverviewSnapshot? snapshot = widget.controller.snapshot;
    return PvePrimaryScrollView(
      title: 'Tasks',
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
              loadingLabel: 'Loading recent activity',
              onRetry: widget.onRefresh,
            ),
          )
        else
          PveCenteredSliver(
            maxWidth: 980,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: _buildContent(
              context,
              snapshot.tasks,
              usesExpandedPresentation: usesExpandedPresentation,
              usesDesktopTaskTable: usesDesktopTaskTable,
            ),
          ),
      ],
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<ClusterTask> tasks, {
    required bool usesExpandedPresentation,
    required bool usesDesktopTaskTable,
  }) {
    final List<ClusterTask> orderedTasks = List<ClusterTask>.of(tasks)
      ..sort(_compareTasks);
    final List<ClusterTask> visibleTasks = orderedTasks
        .where(_matchesFilter)
        .where(_matchesDate)
        .where(_matchesQuery)
        .toList(growable: false);
    final int runningCount = tasks
        .where(
          (ClusterTask task) =>
              task.state == ClusterTaskState.running &&
              !task.isInteractiveSession,
        )
        .length;
    final int interactiveSessionCount = tasks
        .where(
          (ClusterTask task) =>
              task.state == ClusterTaskState.running &&
              task.isInteractiveSession,
        )
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
        _TaskFilter.unknown: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('Unknown'),
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
              label: 'Recent',
              value: '${tasks.length}',
              icon: CupertinoIcons.clock_fill,
            ),
            PveMetricStripItem(
              label: 'Active work',
              value: '$runningCount',
              icon: CupertinoIcons.arrow_2_circlepath,
            ),
            if (interactiveSessionCount > 0)
              PveMetricStripItem(
                label: 'Sessions',
                value: '$interactiveSessionCount',
                icon: CupertinoIcons.desktopcomputer,
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
                  ? PveAppleColors.secondaryLabel(context)
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
          primary: const PveSectionTitle(title: 'Recent activity'),
          secondary: filter,
        ),
        const SizedBox(height: 12),
        CupertinoSearchTextField(
          key: const ValueKey<String>('task-search'),
          placeholder: 'Search operation, node, or operator',
          onChanged: (String value) => setState(() => _query = value),
        ),
        const SizedBox(height: 10),
        _TaskFilterControls(
          dateFilter: _dateFilter,
          node: _node,
          operatorName: _operator,
          nodes: tasks.map((ClusterTask task) => task.node).toSet(),
          operators: tasks.map((ClusterTask task) => task.user).toSet(),
          onDateFilterChanged: (_TaskDateFilter value) =>
              setState(() => _dateFilter = value),
          onNodeChanged: (String? value) => setState(() => _node = value),
          onOperatorChanged: (String? value) =>
              setState(() => _operator = value),
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
            child: Column(
              children: <Widget>[
                Text(
                  'No tasks match these controls.',
                  textAlign: TextAlign.center,
                  style: PveAppleText.secondary(context),
                ),
                const SizedBox(height: 8),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => setState(() {
                    _filter = _TaskFilter.all;
                    _query = '';
                  }),
                  child: const Text('Clear filters'),
                ),
              ],
            ),
          )
        else if (usesDesktopTaskTable)
          _DesktopTaskTable(
            tasks: visibleTasks,
            sort: _sort,
            onSortChanged: (_TaskSort value) => setState(() => _sort = value),
            onInspect: _showTaskInspector,
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
                        child: _TaskCard(
                          task: task,
                          onTap: () => _showTaskInspector(task),
                        ),
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
                .map(
                  (ClusterTask task) => _TaskRow(
                    task: task,
                    onTap: () => _showTaskInspector(task),
                  ),
                )
                .toList(growable: false),
          ),
        if (!usesExpandedPresentation) ...<Widget>[
          const SizedBox(height: 24),
          const PveSectionTitle(title: 'Activity analysis'),
          const SizedBox(height: 12),
          TaskActivityInsights(tasks: orderedTasks),
        ],
        if (tasks.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            'Showing ${visibleTasks.length} of ${tasks.length} recent ${tasks.length == 1 ? 'task' : 'tasks'}',
            textAlign: TextAlign.center,
            style: PveAppleText.caption(context),
          ),
        ],
      ],
    );
  }

  bool _matchesFilter(ClusterTask task) => switch (_filter) {
    _TaskFilter.all => true,
    _TaskFilter.running => task.state == ClusterTaskState.running,
    _TaskFilter.failed => task.state == ClusterTaskState.failed,
    _TaskFilter.unknown => task.state == ClusterTaskState.unknown,
  };

  bool _matchesDate(ClusterTask task) {
    final DateTime? startedAt = task.startedAt;
    final Duration? maximumAge = switch (_dateFilter) {
      _TaskDateFilter.all => null,
      _TaskDateFilter.day => const Duration(days: 1),
      _TaskDateFilter.week => const Duration(days: 7),
    };
    if (maximumAge == null || startedAt == null) return true;
    return !DateTime.now().difference(startedAt).isNegative &&
        DateTime.now().difference(startedAt) <= maximumAge;
  }

  bool _matchesQuery(ClusterTask task) {
    final String query = _query.trim().toLowerCase();
    final bool matchesText =
        query.isEmpty ||
        task.type.toLowerCase().contains(query) ||
        task.node.toLowerCase().contains(query) ||
        task.user.toLowerCase().contains(query);
    return matchesText &&
        (_node == null || task.node == _node) &&
        (_operator == null || task.user == _operator);
  }

  int _compareTasks(ClusterTask left, ClusterTask right) => switch (_sort) {
    _TaskSort.attention => _compareTasksForAttention(left, right),
    _TaskSort.started => compareClusterTasksByRecency(left, right),
    _TaskSort.node => left.node.compareTo(right.node),
    _TaskSort.operation => left.type.compareTo(right.type),
    _TaskSort.operatorName => left.user.compareTo(right.user),
  };

  Future<void> _showTaskInspector(ClusterTask task) => showPveModalSheet<void>(
    context: context,
    scrollableBuilder: (BuildContext context, ScrollController controller) =>
        _TaskInspector(task: task, scrollController: controller),
  );
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task, required this.onTap});

  final ClusterTask task;
  final VoidCallback onTap;

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
      onTap: onTap,
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, required this.onTap});

  final ClusterTask task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DatacenterDashboardTone tone = dashboardToneForTask(task);
    final Color accent = dashboardToneColor(context, tone);
    return Semantics(
      button: true,
      label: 'Inspect ${task.type} on ${task.node}',
      child: PveInsetGroup(
        key: ValueKey<String>('ipad-task-card-${task.upid}'),
        onTap: onTap,
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
                    '${formatPveDateTime(task.startedAt)} · ${_taskDurationLabel(task)}',
                    style: PveAppleText.caption(context),
                  ),
                ],
              ),
            ),
            Text(
              task.isLongRunning
                  ? 'Long-running'
                  : dashboardTaskStateLabel(task),
              style: PveAppleText.caption(
                context,
              ).copyWith(color: accent, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskFilterControls extends StatelessWidget {
  const _TaskFilterControls({
    required this.dateFilter,
    required this.node,
    required this.operatorName,
    required this.nodes,
    required this.operators,
    required this.onDateFilterChanged,
    required this.onNodeChanged,
    required this.onOperatorChanged,
  });

  final _TaskDateFilter dateFilter;
  final String? node;
  final String? operatorName;
  final Set<String> nodes;
  final Set<String> operators;
  final ValueChanged<_TaskDateFilter> onDateFilterChanged;
  final ValueChanged<String?> onNodeChanged;
  final ValueChanged<String?> onOperatorChanged;

  @override
  Widget build(BuildContext context) {
    final List<String> orderedNodes = nodes.toList()..sort();
    final List<String> orderedOperators = operators.toList()..sort();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        CupertinoSlidingSegmentedControl<_TaskDateFilter>(
          groupValue: dateFilter,
          children: const <_TaskDateFilter, Widget>{
            _TaskDateFilter.all: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('Any time'),
            ),
            _TaskDateFilter.day: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('24h'),
            ),
            _TaskDateFilter.week: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('7d'),
            ),
          },
          onValueChanged: (_TaskDateFilter? value) {
            if (value != null) onDateFilterChanged(value);
          },
        ),
        _TaskChoiceMenu(
          label: node == null ? 'All nodes' : node!,
          choices: orderedNodes,
          onSelected: onNodeChanged,
        ),
        _TaskChoiceMenu(
          label: operatorName == null ? 'All operators' : operatorName!,
          choices: orderedOperators,
          onSelected: onOperatorChanged,
        ),
      ],
    );
  }
}

class _TaskChoiceMenu extends StatelessWidget {
  const _TaskChoiceMenu({
    required this.label,
    required this.choices,
    required this.onSelected,
  });

  final String label;
  final List<String> choices;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
      onPressed: () => showCupertinoModalPopup<void>(
        context: context,
        builder: (BuildContext popupContext) => CupertinoActionSheet(
          title: Text(label.startsWith('All ') ? label.substring(4) : label),
          actions: <Widget>[
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(popupContext).pop();
                onSelected(null);
              },
              child: const Text('All'),
            ),
            ...choices.map(
              (String choice) => CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.of(popupContext).pop();
                  onSelected(choice);
                },
                child: Text(choice),
              ),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(popupContext).pop(),
            child: const Text('Cancel'),
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(label),
          const SizedBox(width: 4),
          const Icon(CupertinoIcons.chevron_down, size: 13),
        ],
      ),
    );
  }
}

class _DesktopTaskTable extends StatelessWidget {
  const _DesktopTaskTable({
    required this.tasks,
    required this.sort,
    required this.onSortChanged,
    required this.onInspect,
  });

  final List<ClusterTask> tasks;
  final _TaskSort sort;
  final ValueChanged<_TaskSort> onSortChanged;
  final ValueChanged<ClusterTask> onInspect;

  @override
  Widget build(BuildContext context) {
    return PveInsetGroup(
      key: const ValueKey<String>('desktop-task-table'),
      child: Column(
        children: <Widget>[
          _TaskTableHeader(sort: sort, onSortChanged: onSortChanged),
          const PveRowSeparator(),
          for (int index = 0; index < tasks.length; index += 1) ...<Widget>[
            _DesktopTaskRow(
              task: tasks[index],
              onTap: () => onInspect(tasks[index]),
            ),
            if (index < tasks.length - 1) const PveRowSeparator(),
          ],
        ],
      ),
    );
  }
}

class _TaskTableHeader extends StatelessWidget {
  const _TaskTableHeader({required this.sort, required this.onSortChanged});

  final _TaskSort sort;
  final ValueChanged<_TaskSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: <Widget>[
          _TaskHeaderButton(
            label: 'Status',
            value: _TaskSort.attention,
            sort: sort,
            onChanged: onSortChanged,
            width: 102,
          ),
          _TaskHeaderButton(
            label: 'Operation',
            value: _TaskSort.operation,
            sort: sort,
            onChanged: onSortChanged,
            flex: 3,
          ),
          _TaskHeaderButton(
            label: 'Node',
            value: _TaskSort.node,
            sort: sort,
            onChanged: onSortChanged,
            flex: 2,
          ),
          _TaskHeaderButton(
            label: 'Operator',
            value: _TaskSort.operatorName,
            sort: sort,
            onChanged: onSortChanged,
            flex: 2,
          ),
          _TaskHeaderButton(
            label: 'Started',
            value: _TaskSort.started,
            sort: sort,
            onChanged: onSortChanged,
            width: 154,
          ),
        ],
      ),
    );
  }
}

class _TaskHeaderButton extends StatelessWidget {
  const _TaskHeaderButton({
    required this.label,
    required this.value,
    required this.sort,
    required this.onChanged,
    this.flex,
    this.width,
  });
  final String label;
  final _TaskSort value;
  final _TaskSort sort;
  final ValueChanged<_TaskSort> onChanged;
  final int? flex;
  final double? width;
  @override
  Widget build(BuildContext context) {
    final Widget button = CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(24, 24),
      onPressed: () => onChanged(value),
      child: Text(
        '$label${sort == value ? ' ↓' : ''}',
        overflow: TextOverflow.ellipsis,
        style: PveAppleText.caption(context),
      ),
    );
    if (width != null) return SizedBox(width: width, child: button);
    return Expanded(flex: flex!, child: button);
  }
}

class _DesktopTaskRow extends StatelessWidget {
  const _DesktopTaskRow({required this.task, required this.onTap});
  final ClusterTask task;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final DatacenterDashboardTone tone = dashboardToneForTask(task);
    final Color accent = dashboardToneColor(context, tone);
    return Semantics(
      button: true,
      label: 'Inspect ${task.type} on ${task.node}',
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        alignment: Alignment.centerLeft,
        onPressed: onTap,
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 102,
              child: Text(
                task.isLongRunning
                    ? 'Long-running'
                    : dashboardTaskStateLabel(task),
                style: PveAppleText.caption(
                  context,
                ).copyWith(color: accent, fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                '${task.type} on ${task.node}',
                overflow: TextOverflow.ellipsis,
                style: PveAppleText.body(context),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                task.node,
                overflow: TextOverflow.ellipsis,
                style: PveAppleText.body(context),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                task.user,
                overflow: TextOverflow.ellipsis,
                style: PveAppleText.body(context),
              ),
            ),
            SizedBox(
              width: 154,
              child: Text(
                formatPveDateTime(task.startedAt),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: PveAppleText.caption(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskInspector extends StatelessWidget {
  const _TaskInspector({required this.task, required this.scrollController});
  final ClusterTask task;
  final ScrollController scrollController;
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Task details'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ),
      child: SafeArea(
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Text(task.type, style: PveAppleText.largeTitle(context)),
            const SizedBox(height: 6),
            Text(
              'Read-only details from the latest task list refresh. This app has not loaded a server task log.',
              style: PveAppleText.secondary(context),
            ),
            const SizedBox(height: 18),
            CupertinoListSection.insetGrouped(
              margin: EdgeInsets.zero,
              children: <Widget>[
                _InspectorRow(
                  label: 'Status',
                  value: dashboardTaskStateLabel(task),
                ),
                _InspectorRow(label: 'Node', value: task.node),
                _InspectorRow(label: 'Operator', value: task.user),
                _InspectorRow(
                  label: 'Started',
                  value: formatPveDateTime(task.startedAt),
                ),
                _InspectorRow(
                  label: 'Finished',
                  value: formatPveDateTime(task.endedAt),
                ),
                _InspectorRow(
                  label: 'Duration',
                  value: _taskDurationLabel(task),
                ),
                _InspectorRow(label: 'Task ID', value: task.upid),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InspectorRow extends StatelessWidget {
  const _InspectorRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => CupertinoListTile(
    title: Text(label),
    additionalInfo: SizedBox(
      width: 200,
      child: Text(
        value,
        textAlign: TextAlign.end,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}

enum _TaskFilter { all, running, failed, unknown }

enum _TaskDateFilter { all, day, week }

enum _TaskSort { attention, started, node, operation, operatorName }

int _compareTasksForAttention(ClusterTask left, ClusterTask right) {
  final int priorityComparison = _taskAttentionPriority(
    left,
  ).compareTo(_taskAttentionPriority(right));
  if (priorityComparison != 0) return priorityComparison;
  return compareClusterTasksByRecency(left, right);
}

int _taskAttentionPriority(ClusterTask task) {
  if (task.state == ClusterTaskState.failed) return 0;
  if (task.isLongRunning) return 1;
  if (task.state == ClusterTaskState.running && !task.isInteractiveSession) {
    return 2;
  }
  if (task.state == ClusterTaskState.unknown) return 3;
  if (task.isInteractiveSession) return 4;
  return 5;
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
