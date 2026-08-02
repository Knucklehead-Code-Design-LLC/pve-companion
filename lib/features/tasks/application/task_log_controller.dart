import 'package:flutter/foundation.dart';

import '../../../core/api/proxmox_session.dart';
import '../../cluster_overview/domain/cluster_overview_snapshot.dart';
import '../data/proxmox_task_log_repository.dart';
import '../domain/pve_task_log.dart';

class TaskLogController extends ChangeNotifier {
  TaskLogController({
    required PveTaskLogRepository repository,
    required ProxmoxSession? session,
    required ClusterTask task,
  }) : _repository = repository,
       _session = session,
       _task = task;

  final PveTaskLogRepository _repository;
  final ProxmoxSession? _session;
  final ClusterTask _task;
  PveTaskLogResult? _result;
  bool _loading = false;
  bool _disposed = false;

  PveTaskLogResult? get result => _result;
  bool get isLoading => _loading;
  bool get canLoad => _session != null;

  Future<void> load() async {
    final ProxmoxSession? session = _session;
    if (session == null || _loading) return;
    _loading = true;
    notifyListeners();
    late final PveTaskLogResult result;
    try {
      result = await _repository.load(session, _task);
    } catch (_) {
      result = const PveTaskLogResult.failed(
        'The task log could not be loaded.',
      );
    }
    if (_disposed) return;
    _result = result;
    _loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
