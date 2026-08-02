import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/core/api/proxmox_session.dart';
import 'package:pve_companion/features/cluster_overview/domain/cluster_overview_snapshot.dart';
import 'package:pve_companion/features/tasks/application/task_log_controller.dart';
import 'package:pve_companion/features/tasks/data/proxmox_task_log_repository.dart';
import 'package:pve_companion/features/tasks/domain/pve_task_log.dart';

void main() {
  test(
    'converts an unexpected repository failure into a visible failed state',
    () async {
      final TaskLogController controller = TaskLogController(
        repository: const _ThrowingTaskLogRepository(),
        session: const _Session(),
        task: const ClusterTask(
          upid: 'UPID:task',
          node: 'pve-01',
          type: 'backup',
          user: 'root@pam',
        ),
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.isLoading, isFalse);
      expect(controller.result?.state, PveTaskLogState.failed);
    },
  );
}

class _ThrowingTaskLogRepository implements PveTaskLogRepository {
  const _ThrowingTaskLogRepository();

  @override
  Future<PveTaskLogResult> load(ProxmoxSession session, ClusterTask task) =>
      throw StateError('unexpected');
}

class _Session implements ProxmoxSession {
  const _Session();
  @override
  void close() {}
  @override
  Future<Object?> getData(
    String resource, {
    Map<String, String> query = const <String, String>{},
  }) => throw UnimplementedError();
  @override
  Future<Object?> postForm(
    String resource, {
    required Map<String, String> fields,
  }) => throw UnimplementedError();
}
