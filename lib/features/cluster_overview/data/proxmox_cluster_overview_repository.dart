import 'dart:async';

import '../../../core/api/proxmox_api_exception.dart';
import '../../../core/api/proxmox_session.dart';
import '../../guests/domain/pve_guest.dart';
import '../domain/cluster_overview_snapshot.dart';
import '../domain/datacenter_resource_history.dart';

abstract interface class ClusterOverviewRepository {
  Future<ClusterOverviewSnapshot> load(ProxmoxSession session);
}

class ProxmoxClusterOverviewRepository implements ClusterOverviewRepository {
  static const Duration _resourceHistoryTimeout = Duration(seconds: 8);

  @override
  Future<ClusterOverviewSnapshot> load(ProxmoxSession session) async {
    final responses = await Future.wait<Object?>(<Future<Object?>>[
      session.getData('version'),
      session.getData('nodes'),
      _loadClusterResources(session),
      session.getData('storage'),
      session.getData('cluster/tasks'),
    ]);

    final nodes = _decodeNodes(responses[1]);
    final resourceHistory = await _loadResourceHistory(session, nodes);
    return ClusterOverviewSnapshot(
      version: _decodeVersion(responses[0]),
      nodes: nodes,
      guests: _decodeGuests(responses[2]),
      storages: _decodeStorages(responses[3], responses[2]),
      tasks: _decodeTasks(responses[4]),
      resourceHistory: resourceHistory,
    );
  }

  Future<Object?> _loadClusterResources(ProxmoxSession session) async {
    try {
      return await session.getData('cluster/resources');
    } on ProxmoxUnauthorizedException {
      return const <Object?>[];
    } on ProxmoxResponseException catch (error) {
      if (error.statusCode == 404 || error.statusCode == 501) {
        return const <Object?>[];
      }
      rethrow;
    }
  }

  Future<DatacenterResourceHistory> _loadResourceHistory(
    ProxmoxSession session,
    List<ClusterNode> nodes,
  ) async {
    if (nodes.isEmpty) {
      return const DatacenterResourceHistory.unavailable(
        unavailableReason: DatacenterResourceHistoryUnavailableReason.noNodes,
      );
    }
    final nodeResponses = await Future.wait<_NodeResourceHistoryResponse>(
      nodes.map(
        (ClusterNode node) => _loadNodeResourceHistory(session, node.name),
      ),
    );
    final samplesByTime = <DateTime, List<_NodeResourceSample>>{};
    var reportingNodeCount = 0;
    for (final response in nodeResponses) {
      if (response.samples.isNotEmpty) {
        reportingNodeCount += 1;
      }
      for (final sample in response.samples) {
        samplesByTime
            .putIfAbsent(sample.recordedAt, () => <_NodeResourceSample>[])
            .add(sample);
      }
    }
    final samples =
        samplesByTime.entries
            .map(
              (MapEntry<DateTime, List<_NodeResourceSample>> entry) =>
                  _aggregateResourceSample(entry.key, entry.value),
            )
            .where(
              (DatacenterResourceSample sample) => sample.hasReportedMetric,
            )
            .toList(growable: false)
          ..sort(
            (DatacenterResourceSample left, DatacenterResourceSample right) =>
                left.recordedAt.compareTo(right.recordedAt),
          );
    if (samples.isEmpty) {
      return DatacenterResourceHistory.unavailable(
        requestedNodeCount: nodes.length,
        unavailableReason: _historyUnavailableReason(nodeResponses),
      );
    }
    return DatacenterResourceHistory(
      samples: samples,
      requestedNodeCount: nodes.length,
      reportingNodeCount: reportingNodeCount,
    );
  }

  Future<_NodeResourceHistoryResponse> _loadNodeResourceHistory(
    ProxmoxSession session,
    String node,
  ) async {
    try {
      final response = await session
          .getData(
            'nodes/$node/rrddata',
            query: const <String, String>{'timeframe': 'day', 'cf': 'AVERAGE'},
          )
          .timeout(_resourceHistoryTimeout);
      return _NodeResourceHistoryResponse.loaded(
        _decodeNodeResourceSamples(response),
      );
    } on ProxmoxUnauthorizedException {
      return const _NodeResourceHistoryResponse.permissionDenied();
    } on ProxmoxResponseException catch (error) {
      if (error.statusCode == 404 || error.statusCode == 501) {
        return const _NodeResourceHistoryResponse.unsupported();
      }
      return const _NodeResourceHistoryResponse.failed();
    } on ProxmoxApiException {
      return const _NodeResourceHistoryResponse.failed();
    } catch (_) {
      return const _NodeResourceHistoryResponse.failed();
    }
  }

