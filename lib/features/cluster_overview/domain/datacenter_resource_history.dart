import 'cluster_overview_snapshot.dart';

/// A locally observed aggregate, captured only when the user refreshes the
/// datacenter. This is deliberately not a monitoring history: samples are
/// held in memory for the current app session and discarded on sign-out.
class DatacenterResourceSample {
  const DatacenterResourceSample({
    required this.capturedAt,
    required this.cpuFraction,
    required this.memoryFraction,
    required this.diskFraction,
    required this.storageFraction,
  });

  factory DatacenterResourceSample.fromSnapshot(
    ClusterOverviewSnapshot snapshot, {
    required DateTime capturedAt,
  }) {
    return DatacenterResourceSample(
      capturedAt: capturedAt,
      cpuFraction: _average(
        snapshot.nodes.map((ClusterNode node) => node.cpuFraction),
      ),
      memoryFraction: _ratioForNodes(
        snapshot.nodes,
        (ClusterNode node) => node.memoryBytes,
        (ClusterNode node) => node.memoryLimitBytes,
      ),
      diskFraction: _ratioForNodes(
        snapshot.nodes,
        (ClusterNode node) => node.diskBytes,
        (ClusterNode node) => node.diskLimitBytes,
      ),
      storageFraction: _ratioForStorages(snapshot.storages),
    );
  }

  final DateTime capturedAt;
  final double? cpuFraction;
  final double? memoryFraction;
  final double? diskFraction;
  final double? storageFraction;

  static double? _average(Iterable<double?> values) {
    final reported = values.whereType<double>().toList(growable: false);
    if (reported.isEmpty) return null;
    return reported.reduce((double total, double value) => total + value) /
        reported.length;
  }

  static double? _ratio(int used, int capacity) {
    if (capacity <= 0) return null;
    return used / capacity;
  }

  static double? _ratioForNodes(
    Iterable<ClusterNode> nodes,
    int? Function(ClusterNode node) used,
    int? Function(ClusterNode node) capacity,
  ) {
    var reportedUsage = 0;
    var reportedCapacity = 0;
    var hasReportedPair = false;
    for (final node in nodes) {
      final nodeUsage = used(node);
      final nodeCapacity = capacity(node);
      if (nodeUsage == null || nodeCapacity == null || nodeCapacity <= 0) {
        continue;
      }
      hasReportedPair = true;
      reportedUsage += nodeUsage;
      reportedCapacity += nodeCapacity;
    }
    return hasReportedPair ? _ratio(reportedUsage, reportedCapacity) : null;
  }

  static double? _ratioForStorages(Iterable<ClusterStorage> storages) {
    var reportedUsage = 0;
    var reportedCapacity = 0;
    var hasReportedPair = false;
    for (final storage in storages) {
      final storageUsage = storage.usedBytes;
      final storageCapacity = storage.capacityBytes;
      if (storageUsage == null ||
          storageCapacity == null ||
          storageCapacity <= 0) {
        continue;
      }
      hasReportedPair = true;
      reportedUsage += storageUsage;
      reportedCapacity += storageCapacity;
    }
    return hasReportedPair ? _ratio(reportedUsage, reportedCapacity) : null;
  }
}
