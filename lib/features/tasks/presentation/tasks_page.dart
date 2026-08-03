import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import '../../../core/api/proxmox_session.dart';
import '../../../core/presentation/pve_apple_ui.dart';
import '../../../core/presentation/pve_modal_sheet.dart';
import '../../../core/presentation/pve_value_format.dart';
import '../../cluster_overview/application/cluster_overview_controller.dart';
import '../../cluster_overview/domain/cluster_overview_snapshot.dart';
import '../../cluster_overview/presentation/cluster_load_state_view.dart';
import '../../cluster_overview/presentation/datacenter_dashboard_visuals.dart';
import '../../guests/domain/pve_guest.dart';
import 'task_activity_insights.dart';
import 'task_inspector.dart';
import 'task_query.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({
    super.key,
    required this.controller,
    required this.onRefresh,
    this.session,
    this.showsSliverNavigationBar = true,
    this.navigationLeading,
    this.navigationTrailing,
  });

  final ClusterOverviewController controller;
  final Future<void> Function() onRefresh;
  final ProxmoxSession? session;
  final bool showsSliverNavigationBar;
  final Widget? navigationLeading;
  final Widget? navigationTrailing;

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  TaskQuery _taskQuery = TaskQuery.all;
  final TextEditingController _searchController = TextEditingController();
  String? _selectedTaskUpid;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool usesExpandedPresentation =
        PveAppleLayout.usesExpandedPresentation(context);
    final bool usesDesktopTaskTable =
        usesExpandedPresentation &&
        defaultTargetPlatform == TargetPlatform.macOS;
    final bool usesDesktopInspector =
        usesDesktopTaskTable && PveAppleLayout.usesWidePresentation(context);
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
            maxWidth: usesDesktopInspector ? 1100 : 980,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: _buildContent(
              context,
              snapshot,
              usesExpandedPresentation: usesExpandedPresentation,
              usesDesktopTaskTable: usesDesktopTaskTable,
              usesDesktopInspector: usesDesktopInspector,
            ),
          ),
      ],
    );
  }

  Widget _buildContent(
    BuildContext context,
    ClusterOverviewSnapshot snapshot, {
    required bool usesExpandedPresentation,
    required bool usesDesktopTaskTable,
    required bool usesDesktopInspector,
  }) {
    final List<ClusterTask> tasks = snapshot.tasks;
    final DateTime filterNow = DateTime.now();
    final List<ClusterTask> orderedTasks = TaskQuery(
      sort: _taskQuery.sort,
    ).apply(tasks, now: filterNow);
    final List<ClusterTask> visibleTasks = _taskQuery.apply(
      tasks,
      now: filterNow,
    );
    final List<ClusterTask> visibleSessions = visibleTasks
        .where(
          (ClusterTask task) =>
              task.state == ClusterTaskState.running &&
              task.isInteractiveSession,
        )
        .toList(growable: false);
    final List<ClusterTask> visibleOperations = visibleTasks
        .where(
          (ClusterTask task) =>
              task.state != ClusterTaskState.running ||
              !task.isInteractiveSession,
        )
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
    final Widget filter = PveSlidingSegmentedControl<TaskStateFilter>(
      key: const ValueKey<String>('task-state-filter'),
      groupValue: _taskQuery.state,
      children: const <TaskStateFilter, Widget>{
        TaskStateFilter.all: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('All'),
        ),
        TaskStateFilter.running: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('Running'),
        ),
        TaskStateFilter.failed: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('Failed'),
        ),
        TaskStateFilter.unknown: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('Unknown'),
        ),
      },
      onValueChanged: (TaskStateFilter? value) {
        if (value != null) {
          setState(() => _taskQuery = _taskQuery.copyWith(state: value));
        }
      },
    );
    void inspectTask(ClusterTask task) {
      if (usesDesktopInspector) {
        setState(() => _selectedTaskUpid = task.upid);
        return;
      }
      _showTaskInspector(task);
    }

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
              label: 'Recent operations',
              value: '${tasks.length}',
              icon: CupertinoIcons.clock_fill,
              scope: 'Latest server response',
            ),
            PveMetricStripItem(
              label: 'Active work',
              value: '$runningCount',
              icon: CupertinoIcons.arrow_2_circlepath,
              scope: 'Reported running operations',
            ),
            if (interactiveSessionCount > 0)
              PveMetricStripItem(
                label: 'Sessions',
                value: '$interactiveSessionCount',
                icon: CupertinoIcons.desktopcomputer,
                scope: 'Reported interactive sessions',
              ),
            PveMetricStripItem(
              label: 'Successful',
              value: '$successfulCount',
              icon: CupertinoIcons.check_mark_circled_solid,
              color: PveAppleColors.success(context),
              scope: 'Recent reported operations',
            ),
            PveMetricStripItem(
              label: 'Failed',
              value: '$failedCount',
              icon: CupertinoIcons.xmark_circle_fill,
              color: failedCount == 0
                  ? PveAppleColors.secondaryLabel(context)
                  : PveAppleColors.destructive(context),
              scope: 'Recent reported operations',
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
          controller: _searchController,
          placeholder: 'Search operation, node, or operator',
          onChanged: (String value) =>
              setState(() => _taskQuery = _taskQuery.copyWith(query: value)),
        ),
        const SizedBox(height: 10),
        _TaskFilterControls(
          dateFilter: _taskQuery.period,
          node: _taskQuery.node,
          operatorName: _taskQuery.operatorName,
          guestVmid: _taskQuery.guestVmid,
          nodes: tasks.map((ClusterTask task) => task.node).toSet(),
          operators: tasks.map((ClusterTask task) => task.user).toSet(),
          guests: _knownTaskGuests(snapshot),
          onDateFilterChanged: (TaskPeriodFilter value) =>
              setState(() => _taskQuery = _taskQuery.copyWith(period: value)),
          onNodeChanged: (String? value) =>
              setState(() => _taskQuery = _taskQuery.withNode(value)),
          onOperatorChanged: (String? value) =>
              setState(() => _taskQuery = _taskQuery.withOperatorName(value)),
          onGuestChanged: (int? value) =>
              setState(() => _taskQuery = _taskQuery.withGuestVmid(value)),
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
                  onPressed: _clearFilters,
                  child: const Text('Clear filters'),
                ),
              ],
            ),
          )
        else
          _buildTaskResults(
            context,
            visibleTasks: visibleTasks,
            visibleSessions: visibleSessions,
            visibleOperations: visibleOperations,
            usesExpandedPresentation: usesExpandedPresentation,
            usesDesktopTaskTable: usesDesktopTaskTable,
            usesDesktopInspector: usesDesktopInspector,
            onInspect: inspectTask,
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

  Widget _buildTaskResults(
    BuildContext context, {
    required List<ClusterTask> visibleTasks,
    required List<ClusterTask> visibleSessions,
    required List<ClusterTask> visibleOperations,
    required bool usesExpandedPresentation,
    required bool usesDesktopTaskTable,
    required bool usesDesktopInspector,
    required ValueChanged<ClusterTask> onInspect,
  }) {
    final ClusterTask? selectedTask = _selectedVisibleTask(visibleTasks);
    final Widget activity = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (visibleSessions.isNotEmpty) ...<Widget>[
          _InteractiveSessionsGroup(
            sessions: visibleSessions,
            selectedUpid: selectedTask?.upid,
            onInspect: onInspect,
          ),
          const SizedBox(height: 16),
        ],
        if (visibleOperations.isEmpty)
          PveInsetGroup(
            padding: const EdgeInsets.all(22),
            child: Text(
              'No non-session operations match these controls.',
              textAlign: TextAlign.center,
              style: PveAppleText.secondary(context),
            ),
          )
        else if (usesDesktopTaskTable)
          _DesktopTaskTable(
            tasks: visibleOperations,
            selectedUpid: selectedTask?.upid,
            sort: _taskQuery.sort,
            onSortChanged: (TaskSort value) =>
                setState(() => _taskQuery = _taskQuery.copyWith(sort: value)),
            onInspect: onInspect,
          )
        else if (usesExpandedPresentation)
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool twoColumns =
                  constraints.maxWidth >=
                  PveAppleLayout.controlBarStackBreakpoint;
              final double cardWidth = twoColumns
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: visibleOperations
                    .map(
                      (ClusterTask task) => SizedBox(
                        width: cardWidth,
                        child: _TaskCard(
                          task: task,
                          selected: selectedTask?.upid == task.upid,
                          onTap: () => onInspect(task),
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
            children: visibleOperations
                .map(
                  (ClusterTask task) =>
                      _TaskRow(task: task, onTap: () => onInspect(task)),
                )
                .toList(growable: false),
          ),
      ],
    );
    if (!usesDesktopInspector) return activity;
    return PveInspectorLayout(
      primary: activity,
      inspector: selectedTask == null
          ? const TaskInspectorPlaceholder()
          : TaskInspector(
              key: ValueKey<String>(
                'desktop-task-inspector-${selectedTask.upid}',
              ),
              task: selectedTask,
              session: widget.session,
              inline: true,
            ),
    );
  }

  ClusterTask? _selectedVisibleTask(List<ClusterTask> visibleTasks) {
    final String? selectedUpid = _selectedTaskUpid;
    if (selectedUpid == null) return null;
    for (final ClusterTask task in visibleTasks) {
      if (task.upid == selectedUpid) return task;
    }
    return null;
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() => _taskQuery = _taskQuery.clearFilters());
  }

  List<PveGuest> _knownTaskGuests(ClusterOverviewSnapshot snapshot) {
    final Set<int> taskGuestIds = snapshot.tasks
        .map((ClusterTask task) => task.guestVmid)
        .whereType<int>()
        .toSet();
    return snapshot.guests
        .where((PveGuest guest) => taskGuestIds.contains(guest.vmid))
        .toList(growable: false)
      ..sort(
        (PveGuest left, PveGuest right) => left.title.compareTo(right.title),
      );
  }

  Future<void> _showTaskInspector(ClusterTask task) => showPveModalSheet<void>(
    context: context,
    scrollableBuilder: (BuildContext context, ScrollController controller) =>
        TaskInspector(
          task: task,
          session: widget.session,
          scrollController: controller,
        ),
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
        '${taskDurationLabel(task)}',
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

class _InteractiveSessionsGroup extends StatelessWidget {
  const _InteractiveSessionsGroup({
    required this.sessions,
    required this.selectedUpid,
    required this.onInspect,
  });

  final List<ClusterTask> sessions;
  final String? selectedUpid;
  final ValueChanged<ClusterTask> onInspect;

  @override
  Widget build(BuildContext context) => PveInsetGroup(
    key: const ValueKey<String>('interactive-sessions-group'),
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
          child: Text(
            'Interactive sessions',
            style: PveAppleText.title3(context),
          ),
        ),
        for (final ClusterTask session in sessions)
          Semantics(
            selected: session.upid == selectedUpid,
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              alignment: Alignment.centerLeft,
              color: session.upid == selectedUpid
                  ? PveAppleColors.primary(context).withValues(alpha: 0.09)
                  : null,
              onPressed: () => onInspect(session),
              child: Row(
                children: <Widget>[
                  Icon(
                    CupertinoIcons.desktopcomputer,
                    color: PveAppleColors.primary(context),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '${session.type} on ${session.node}',
                          style: PveAppleText.body(context),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${session.user} · ${_taskAgeLabel(session)}',
                          style: PveAppleText.caption(context),
                        ),
                      ],
                    ),
                  ),
                  const Icon(CupertinoIcons.chevron_right, size: 16),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.selected,
    required this.onTap,
  });

  final ClusterTask task;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DatacenterDashboardTone tone = dashboardToneForTask(task);
    final Color accent = dashboardToneColor(context, tone);
    return Semantics(
      button: true,
      selected: selected,
      label: 'Inspect ${task.type} on ${task.node}',
      child: PveInsetGroup(
        key: ValueKey<String>('ipad-task-card-${task.upid}'),
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        color: selected
            ? PveAppleColors.primary(context).withValues(alpha: 0.09)
            : null,
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
                    '${formatPveDateTime(task.startedAt)} · ${taskDurationLabel(task)}',
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
    required this.guestVmid,
    required this.nodes,
    required this.operators,
    required this.guests,
    required this.onDateFilterChanged,
    required this.onNodeChanged,
    required this.onOperatorChanged,
    required this.onGuestChanged,
  });

  final TaskPeriodFilter dateFilter;
  final String? node;
  final String? operatorName;
  final int? guestVmid;
  final Set<String> nodes;
  final Set<String> operators;
  final List<PveGuest> guests;
  final ValueChanged<TaskPeriodFilter> onDateFilterChanged;
  final ValueChanged<String?> onNodeChanged;
  final ValueChanged<String?> onOperatorChanged;
  final ValueChanged<int?> onGuestChanged;

  @override
  Widget build(BuildContext context) {
    final List<String> orderedNodes = nodes.toList()..sort();
    final List<String> orderedOperators = operators.toList()..sort();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        PveSlidingSegmentedControl<TaskPeriodFilter>(
          groupValue: dateFilter,
          children: const <TaskPeriodFilter, Widget>{
            TaskPeriodFilter.all: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('Any time'),
            ),
            TaskPeriodFilter.day: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('24h'),
            ),
            TaskPeriodFilter.week: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('7d'),
            ),
          },
          onValueChanged: (TaskPeriodFilter? value) {
            if (value != null) onDateFilterChanged(value);
          },
          semanticLabels: const <TaskPeriodFilter, String>{
            TaskPeriodFilter.all: 'Tasks from any time',
            TaskPeriodFilter.day: 'Tasks from the last 24 hours',
            TaskPeriodFilter.week: 'Tasks from the last 7 days',
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
        if (guests.isNotEmpty)
          _TaskGuestChoiceMenu(
            selectedVmid: guestVmid,
            guests: guests,
            onSelected: onGuestChanged,
          )
        else
          const Text('Guest filtering is unavailable for these task records.'),
      ],
    );
  }
}

