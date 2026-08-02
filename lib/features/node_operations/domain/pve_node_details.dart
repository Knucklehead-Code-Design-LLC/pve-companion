import '../../cluster_overview/domain/cluster_overview_snapshot.dart';

/// The overview data used to open an operational node detail surface.
class PveNodeDetailsSeed {
  const PveNodeDetailsSeed(this.node);

  final ClusterNode node;
}

enum PveNodePowerAction {
  reboot('reboot', 'Restart Node'),
  shutdown('shutdown', 'Shut Down Node');

  const PveNodePowerAction(this.apiCommand, this.label);

  final String apiCommand;
  final String label;
}

class PveNodeService {
  const PveNodeService({
    required this.name,
    required this.state,
    this.description,
  });

  final String name;
  final String state;
  final String? description;

  bool get isRunning => state.trim().toLowerCase() == 'running';
}

class PveNodePackageUpdate {
  const PveNodePackageUpdate({
    required this.packageName,
    this.installedVersion,
    this.availableVersion,
    this.title,
  });

  final String packageName;
  final String? installedVersion;
  final String? availableVersion;
  final String? title;
}

class PveNodeDetails {
  const PveNodeDetails({
    required this.node,
    this.pveVersion,
    this.kernelVersion,
    this.cpuModel,
    this.loadAverages = const <double>[],
    this.services = const <PveNodeService>[],
    this.availablePackageUpdates = const <PveNodePackageUpdate>[],
  });

  final ClusterNode node;
  final String? pveVersion;
  final String? kernelVersion;
  final String? cpuModel;
  final List<double> loadAverages;
  final List<PveNodeService> services;
  final List<PveNodePackageUpdate> availablePackageUpdates;

  int get stoppedServiceCount =>
      services.where((PveNodeService service) => !service.isRunning).length;
}
