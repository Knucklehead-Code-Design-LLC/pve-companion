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
    final usesExpandedPresentation = PveAppleLayout.usesExpandedPresentation(
      context,
    );
    final usesDesktopTaskTable =
        usesExpandedPresentation &&
        defaultTargetPlatform == TargetPlatform.macOS;
    final usesDesktopInspector =
        usesDesktopTaskTable && PveAppleLayout.usesWidePresentation(context);
    final snapshot = widget.controller.snapshot;
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
    final tasks = snapshot.tasks;
    final filterNow = DateTime.now();
    final orderedTasks = TaskQuery(
      sort: _taskQuery.sort,
    ).apply(tasks, now: filterNow);
    final visibleTasks = _taskQuery.apply(tasks, now: filterNow);
    final visibleSessions = visibleTasks
        .where(
          (ClusterTask task) =>
              task.state == ClusterTaskState.running &&
              task.isInteractiveSession,
        )
        .toList(growable: false);
    final visibleOperations = visibleTasks
        .where(
          (ClusterTask task) =>
              task.state != ClusterTaskState.running ||
              !task.isInteractiveSession,
        )
        .toList(growable: false);
    final runningCount = tasks
        .where(
          (ClusterTask task) =>
              task.state == ClusterTaskState.running &&
              !task.isInteractiveSession,
        )
        .length;
    final interactiveSessionCount = tasks
        .where(
          (ClusterTask task) =>
              task.state == ClusterTaskState.running &&
              task.isInteractiveSession,
        )
        .length;
    final failedCount = tasks
        .where((ClusterTask task) => task.state == ClusterTaskState.failed)
        .length;
    final successfulCount = tasks
        .where((ClusterTask task) => task.state == ClusterTaskState.successful)
        .length;
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
          showsItemScopes: false,
          footer: 'Latest server-reported activity.',
          items: <PveMetricStripItem>[
            PveMetricStripItem(
              label: 'Recent',
              value: '${tasks.length}',
              icon: CupertinoIcons.clock_fill,
              scope: 'Latest server response',
            ),
            PveMetricStripItem(
              label: 'Running',
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
        const SizedBox(height: 20),
        PveInventoryToolbar(
          title: const PveSectionTitle(title: 'Recent activity'),
          search: CupertinoSearchTextField(
            key: const ValueKey<String>('task-search'),
            controller: _searchController,
            placeholder: 'Search tasks',
            onChanged: (String value) =>
                setState(() => _taskQuery = _taskQuery.copyWith(query: value)),
          ),
          trailingControls: <Widget>[
            PveInventoryMenuButton(
              key: const ValueKey<String>('task-refine'),
              label: 'Refine',
              semanticLabel: 'Filter and sort task activity',
              icon: CupertinoIcons.line_horizontal_3_decrease_circle,
              onPressed: () => _showTaskRefinementPicker(snapshot),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (tasks.isNotEmpty)
          Text(
            'Showing ${visibleTasks.length} of ${tasks.length} recent ${tasks.length == 1 ? 'task' : 'tasks'}',
            key: const ValueKey<String>('task-result-count'),
            style: PveAppleText.secondary(context),
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
        const SizedBox(height: 24),
        const PveSectionTitle(title: 'Activity analysis'),
        const SizedBox(height: 12),
        TaskActivityInsights(tasks: orderedTasks),
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
    final selectedTask = _selectedVisibleTask(visibleTasks);
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
              final twoColumns =
                  constraints.maxWidth >=
                  PveAppleLayout.controlBarStackBreakpoint;
              final cardWidth = twoColumns
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  for (final task in visibleOperations)
                    SizedBox(
                      width: cardWidth,
                      child: _TaskCard(
                        task: task,
                        selected: selectedTask?.upid == task.upid,
                        onTap: () => onInspect(task),
                      ),
                    ),
                ],
              );
            },
          )
        else
          CupertinoListSection.insetGrouped(
            margin: EdgeInsets.zero,
            children: <Widget>[
              for (final task in visibleOperations)
                _TaskRow(task: task, onTap: () => onInspect(task)),
            ],
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
    final selectedUpid = _selectedTaskUpid;
    if (selectedUpid == null) return null;
    for (final task in visibleTasks) {
      if (task.upid == selectedUpid) return task;
    }
    return null;
  }

  void _clearFilters() {
    _searchController.clear();
    setState(() => _taskQuery = _taskQuery.clearFilters());
  }

  int get _taskRefinementCount {
    var count = 0;
    if (_taskQuery.period != TaskPeriodFilter.all) {
      count += 1;
    }
    if (_taskQuery.node != null) {
      count += 1;
    }
    if (_taskQuery.operatorName != null) {
      count += 1;
    }
    if (_taskQuery.guestVmid != null) {
      count += 1;
    }
    return count;
  }

  Future<void> _showTaskRefinementPicker(
    ClusterOverviewSnapshot snapshot,
  ) async {
    final guests = _knownTaskGuests(snapshot);
    final selectedGuest = _guestWithVmid(guests, _taskQuery.guestVmid);
    final selection = await showCupertinoModalPopup<_TaskRefinement>(
      context: context,
      builder: (BuildContext popupContext) => CupertinoActionSheet(
        title: const Text('Refine activity'),
        actions: <Widget>[
          CupertinoActionSheetAction(
            onPressed: () =>
                Navigator.of(popupContext).pop(_TaskRefinement.state),
            child: Text('Status · ${_taskStateFilterLabel(_taskQuery.state)}'),
          ),
          CupertinoActionSheetAction(
            onPressed: () =>
                Navigator.of(popupContext).pop(_TaskRefinement.period),
            child: Text('Time · ${_taskPeriodLabel(_taskQuery.period)}'),
          ),
          CupertinoActionSheetAction(
            onPressed: () =>
                Navigator.of(popupContext).pop(_TaskRefinement.node),
            child: Text('Node · ${_taskQuery.node ?? 'All nodes'}'),
          ),
          CupertinoActionSheetAction(
            onPressed: () =>
                Navigator.of(popupContext).pop(_TaskRefinement.operatorName),
            child: Text(
              'Operator · ${_taskQuery.operatorName ?? 'All operators'}',
            ),
          ),
          if (guests.isNotEmpty)
            CupertinoActionSheetAction(
              onPressed: () =>
                  Navigator.of(popupContext).pop(_TaskRefinement.guest),
              child: Text('Guest · ${selectedGuest?.title ?? 'All guests'}'),
            ),
          CupertinoActionSheetAction(
            onPressed: () =>
                Navigator.of(popupContext).pop(_TaskRefinement.sort),
            child: Text('Sort · ${_taskSortLabel(_taskQuery.sort)}'),
          ),
          if (_taskRefinementCount > 0 ||
              _taskQuery.state != TaskStateFilter.all)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () =>
                  Navigator.of(popupContext).pop(_TaskRefinement.clear),
              child: const Text('Clear refinements'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(popupContext).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (!mounted || selection == null) {
      return;
    }
    await _openTaskRefinement(selection, snapshot, guests);
  }

  Future<void> _openTaskRefinement(
    _TaskRefinement selection,
    ClusterOverviewSnapshot snapshot,
    List<PveGuest> guests,
  ) async {
    switch (selection) {
      case _TaskRefinement.state:
        await _showTaskStatePicker(context);
        return;
      case _TaskRefinement.period:
        await _showTaskPeriodPicker(context);
        return;
      case _TaskRefinement.node:
        await _showTaskTextFilterPicker(
          context,
          title: 'Node',
          allLabel: 'All nodes',
          choices: snapshot.tasks.map((ClusterTask task) => task.node),
          onSelected: (String? value) {
            setState(() => _taskQuery = _taskQuery.withNode(value));
          },
        );
        return;
      case _TaskRefinement.operatorName:
        await _showTaskTextFilterPicker(
          context,
          title: 'Operator',
          allLabel: 'All operators',
          choices: snapshot.tasks.map((ClusterTask task) => task.user),
          onSelected: (String? value) {
            setState(() => _taskQuery = _taskQuery.withOperatorName(value));
          },
        );
        return;
      case _TaskRefinement.guest:
        await _showTaskGuestFilterPicker(context, guests);
        return;
      case _TaskRefinement.sort:
        await _showTaskSortPicker(context);
        return;
      case _TaskRefinement.clear:
        setState(
          () => _taskQuery = _taskQuery
              .copyWith(
                state: TaskStateFilter.all,
                period: TaskPeriodFilter.all,
              )
              .withNode(null)
              .withOperatorName(null)
              .withGuestVmid(null),
        );
        return;
    }
  }

  Future<void> _showTaskPeriodPicker(BuildContext context) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext popupContext) => CupertinoActionSheet(
        title: const Text('Time'),
        actions: <Widget>[
          for (final TaskPeriodFilter value in TaskPeriodFilter.values)
            CupertinoActionSheetAction(
              isDefaultAction: value == _taskQuery.period,
              onPressed: () {
                Navigator.of(popupContext).pop();
                if (mounted) {
                  setState(
                    () => _taskQuery = _taskQuery.copyWith(period: value),
                  );
                }
              },
              child: Text(_taskPeriodLabel(value)),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(popupContext).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _showTaskStatePicker(BuildContext context) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext popupContext) => CupertinoActionSheet(
        title: const Text('Status'),
        actions: <Widget>[
          for (final TaskStateFilter value in TaskStateFilter.values)
            CupertinoActionSheetAction(
              isDefaultAction: value == _taskQuery.state,
              onPressed: () {
                Navigator.of(popupContext).pop();
                if (mounted) {
                  setState(
                    () => _taskQuery = _taskQuery.copyWith(state: value),
                  );
                }
              },
              child: Text(_taskStateFilterLabel(value)),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(popupContext).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _showTaskTextFilterPicker(
    BuildContext context, {
    required String title,
    required String allLabel,
    required Iterable<String> choices,
    required ValueChanged<String?> onSelected,
  }) async {
    final orderedChoices = choices.toSet().toList()..sort();
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext popupContext) => CupertinoActionSheet(
        title: Text(title),
        actions: <Widget>[
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(popupContext).pop();
              if (mounted) {
                onSelected(null);
              }
            },
            child: Text(allLabel),
          ),
          for (final choice in orderedChoices)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(popupContext).pop();
                if (mounted) {
                  onSelected(choice);
                }
              },
              child: Text(choice),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(popupContext).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _showTaskGuestFilterPicker(
    BuildContext context,
    List<PveGuest> guests,
  ) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext popupContext) => CupertinoActionSheet(
        title: const Text('Guest'),
        actions: <Widget>[
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(popupContext).pop();
              if (mounted) {
                setState(() => _taskQuery = _taskQuery.withGuestVmid(null));
              }
            },
            child: const Text('All guests'),
          ),
          for (final guest in guests)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(popupContext).pop();
                if (mounted) {
                  setState(
                    () => _taskQuery = _taskQuery.withGuestVmid(guest.vmid),
                  );
                }
              },
              child: Text('${guest.title} (${guest.vmid})'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(popupContext).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  Future<void> _showTaskSortPicker(BuildContext context) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext popupContext) => CupertinoActionSheet(
        title: const Text('Sort activity'),
        actions: <Widget>[
          for (final TaskSort value in TaskSort.values)
            CupertinoActionSheetAction(
              isDefaultAction: value == _taskQuery.sort,
              onPressed: () {
                Navigator.of(popupContext).pop();
                if (mounted) {
                  setState(() => _taskQuery = _taskQuery.copyWith(sort: value));
                }
              },
              child: Text(_taskSortLabel(value)),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(popupContext).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  List<PveGuest> _knownTaskGuests(ClusterOverviewSnapshot snapshot) {
    final taskGuestIds = snapshot.tasks
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
    final tone = dashboardToneForTask(task);
    final accent = dashboardToneColor(context, tone);
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
    final tone = dashboardToneForTask(task);
    final accent = dashboardToneColor(context, tone);
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

PveGuest? _guestWithVmid(List<PveGuest> guests, int? vmid) {
  for (final guest in guests) {
    if (guest.vmid == vmid) {
      return guest;
    }
  }
  return null;
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
    final tone = dashboardToneForTask(task);
    final accent = dashboardToneColor(context, tone);
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
  final startedAt = task.startedAt;
  if (startedAt == null) return 'Start time unavailable';
  final age = DateTime.now().difference(startedAt);
  if (age.isNegative) return 'Start time unavailable';
  if (age.inHours > 0) {
    return 'Active ${age.inHours}h ${age.inMinutes.remainder(60)}m';
  }
  if (age.inMinutes > 0) return 'Active ${age.inMinutes}m';
  return 'Active just now';
}

enum _TaskRefinement { state, period, node, operatorName, guest, sort, clear }

String _taskStateFilterLabel(TaskStateFilter value) => switch (value) {
  TaskStateFilter.all => 'All activity',
  TaskStateFilter.running => 'Running',
  TaskStateFilter.failed => 'Failed',
  TaskStateFilter.unknown => 'Unknown',
};

String _taskPeriodLabel(TaskPeriodFilter value) => switch (value) {
  TaskPeriodFilter.all => 'Any time',
  TaskPeriodFilter.day => 'Last 24 hours',
  TaskPeriodFilter.week => 'Last 7 days',
};

String _taskSortLabel(TaskSort value) => switch (value) {
  TaskSort.attention => 'Attention',
  TaskSort.started => 'Newest',
  TaskSort.node => 'Node',
  TaskSort.operation => 'Operation',
  TaskSort.operatorName => 'Operator',
};
