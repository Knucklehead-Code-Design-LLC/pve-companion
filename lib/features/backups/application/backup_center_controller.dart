import 'package:flutter/foundation.dart';

import '../../../core/api/proxmox_api_exception.dart';
import '../../../core/api/proxmox_session.dart';
import '../../cluster_overview/domain/cluster_overview_snapshot.dart';
import '../data/proxmox_backup_repository.dart';
import '../domain/pve_backup_center.dart';

enum BackupCenterLoadState { loading, ready, failed }

class BackupCenterController extends ChangeNotifier {
  BackupCenterController({
    required PveBackupRepository repository,
    required ProxmoxSession session,
    required ClusterOverviewSnapshot overview,
  }) : _repository = repository,
       _session = session,
       _overview = overview;

  final PveBackupRepository _repository;
  final ProxmoxSession _session;
  final ClusterOverviewSnapshot _overview;

  BackupCenterLoadState _state = BackupCenterLoadState.loading;
  PveBackupCenterSnapshot? _snapshot;
  String? _errorMessage;
  int _requestEpoch = 0;
  bool _isDisposed = false;

  BackupCenterLoadState get state => _state;

  PveBackupCenterSnapshot? get snapshot => _snapshot;

  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    final int requestEpoch = ++_requestEpoch;
    _state = BackupCenterLoadState.loading;
    _errorMessage = null;
    _notify();
    try {
      final PveBackupCenterSnapshot snapshot = await _repository.load(
        _session,
        _overview,
      );
      if (_isStale(requestEpoch)) {
        return;
      }
      _snapshot = snapshot;
      _state = BackupCenterLoadState.ready;
      _notify();
    } on ProxmoxApiException catch (error) {
      _fail(requestEpoch, error.message);
    } catch (_) {
      _fail(requestEpoch, 'Backup data could not be loaded.');
    }
  }

  void _fail(int requestEpoch, String message) {
    if (_isStale(requestEpoch)) {
      return;
    }
    _state = BackupCenterLoadState.failed;
    _errorMessage = message;
    _notify();
  }

  bool _isStale(int requestEpoch) =>
      _isDisposed || requestEpoch != _requestEpoch;

  void _notify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _requestEpoch += 1;
    super.dispose();
  }
}