  List<_NodeResourceSample> _decodeNodeResourceSamples(Object? value) {
    return _objects(value, 'node RRD data')
        .map((Map<String, Object?> sample) {
          final time = _optionalInt(sample, 'time');
          if (time == null || time < 0) {
            return null;
          }
          final recordedAt = _unixSecondsToDateTime(time);
          if (recordedAt == null) {
            return null;
          }
          final memoryUsedBytes = _optionalInt(sample, 'mem');
          final memoryCapacityBytes = _optionalInt(sample, 'maxmem');
          // Node RRD samples use rootfs/maxroot while live node status uses
          // disk/maxdisk. Accept either explicit pair when a server supplies
          // one schema, without treating a missing capacity as zero.
          final rootDiskUsedBytes =
              _optionalInt(sample, 'rootfs') ?? _optionalInt(sample, 'disk');
          final rootDiskCapacityBytes =
              _optionalInt(sample, 'maxroot') ??
              _optionalInt(sample, 'maxdisk');
          final result = _NodeResourceSample(
            recordedAt: recordedAt,
            cpuFraction: _reportedFraction(sample, 'cpu'),
            memoryUsedBytes: memoryUsedBytes,
            memoryCapacityBytes: memoryCapacityBytes,
            diskUsedBytes: rootDiskUsedBytes,
            diskCapacityBytes: rootDiskCapacityBytes,
          );
          return result.hasReportedMetric ? result : null;
        })
        .whereType<_NodeResourceSample>()
        .toList(growable: false);
  }

  double? _reportedFraction(Map<String, Object?> value, String key) {
    final fraction = _optionalDouble(value, key);
    if (fraction == null || !fraction.isFinite || fraction < 0) {
      return null;
    }
    return fraction;
  }

  DatacenterResourceSample _aggregateResourceSample(
    DateTime recordedAt,
    List<_NodeResourceSample> samples,
  ) {
    return DatacenterResourceSample(
      recordedAt: recordedAt,
      cpuFraction: _averageFraction(
        samples.map((sample) => sample.cpuFraction),
      ),
      memoryFraction: _combinedFraction(
        samples,
        usage: (_NodeResourceSample sample) => sample.memoryUsedBytes,
        capacity: (_NodeResourceSample sample) => sample.memoryCapacityBytes,
      ),
      diskFraction: _combinedFraction(
        samples,
        usage: (_NodeResourceSample sample) => sample.diskUsedBytes,
        capacity: (_NodeResourceSample sample) => sample.diskCapacityBytes,
      ),
    );
  }

  double? _averageFraction(Iterable<double?> fractions) {
    var total = 0.0;
    var count = 0;
    for (final fraction in fractions) {
      if (fraction == null) {
        continue;
      }
      total += fraction;
      count += 1;
    }
    return count == 0 ? null : total / count;
  }

  double? _combinedFraction(
    Iterable<_NodeResourceSample> samples, {
    required int? Function(_NodeResourceSample sample) usage,
    required int? Function(_NodeResourceSample sample) capacity,
  }) {
    var totalUsage = 0;
    var totalCapacity = 0;
    var hasReportedPair = false;
    for (final sample in samples) {
      final used = usage(sample);
      final limit = capacity(sample);
      if (used == null || used < 0 || limit == null || limit <= 0) {
        continue;
      }
      totalUsage += used;
      totalCapacity += limit;
      hasReportedPair = true;
    }
    if (!hasReportedPair || totalCapacity <= 0) {
      return null;
    }
    return totalUsage / totalCapacity;
  }

