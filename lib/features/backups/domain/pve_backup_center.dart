import '../../cluster_overview/domain/cluster_overview_snapshot.dart';

class PveBackupDestination {
  const PveBackupDestination({required this.storage});

  final ClusterStorage storage;

  String get name => storage.name;

  bool get isAvailable => storage.isAvailable;

  int? get usedBytes => storage.usedBytes;

  int? get capacityBytes => storage.capacityBytes;

  double? get usageFraction => storage.usageFraction;
}

class PveBackupSchedule {
  const PveBackupSchedule({
    required this.id,
    this.storage,
    this.schedule,
    this.enabled,
    this.guestSelection,
  });

  final String id;
  final String? storage;
  final String? schedule;
  final bool? enabled;
  final String? guestSelection;
}

class PveBackupRecord {
  const PveBackupRecord({
    required this.volumeId,
    required this.storage,
    required this.node,
    this.guestId,
    this.createdAt,
    this.sizeBytes,
    this.format,
    this.notes,
    this.protected = false,
  });

  final String volumeId;
  final String storage;
  final String node;
  final int? guestId;
  final DateTime? createdAt;
  final int? sizeBytes;
  final String? format;
  final String? notes;
  final bool protected;
}

class PveBackupCenterSnapshot {
  const PveBackupCenterSnapshot({
    required this.destinations,
    required this.schedules,
    required this.records,
    required this.recentTasks,
    this.scheduleDataState = PveBackupDataState.available,
    this.recordDataState = PveBackupDataState.available,
  });

  final List<PveBackupDestination> destinations;
  final List<PveBackupSchedule> schedules;
  final List<PveBackupRecord> records;
  final List<ClusterTask> recentTasks;
  final PveBackupDataState scheduleDataState;
  final PveBackupDataState recordDataState;

  int get failedRecentTaskCount => recentTasks
      .where((ClusterTask task) => task.state == ClusterTaskState.failed)
      .length;

  PveBackupReadiness get readiness {
    if (destinations.isEmpty) return PveBackupReadiness.noDestination;
    if (scheduleDataState == PveBackupDataState.permissionLimited) {
      return PveBackupReadiness.configurationUnreadable;
    }
    if (scheduleDataState == PveBackupDataState.unavailable ||
        scheduleDataState == PveBackupDataState.partiallyAvailable) {
      return PveBackupReadiness.configurationUnavailable;
    }
    if (schedules.isEmpty &&
        scheduleDataState == PveBackupDataState.available) {
      return PveBackupReadiness.noSchedule;
    }
    if (recordDataState == PveBackupDataState.permissionLimited) {
      return PveBackupReadiness.copiesUnreadable;
    }
    if (recordDataState == PveBackupDataState.unavailable) {
      return PveBackupReadiness.copiesUnavailable;
    }
    if (recordDataState == PveBackupDataState.partiallyAvailable) {
      return PveBackupReadiness.copiesPartiallyReported;
    }
    if (records.isNotEmpty) return PveBackupReadiness.copiesReported;
    return PveBackupReadiness.copiesNotReported;
  }
}

enum PveBackupDataState {
  available,
  partiallyAvailable,
  unavailable,
  permissionLimited,
  notConfigured,
}

/// A concise statement of what Backup Center can verify from currently
/// reported data. It intentionally does not make a restore-readiness claim.
enum PveBackupReadiness {
  noDestination,
  configurationUnreadable,
  configurationUnavailable,
  noSchedule,
  copiesUnreadable,
  copiesUnavailable,
  copiesPartiallyReported,
  copiesReported,
  copiesNotReported,
}
