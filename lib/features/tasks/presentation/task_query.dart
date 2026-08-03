import '../../cluster_overview/domain/cluster_overview_snapshot.dart';

/// Immutable presentation query for the task activity list.
///
/// Keeping selection and ordering together makes the list deterministic and
/// lets callers capture one clock value for an entire filtering pass.
class TaskQuery {
  const TaskQuery({
    this.state = TaskStateFilter.all,
    this.period = TaskPeriodFilter.all,
    this.sort = TaskSort.attention,
    this.query = '',
    this.node,
    this.operatorName,
    this.guestVmid,
  });

  static const TaskQuery all = TaskQuery();

  final TaskStateFilter state;
  final TaskPeriodFilter period;
  final TaskSort sort;
  final String query;
  final String? node;
  final String? operatorName;
  final int? guestVmid;

  bool get hasFilters =>
      state != TaskStateFilter.all ||
      period != TaskPeriodFilter.all ||
      query.trim().isNotEmpty ||
      node != null ||
      operatorName != null ||
      guestVmid != null;

  /// Removes the query facets while preserving the operator's chosen ordering.
  TaskQuery clearFilters() => TaskQuery(sort: sort);

  TaskQuery copyWith({
    TaskStateFilter? state,
    TaskPeriodFilter? period,
    TaskSort? sort,
    String? query,
  }) {
    return TaskQuery(
      state: state ?? this.state,
      period: period ?? this.period,
      sort: sort ?? this.sort,
      query: query ?? this.query,
      node: this.node,
      operatorName: this.operatorName,
      guestVmid: this.guestVmid,
    );
  }

  TaskQuery withNode(String? value) => TaskQuery(
    state: state,
    period: period,
    sort: sort,
    query: query,
    node: value,
    operatorName: operatorName,
    guestVmid: guestVmid,
  );

  TaskQuery withOperatorName(String? value) => TaskQuery(
    state: state,
    period: period,
    sort: sort,
    query: query,
    node: node,
    operatorName: value,
    guestVmid: guestVmid,
  );

  TaskQuery withGuestVmid(int? value) => TaskQuery(
    state: state,
    period: period,
    sort: sort,
    query: query,
    node: node,
    operatorName: operatorName,
    guestVmid: value,
  );

  List<ClusterTask> apply(
    Iterable<ClusterTask> tasks, {
    required DateTime now,
  }) {
    final List<ClusterTask> matching = tasks
        .where((ClusterTask task) => matches(task, now: now))
        .toList(growable: false);
    matching.sort(
      (ClusterTask left, ClusterTask right) => compare(left, right, now: now),
    );
    return matching;
  }

  bool matches(ClusterTask task, {required DateTime now}) {
    if (!_matchesState(task)) return false;
    if (!_matchesPeriod(task, now: now)) return false;
    if (!_matchesTextAndFacets(task)) return false;
    return guestVmid == null || task.guestVmid == guestVmid;
  }

  bool _matchesState(ClusterTask task) => switch (state) {
    TaskStateFilter.all => true,
    TaskStateFilter.running => task.state == ClusterTaskState.running,
    TaskStateFilter.failed => task.state == ClusterTaskState.failed,
    TaskStateFilter.unknown => task.state == ClusterTaskState.unknown,
  };

  bool _matchesPeriod(ClusterTask task, {required DateTime now}) {
    final Duration? maximumAge = period.maximumAge;
    if (maximumAge == null) return true;

    final DateTime? startedAt = task.startedAt;
    if (startedAt == null || startedAt.isAfter(now)) return false;
    return now.difference(startedAt) <= maximumAge;
  }

  bool _matchesTextAndFacets(ClusterTask task) {
    if (node != null && task.node != node) return false;
    if (operatorName != null && task.user != operatorName) return false;

    final String normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return true;
    return task.type.toLowerCase().contains(normalizedQuery) ||
        task.node.toLowerCase().contains(normalizedQuery) ||
        task.user.toLowerCase().contains(normalizedQuery);
  }

  int compare(ClusterTask left, ClusterTask right, {required DateTime now}) =>
      switch (sort) {
        TaskSort.attention => compareTasksForAttention(left, right, now: now),
        TaskSort.started => compareClusterTasksByRecency(left, right),
        TaskSort.node => left.node.compareTo(right.node),
        TaskSort.operation => left.type.compareTo(right.type),
        TaskSort.operatorName => left.user.compareTo(right.user),
      };
}

enum TaskStateFilter { all, running, failed, unknown }

enum TaskPeriodFilter {
  all(null),
  day(Duration(days: 1)),
  week(Duration(days: 7));

  const TaskPeriodFilter(this.maximumAge);

  final Duration? maximumAge;
}

enum TaskSort { attention, started, node, operation, operatorName }

int compareTasksForAttention(
  ClusterTask left,
  ClusterTask right, {
  required DateTime now,
}) {
  final int priorityComparison = taskAttentionPriority(
    left,
    now: now,
  ).compareTo(taskAttentionPriority(right, now: now));
  if (priorityComparison != 0) return priorityComparison;
  return compareClusterTasksByRecency(left, right);
}

int taskAttentionPriority(ClusterTask task, {required DateTime now}) {
  if (task.state == ClusterTaskState.failed) return 0;
  if (task.isLongRunningAt(now)) return 1;
  if (task.state == ClusterTaskState.running && !task.isInteractiveSession) {
    return 2;
  }
  if (task.state == ClusterTaskState.unknown) return 3;
  if (task.isInteractiveSession) return 4;
  return 5;
}