  DatacenterResourceHistoryUnavailableReason _historyUnavailableReason(
    List<_NodeResourceHistoryResponse> responses,
  ) {
    if (responses.every(
      (_NodeResourceHistoryResponse response) =>
          response.status == _NodeResourceHistoryStatus.permissionDenied,
    )) {
      return DatacenterResourceHistoryUnavailableReason.permissionDenied;
    }
    if (responses.every(
      (_NodeResourceHistoryResponse response) =>
          response.status == _NodeResourceHistoryStatus.unsupported,
    )) {
      return DatacenterResourceHistoryUnavailableReason.unsupported;
    }
    if (responses.any(
      (_NodeResourceHistoryResponse response) =>
          response.status == _NodeResourceHistoryStatus.failed,
    )) {
      return DatacenterResourceHistoryUnavailableReason.requestFailed;
    }
    return DatacenterResourceHistoryUnavailableReason.noData;
  }

  PveVersion _decodeVersion(Object? value) {
    final data = _object(value, 'version');
    return PveVersion(
      version: _requiredString(data, 'version', 'version'),
      release: _optionalString(data, 'release'),
    );
  }

  List<ClusterNode> _decodeNodes(Object? value) {
    return _objects(value, 'nodes')
        .map((Map<String, Object?> node) {
          return ClusterNode(
            name: _requiredString(node, 'node', 'node'),
            status: _requiredString(node, 'status', 'node'),
            cpuFraction: _optionalDouble(node, 'cpu'),
            cpuCores: _optionalInt(node, 'maxcpu'),
            memoryBytes: _optionalInt(node, 'mem'),
            memoryLimitBytes: _optionalInt(node, 'maxmem'),
            diskBytes: _optionalInt(node, 'disk'),
            diskLimitBytes: _optionalInt(node, 'maxdisk'),
            uptimeSeconds: _optionalInt(node, 'uptime'),
          );
        })
        .toList(growable: false);
  }

  List<PveGuest> _decodeGuests(Object? value) {
    return _objects(value, 'guests')
        .where((Map<String, Object?> resource) {
          final type = resource['type'];
          return type == 'qemu' || type == 'lxc';
        })
        .map((Map<String, Object?> guest) {
          final type = _requiredString(guest, 'type', 'guest');
          final kind = switch (type) {
            'qemu' => GuestKind.virtualMachine,
            'lxc' => GuestKind.container,
            _ => throw ProxmoxMalformedResponseException(
              'The server returned an unknown guest type: $type.',
            ),
          };
          return PveGuest(
            vmid: _requiredInt(guest, 'vmid', 'guest'),
            node: _requiredString(guest, 'node', 'guest'),
            kind: kind,
            status: _requiredString(guest, 'status', 'guest'),
            name: _optionalString(guest, 'name'),
            cpuFraction: _optionalDouble(guest, 'cpu'),
            cpuCores: _optionalInt(guest, 'maxcpu'),
            memoryBytes: _optionalInt(guest, 'mem'),
            memoryLimitBytes: _optionalInt(guest, 'maxmem'),
            diskBytes: _optionalInt(guest, 'disk'),
            diskLimitBytes: _optionalInt(guest, 'maxdisk'),
            uptimeSeconds: _optionalInt(guest, 'uptime'),
            isTemplate: guest['template'] == 1 || guest['template'] == true,
          );
        })
        .toList(growable: false);
  }

  List<ClusterStorage> _decodeStorages(
    Object? configurationValue,
    Object? resourceValue,
  ) {
    final resourcesByStorage = <String, List<ClusterStorageResource>>{};
    for (final resource in _objects(resourceValue, 'storage resources')) {
      final storageName = _optionalString(resource, 'storage');
      final nodeName = _optionalString(resource, 'node');
      if (storageName == null || nodeName == null) {
        continue;
      }
      resourcesByStorage
          .putIfAbsent(storageName, () => <ClusterStorageResource>[])
          .add(
            ClusterStorageResource(
              node: nodeName,
              status: _optionalString(resource, 'status') ?? '',
              usedBytes: _optionalInt(resource, 'disk'),
              capacityBytes: _optionalInt(resource, 'maxdisk'),
            ),
          );
    }
    return _objects(configurationValue, 'storage')
        .map((Map<String, Object?> storage) {
          final name = _requiredString(storage, 'storage', 'storage');
          return ClusterStorage(
            name: name,
            type: _requiredString(storage, 'type', 'storage'),
            content: _optionalString(storage, 'content') ?? 'Not reported',
            shared: storage['shared'] == 1 || storage['shared'] == true,
            resources: List<ClusterStorageResource>.unmodifiable(
              resourcesByStorage[name] ?? const <ClusterStorageResource>[],
            ),
          );
        })
        .toList(growable: false);
  }

