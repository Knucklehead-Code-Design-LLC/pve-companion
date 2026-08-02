import '../../../core/api/proxmox_api_exception.dart';
import '../../../core/api/proxmox_session.dart';
import '../../cluster_overview/domain/cluster_overview_snapshot.dart';
import '../domain/pve_cluster_administration.dart';

abstract interface class PveClusterAdministrationRepository {
  Future<PveClusterAdministrationSnapshot> load(
    ProxmoxSession session,
    ClusterOverviewSnapshot overview,
  );
}

class ProxmoxClusterAdministrationRepository
    implements PveClusterAdministrationRepository {
  static const Set<String> _visibleOptionKeys = <String>{
    'console',
    'keyboard',
    'language',
    'max_workers',
    'migration',
  };

  @override
  Future<PveClusterAdministrationSnapshot> load(
    ProxmoxSession session,
    ClusterOverviewSnapshot overview,
  ) async {
    final List<Object?> results = await Future.wait<Object?>(<Future<Object?>>[
      _loadOptional(session, 'cluster/status'),
      _loadOptional(session, 'cluster/options'),
      _loadOptional(session, 'cluster/ha/status/current'),
    ]);
    return PveClusterAdministrationSnapshot(
      overview: overview,
      clusterStatus: _decodeStatus(results[0]),
      options: Map<String, String>.unmodifiable(_decodeOptions(results[1])),
      haResources: List<PveHaResourceStatus>.unmodifiable(
        _decodeHaResources(results[2]),
      ),
    );
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

  PveClusterStatus? _decodeStatus(Object? value) {
    if (value is! List<Object?>) {
      return null;
    }
    String? name;
    bool? quorate;
    int? version;
    final List<PveClusterMember> members = <PveClusterMember>[];
    for (final Map<Object?, Object?> item
        in value.whereType<Map<Object?, Object?>>()) {
      final String? type = _string(item['type']);
      if (type == null) {
        continue;
      }
      if (type == 'cluster') {
        name = _string(item['name']) ?? name;
        quorate = _boolean(item['quorate']) ?? quorate;
        version = _integer(item['version']) ?? version;
        continue;
      }
      final String? memberName = _string(item['name']);
      if (memberName == null) {
        continue;
      }
      members.add(
        PveClusterMember(
          name: memberName,
          type: type,
          nodeId: _integer(item['nodeid']),
          online: _boolean(item['online']),
          local: _boolean(item['local']) ?? false,
          address: _string(item['ip']) ?? _string(item['address']),
        ),
      );
    }
    return PveClusterStatus(
      name: name,
      quorate: quorate,
      version: version,
      members: List<PveClusterMember>.unmodifiable(members),
    );
  }

  Map<String, String> _decodeOptions(Object? value) {
    if (value is! Map<Object?, Object?>) {
      return const <String, String>{};
    }
    final Map<String, String> options = <String, String>{};
    for (final MapEntry<Object?, Object?> entry in value.entries) {
      final String key = entry.key.toString();
      if (_visibleOptionKeys.contains(key) && entry.value != null) {
        options[key] = entry.value.toString();
      }
    }
    return options;
  }

  List<PveHaResourceStatus> _decodeHaResources(Object? value) {
    if (value is! List<Object?>) {
      return const <PveHaResourceStatus>[];
    }
    return value
        .whereType<Map<Object?, Object?>>()
        .map((Map<Object?, Object?> item) {
          final String? service =
              _string(item['sid']) ?? _string(item['service']);
          final String? state = _string(item['state']);
          if (service == null || state == null) {
            return null;
          }
          return PveHaResourceStatus(
            service: service,
            state: state,
            node: _string(item['node']),
            status: _string(item['status']),
          );
        })
        .whereType<PveHaResourceStatus>()
        .toList(growable: false);
  }

  String? _string(Object? value) =>
      value is String && value.trim().isNotEmpty ? value : null;

  int? _integer(Object? value) => value is num ? value.toInt() : null;

  bool? _boolean(Object? value) => switch (value) {
    true || 1 || '1' || 'true' => true,
    false || 0 || '0' || 'false' => false,
    _ => null,
  };
}
