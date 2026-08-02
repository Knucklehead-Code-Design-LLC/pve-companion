import 'package:flutter/foundation.dart';

import '../../../core/api/proxmox_session.dart';
import '../../cluster_overview/data/proxmox_cluster_overview_repository.dart';
import '../../cluster_overview/domain/cluster_overview_snapshot.dart';
import '../../cluster_overview/domain/datacenter_health.dart';
import '../../cluster_overview/domain/datacenter_health_evaluator.dart';
import '../../connection_profiles/application/connection_profiles_controller.dart';
import '../../connection_profiles/domain/connection_profile.dart';
import '../domain/fleet_datacenter.dart';

enum FleetOverviewLoadState { idle, loading, ready }

class FleetOverviewController extends ChangeNotifier {
  FleetOverviewController({
    required ConnectionProfilesController connectionProfiles,
    required ClusterOverviewRepository overviewRepository,
  }) : _connectionProfiles = connectionProfiles,
       _overviewRepository = overviewRepository;

  factory FleetOverviewController.unsupported({
    required ConnectionProfilesController connectionProfiles,
  }) => FleetOverviewController(
    connectionProfiles: connectionProfiles,
    overviewRepository: const _UnavailableClusterOverviewRepository(),
  );

  final ConnectionProfilesController _connectionProfiles;
  final ClusterOverviewRepository _overviewRepository;

  FleetOverviewLoadState _state = FleetOverviewLoadState.idle;
  List<FleetDatacenter> _datacenters = const <FleetDatacenter>[];
  DateTime? _lastUpdatedAt;
  int _requestEpoch = 0;
  bool _isDisposed = false;

  FleetOverviewLoadState get state => _state;

  List<FleetDatacenter> get datacenters =>
      List<FleetDatacenter>.unmodifiable(_datacenters);

  DateTime? get lastUpdatedAt => _lastUpdatedAt;

  Future<void> refresh() async {
    final int requestEpoch = ++_requestEpoch;
    _state = FleetOverviewLoadState.loading;
    _notify();
    final List<ConnectionProfile> profiles = _connectionProfiles.profiles;
    final List<FleetDatacenter> datacenters = await _runWithConcurrencyLimit(
      profiles,
      maximumConcurrentOperations: 3,
      task: _loadProfile,
    );
    if (_isStale(requestEpoch)) {
      return;
    }
    datacenters.sort(_compareDatacenters);
    _datacenters = List<FleetDatacenter>.unmodifiable(datacenters);
    _lastUpdatedAt = DateTime.now();
    _state = FleetOverviewLoadState.ready;
    _notify();
  }

  Future<FleetDatacenter> _loadProfile(ConnectionProfile profile) async {
    final BackgroundSessionAttempt connection = await _connectionProfiles
        .openBackgroundSession(profile);
    final session = connection.session;
    if (session == null) {
      return FleetDatacenter(
        profile: profile,
        state: FleetDatacenterState.unavailable,
        message: connection.message,
      );
    }
    try {
      final ClusterOverviewSnapshot overview = await _overviewRepository.load(
        session,
      );
      final DatacenterHealth health = DatacenterHealthEvaluator.evaluate(
        overview,
      );
      return FleetDatacenter(
        profile: profile,
        state: switch (health.state) {
          DatacenterHealthState.healthy => FleetDatacenterState.healthy,
          DatacenterHealthState.warning => FleetDatacenterState.warning,
          DatacenterHealthState.critical => FleetDatacenterState.critical,
        },
        health: health,
        updatedAt: DateTime.now(),
      );
    } catch (_) {
      return FleetDatacenter(
        profile: profile,
        state: FleetDatacenterState.unavailable,
        message: 'Datacenter telemetry could not be read.',
      );
    } finally {
      session.close();
    }
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

Future<List<T>> _runWithConcurrencyLimit<S, T>(
  List<S> values, {
  required int maximumConcurrentOperations,
  required Future<T> Function(S value) task,
}) async {
  if (values.isEmpty) {
    return <T>[];
  }
  final List<T?> results = List<T?>.filled(values.length, null);
  int nextIndex = 0;
  Future<void> worker() async {
    while (true) {
      final int index = nextIndex;
      nextIndex += 1;
      if (index >= values.length) {
        return;
      }
      results[index] = await task(values[index]);
    }
  }

  final int workerCount = maximumConcurrentOperations
      .clamp(1, values.length)
      .toInt();
  await Future.wait<void>(
    List<Future<void>>.generate(workerCount, (_) => worker()),
  );
  return results.cast<T>();
}

int _compareDatacenters(FleetDatacenter left, FleetDatacenter right) {
  final int stateComparison = _stateRank(
    left.state,
  ).compareTo(_stateRank(right.state));
  if (stateComparison != 0) {
    return stateComparison;
  }
  return left.profile.displayName.toLowerCase().compareTo(
    right.profile.displayName.toLowerCase(),
  );
}

int _stateRank(FleetDatacenterState state) => switch (state) {
  FleetDatacenterState.critical => 0,
  FleetDatacenterState.warning => 1,
  FleetDatacenterState.unavailable => 2,
  FleetDatacenterState.healthy => 3,
};

class _UnavailableClusterOverviewRepository
    implements ClusterOverviewRepository {
  const _UnavailableClusterOverviewRepository();

  @override
  Future<ClusterOverviewSnapshot> load(ProxmoxSession session) =>
      throw UnsupportedError('Fleet telemetry is unavailable in this context.');
}
