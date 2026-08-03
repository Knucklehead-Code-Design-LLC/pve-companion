import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/core/api/proxmox_api_exception.dart';
import 'package:pve_companion/core/api/proxmox_session.dart';
import 'package:pve_companion/features/cluster_overview/domain/cluster_overview_snapshot.dart';
import 'package:pve_companion/features/tasks/data/proxmox_task_log_repository.dart';
import 'package:pve_companion/features/tasks/domain/pve_task_log.dart';

void main() {
  const task = ClusterTask(
    upid: 'UPID:pve-01:00000001:00000001:00000001:vzdump:101:root@pam:',
    node: 'pve-01',
    type: 'vzdump',
    user: 'root@pam',
  );

  test('decodes real task log lines without inventing text', () async {
    final session = _TaskLogSession(
      response: <Object?>[
        <Object?, Object?>{'n': 1, 't': 'starting backup'},
        <Object?, Object?>{'n': 2, 't': 'completed'},
      ],
    );

    final result = await const ProxmoxTaskLogRepository().load(session, task);

    expect(result.state, PveTaskLogState.available);
    expect(result.lines.map((PveTaskLogLine line) => line.text), <String>[
      'starting backup',
      'completed',
    ]);
    expect(session.requestedResource, 'nodes/pve-01/tasks/${task.upid}/log');
    expect(session.query, <String, String>{'start': '0', 'limit': '200'});
  });

  test(
    'reports authorization limits and unavailable endpoints distinctly',
    () async {
      final limited = await const ProxmoxTaskLogRepository().load(
        _TaskLogSession(
          error: const ProxmoxResponseException(
            statusCode: 403,
            message: 'forbidden',
          ),
        ),
        task,
      );
      final unavailable = await const ProxmoxTaskLogRepository().load(
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

  test(
    'reports malformed log data as a failure instead of an empty log',
    () async {
      final result = await const ProxmoxTaskLogRepository().load(
        _TaskLogSession(
          response: <Object?>[
            <Object?, Object?>{'n': '1', 't': 'bad'},
          ],
        ),
        task,
      );

      expect(result.state, PveTaskLogState.failed);
    },
  );
}

class _TaskLogSession implements ProxmoxSession {
  _TaskLogSession({this.response, this.error});

  final Object? response;
  final Object? error;
  String? requestedResource;
  Map<String, String>? query;

  @override
  Future<Object?> getData(
    String resource, {
    Map<String, String> query = const <String, String>{},
  }) async {
    requestedResource = resource;
    this.query = query;
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
