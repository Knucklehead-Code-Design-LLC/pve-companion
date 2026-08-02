import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/features/cluster_overview/domain/cluster_overview_snapshot.dart';

void main() {
  test('orders cluster tasks newest first and missing timestamps last', () {
    final List<ClusterTask> tasks = <ClusterTask>[
      const ClusterTask(
        upid: 'missing',
        node: 'pve-01',
        type: 'backup',
        user: 'root@pam',
      ),
      ClusterTask(
        upid: 'older',
        node: 'pve-01',
        type: 'backup',
        user: 'root@pam',
        startedAt: DateTime.utc(2026, 8, 1, 8),
      ),
      ClusterTask(
        upid: 'newer',
        node: 'pve-01',
        type: 'backup',
        user: 'root@pam',
        startedAt: DateTime.utc(2026, 8, 1, 9),
      ),
    ]..sort(compareClusterTasksByRecency);

    expect(tasks.map((ClusterTask task) => task.upid), <String>[
      'newer',
      'older',
      'missing',
    ]);
  });

  test('uses an explicit terminal task status even without an end time', () {
    const ClusterTask successful = ClusterTask(
      upid: 'success',
      node: 'pve-01',
      type: 'start',
      user: 'root@pam',
      status: 'OK',
    );
    const ClusterTask failed = ClusterTask(
      upid: 'failed',
      node: 'pve-01',
      type: 'backup',
      user: 'root@pam',
      status: 'ERROR: backup failed',
    );
    const ClusterTask running = ClusterTask(
      upid: 'running',
      node: 'pve-01',
      type: 'backup',
      user: 'root@pam',
      status: 'running',
    );

    expect(successful.state, ClusterTaskState.successful);
    expect(failed.state, ClusterTaskState.failed);
    expect(running.state, ClusterTaskState.running);
  });

  test('recognizes long-running interactive task types as sessions', () {
    const ClusterTask console = ClusterTask(
      upid: 'console',
      node: 'pve-01',
      type: 'vncproxy',
      user: 'root@pam',
      status: 'running',
    );
    const ClusterTask backup = ClusterTask(
      upid: 'backup',
      node: 'pve-01',
      type: 'backup',
      user: 'root@pam',
      status: 'running',
    );

    expect(console.isInteractiveSession, isTrue);
    expect(backup.isInteractiveSession, isFalse);
  });
}
