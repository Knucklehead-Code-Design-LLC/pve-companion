import '../../../core/api/proxmox_api_exception.dart';
import '../../../core/api/proxmox_session.dart';
import '../../../core/api/proxmox_task.dart';
import '../domain/pve_guest.dart';

abstract interface class PveGuestRepository {
  Future<PveGuestDetails> loadDetails(ProxmoxSession session, PveGuest guest);

  Future<ProxmoxTaskReference?> runPowerAction(
    ProxmoxSession session,
    PveGuest guest,
    GuestPowerAction action,
  );

  Future<ProxmoxTaskReference> createSnapshot(
    ProxmoxSession session,
    PveGuest guest, {
    required String name,
    String? description,
    required bool includeMemoryState,
  });

  Future<ProxmoxTaskReference> rollbackSnapshot(
    ProxmoxSession session,
    PveGuest guest,
    PveGuestSnapshot snapshot,
  );

  Future<ProxmoxTaskReference> deleteSnapshot(
    ProxmoxSession session,
    PveGuest guest,
    PveGuestSnapshot snapshot,
  );

  Future<ProxmoxTaskReference> createBackup(
    ProxmoxSession session,
    PveGuest guest,
    PveGuestBackupRequest request,
  );

  Future<void> updateConfiguration(
    ProxmoxSession session,
    PveGuest guest,
    PveGuestConfigurationChange change,
  );
}

class ProxmoxGuestRepository implements PveGuestRepository {
  static const Set<String> _visibleConfigurationKeys = <String>{
    'agent',
    'arch',
    'boot',
    'cores',
    'cpu',
    'description',
    'hostname',
    'memory',
    'net0',
    'onboot',
    'ostype',
    'rootfs',
    'scsi0',
    'sockets',
    'startdate',
    'tags',
    'template',
    'vmgenid',
  };

  @override
  Future<PveGuestDetails> loadDetails(
    ProxmoxSession session,
    PveGuest guest,
  ) async {
    final String guestPath =
        'nodes/${guest.node}/${guest.resourceSegment}/${guest.vmid}';
    final List<Object?> responses = await Future.wait<Object?>(
      <Future<Object?>>[
        session.getData('$guestPath/config'),
        _loadOptional(session, '$guestPath/status/current'),
        _loadOptional(session, '$guestPath/snapshot'),
        _loadOptional(
          session,
          'nodes/${guest.node}/tasks',
          query: <String, String>{
            'vmid': '${guest.vmid}',
            'source': 'all',
            'limit': '12',
          },
        ),
      ],
    );
    final Object? configurationResponse = responses.first;
    if (configurationResponse is! Map<Object?, Object?>) {
      throw const ProxmoxMalformedResponseException(
        'The guest configuration response was not an object.',
      );
    }

    final Map<String, String> configuration = <String, String>{};
    for (final MapEntry<Object?, Object?> entry
        in configurationResponse.entries) {
      final String key = entry.key.toString();
      if (_visibleConfigurationKeys.contains(key) && entry.value != null) {
        configuration[key] = entry.value.toString();
      }
    }
    return PveGuestDetails(
      guest: guest,
      configuration: Map<String, String>.unmodifiable(configuration),
      runtime: _decodeRuntime(responses[1], guest),
      snapshots: _decodeSnapshots(responses[2]),
      recentTasks: _decodeTasks(responses[3]),
    );
  }

  @override
  Future<ProxmoxTaskReference?> runPowerAction(
    ProxmoxSession session,
    PveGuest guest,
    GuestPowerAction action,
  ) async {
    if (guest.isTemplate) {
      throw const ProxmoxResponseException(
        statusCode: 400,
        message: 'Templates cannot be powered on or off.',
      );
    }
    if (!action.supports(guest)) {
      throw ProxmoxResponseException(
        statusCode: 400,
        message: '${action.label} is not supported for ${guest.kind.label}s.',
      );
    }
    final Object? response = await session.postForm(
      'nodes/${guest.node}/${guest.resourceSegment}/${guest.vmid}/status/'
      '${action.apiPathSegment}',
      fields: const <String, String>{},
    );
    return _taskReferenceOrNull(
      response,
      node: guest.node,
      operationLabel: action.label,
    );
  }

