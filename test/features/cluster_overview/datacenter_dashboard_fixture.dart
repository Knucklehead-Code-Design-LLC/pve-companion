import 'package:pve_companion/core/api/proxmox_api_exception.dart';
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

Future<ClusterOverviewController> staleDashboardController(
  ClusterOverviewSnapshot snapshot,
) async {
  final ClusterOverviewController controller = ClusterOverviewController(
    _FailingAfterSnapshotRepository(snapshot),
  );
  const _DashboardFixtureSession session = _DashboardFixtureSession();
  await controller.refresh(session);
  await controller.refresh(session);
  return controller;
}

Future<ClusterOverviewController> failedDashboardController() async {
  final ClusterOverviewController controller = ClusterOverviewController(
    const _FailingDashboardRepository(),
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

class _FailingAfterSnapshotRepository implements ClusterOverviewRepository {
  _FailingAfterSnapshotRepository(this.snapshot);

  final ClusterOverviewSnapshot snapshot;
  bool _returnedSnapshot = false;

  @override
  Future<ClusterOverviewSnapshot> load(ProxmoxSession session) async {
    if (!_returnedSnapshot) {
      _returnedSnapshot = true;
      return snapshot;
    }
    throw const ProxmoxNetworkException('Refresh failed.');
  }
}

class _FailingDashboardRepository implements ClusterOverviewRepository {
  const _FailingDashboardRepository();

  @override
  Future<ClusterOverviewSnapshot> load(ProxmoxSession session) async {
    throw const ProxmoxNetworkException('Initial load failed.');
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