class _TaskGuestChoiceMenu extends StatelessWidget {
  const _TaskGuestChoiceMenu({
    required this.selectedVmid,
    required this.guests,
    required this.onSelected,
  });

  final int? selectedVmid;
  final List<PveGuest> guests;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    final PveGuest? selected = guests.cast<PveGuest?>().firstWhere(
      (PveGuest? guest) => guest?.vmid == selectedVmid,
      orElse: () => null,
    );
    return CupertinoButton(
      key: const ValueKey<String>('task-guest-filter'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
      onPressed: () => showCupertinoModalPopup<void>(
        context: context,
        builder: (BuildContext popupContext) => CupertinoActionSheet(
          title: const Text('Guest'),
          actions: <Widget>[
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(popupContext).pop();
                onSelected(null);
              },
              child: const Text('All guests'),
            ),
            ...guests.map(
              (PveGuest guest) => CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.of(popupContext).pop();
                  onSelected(guest.vmid);
                },
                child: Text('${guest.title} (${guest.vmid})'),
              ),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(popupContext).pop(),
            child: const Text('Cancel'),
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(selected == null ? 'All guests' : selected.title),
          const SizedBox(width: 4),
          const Icon(CupertinoIcons.chevron_down, size: 13),
        ],
      ),
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
    required this.selectedUpid,
    required this.sort,
    required this.onSortChanged,
    required this.onInspect,
  });

  final List<ClusterTask> tasks;
  final String? selectedUpid;
  final TaskSort sort;
  final ValueChanged<TaskSort> onSortChanged;
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
              selected: tasks[index].upid == selectedUpid,
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

  final TaskSort sort;
  final ValueChanged<TaskSort> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: <Widget>[
          _TaskHeaderButton(
            label: 'Status',
            value: TaskSort.attention,
            sort: sort,
            onChanged: onSortChanged,
            width: 102,
          ),
          _TaskHeaderButton(
            label: 'Operation',
            value: TaskSort.operation,
            sort: sort,
            onChanged: onSortChanged,
            flex: 3,
          ),
          _TaskHeaderButton(
            label: 'Node',
            value: TaskSort.node,
            sort: sort,
            onChanged: onSortChanged,
            flex: 2,
          ),
          _TaskHeaderButton(
            label: 'Operator',
            value: TaskSort.operatorName,
            sort: sort,
            onChanged: onSortChanged,
            flex: 2,
          ),
          _TaskHeaderButton(
            label: 'Started',
            value: TaskSort.started,
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
  final TaskSort value;
  final TaskSort sort;
  final ValueChanged<TaskSort> onChanged;
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
  const _DesktopTaskRow({
    required this.task,
    required this.selected,
    required this.onTap,
  });
  final ClusterTask task;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final DatacenterDashboardTone tone = dashboardToneForTask(task);
    final Color accent = dashboardToneColor(context, tone);
    return Semantics(
      button: true,
      selected: selected,
      label: 'Inspect ${task.type} on ${task.node}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected
              ? PveAppleColors.primary(context).withValues(alpha: 0.09)
              : null,
        ),
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
      ),
    );
  }
}

String _taskAgeLabel(ClusterTask task) {
  final DateTime? startedAt = task.startedAt;
  if (startedAt == null) return 'Start time unavailable';
  final Duration age = DateTime.now().difference(startedAt);
  if (age.isNegative) return 'Start time unavailable';
  if (age.inHours > 0)
    return 'Active ${age.inHours}h ${age.inMinutes.remainder(60)}m';
  if (age.inMinutes > 0) return 'Active ${age.inMinutes}m';
  return 'Active just now';
}
