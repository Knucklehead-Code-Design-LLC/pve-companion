import '../../../core/api/proxmox_api_exception.dart';
import '../../../core/api/proxmox_session.dart';
import '../../../core/api/proxmox_task.dart';
import '../../cluster_overview/domain/cluster_overview_snapshot.dart';
import '../domain/pve_task_log.dart';

abstract interface class PveTaskLogRepository {
  Future<PveTaskLogResult> load(ProxmoxSession session, ClusterTask task);
}

class ProxmoxTaskLogRepository implements PveTaskLogRepository {
  const ProxmoxTaskLogRepository({
    ProxmoxTaskClient taskClient = const ProxmoxTaskClient(),
  }) : _taskClient = taskClient;

  final ProxmoxTaskClient _taskClient;

  @override
  Future<PveTaskLogResult> load(
    ProxmoxSession session,
    ClusterTask task,
  ) async {
    try {
      final lines = await _taskClient.loadLog(
        session,
        ProxmoxTaskReference(
          upid: task.upid,
          node: task.node,
          operationLabel: task.type,
          submittedAt: task.startedAt ?? DateTime.now(),
        ),
      );
      return lines.isEmpty
          ? const PveTaskLogResult.empty()
          : PveTaskLogResult.available(
              lines
                  .map(
                    (ProxmoxTaskLogLine line) =>
                        PveTaskLogLine(sequence: line.line, text: line.text),
                  )
                  .toList(growable: false),
            );
    } on ProxmoxUnauthorizedException catch (error) {
      return PveTaskLogResult.permissionLimited(error.message);
    } on ProxmoxResponseException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        return PveTaskLogResult.permissionLimited(error.message);
      }
      if (error.statusCode == 404 || error.statusCode == 501) {
        return PveTaskLogResult.unavailable(error.message);
      }
      return PveTaskLogResult.failed(error.message);
    } on ProxmoxApiException catch (error) {
      return PveTaskLogResult.failed(error.message);
    } catch (_) {
      return const PveTaskLogResult.failed('The task log could not be loaded.');
    }
  }
}
