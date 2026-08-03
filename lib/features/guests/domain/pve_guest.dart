enum GuestKind { virtualMachine, container }

enum GuestPowerAction {
  start('start', 'Start'),
  shutdown('shutdown', 'Shut down'),
  reboot('reboot', 'Restart'),
  stop('stop', 'Force Stop'),
  reset('reset', 'Reset');

  const GuestPowerAction(this.apiPathSegment, this.label);

  final String apiPathSegment;
  final String label;

  bool get isPotentiallyDisruptive => this != GuestPowerAction.start;

  bool get isForceful =>
      this == GuestPowerAction.stop || this == GuestPowerAction.reset;

  bool supports(PveGuest guest) =>
      this != GuestPowerAction.reset || guest.kind == GuestKind.virtualMachine;
}

class PveGuest {
  const PveGuest({
    required this.vmid,
    required this.node,
    required this.kind,
    required this.status,
    this.name,
    this.cpuFraction,
    this.cpuCores,
    this.memoryBytes,
    this.memoryLimitBytes,
    this.diskBytes,
    this.diskLimitBytes,
    this.uptimeSeconds,
    this.isTemplate = false,
  });

  final int vmid;
  final String node;
  final GuestKind kind;
  final String status;
  final String? name;
  final double? cpuFraction;
  final int? cpuCores;
  final int? memoryBytes;
  final int? memoryLimitBytes;
  final int? diskBytes;
  final int? diskLimitBytes;
  final int? uptimeSeconds;
  final bool isTemplate;

  String get title => name?.isNotEmpty == true ? name! : '${kind.label} $vmid';

  String get resourceSegment => switch (kind) {
    GuestKind.virtualMachine => 'qemu',
    GuestKind.container => 'lxc',
  };

  bool get isRunning => status.toLowerCase() == 'running';
}

extension GuestKindLabel on GuestKind {
  String get label => switch (this) {
    GuestKind.virtualMachine => 'Virtual machine',
    GuestKind.container => 'Container',
  };

  String get shortLabel => switch (this) {
    GuestKind.virtualMachine => 'VM',
    GuestKind.container => 'LXC',
  };
}

class PveGuestRuntime {
  const PveGuestRuntime({
    required this.status,
    this.cpuFraction,
    this.cpuCores,
    this.memoryBytes,
    this.memoryLimitBytes,
    this.diskBytes,
    this.diskLimitBytes,
    this.uptimeSeconds,
  });

  factory PveGuestRuntime.fromGuest(PveGuest guest) => PveGuestRuntime(
    status: guest.status,
    cpuFraction: guest.cpuFraction,
    cpuCores: guest.cpuCores,
    memoryBytes: guest.memoryBytes,
    memoryLimitBytes: guest.memoryLimitBytes,
    diskBytes: guest.diskBytes,
    diskLimitBytes: guest.diskLimitBytes,
    uptimeSeconds: guest.uptimeSeconds,
  );

  final String status;
  final double? cpuFraction;
  final int? cpuCores;
  final int? memoryBytes;
  final int? memoryLimitBytes;
  final int? diskBytes;
  final int? diskLimitBytes;
  final int? uptimeSeconds;

  bool get isRunning => status.toLowerCase() == 'running';
}

class PveGuestSnapshot {
  const PveGuestSnapshot({
    required this.name,
    required this.createdAt,
    this.description,
    this.isCurrent = false,
    this.includesMemoryState = false,
  });

  final String name;
  final DateTime? createdAt;
  final String? description;
  final bool isCurrent;
  final bool includesMemoryState;
}

/// The narrow set of snapshot options that are safe to expose from the
/// companion. Disk inclusion and retention are intentionally owned by the
/// guest's Proxmox configuration rather than duplicated in the client.
class PveGuestSnapshotRequest {
  const PveGuestSnapshotRequest({
    required this.name,
    this.description,
    this.includeMemoryState = false,
  });

  final String name;
  final String? description;
  final bool includeMemoryState;

  String get normalizedName => name.trim();

  String? get normalizedDescription {
    final value = description?.trim() ?? '';
    return value.isEmpty ? null : value;
  }

  /// Proxmox snapshot names are simple identifiers. Validating here makes an
  /// accidental space or shell-like input an immediately understandable form
  /// error instead of a remote API failure.
  String? get validationMessage {
    final loweredName = normalizedName.toLowerCase();
    if (!RegExp(
      r'^[A-Za-z0-9][A-Za-z0-9._-]{0,39}$',
    ).hasMatch(normalizedName)) {
      return 'Use 1–40 letters, numbers, dots, dashes, or underscores.';
    }
    if (loweredName == 'current' || loweredName == 'vzdump') {
      return '“current” and “vzdump” are reserved Proxmox snapshot names.';
    }
    return null;
  }

  bool get hasValidName => validationMessage == null;
}

enum PveGuestTaskState { running, successful, failed, unknown }

class PveGuestTask {
  const PveGuestTask({
    required this.upid,
    required this.type,
    required this.state,
    this.status,
    this.startedAt,
    this.endedAt,
  });

  final String upid;
  final String type;
  final PveGuestTaskState state;
  final String? status;
  final DateTime? startedAt;
  final DateTime? endedAt;
}

enum PveGuestBackupMode { snapshot, suspend, stop }

extension PveGuestBackupModeLabel on PveGuestBackupMode {
  String get label => switch (this) {
    PveGuestBackupMode.snapshot => 'Snapshot',
    PveGuestBackupMode.suspend => 'Suspend',
    PveGuestBackupMode.stop => 'Stop',
  };
}

class PveGuestBackupRequest {
  const PveGuestBackupRequest({
    required this.storage,
    this.mode = PveGuestBackupMode.snapshot,
    this.compression = 'zstd',
  });

  final String storage;
  final PveGuestBackupMode mode;
  final String compression;
}

class PveGuestConfigurationChange {
  const PveGuestConfigurationChange({
    this.cores,
    this.memoryMiB,
    this.onBoot,
    this.description,
  });

  final int? cores;
  final int? memoryMiB;
  final bool? onBoot;
  final String? description;

  bool get isEmpty =>
      cores == null &&
      memoryMiB == null &&
      onBoot == null &&
      description == null;

  Map<String, String> toFormFields() => <String, String>{
    if (cores != null) 'cores': '$cores',
    if (memoryMiB != null) 'memory': '$memoryMiB',
    if (onBoot != null) 'onboot': onBoot! ? '1' : '0',
    'description': ?description,
  };
}

class PveGuestDetails {
  const PveGuestDetails({
    required this.guest,
    required this.configuration,
    required this.runtime,
    this.snapshots = const <PveGuestSnapshot>[],
    this.recentTasks = const <PveGuestTask>[],
  });

  final PveGuest guest;
  final Map<String, String> configuration;
  final PveGuestRuntime runtime;
  final List<PveGuestSnapshot> snapshots;
  final List<PveGuestTask> recentTasks;
}
