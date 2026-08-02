enum DatacenterIncidentSeverity { warning, critical }

enum DatacenterIncidentTarget { nodes, storage, tasks }

class DatacenterIncident {
  const DatacenterIncident({
    required this.id,
    required this.severity,
    required this.target,
    required this.title,
    required this.detail,
  });

  final String id;
  final DatacenterIncidentSeverity severity;
  final DatacenterIncidentTarget target;
  final String title;
  final String detail;
}

class DatacenterIncidentSnapshot {
  const DatacenterIncidentSnapshot({required this.incidents});

  final List<DatacenterIncident> incidents;

  int get criticalCount => incidents
      .where(
        (DatacenterIncident incident) =>
            incident.severity == DatacenterIncidentSeverity.critical,
      )
      .length;

  int get warningCount => incidents
      .where(
        (DatacenterIncident incident) =>
            incident.severity == DatacenterIncidentSeverity.warning,
      )
      .length;

  bool get isEmpty => incidents.isEmpty;
}
