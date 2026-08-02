import 'package:flutter/foundation.dart';

import '../data/system_surfaces_repository.dart';
import '../domain/datacenter_surface_snapshot.dart';

class SystemSurfacesController extends ChangeNotifier {
  SystemSurfacesController(this._repository);

  factory SystemSurfacesController.unsupported() =>
      SystemSurfacesController(const UnsupportedSystemSurfacesRepository());

  static const Duration datacenterWatchDuration = Duration(hours: 4);

  final SystemSurfacesRepository _repository;

  bool _widgetsAvailable = false;
  bool _liveActivitiesAvailable = false;
  bool _datacenterWatchActive = false;
  bool _isBusy = false;
  String? _errorMessage;
  DatacenterSurfaceSnapshot? _latestSnapshot;
  bool _isDisposed = false;

  bool get widgetsAvailable => _widgetsAvailable;

  bool get liveActivitiesAvailable => _liveActivitiesAvailable;

  bool get datacenterWatchActive => _datacenterWatchActive;

  bool get isBusy => _isBusy;

  String? get errorMessage => _errorMessage;

  bool get canStartDatacenterWatch =>
      _liveActivitiesAvailable && _latestSnapshot != null && !_isBusy;

  Future<void> initialize() async {
    try {
      final SystemSurfaceCapabilities capabilities = await _repository
          .loadCapabilities();
      _widgetsAvailable = capabilities.widgetsAvailable;
      _liveActivitiesAvailable = capabilities.liveActivitiesAvailable;
      _datacenterWatchActive = capabilities.datacenterWatchActive;
    } catch (_) {
      _widgetsAvailable = false;
      _liveActivitiesAvailable = false;
      _datacenterWatchActive = false;
    }
    _notify();
  }

  Future<void> publish(DatacenterSurfaceSnapshot snapshot) async {
    _latestSnapshot = snapshot;
    _errorMessage = null;
    _notify();
    try {
      await _repository.publishSnapshot(snapshot);
      if (_datacenterWatchActive) {
        await _repository.updateDatacenterWatch(snapshot);
      }
    } catch (_) {
      _errorMessage = 'Apple system surfaces could not be updated.';
      _notify();
    }
  }

  Future<bool> startDatacenterWatch() async {
    final DatacenterSurfaceSnapshot? snapshot = _latestSnapshot;
    if (snapshot == null || !canStartDatacenterWatch) {
      return false;
    }
    _setBusy(true);
    try {
      final bool started = await _repository.startDatacenterWatch(
        snapshot,
        duration: datacenterWatchDuration,
      );
      _datacenterWatchActive = started;
      _errorMessage = started
          ? null
          : 'Live Activities are unavailable on this device.';
      return started;
    } catch (_) {
      _errorMessage = 'Datacenter Watch could not be started.';
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> endDatacenterWatch() async {
    if (!_datacenterWatchActive || _isBusy) {
      return;
    }
    _setBusy(true);
    try {
      await _repository.endDatacenterWatch();
      _datacenterWatchActive = false;
      _errorMessage = null;
    } catch (_) {
      _errorMessage = 'Datacenter Watch could not be ended.';
    } finally {
      _setBusy(false);
    }
  }

  void _setBusy(bool value) {
    _isBusy = value;
    _notify();
  }

  void _notify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
