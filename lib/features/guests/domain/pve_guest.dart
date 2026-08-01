enum GuestKind { virtualMachine, container }

enum GuestPowerAction {
  start('start', 'Start'),
  shutdown('shutdown', 'Shut down'),
  reboot('reboot', 'Reboot');

  const GuestPowerAction(this.apiPathSegment, this.label);

  final String apiPathSegment;
  final String label;

  bool get isPotentiallyDisruptive => this != GuestPowerAction.start;
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

class PveGuestDetails {
  const PveGuestDetails({required this.guest, required this.configuration});

  final PveGuest guest;
  final Map<String, String> configuration;
}