  @override
  Future<ProxmoxTaskReference> createSnapshot(
    ProxmoxSession session,
    PveGuest guest, {
    required String name,
    String? description,
    required bool includeMemoryState,
  }) async {
    final Object? response = await session.postForm(
      'nodes/${guest.node}/${guest.resourceSegment}/${guest.vmid}/snapshot',
      fields: <String, String>{
        'snapname': name,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
        if (includeMemoryState && guest.kind == GuestKind.virtualMachine)
          'vmstate': '1',
      },
    );
    return _taskReference(
      response,
      node: guest.node,
      operationLabel: 'Create snapshot',
    );
  }

  @override
  Future<ProxmoxTaskReference> rollbackSnapshot(
    ProxmoxSession session,
    PveGuest guest,
    PveGuestSnapshot snapshot,
  ) async {
    final String snapshotName = _safeSnapshotName(snapshot);
    final Object? response = await session.postForm(
      'nodes/${guest.node}/${guest.resourceSegment}/${guest.vmid}/snapshot/'
      '$snapshotName/rollback',
      fields: const <String, String>{},
    );
    return _taskReference(
      response,
      node: guest.node,
      operationLabel: 'Rollback snapshot',
    );
  }

  @override
  Future<ProxmoxTaskReference> deleteSnapshot(
    ProxmoxSession session,
    PveGuest guest,
    PveGuestSnapshot snapshot,
  ) async {
    final String snapshotName = _safeSnapshotName(snapshot);
    final ProxmoxWritableSession writable = _writableSession(session);
    final Object? response = await writable.deleteResource(
      'nodes/${guest.node}/${guest.resourceSegment}/${guest.vmid}/snapshot/'
      '$snapshotName',
    );
    return _taskReference(
      response,
      node: guest.node,
      operationLabel: 'Delete snapshot',
    );
  }

  @override
  Future<ProxmoxTaskReference> createBackup(
    ProxmoxSession session,
    PveGuest guest,
    PveGuestBackupRequest request,
  ) async {
    final Object? response = await session.postForm(
      'nodes/${guest.node}/vzdump',
      fields: <String, String>{
        'vmid': '${guest.vmid}',
        'storage': request.storage,
        'mode': request.mode.name,
        'compress': request.compression,
      },
    );
    return _taskReference(
      response,
      node: guest.node,
      operationLabel: 'Run backup',
    );
  }

  @override
  Future<void> updateConfiguration(
    ProxmoxSession session,
    PveGuest guest,
    PveGuestConfigurationChange change,
  ) async {
    if (change.isEmpty) {
      return;
    }
    final ProxmoxWritableSession writable = _writableSession(session);
    await writable.putForm(
      'nodes/${guest.node}/${guest.resourceSegment}/${guest.vmid}/config',
      fields: change.toFormFields(),
    );
  }

  Future<Object?> _loadOptional(
    ProxmoxSession session,
    String resource, {
    Map<String, String> query = const <String, String>{},
  }) async {
    try {
      return await session.getData(resource, query: query);
    } on ProxmoxUnauthorizedException {
      return null;
    } on ProxmoxResponseException catch (error) {
      if (error.statusCode == 403 ||
          error.statusCode == 404 ||
          error.statusCode == 501) {
        return null;
      }
      rethrow;
    }
  }

  PveGuestRuntime _decodeRuntime(Object? value, PveGuest guest) {
    if (value is! Map<Object?, Object?>) {
      return PveGuestRuntime.fromGuest(guest);
    }
    return PveGuestRuntime(
      status: _string(value['status']) ?? guest.status,
      cpuFraction: _double(value['cpu']) ?? guest.cpuFraction,
      cpuCores: _integer(value['cpus']) ?? guest.cpuCores,
      memoryBytes: _integer(value['mem']) ?? guest.memoryBytes,
      memoryLimitBytes: _integer(value['maxmem']) ?? guest.memoryLimitBytes,
      diskBytes: _integer(value['disk']) ?? guest.diskBytes,
      diskLimitBytes: _integer(value['maxdisk']) ?? guest.diskLimitBytes,
      uptimeSeconds: _integer(value['uptime']) ?? guest.uptimeSeconds,
    );
  }

