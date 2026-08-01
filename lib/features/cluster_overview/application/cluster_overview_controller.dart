import 'package:flutter/foundation.dart';

import '../../../core/api/proxmox_api_exception.dart';
import '../../../core/api/proxmox_session.dart';
import '../data/proxmox_cluster_overview_repository.dart';
import '../domain/cluster_overview_snapshot.dart';

enum ClusterOverviewLoadState { idle, loading, ready, failed }

class ClusterOverviewController extends ChangeNotifier {
  ClusterOverviewController(this._repository);

  final ClusterOverviewRepository _repository;

  ClusterOverviewLoadState _state = ClusterOverviewLoadState.idle;
  ClusterOverviewSnapshot? _snapshot;
  String? _errorMessage;
  int _requestEpoch = 0;
  bool _isDisposed = false;

  ClusterOverviewLoadState get state => _state;

  ClusterOverviewSnapshot? get snapshot => _snapshot;

  String? get errorMessage => _errorMessage;

  Future<void> refresh(ProxmoxSession session) async {
    final int requestEpoch = ++_requestEpoch;
    _state = ClusterOverviewLoadState.loading;
    _errorMessage = null;
    _notify();

    try {
      final ClusterOverviewSnapshot snapshot = await _repository.load(session);
      if (_isStale(requestEpoch)) {
        return;
      }
      _snapshot = snapshot;
      _state = ClusterOverviewLoadState.ready;
      _notify();
    } on ProxmoxApiException catch (error) {
      _setFailure(requestEpoch, error.message);
    } catch (_) {
      _setFailure(
        requestEpoch,
        'Cluster data could not be loaded. Check the connection and retry.',
      );
    }
  }

  void clear() {
    _requestEpoch += 1;
    _state = ClusterOverviewLoadState.idle;
    _snapshot = null;
    _errorMessage = null;
    _notify();
  }

  void _setFailure(int requestEpoch, String message) {
    if (_isStale(requestEpoch)) {
      return;
    }
    _state = ClusterOverviewLoadState.failed;
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
