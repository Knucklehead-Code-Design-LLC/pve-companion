import 'package:pve_companion/core/api/proxmox_session.dart';
import 'package:pve_companion/features/cluster_overview/application/cluster_overview_controller.dart';
import 'package:pve_companion/features/cluster_overview/data/proxmox_cluster_overview_repository.dart';
import 'package:pve_companion/features/cluster_overview/domain/cluster_overview_snapshot.dart';

import '../../../tool/support/datacenter_dashboard_preview_data.dart';

ClusterOverviewSnapshot healthyDatacenterSnapshot() {
  return datacenterDashboardHealthyPreviewSnapshot();
}

ClusterOverviewSnapshot criticalDatacenterSnapshot() {
  return datacenterDashboardCriticalPreviewSnapshot();
}

Future<ClusterOverviewController> readyDashboardController(
  ClusterOverviewSnapshot snapshot,
) async {
  final ClusterOverviewController controller = ClusterOverviewController(
    _StaticDashboardRepository(snapshot),
  );
  await controller.refresh(const _DashboardFixtureSession());
  return controller;
}

class _StaticDashboardRepository implements ClusterOverviewRepository {
  const _StaticDashboardRepository(this.snapshot);

  final ClusterOverviewSnapshot snapshot;

  @override
  Future<ClusterOverviewSnapshot> load(ProxmoxSession session) async {
    return snapshot;
  }
}

class _DashboardFixtureSession implements ProxmoxSession {
  const _DashboardFixtureSession();

  @override
  void close() {}

  @override
  Future<Object?> getData(
    String resource, {
    Map<String, String> query = const <String, String>{},
  }) async {
    return null;
  }

  @override
  Future<Object?> postForm(
    String resource, {
    required Map<String, String> fields,
  }) async {
    return null;
  }
}