  List<PveGuestSnapshot> _decodeSnapshots(Object? value) {
    if (value is! List<Object?>) {
      return const <PveGuestSnapshot>[];
    }
    return value
        .whereType<Map<Object?, Object?>>()
        .map((Map<Object?, Object?> snapshot) {
          final String? name = _string(snapshot['name']);
          if (name == null) {
            return null;
          }
          return PveGuestSnapshot(
            name: name,
            createdAt: _date(snapshot['snaptime']),
            description: _string(snapshot['description']),
            isCurrent: snapshot['current'] == 1 || snapshot['current'] == true,
            includesMemoryState:
                snapshot['vmstate'] == 1 || snapshot['vmstate'] == true,
          );
        })
        .whereType<PveGuestSnapshot>()
        .where((PveGuestSnapshot snapshot) => !snapshot.isCurrent)
        .toList(growable: false);
  }

  List<PveGuestTask> _decodeTasks(Object? value) {
    if (value is! List<Object?>) {
      return const <PveGuestTask>[];
    }
    return value
        .whereType<Map<Object?, Object?>>()
        .map((Map<Object?, Object?> task) {
          final String? upid = _string(task['upid']);
          final String? type = _string(task['type']);
          if (upid == null || type == null) {
            return null;
          }
          final String? status = _string(task['status']);
          final DateTime? endedAt = _date(task['endtime']);
          return PveGuestTask(
            upid: upid,
            type: type,
            state: _taskState(status: status, endedAt: endedAt),
            status: status,
            startedAt: _date(task['starttime']),
            endedAt: endedAt,
          );
        })
        .whereType<PveGuestTask>()
        .toList(growable: false);
  }

  PveGuestTaskState _taskState({
    required String? status,
    required DateTime? endedAt,
  }) {
    final String normalized = status?.trim().toLowerCase() ?? '';
    if (endedAt == null &&
        (normalized.isEmpty ||
            normalized == 'running' ||
            normalized == 'in progress')) {
      return PveGuestTaskState.running;
    }
    if (normalized == 'ok' ||
        normalized == 'success' ||
        normalized == 'successful') {
      return PveGuestTaskState.successful;
    }
    if (normalized.isEmpty) {
      return PveGuestTaskState.unknown;
    }
    return PveGuestTaskState.failed;
  }

  ProxmoxWritableSession _writableSession(ProxmoxSession session) {
    if (session is ProxmoxWritableSession) {
      return session;
    }
    throw const ProxmoxResponseException(
      statusCode: 501,
      message: 'This connection does not support configuration changes.',
    );
  }

  ProxmoxTaskReference _taskReference(
    Object? response, {
    required String node,
    required String operationLabel,
  }) {
    return ProxmoxTaskReference.fromResponse(
      response: response,
      node: node,
      operationLabel: operationLabel,
    );
  }

  ProxmoxTaskReference? _taskReferenceOrNull(
    Object? response, {
    required String node,
    required String operationLabel,
  }) {
    if (response is! String || response.trim().isEmpty) {
      return null;
    }
    return _taskReference(response, node: node, operationLabel: operationLabel);
  }

  String _safeSnapshotName(PveGuestSnapshot snapshot) {
    final PveGuestSnapshotRequest request = PveGuestSnapshotRequest(
      name: snapshot.name,
    );
    if (!request.hasValidName) {
      throw const ProxmoxResponseException(
        statusCode: 400,
        message: 'The reported snapshot name is not safe to operate on.',
      );
    }
    return request.normalizedName;
  }

  String? _string(Object? value) {
    return value is String && value.trim().isNotEmpty ? value : null;
  }

  int? _integer(Object? value) => value is num ? value.toInt() : null;

  double? _double(Object? value) => value is num ? value.toDouble() : null;

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
