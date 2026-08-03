import 'package:flutter/foundation.dart';

import '../../../core/api/proxmox_api_exception.dart';
import '../../../core/api/proxmox_session.dart';
import '../data/proxmox_cluster_overview_repository.dart';
import '../domain/cluster_overview_snapshot.dart';
import '../domain/datacenter_resource_history.dart';

enum ClusterOverviewLoadState { idle, loading, ready, failed }

class ClusterOverviewController extends ChangeNotifier {
  ClusterOverviewController(this._repository);

  final ClusterOverviewRepository _repository;

  ClusterOverviewLoadState _state = ClusterOverviewLoadState.idle;
  ClusterOverviewSnapshot? _snapshot;
  String? _errorMessage;
  DateTime? _lastUpdatedAt;
  int _requestEpoch = 0;
  bool _isDisposed = false;
  static const int _maximumResourceHistorySamples = 24;
  final List<DatacenterResourceSample> _resourceHistory =
      <DatacenterResourceSample>[];

  ClusterOverviewLoadState get state => _state;

  ClusterOverviewSnapshot? get snapshot => _snapshot;

  String? get errorMessage => _errorMessage;

  DateTime? get lastUpdatedAt => _lastUpdatedAt;

  /// Recent samples for this app session only. They are intentionally bounded
  /// and are never presented as a server-provided or durable history.
  List<DatacenterResourceSample> get resourceHistory =>
      List<DatacenterResourceSample>.unmodifiable(_resourceHistory);

  Future<ClusterOverviewSnapshot?> refresh(ProxmoxSession session) async {
    final requestEpoch = ++_requestEpoch;
    _state = ClusterOverviewLoadState.loading;
    _errorMessage = null;
    _notify();

    try {
      final snapshot = await _repository.load(session);
      if (_isStale(requestEpoch)) {
        return null;
      }
      _snapshot = snapshot;
      final refreshedAt = DateTime.now();
      _lastUpdatedAt = refreshedAt;
      _resourceHistory.add(
        DatacenterResourceSample.fromSnapshot(
          snapshot,
          capturedAt: refreshedAt,
        ),
      );
      if (_resourceHistory.length > _maximumResourceHistorySamples) {
        _resourceHistory.removeRange(
          0,
          _resourceHistory.length - _maximumResourceHistorySamples,
        );
      }
      _state = ClusterOverviewLoadState.ready;
      _notify();
      return snapshot;
    } on ProxmoxApiException catch (error) {
      _setFailure(requestEpoch, error.message);
      return null;
    } catch (_) {
      _setFailure(
        requestEpoch,
        'Cluster data could not be loaded. Check the connection and retry.',
      );
      return null;
    }
  }

  void clear() {
    _requestEpoch += 1;
    _state = ClusterOverviewLoadState.idle;
    _snapshot = null;
    _errorMessage = null;
    _lastUpdatedAt = null;
    _resourceHistory.clear();
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
