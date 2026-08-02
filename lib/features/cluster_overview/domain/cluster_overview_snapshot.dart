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
    this.resources = const <ClusterStorageResource>[],
  });

  final String name;
  final String type;
  final String content;
  final bool shared;
  final List<ClusterStorageResource> resources;

  Iterable<ClusterStorageResource> get resourcesWithCapacity => resources.where(
    (ClusterStorageResource resource) => resource.hasCapacity,
  );

  int get reportedNodeCount => resources.length;

  int get reportedAvailabilityNodeCount => resources
      .where(
        (ClusterStorageResource resource) => resource.hasAvailabilityStatus,
      )
      .length;

  int get availableNodeCount => resources
      .where(
        (ClusterStorageResource resource) =>
            resource.hasAvailabilityStatus && resource.isAvailable,
      )
      .length;

  int? get usedBytes => _aggregateResourceBytes(
    (ClusterStorageResource resource) => resource.usedBytes,
  );

  int? get capacityBytes => _aggregateResourceBytes(
    (ClusterStorageResource resource) => resource.capacityBytes,
  );

  int? get availableBytes {
    final int? capacity = capacityBytes;
    final int? used = usedBytes;
    if (capacity == null || used == null) {
      return null;
    }
    return (capacity - used).clamp(0, capacity);
  }

  double? get usageFraction {
    final int? capacity = capacityBytes;
    final int? used = usedBytes;
    if (capacity == null || capacity <= 0 || used == null) {
      return null;
    }
    return used / capacity;
  }

  bool get hasAvailabilityTelemetry => reportedAvailabilityNodeCount > 0;

  bool get isAvailable => availableNodeCount > 0;

  bool get isFullyAvailable =>
      hasAvailabilityTelemetry &&
      availableNodeCount == reportedAvailabilityNodeCount;

  bool get isPartiallyAvailable => isAvailable && !isFullyAvailable;

  int? _aggregateResourceBytes(
    int? Function(ClusterStorageResource resource) selector,
  ) {
    final List<int> values = resourcesWithCapacity
        .map(selector)
        .whereType<int>()
        .toList(growable: false);
    if (values.isEmpty) {
      return null;
    }
    if (shared) {
      return values.reduce(
        (int left, int right) => left > right ? left : right,
      );
    }
    return values.fold<int>(0, (int total, int value) => total + value);
  }
}

class ClusterStorageResource {
  const ClusterStorageResource({
    required this.node,
    required this.status,
    this.usedBytes,
    this.capacityBytes,
  });

  final String node;
  final String status;
  final int? usedBytes;
  final int? capacityBytes;

  bool get hasAvailabilityStatus => status.trim().isNotEmpty;

  bool get isAvailable {
    final String normalizedStatus = status.trim().toLowerCase();
    return normalizedStatus == 'available' || normalizedStatus == 'active';
  }

  bool get hasCapacity =>
      usedBytes != null &&
      usedBytes! >= 0 &&
      capacityBytes != null &&
      capacityBytes! > 0;
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
    final String normalisedStatus = status?.trim().toLowerCase() ?? '';
    if (endedAt == null &&
        (normalisedStatus.isEmpty ||
            normalisedStatus == 'running' ||
            normalisedStatus == 'in progress')) {
      return ClusterTaskState.running;
    }
    if (normalisedStatus == 'ok' ||
        normalisedStatus == 'success' ||
        normalisedStatus == 'successful') {
      return ClusterTaskState.successful;
    }
    if (normalisedStatus.isEmpty) {
      return ClusterTaskState.unknown;
    }
    return ClusterTaskState.failed;
  }

  bool get isRunning => state == ClusterTaskState.running;

  /// A running non-interactive operation is surfaced more prominently after
  /// this age. Interactive console sessions are deliberately excluded.
  bool get isLongRunning {
    final DateTime? startedAt = this.startedAt;
    if (!isRunning || isInteractiveSession || startedAt == null) return false;
    return DateTime.now().difference(startedAt) >= const Duration(minutes: 30);
  }

  /// Proxmox reports interactive connections as long-running tasks. They are
  /// sessions, not necessarily work that needs an operator's attention.
  bool get isInteractiveSession {
    final String normalizedType = type.trim().toLowerCase();
    return normalizedType.contains('console') ||
        normalizedType.contains('vnc') ||
        normalizedType.contains('shell') ||
        normalizedType.contains('termproxy');
  }

  /// Returns a guest ID only when the server-provided UPID contains one in
  /// its documented worker-id position. A task type alone is not enough to
  /// attribute work to a guest.
  int? get guestVmid {
    final List<String> parts = upid.split(':');
    if (parts.length < 8 || parts.first != 'UPID') {
      return null;
    }
    return int.tryParse(parts[6]);
  }
}

int compareClusterTasksByRecency(ClusterTask left, ClusterTask right) {
  final DateTime? leftTime = left.startedAt;
  final DateTime? rightTime = right.startedAt;
  if (leftTime == null && rightTime == null) {
    return left.upid.compareTo(right.upid);
  }
  if (leftTime == null) {
    return 1;
  }
  if (rightTime == null) {
    return -1;
  }
  final int timeComparison = rightTime.compareTo(leftTime);
  return timeComparison != 0 ? timeComparison : left.upid.compareTo(right.upid);
}
