import '../../cluster_overview/domain/cluster_overview_snapshot.dart';
import '../../cluster_overview/domain/datacenter_health.dart';
import '../../cluster_overview/domain/datacenter_health_evaluator.dart';
import 'datacenter_incident.dart';

abstract final class DatacenterIncidentEvaluator {
  static DatacenterIncidentSnapshot evaluate(ClusterOverviewSnapshot overview) {
    final DatacenterHealth health = DatacenterHealthEvaluator.evaluate(
      overview,
    );
    final List<DatacenterIncident> incidents = <DatacenterIncident>[];
    for (final DatacenterNodeHealth node in health.nodes) {
      if (!node.node.isOnline) {
        incidents.add(
          DatacenterIncident(
            id: 'node-offline:${node.node.name}',
            severity: DatacenterIncidentSeverity.critical,
            target: DatacenterIncidentTarget.nodes,
            title: '${node.node.name} is offline',
            detail: 'Proxmox did not report this node as online.',
          ),
        );
        continue;
      }
      _addPressureIncident(
        incidents,
        nodeName: node.node.name,
        label: 'CPU',
        pressure: node.cpu,
      );
      _addPressureIncident(
        incidents,
        nodeName: node.node.name,
        label: 'memory',
        pressure: node.memory,
      );
      _addPressureIncident(
        incidents,
        nodeName: node.node.name,
        label: 'root disk',
        pressure: node.rootDisk,
      );
    }
    for (final ClusterStorage storage in overview.storages) {
      if (storage.hasAvailabilityTelemetry && !storage.isAvailable) {
        incidents.add(
          DatacenterIncident(
            id: 'storage-unavailable:${storage.name}',
            severity: DatacenterIncidentSeverity.critical,
            target: DatacenterIncidentTarget.storage,
            title: '${storage.name} is unavailable',
            detail: 'No reporting node currently marks this storage available.',
          ),
        );
      }
      final double? fraction = storage.usageFraction;
      if (fraction == null) {
        continue;
      }
      final DatacenterIncidentSeverity? severity =
          fraction >= datacenterPressureCriticalThreshold
          ? DatacenterIncidentSeverity.critical
          : fraction >= datacenterPressureWarningThreshold
          ? DatacenterIncidentSeverity.warning
          : null;
      if (severity != null) {
        incidents.add(
          DatacenterIncident(
            id: 'storage-capacity:${storage.name}',
            severity: severity,
            target: DatacenterIncidentTarget.storage,
            title: '${storage.name} capacity is ${_percent(fraction)} used',
            detail:
                'Review free space and backup retention before capacity is exhausted.',
          ),
        );
      }
    }
    for (final ClusterTask task in overview.tasks) {
      if (task.state != ClusterTaskState.failed) {
        continue;
      }
      incidents.add(
        DatacenterIncident(
          id: 'task-failed:${task.upid}',
          severity: DatacenterIncidentSeverity.warning,
          target: DatacenterIncidentTarget.tasks,
          title: '${task.type} failed on ${task.node}',
          detail: task.status?.trim().isNotEmpty == true
              ? task.status!
              : 'Review the task log in Proxmox for details.',
        ),
      );
    }
    incidents.sort(_compareIncidents);
    return DatacenterIncidentSnapshot(
      incidents: List<DatacenterIncident>.unmodifiable(incidents),
    );
  }
}

void _addPressureIncident(
  List<DatacenterIncident> incidents, {
  required String nodeName,
  required String label,
  required DatacenterPressureMetric? pressure,
}) {
  if (pressure == null || pressure.level == DatacenterPressureLevel.normal) {
    return;
  }
  final DatacenterIncidentSeverity severity =
      pressure.level == DatacenterPressureLevel.critical
      ? DatacenterIncidentSeverity.critical
      : DatacenterIncidentSeverity.warning;
  incidents.add(
    DatacenterIncident(
      id: 'node-pressure:$nodeName:$label',
      severity: severity,
      target: DatacenterIncidentTarget.nodes,
      title: '$nodeName $label is ${_percent(pressure.fraction)} utilized',
      detail: severity == DatacenterIncidentSeverity.critical
          ? 'This pressure is at or above the critical threshold.'
          : 'This pressure is above the attention threshold.',
    ),
  );
}

int _compareIncidents(DatacenterIncident left, DatacenterIncident right) {
  final int severityComparison = _severityRank(
    left.severity,
  ).compareTo(_severityRank(right.severity));
  if (severityComparison != 0) {
    return severityComparison;
  }
  return left.title.toLowerCase().compareTo(right.title.toLowerCase());
}

int _severityRank(DatacenterIncidentSeverity severity) => switch (severity) {
  DatacenterIncidentSeverity.critical => 0,
  DatacenterIncidentSeverity.warning => 1,
};

String _percent(double fraction) => '${(fraction * 100).round()}%';