  List<ClusterTask> _decodeTasks(Object? value) {
    return _objects(value, 'tasks')
        .take(25)
        .map((Map<String, Object?> task) {
          return ClusterTask(
            upid: _requiredString(task, 'upid', 'task'),
            node: _requiredString(task, 'node', 'task'),
            type: _requiredString(task, 'type', 'task'),
            user: _requiredString(task, 'user', 'task'),
            status: _optionalString(task, 'status'),
            startedAt: _unixSecondsToDateTime(_optionalInt(task, 'starttime')),
            endedAt: _unixSecondsToDateTime(_optionalInt(task, 'endtime')),
          );
        })
        .toList(growable: false);
  }

  List<Map<String, Object?>> _objects(Object? value, String resource) {
    if (value is! List<Object?>) {
      throw ProxmoxMalformedResponseException(
        'The $resource response was not a list.',
      );
    }
    return value
        .map((Object? item) => _object(item, resource))
        .toList(growable: false);
  }

  Map<String, Object?> _object(Object? value, String resource) {
    if (value is! Map<Object?, Object?>) {
      throw ProxmoxMalformedResponseException(
        'The $resource response contained an invalid object.',
      );
    }
    return value.map<String, Object?>(
      (Object? key, Object? item) => MapEntry(key.toString(), item),
    );
  }

  String _requiredString(
    Map<String, Object?> value,
    String key,
    String resource,
  ) {
    final result = _optionalString(value, key);
    if (result == null) {
      throw ProxmoxMalformedResponseException(
        'The $resource response did not contain $key.',
      );
    }
    return result;
  }

  String? _optionalString(Map<String, Object?> value, String key) {
    final result = value[key];
    return result is String && result.isNotEmpty ? result : null;
  }

  int _requiredInt(Map<String, Object?> value, String key, String resource) {
    final result = _optionalInt(value, key);
    if (result == null) {
      throw ProxmoxMalformedResponseException(
        'The $resource response did not contain a numeric $key.',
      );
    }
    return result;
  }

  int? _optionalInt(Map<String, Object?> value, String key) {
    final result = value[key];
    return result is num ? result.toInt() : null;
  }

  double? _optionalDouble(Map<String, Object?> value, String key) {
    final result = value[key];
    return result is num ? result.toDouble() : null;
  }

  DateTime? _unixSecondsToDateTime(int? value) {
    return value == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            value * 1000,
            isUtc: true,
          ).toLocal();
  }
}

enum _NodeResourceHistoryStatus {
  loaded,
  permissionDenied,
  unsupported,
  failed,
}

class _NodeResourceHistoryResponse {
  const _NodeResourceHistoryResponse.loaded(this.samples)
    : status = _NodeResourceHistoryStatus.loaded;

  const _NodeResourceHistoryResponse.permissionDenied()
    : status = _NodeResourceHistoryStatus.permissionDenied,
      samples = const <_NodeResourceSample>[];

  const _NodeResourceHistoryResponse.unsupported()
    : status = _NodeResourceHistoryStatus.unsupported,
      samples = const <_NodeResourceSample>[];

  const _NodeResourceHistoryResponse.failed()
    : status = _NodeResourceHistoryStatus.failed,
      samples = const <_NodeResourceSample>[];

  final _NodeResourceHistoryStatus status;
  final List<_NodeResourceSample> samples;
}

class _NodeResourceSample {
  const _NodeResourceSample({
    required this.recordedAt,
    required this.cpuFraction,
    required this.memoryUsedBytes,
    required this.memoryCapacityBytes,
    required this.diskUsedBytes,
    required this.diskCapacityBytes,
  });

  final DateTime recordedAt;
  final double? cpuFraction;
  final int? memoryUsedBytes;
  final int? memoryCapacityBytes;
  final int? diskUsedBytes;
  final int? diskCapacityBytes;

  bool get hasReportedMetric =>
      cpuFraction != null ||
      _hasCapacityPair(memoryUsedBytes, memoryCapacityBytes) ||
      _hasCapacityPair(diskUsedBytes, diskCapacityBytes);

  bool _hasCapacityPair(int? usage, int? capacity) =>
      usage != null && usage >= 0 && capacity != null && capacity > 0;
}
