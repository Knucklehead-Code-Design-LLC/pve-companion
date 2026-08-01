import '../../guests/domain/pve_guest.dart';

class ClusterOverviewSnapshot {
  const ClusterOverviewSnapshot({
    required this.version,
    required this.nodes,
    required this.guests,
    required this.storages,
    required this.tasks,
  });

  final PveVersion version;
  final List<ClusterNode> nodes;
  final List<PveGuest> guests;
  final List<ClusterStorage> storages;
  final List<ClusterTask> tasks;

  int get runningGuestCount => guests
      .where((PveGuest guest) => guest.status.toLowerCase() == 'running')
      .length;
}

class PveVersion {
  const PveVersion({required this.version, this.release});

  final String version;
  final String? release;
}

class ClusterNode {
  const ClusterNode({
    required this.name,
    required this.status,
    this.cpuFraction,
    this.cpuCores,
    this.memoryBytes,
    this.memoryLimitBytes,
    this.diskBytes,
    this.diskLimitBytes,
    this.uptimeSeconds,
  });

  final String name;
  final String status;
  final double? cpuFraction;
  final int? cpuCores;
  final int? memoryBytes;
  final int? memoryLimitBytes;
  final int? diskBytes;
  final int? diskLimitBytes;
  final int? uptimeSeconds;

  bool get isOnline => status.toLowerCase() == 'online';
}

class ClusterStorage {
  const ClusterStorage({
    required this.name,
    required this.type,
    required this.content,
    required this.shared,
  });

  final String name;
  final String type;
  final String content;
  final bool shared;
}

enum ClusterTaskState { running, successful, failed, unknown }

class ClusterTask {
  const ClusterTask({
    required this.upid,
    required this.node,
    required this.type,
    required this.user,
    this.status,
    this.startedAt,
    this.endedAt,
  });

  final String upid;
  final String node;
  final String type;
  final String user;
  final String? status;
  final DateTime? startedAt;
  final DateTime? endedAt;

  ClusterTaskState get state {
    if (endedAt == null) {
      return ClusterTaskState.running;
    }
    final String normalisedStatus = status?.trim().toLowerCase() ?? '';
    if (normalisedStatus.isEmpty) {
      return ClusterTaskState.unknown;
    }
    if (normalisedStatus == 'ok' ||
        normalisedStatus == 'success' ||
        normalisedStatus == 'successful') {
      return ClusterTaskState.successful;
    }
    return ClusterTaskState.failed;
  }

  bool get isRunning => state == ClusterTaskState.running;
}
