import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/features/backups/domain/pve_backup_center.dart';
import 'package:pve_companion/features/cluster_overview/domain/cluster_overview_snapshot.dart';

void main() {
  test('only reported available backup storage is executable', () {
    const unavailableTelemetry = ClusterStorage(
      name: 'backup-unknown',
      type: 'dir',
      content: 'backup,iso',
      shared: false,
      resources: <ClusterStorageResource>[
        ClusterStorageResource(node: 'pve-01', status: ''),
      ],
    );
    const availableStorage = ClusterStorage(
      name: 'backup-ready',
      type: 'dir',
      content: 'backup',
      shared: false,
      resources: <ClusterStorageResource>[
        ClusterStorageResource(node: 'pve-01', status: 'available'),
      ],
    );

    expect(
      PveBackupDestination.supportsBackupContent(unavailableTelemetry),
      isTrue,
    );
    expect(
      PveBackupDestination.isAvailableForExecution(unavailableTelemetry),
      isFalse,
    );
    expect(
      PveBackupDestination.isAvailableForExecution(availableStorage),
      isTrue,
    );
  });

  test(
    'backup readiness distinguishes setup, access, scheduling, and copies',
    () {
      expect(_snapshot().readiness, PveBackupReadiness.noDestination);
      expect(
        _snapshot(
          destinations: <PveBackupDestination>[_destination],
          scheduleDataState: PveBackupDataState.permissionLimited,
        ).readiness,
        PveBackupReadiness.configurationUnreadable,
      );
      expect(
        _snapshot(destinations: <PveBackupDestination>[_destination]).readiness,
        PveBackupReadiness.noSchedule,
      );
      expect(
        _snapshot(
          destinations: <PveBackupDestination>[_destination],
          schedules: const <PveBackupSchedule>[
            PveBackupSchedule(id: 'nightly'),
          ],
          recordDataState: PveBackupDataState.permissionLimited,
        ).readiness,
        PveBackupReadiness.copiesUnreadable,
      );
      expect(
        _snapshot(
          destinations: <PveBackupDestination>[_destination],
          schedules: const <PveBackupSchedule>[
            PveBackupSchedule(id: 'nightly'),
          ],
          recordDataState: PveBackupDataState.unavailable,
        ).readiness,
        PveBackupReadiness.copiesUnavailable,
      );
      expect(
        _snapshot(
          destinations: <PveBackupDestination>[_destination],
          schedules: const <PveBackupSchedule>[
            PveBackupSchedule(id: 'nightly'),
          ],
          records: const <PveBackupRecord>[
            PveBackupRecord(
              volumeId: 'backup:101',
              storage: 'backup',
              node: 'pve-01',
            ),
          ],
          recordDataState: PveBackupDataState.partiallyAvailable,
        ).readiness,
        PveBackupReadiness.copiesPartiallyReported,
      );
      expect(
        _snapshot(
          destinations: <PveBackupDestination>[_destination],
          schedules: const <PveBackupSchedule>[
            PveBackupSchedule(id: 'nightly'),
          ],
          records: const <PveBackupRecord>[
            PveBackupRecord(
              volumeId: 'backup:101',
              storage: 'backup',
              node: 'pve-01',
            ),
          ],
        ).readiness,
        PveBackupReadiness.copiesReported,
      );
    },
  );
}

PveBackupCenterSnapshot _snapshot({
  List<PveBackupDestination> destinations = const <PveBackupDestination>[],
  List<PveBackupSchedule> schedules = const <PveBackupSchedule>[],
  List<PveBackupRecord> records = const <PveBackupRecord>[],
  PveBackupDataState scheduleDataState = PveBackupDataState.available,
  PveBackupDataState recordDataState = PveBackupDataState.available,
}) => PveBackupCenterSnapshot(
  destinations: destinations,
  schedules: schedules,
  records: records,
  recentTasks: const <ClusterTask>[],
  scheduleDataState: scheduleDataState,
  recordDataState: recordDataState,
);

const PveBackupDestination _destination = PveBackupDestination(
  storage: ClusterStorage(
    name: 'backup',
    type: 'dir',
    content: 'backup',
    shared: false,
  ),
);
