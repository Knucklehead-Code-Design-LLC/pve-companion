import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/features/cluster_overview/domain/cluster_overview_snapshot.dart';
import 'package:pve_companion/features/tasks/presentation/task_query.dart';

void main() {
  final now = DateTime.utc(2026, 8, 2, 12);

  test('period filters exclude undated and future tasks', () {
    final tasks = <ClusterTask>[
      _task('inside', now.subtract(const Duration(hours: 24)), upid: 'inside'),
      _task(
        'outside',
        now.subtract(const Duration(hours: 24, seconds: 1)),
        upid: 'outside',
      ),
      _task('undated', null, upid: 'undated'),
      _task('future', now.add(const Duration(seconds: 1)), upid: 'future'),
    ];

    final result = const TaskQuery(
      period: TaskPeriodFilter.day,
    ).apply(tasks, now: now);

    expect(result.map((ClusterTask task) => task.upid), <String>['inside']);
  });

  test('all time keeps tasks without a reported start time', () {
    final result = TaskQuery.all.apply(<ClusterTask>[
      _task('undated', null, upid: 'undated'),
    ], now: now);

    expect(result.single.upid, 'undated');
  });

  test('clear filters resets every selection while retaining the sort', () {
    const query = TaskQuery(
      state: TaskStateFilter.failed,
      period: TaskPeriodFilter.week,
      sort: TaskSort.node,
      query: 'backup',
      node: 'pve-01',
      operatorName: 'operator@pam',
      guestVmid: 101,
    );

    expect(query.hasFilters, isTrue);
    final cleared = query.clearFilters();
    expect(cleared.hasFilters, isFalse);
    expect(cleared.sort, TaskSort.node);
  });

  test('attention sorting uses the injected clock for long-running tasks', () {
    final result = const TaskQuery().apply(<ClusterTask>[
      _task(
        'recent running task',
        now.subtract(const Duration(minutes: 29)),
        status: 'running',
        upid: 'recent',
      ),
      _task(
        'long-running task',
        now.subtract(const Duration(minutes: 30)),
        status: 'running',
        upid: 'long-running',
      ),
    ], now: now);

    expect(result.map((ClusterTask task) => task.upid), <String>[
      'long-running',
      'recent',
    ]);
  });

  test('query applies every selected facet before sorting', () {
    final result =
        const TaskQuery(
          state: TaskStateFilter.running,
          query: 'backup',
          node: 'pve-01',
          operatorName: 'operator@pam',
          guestVmid: 101,
        ).apply(<ClusterTask>[
          _task('backup', now, status: 'running', upid: _upid(101)),
          _task(
            'backup',
            now,
            status: 'running',
            node: 'pve-02',
            upid: _upid(101),
          ),
          _task('backup', now, status: 'OK', upid: _upid(101)),
        ], now: now);

    expect(result, hasLength(1));
    expect(result.single.node, 'pve-01');
  });
}

ClusterTask _task(
  String type,
  DateTime? startedAt, {
  String? status,
  String node = 'pve-01',
  String upid = 'UPID:task',
}) => ClusterTask(
  upid: upid,
  node: node,
  type: type,
  user: 'operator@pam',
  status: status,
  startedAt: startedAt,
);

String _upid(int vmid) =>
    'UPID:pve-01:00000001:00000001:00000001:vzdump:$vmid:operator@pam:';
