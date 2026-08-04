/// A server-recorded aggregate for one point in the node RRD timeline.
///
/// CPU is the average of the reporting nodes. Memory and root disk are
/// calculated from their combined reported used and capacity values.
class DatacenterResourceSample {
  const DatacenterResourceSample({
    required this.recordedAt,
    required this.cpuFraction,
    required this.memoryFraction,
    required this.diskFraction,
  });

  final DateTime recordedAt;
  final double? cpuFraction;
  final double? memoryFraction;
  final double? diskFraction;

  bool get hasReportedMetric =>
      cpuFraction != null || memoryFraction != null || diskFraction != null;
}

enum DatacenterResourceHistoryUnavailableReason {
  noNodes,
  permissionDenied,
  unsupported,
  noData,
  requestFailed,
}

/// Historical node utilization read from Proxmox's RRD API.
///
/// The server can make this telemetry unavailable independently of the live
/// datacenter snapshot, so callers must preserve that distinction in the UI.
class DatacenterResourceHistory {
  DatacenterResourceHistory({
    required List<DatacenterResourceSample> samples,
    required this.requestedNodeCount,
    required this.reportingNodeCount,
  }) : assert(samples.isNotEmpty),
       assert(
         samples.any(
           (DatacenterResourceSample sample) => sample.hasReportedMetric,
         ),
       ),
       assert(requestedNodeCount > 0),
       assert(
         reportingNodeCount > 0 && reportingNodeCount <= requestedNodeCount,
       ),
       samples = List<DatacenterResourceSample>.unmodifiable(samples),
       unavailableReason = null;

  const DatacenterResourceHistory.unavailable({
    this.requestedNodeCount = 0,
    this.unavailableReason = DatacenterResourceHistoryUnavailableReason.noData,
  }) : assert(requestedNodeCount >= 0),
       samples = const <DatacenterResourceSample>[],
       reportingNodeCount = 0;

  final List<DatacenterResourceSample> samples;
  final int requestedNodeCount;
  final int reportingNodeCount;
  final DatacenterResourceHistoryUnavailableReason? unavailableReason;

  bool get isAvailable => samples.any(
    (DatacenterResourceSample sample) => sample.hasReportedMetric,
  );
}
