import '../../../core/api/proxmox_api_exception.dart';
import '../../../core/api/proxmox_session.dart';
import '../../cluster_overview/domain/cluster_overview_snapshot.dart';
import '../domain/pve_task_log.dart';

abstract interface class PveTaskLogRepository {
  Future<PveTaskLogResult> load(ProxmoxSession session, ClusterTask task);
}

class ProxmoxTaskLogRepository implements PveTaskLogRepository {
  const ProxmoxTaskLogRepository();

  @override
  Future<PveTaskLogResult> load(
    ProxmoxSession session,
    ClusterTask task,
  ) async {
    try {
      final Object? response = await session.getData(
        // The API service builds a URI path from this resource. Supplying an
        // already encoded UPID would encode percent signs a second time.
        // Both values originate in the server's cluster task response.
        'nodes/${task.node}/tasks/${task.upid}/log',
      );
      final List<PveTaskLogLine> lines = _decodeLines(response);
      return lines.isEmpty
          ? const PveTaskLogResult.empty()
          : PveTaskLogResult.available(lines);
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

  List<PveTaskLogLine> _decodeLines(Object? response) {
    if (response is! List<Object?>) return const <PveTaskLogLine>[];
    return response
        .whereType<Map<Object?, Object?>>()
        .map((Map<Object?, Object?> entry) {
          final Object? rawText = entry['t'] ?? entry['text'] ?? entry['line'];
          if (rawText is! String || rawText.trim().isEmpty) return null;
          final Object? rawSequence = entry['n'];
          return PveTaskLogLine(
            sequence: rawSequence is int
                ? rawSequence
                : int.tryParse('$rawSequence'),
            text: rawText,
          );
        })
        .whereType<PveTaskLogLine>()
        .toList(growable: false);
  }
}
