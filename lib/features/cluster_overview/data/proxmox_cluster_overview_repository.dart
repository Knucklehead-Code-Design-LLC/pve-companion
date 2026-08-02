import 'dart:async';

import '../../../core/api/proxmox_api_exception.dart';
import '../../../core/api/proxmox_session.dart';
import '../../guests/domain/pve_guest.dart';
import '../domain/cluster_overview_snapshot.dart';

abstract interface class ClusterOverviewRepository {
  Future<ClusterOverviewSnapshot> load(ProxmoxSession session);
}

class ProxmoxClusterOverviewRepository implements ClusterOverviewRepository {
  @override
  Future<ClusterOverviewSnapshot> load(ProxmoxSession session) async {
    final List<Object?> responses =
        await Future.wait<Object?>(<Future<Object?>>[
          session.getData('version'),
          session.getData('nodes'),
          _loadClusterResources(session),
          session.getData('storage'),
          session.getData('cluster/tasks'),
        ]);

    return ClusterOverviewSnapshot(
      version: _decodeVersion(responses[0]),
      nodes: _decodeNodes(responses[1]),
      guests: _decodeGuests(responses[2]),
      storages: _decodeStorages(responses[3], responses[2]),
      tasks: _decodeTasks(responses[4]),
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

  PveVersion _decodeVersion(Object? value) {
    final Map<String, Object?> data = _object(value, 'version');
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
          final Object? type = resource['type'];
          return type == 'qemu' || type == 'lxc';
        })
        .map((Map<String, Object?> guest) {
          final String type = _requiredString(guest, 'type', 'guest');
          final GuestKind kind = switch (type) {
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
    final Map<String, List<ClusterStorageResource>> resourcesByStorage =
        <String, List<ClusterStorageResource>>{};
    for (final Map<String, Object?> resource in _objects(
      resourceValue,
      'storage resources',
    )) {
      final String? storageName = _optionalString(resource, 'storage');
      final String? nodeName = _optionalString(resource, 'node');
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
          final String name = _requiredString(storage, 'storage', 'storage');
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
    final String? result = _optionalString(value, key);
    if (result == null) {
      throw ProxmoxMalformedResponseException(
        'The $resource response did not contain $key.',
      );
    }
    return result;
  }

  String? _optionalString(Map<String, Object?> value, String key) {
    final Object? result = value[key];
    return result is String && result.isNotEmpty ? result : null;
  }

  int _requiredInt(Map<String, Object?> value, String key, String resource) {
    final int? result = _optionalInt(value, key);
    if (result == null) {
      throw ProxmoxMalformedResponseException(
        'The $resource response did not contain a numeric $key.',
      );
    }
    return result;
  }

  int? _optionalInt(Map<String, Object?> value, String key) {
    final Object? result = value[key];
    return result is num ? result.toInt() : null;
  }

  double? _optionalDouble(Map<String, Object?> value, String key) {
    final Object? result = value[key];
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
