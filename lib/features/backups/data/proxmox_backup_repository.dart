import '../../../core/api/proxmox_api_exception.dart';
import '../../../core/api/proxmox_session.dart';
import '../../cluster_overview/domain/cluster_overview_snapshot.dart';
import '../domain/pve_backup_center.dart';

abstract interface class PveBackupRepository {
  Future<PveBackupCenterSnapshot> load(
    ProxmoxSession session,
    ClusterOverviewSnapshot overview,
  );
}

class ProxmoxBackupRepository implements PveBackupRepository {
  @override
  Future<PveBackupCenterSnapshot> load(
    ProxmoxSession session,
    ClusterOverviewSnapshot overview,
  ) async {
    final List<PveBackupDestination> destinations = overview.storages
        .where(_isBackupStorage)
        .map((ClusterStorage storage) => PveBackupDestination(storage: storage))
        .toList(growable: false);
    final Future<_OptionalBackupData> schedulesRequest = _loadOptional(
      session,
      'cluster/backup',
    );
    final List<_BackupContentRoute> routes = _contentRoutes(
      overview,
      destinations,
    );
    final List<Future<_OptionalBackupData>> recordRequests = routes
        .map(
          (_BackupContentRoute route) => _loadOptional(
            session,
            'nodes/${route.node}/storage/${route.storage}/content',
          ),
        )
        .toList(growable: false);
    final List<_OptionalBackupData> results =
        await Future.wait<_OptionalBackupData>(<Future<_OptionalBackupData>>[
          schedulesRequest,
          ...recordRequests,
        ]);
    final List<PveBackupRecord> records = <PveBackupRecord>[];
    for (int index = 0; index < routes.length; index += 1) {
      records.addAll(_decodeRecords(results[index + 1].data, routes[index]));
    }
    final Map<String, PveBackupRecord> uniqueRecords =
        <String, PveBackupRecord>{};
    for (final PveBackupRecord record in records) {
      final PveBackupRecord? existing = uniqueRecords[record.volumeId];
      if (existing == null || _isNewer(record, existing)) {
        uniqueRecords[record.volumeId] = record;
      }
    }
    final List<PveBackupRecord> orderedRecords = uniqueRecords.values.toList()
      ..sort(
        (PveBackupRecord left, PveBackupRecord right) =>
            (right.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(
                  left.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
                ),
      );
    final List<ClusterTask> recentTasks =
        overview.tasks
            .where(
              (ClusterTask task) => task.type.toLowerCase().contains('vzdump'),
            )
            .toList(growable: false)
          ..sort(compareClusterTasksByRecency);
    return PveBackupCenterSnapshot(
      destinations: List<PveBackupDestination>.unmodifiable(destinations),
      schedules: List<PveBackupSchedule>.unmodifiable(
        _decodeSchedules(results.first.data),
      ),
      records: List<PveBackupRecord>.unmodifiable(orderedRecords),
      recentTasks: List<ClusterTask>.unmodifiable(recentTasks),
      scheduleDataState: results.first.state,
      recordDataState: _combineRecordDataStates(
        results.skip(1).map((_OptionalBackupData result) => result.state),
        hasDestinations: destinations.isNotEmpty,
        hasRoutes: routes.isNotEmpty,
      ),
    );
  }

  bool _isBackupStorage(ClusterStorage storage) => storage.content
      .toLowerCase()
      .split(',')
      .map((String item) => item.trim())
      .contains('backup');

  List<_BackupContentRoute> _contentRoutes(
    ClusterOverviewSnapshot overview,
    List<PveBackupDestination> destinations,
  ) {
    final List<_BackupContentRoute> routes = <_BackupContentRoute>[];
    for (final PveBackupDestination destination in destinations) {
      final List<String> reportingNodes = destination.storage.resources
          .map((ClusterStorageResource resource) => resource.node)
          .toSet()
          .toList(growable: false);
      final List<String> availableReportingNodes = destination.storage.resources
          .where((ClusterStorageResource resource) => resource.isAvailable)
          .map((ClusterStorageResource resource) => resource.node)
          .toSet()
          .toList(growable: false);
      final List<String> candidateNodes = availableReportingNodes.isNotEmpty
          ? availableReportingNodes
          : reportingNodes;
      final Iterable<String> nodes = candidateNodes.isNotEmpty
          ? destination.storage.shared
                ? candidateNodes.take(1)
                : candidateNodes
          : overview.nodes
                .where((ClusterNode node) => node.isOnline)
                .map((ClusterNode node) => node.name)
                .take(destination.storage.shared ? 1 : overview.nodes.length);
      for (final String node in nodes) {
        routes.add(_BackupContentRoute(node: node, storage: destination.name));
      }
    }
    return routes;
  }

  PveBackupDataState _combineRecordDataStates(
    Iterable<PveBackupDataState> states, {
    required bool hasDestinations,
    required bool hasRoutes,
  }) {
    if (!hasDestinations) {
      return PveBackupDataState.notConfigured;
    }
    if (!hasRoutes) {
      return PveBackupDataState.unavailable;
    }
    final bool hasAvailableData = states.contains(PveBackupDataState.available);
    final bool hasLimitedData = states.any(
      (PveBackupDataState state) => state != PveBackupDataState.available,
    );
    if (hasAvailableData && hasLimitedData) {
      return PveBackupDataState.partiallyAvailable;
    }
    if (hasAvailableData) {
      return PveBackupDataState.available;
    }
    if (states.contains(PveBackupDataState.permissionLimited)) {
      return PveBackupDataState.permissionLimited;
    }
    return PveBackupDataState.unavailable;
  }

  Future<_OptionalBackupData> _loadOptional(
    ProxmoxSession session,
    String resource, {
    Map<String, String> query = const <String, String>{},
  }) async {
    try {
      return _OptionalBackupData(
        data: await session.getData(resource, query: query),
        state: PveBackupDataState.available,
      );
    } on ProxmoxUnauthorizedException {
      return const _OptionalBackupData(
        state: PveBackupDataState.permissionLimited,
      );
    } on ProxmoxResponseException catch (error) {
      if (error.statusCode == 403) {
        return const _OptionalBackupData(
          state: PveBackupDataState.permissionLimited,
        );
      }
      if (error.statusCode == 404 || error.statusCode == 501) {
        return const _OptionalBackupData(state: PveBackupDataState.unavailable);
      }
      rethrow;
    }
  }

  List<PveBackupSchedule> _decodeSchedules(Object? value) {
    if (value is! List<Object?>) {
      return const <PveBackupSchedule>[];
    }
    return value
        .whereType<Map<Object?, Object?>>()
        .map((Map<Object?, Object?> item) {
          final String? id = _string(item['id']);
          if (id == null) {
            return null;
          }
          return PveBackupSchedule(
            id: id,
            storage: _string(item['storage']),
            schedule: _string(item['schedule']),
            enabled: _boolean(item['enabled']),
            guestSelection: _string(item['vmid']),
          );
        })
        .whereType<PveBackupSchedule>()
        .toList(growable: false);
  }

  bool _isBackupContent(Map<Object?, Object?> item) {
    final String? content = _string(item['content']);
    if (content != null) {
      return content.toLowerCase() == 'backup';
    }
    final String? volumeId = _string(item['volid']);
    return volumeId?.toLowerCase().contains(':backup/') ?? false;
  }

  List<PveBackupRecord> _decodeRecords(
    Object? value,
    _BackupContentRoute route,
  ) {
    if (value is! List<Object?>) {
      return const <PveBackupRecord>[];
    }
    return value
        .whereType<Map<Object?, Object?>>()
        .where(_isBackupContent)
        .map((Map<Object?, Object?> item) {
          final String? volumeId = _string(item['volid']);
          if (volumeId == null) {
            return null;
          }
          return PveBackupRecord(
            volumeId: volumeId,
            storage: route.storage,
            node: route.node,
            guestId: _integer(item['vmid']),
            createdAt: _date(item['ctime']),
            sizeBytes: _integer(item['size']),
            format: _string(item['format']),
            notes: _string(item['notes']),
            protected: _boolean(item['protected']) ?? false,
          );
        })
        .whereType<PveBackupRecord>()
        .toList(growable: false);
  }

  bool _isNewer(PveBackupRecord candidate, PveBackupRecord current) {
    final DateTime? candidateDate = candidate.createdAt;
    final DateTime? currentDate = current.createdAt;
    if (candidateDate == null) {
      return false;
    }
    return currentDate == null || candidateDate.isAfter(currentDate);
  }

  String? _string(Object? value) =>
      value is String && value.trim().isNotEmpty ? value : null;

  int? _integer(Object? value) => value is num ? value.toInt() : null;

  bool? _boolean(Object? value) => switch (value) {
    true || 1 || '1' || 'true' => true,
    false || 0 || '0' || 'false' => false,
    _ => null,
  };

  DateTime? _date(Object? value) {
    if (value is! num) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(
      value.toInt() * 1000,
      isUtc: true,
    ).toLocal();
  }
}

class _BackupContentRoute {
  const _BackupContentRoute({required this.node, required this.storage});

  final String node;
  final String storage;
}

class _OptionalBackupData {
  const _OptionalBackupData({this.data, required this.state});

  final Object? data;
  final PveBackupDataState state;
}
