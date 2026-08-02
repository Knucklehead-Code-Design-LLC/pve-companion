import '../../cluster_overview/domain/cluster_overview_snapshot.dart';

class PveClusterMember {
  const PveClusterMember({
    required this.name,
    required this.type,
    this.nodeId,
    this.online,
    this.local = false,
    this.address,
  });

  final String name;
  final String type;
  final int? nodeId;
  final bool? online;
  final bool local;
  final String? address;
}

class PveClusterStatus {
  const PveClusterStatus({
    required this.members,
    this.name,
    this.quorate,
    this.version,
  });

  final String? name;
  final bool? quorate;
  final int? version;
  final List<PveClusterMember> members;
}

class PveHaResourceStatus {
  const PveHaResourceStatus({
    required this.service,
    required this.state,
    this.node,
    this.status,
  });

  final String service;
  final String state;
  final String? node;
  final String? status;
}

class PveClusterAdministrationSnapshot {
  const PveClusterAdministrationSnapshot({
    required this.overview,
    required this.clusterStatus,
    required this.options,
    required this.haResources,
  });

  final ClusterOverviewSnapshot overview;
  final PveClusterStatus? clusterStatus;
  final Map<String, String> options;
  final List<PveHaResourceStatus> haResources;
}
