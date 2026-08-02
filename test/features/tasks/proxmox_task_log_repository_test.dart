import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/core/api/proxmox_api_exception.dart';
import 'package:pve_companion/core/api/proxmox_session.dart';
import 'package:pve_companion/features/cluster_overview/domain/cluster_overview_snapshot.dart';
import 'package:pve_companion/features/tasks/data/proxmox_task_log_repository.dart';
import 'package:pve_companion/features/tasks/domain/pve_task_log.dart';

void main() {
  const ClusterTask task = ClusterTask(
    upid: 'UPID:pve-01:00000001:00000001:00000001:vzdump:101:root@pam:',
    node: 'pve-01',
    type: 'vzdump',
    user: 'root@pam',
  );

  test('decodes real task log lines without inventing text', () async {
    final _TaskLogSession session = _TaskLogSession(
      response: <Object?>[
        <Object?, Object?>{'n': 1, 't': 'starting backup'},
        <Object?, Object?>{'n': '2', 't': 'completed'},
        <Object?, Object?>{'n': 3},
      ],
    );

    final PveTaskLogResult result = await const ProxmoxTaskLogRepository().load(
      session,
      task,
    );

    expect(result.state, PveTaskLogState.available);
    expect(result.lines.map((PveTaskLogLine line) => line.text), <String>[
      'starting backup',
      'completed',
    ]);
    expect(session.requestedResource, 'nodes/pve-01/tasks/${task.upid}/log');
  });

  test(
    'reports authorization limits and unavailable endpoints distinctly',
    () async {
      final PveTaskLogResult limited = await const ProxmoxTaskLogRepository()
          .load(
            _TaskLogSession(
              error: const ProxmoxResponseException(
                statusCode: 403,
                message: 'forbidden',
              ),
            ),
            task,
          );
      final PveTaskLogResult unavailable =
          await const ProxmoxTaskLogRepository().load(
            _TaskLogSession(
              error: const ProxmoxResponseException(
                statusCode: 404,
                message: 'not found',
              ),
            ),
            task,
          );

      expect(limited.state, PveTaskLogState.permissionLimited);
      expect(unavailable.state, PveTaskLogState.unavailable);
    },
  );
}

class _TaskLogSession implements ProxmoxSession {
  _TaskLogSession({this.response, this.error});

  final Object? response;
  final Object? error;
  String? requestedResource;

  @override
  Future<Object?> getData(
    String resource, {
    Map<String, String> query = const <String, String>{},
  }) async {
    requestedResource = resource;
    if (error != null) throw error!;
    return response;
  }

  @override
  Future<Object?> postForm(
    String resource, {
    required Map<String, String> fields,
  }) => throw UnimplementedError();

  @override
  void close() {}
}
