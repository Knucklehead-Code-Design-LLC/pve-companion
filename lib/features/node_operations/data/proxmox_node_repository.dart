import '../../../core/api/proxmox_api_exception.dart';
import '../../../core/api/proxmox_session.dart';
import '../../../core/api/proxmox_task.dart';
import '../domain/pve_node_details.dart';

abstract interface class PveNodeRepository {
  Future<PveNodeDetails> loadDetails(
    ProxmoxSession session,
    PveNodeDetailsSeed seed,
  );

  Future<ProxmoxTaskReference> runPowerAction(
    ProxmoxSession session,
    PveNodeDetailsSeed seed,
    PveNodePowerAction action,
  );

  Future<ProxmoxTaskReference> restartService(
    ProxmoxSession session,
    PveNodeDetailsSeed seed,
    PveNodeService service,
  );

  Future<ProxmoxTaskReference> refreshPackageIndex(
    ProxmoxSession session,
    PveNodeDetailsSeed seed,
  );
}

class ProxmoxNodeRepository implements PveNodeRepository {
  @override
  Future<PveNodeDetails> loadDetails(
    ProxmoxSession session,
    PveNodeDetailsSeed seed,
  ) async {
    final String node = seed.node.name;
    final List<Object?> results = await Future.wait<Object?>(<Future<Object?>>[
      _loadOptional(session, 'nodes/$node/status'),
      _loadOptional(session, 'nodes/$node/services'),
      _loadOptional(session, 'nodes/$node/apt/update'),
    ]);
    final Map<Object?, Object?>? status = _map(results[0]);
    return PveNodeDetails(
      node: seed.node,
      pveVersion: _string(status?['pveversion']),
      kernelVersion: _string(status?['kversion']),
      cpuModel: _cpuModel(status?['cpuinfo']),
      loadAverages: _loadAverages(status?['loadavg']),
      services: _decodeServices(results[1]),
      availablePackageUpdates: _decodePackageUpdates(results[2]),
    );
  }

  @override
  Future<ProxmoxTaskReference> runPowerAction(
    ProxmoxSession session,
    PveNodeDetailsSeed seed,
    PveNodePowerAction action,
  ) async {
    final Object? response = await session.postForm(
      'nodes/${seed.node.name}/status',
      fields: <String, String>{'command': action.apiCommand},
    );
    return _task(response, seed.node.name, action.label);
  }

  @override
  Future<ProxmoxTaskReference> restartService(
    ProxmoxSession session,
    PveNodeDetailsSeed seed,
    PveNodeService service,
  ) async {
    if (!RegExp(r'^[A-Za-z0-9@_.-]+$').hasMatch(service.name)) {
      throw const ProxmoxResponseException(
        statusCode: 400,
        message: 'The reported service name is not safe to restart.',
      );
    }
    final Object? response = await session.postForm(
      'nodes/${seed.node.name}/services/${service.name}/restart',
      fields: const <String, String>{},
    );
    return _task(response, seed.node.name, 'Restart ${service.name}');
  }

  @override
  Future<ProxmoxTaskReference> refreshPackageIndex(
    ProxmoxSession session,
    PveNodeDetailsSeed seed,
  ) async {
    final Object? response = await session.postForm(
      'nodes/${seed.node.name}/apt/update',
      fields: const <String, String>{},
    );
    return _task(response, seed.node.name, 'Refresh package index');
  }

  Future<Object?> _loadOptional(ProxmoxSession session, String resource) async {
    try {
      return await session.getData(resource);
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

  ProxmoxTaskReference _task(
    Object? response,
    String node,
    String operationLabel,
  ) => ProxmoxTaskReference.fromResponse(
    response: response,
    node: node,
    operationLabel: operationLabel,
  );

  Map<Object?, Object?>? _map(Object? value) =>
      value is Map<Object?, Object?> ? value : null;

  String? _string(Object? value) =>
      value is String && value.trim().isNotEmpty ? value : null;

  String? _cpuModel(Object? value) {
    if (value is! Map<Object?, Object?>) {
      return null;
    }
    return _string(value['model']) ?? _string(value['cputype']);
  }

  List<double> _loadAverages(Object? value) {
    if (value is! List<Object?>) {
      return const <double>[];
    }
    return value
        .whereType<num>()
        .map((num average) => average.toDouble())
        .toList(growable: false);
  }

  List<PveNodeService> _decodeServices(Object? value) {
    if (value is! List<Object?>) {
      return const <PveNodeService>[];
    }
    return value
        .whereType<Map<Object?, Object?>>()
        .map((Map<Object?, Object?> item) {
          final String? name =
              _string(item['service']) ?? _string(item['name']);
          final String? state = _string(item['state']);
          if (name == null || state == null) {
            return null;
          }
          return PveNodeService(
            name: name,
            state: state,
            description: _string(item['desc']) ?? _string(item['description']),
          );
        })
        .whereType<PveNodeService>()
        .toList(growable: false);
  }

  List<PveNodePackageUpdate> _decodePackageUpdates(Object? value) {
    if (value is! List<Object?>) {
      return const <PveNodePackageUpdate>[];
    }
    return value
        .whereType<Map<Object?, Object?>>()
        .map((Map<Object?, Object?> item) {
          final String? packageName =
              _string(item['Package']) ?? _string(item['package']);
          if (packageName == null) {
            return null;
          }
          return PveNodePackageUpdate(
            packageName: packageName,
            installedVersion:
                _string(item['OldVersion']) ?? _string(item['oldversion']),
            availableVersion:
                _string(item['Version']) ?? _string(item['version']),
            title: _string(item['Title']) ?? _string(item['title']),
          );
        })
        .whereType<PveNodePackageUpdate>()
        .toList(growable: false);
  }
}
