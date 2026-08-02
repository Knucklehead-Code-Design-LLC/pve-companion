import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/features/system_surfaces/application/system_surfaces_controller.dart';
import 'package:pve_companion/features/system_surfaces/data/system_surfaces_repository.dart';
import 'package:pve_companion/features/system_surfaces/domain/datacenter_surface_snapshot.dart';

void main() {
  test('publishes widgets and keeps an active watch current', () async {
    final _RecordingSystemSurfacesRepository repository =
        _RecordingSystemSurfacesRepository(
          capabilities: const SystemSurfaceCapabilities(
            widgetsAvailable: true,
            liveActivitiesAvailable: true,
            datacenterWatchActive: true,
          ),
        );
    final SystemSurfacesController controller = SystemSurfacesController(
      repository,
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    await controller.publish(_snapshot);

    expect(controller.widgetsAvailable, isTrue);
    expect(controller.datacenterWatchActive, isTrue);
    expect(repository.publishedSnapshots, <DatacenterSurfaceSnapshot>[
      _snapshot,
    ]);
    expect(repository.updatedSnapshots, <DatacenterSurfaceSnapshot>[_snapshot]);
  });

  test('starts and ends a four-hour Datacenter Watch', () async {
    final _RecordingSystemSurfacesRepository repository =
        _RecordingSystemSurfacesRepository(
          capabilities: const SystemSurfaceCapabilities(
            widgetsAvailable: true,
            liveActivitiesAvailable: true,
            datacenterWatchActive: false,
          ),
        );
    final SystemSurfacesController controller = SystemSurfacesController(
      repository,
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    await controller.publish(_snapshot);
    final bool started = await controller.startDatacenterWatch();
    await controller.endDatacenterWatch();

    expect(started, isTrue);
    expect(repository.startedDuration, const Duration(hours: 4));
    expect(repository.endCount, 1);
    expect(controller.datacenterWatchActive, isFalse);
  });

  test('clears a stale server snapshot and ends its active watch', () async {
    final _RecordingSystemSurfacesRepository repository =
        _RecordingSystemSurfacesRepository(
          capabilities: const SystemSurfaceCapabilities(
            widgetsAvailable: true,
            liveActivitiesAvailable: true,
            datacenterWatchActive: true,
          ),
        );
    final SystemSurfacesController controller = SystemSurfacesController(
      repository,
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    await controller.publish(_snapshot);
    await controller.clearSnapshot();

    expect(repository.clearCount, 1);
    expect(repository.endCount, 1);
    expect(controller.datacenterWatchActive, isFalse);
    expect(controller.canStartDatacenterWatch, isFalse);
  });
}

final DatacenterSurfaceSnapshot _snapshot = DatacenterSurfaceSnapshot(
  healthCode: 'healthy',
  healthLabel: 'Healthy',
  issueCount: 0,
  onlineNodeCount: 1,
  nodeCount: 1,
  runningGuestCount: 4,
  guestCount: 5,
  runningTaskCount: 0,
  failedTaskCount: 0,
  updatedAt: _updatedAt,
);

final DateTime _updatedAt = DateTime.fromMillisecondsSinceEpoch(
  1785616200000,
  isUtc: true,
);

class _RecordingSystemSurfacesRepository implements SystemSurfacesRepository {
  _RecordingSystemSurfacesRepository({required this.capabilities});

  final SystemSurfaceCapabilities capabilities;
  final List<DatacenterSurfaceSnapshot> publishedSnapshots =
      <DatacenterSurfaceSnapshot>[];
  final List<DatacenterSurfaceSnapshot> updatedSnapshots =
      <DatacenterSurfaceSnapshot>[];
  Duration? startedDuration;
  int endCount = 0;
  int clearCount = 0;

  @override
  Future<SystemSurfaceCapabilities> loadCapabilities() async => capabilities;

  @override
  Future<void> publishSnapshot(DatacenterSurfaceSnapshot snapshot) async {
    publishedSnapshots.add(snapshot);
  }

  @override
  Future<void> clearSnapshot() async {
    clearCount += 1;
  }

  @override
  Future<bool> startDatacenterWatch(
    DatacenterSurfaceSnapshot snapshot, {
    required Duration duration,
  }) async {
    startedDuration = duration;
    return true;
  }

  @override
  Future<void> updateDatacenterWatch(DatacenterSurfaceSnapshot snapshot) async {
    updatedSnapshots.add(snapshot);
  }

  @override
  Future<void> endDatacenterWatch() async {
    endCount += 1;
  }
}
