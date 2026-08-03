import 'package:flutter/foundation.dart';

import '../../../core/api/proxmox_api_exception.dart';
import '../../../core/api/proxmox_session.dart';
import '../../cluster_overview/domain/cluster_overview_snapshot.dart';
import '../data/proxmox_cluster_administration_repository.dart';
import '../domain/pve_cluster_administration.dart';

enum ClusterAdministrationLoadState { loading, ready, failed }

class ClusterAdministrationController extends ChangeNotifier {
  ClusterAdministrationController({
    required PveClusterAdministrationRepository repository,
    required ProxmoxSession session,
    required ClusterOverviewSnapshot overview,
  }) : _repository = repository,
       _session = session,
       _overview = overview;

  final PveClusterAdministrationRepository _repository;
  final ProxmoxSession _session;
  final ClusterOverviewSnapshot _overview;

  ClusterAdministrationLoadState _state =
      ClusterAdministrationLoadState.loading;
  PveClusterAdministrationSnapshot? _snapshot;
  String? _errorMessage;
  int _requestEpoch = 0;
  bool _isDisposed = false;

  ClusterAdministrationLoadState get state => _state;
  PveClusterAdministrationSnapshot? get snapshot => _snapshot;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    final requestEpoch = ++_requestEpoch;
    _state = ClusterAdministrationLoadState.loading;
    _errorMessage = null;
    _notify();
    try {
      final snapshot = await _repository.load(_session, _overview);
      if (_isStale(requestEpoch)) {
        return;
      }
      _snapshot = snapshot;
      _state = ClusterAdministrationLoadState.ready;
      _notify();
    } on ProxmoxApiException catch (error) {
      _fail(requestEpoch, error.message);
    } catch (_) {
      _fail(requestEpoch, 'Cluster administration data could not be loaded.');
    }
  }

  void _fail(int requestEpoch, String message) {
    if (_isStale(requestEpoch)) {
      return;
    }
    _state = ClusterAdministrationLoadState.failed;
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
