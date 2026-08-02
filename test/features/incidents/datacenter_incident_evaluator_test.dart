import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/features/incidents/domain/datacenter_incident.dart';
import 'package:pve_companion/features/incidents/domain/datacenter_incident_evaluator.dart';

import '../cluster_overview/datacenter_dashboard_fixture.dart';

void main() {
  test('keeps a healthy datacenter free of synthesized incidents', () {
    final snapshot = DatacenterIncidentEvaluator.evaluate(
      healthyDatacenterSnapshot(),
    );

    expect(snapshot.isEmpty, isTrue);
  });

  test('prioritizes node, capacity, and failed-task signals', () {
    final snapshot = DatacenterIncidentEvaluator.evaluate(
      criticalDatacenterSnapshot(),
    );

    expect(snapshot.criticalCount, greaterThanOrEqualTo(4));
    expect(snapshot.warningCount, 1);
    expect(
      snapshot.incidents.first.severity,
      DatacenterIncidentSeverity.critical,
    );
    expect(
      snapshot.incidents.map((DatacenterIncident incident) => incident.id),
      containsAll(<String>[
        'node-offline:edge-a',
        'node-pressure:compute-a:CPU',
        'storage-capacity:local',
        'task-failed:UPID:failed',
      ]),
    );
  });
}
