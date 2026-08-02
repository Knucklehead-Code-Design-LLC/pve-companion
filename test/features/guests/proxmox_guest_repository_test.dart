import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/core/api/proxmox_api_exception.dart';
import 'package:pve_companion/core/api/proxmox_session.dart';
import 'package:pve_companion/features/guests/data/proxmox_guest_repository.dart';
import 'package:pve_companion/features/guests/domain/pve_guest.dart';

void main() {
  group('ProxmoxGuestRepository.runPowerAction', () {
    test('posts a VM start to its terminal action endpoint', () async {
      final _RecordingSession session = _RecordingSession();
      const PveGuest guest = PveGuest(
        vmid: 201,
        node: 'compute-a',
        kind: GuestKind.virtualMachine,
        status: 'stopped',
      );

      await ProxmoxGuestRepository().runPowerAction(
        session,
        guest,
        GuestPowerAction.start,
      );

      expect(session.postedResources, <String>[
        'nodes/compute-a/qemu/201/status/start',
      ]);
      expect(session.postedFields.single, isEmpty);
    });

    test('posts an LXC shutdown to its terminal action endpoint', () async {
      final _RecordingSession session = _RecordingSession();
      const PveGuest guest = PveGuest(
        vmid: 302,
        node: 'edge-a',
        kind: GuestKind.container,
        status: 'running',
      );

      await ProxmoxGuestRepository().runPowerAction(
        session,
        guest,
        GuestPowerAction.shutdown,
      );

      expect(session.postedResources, <String>[
        'nodes/edge-a/lxc/302/status/shutdown',
      ]);
      expect(session.postedFields.single, isEmpty);
    });
  });

  group('ProxmoxGuestRepository.createSnapshot', () {
    test('posts a VM snapshot and preserves its memory-state choice', () async {
      final _RecordingSession session = _RecordingSession(
        postResponse: 'UPID:compute-a:vm-snapshot',
      );
      const PveGuest guest = PveGuest(
        vmid: 201,
        node: 'compute-a',
        kind: GuestKind.virtualMachine,
        status: 'running',
      );

      final task = await ProxmoxGuestRepository().createSnapshot(
        session,
        guest,
        name: 'before-upgrade',
        description: 'Validate the upgrade path',
        includeMemoryState: true,
      );

      expect(task.upid, 'UPID:compute-a:vm-snapshot');
      expect(
        session.postedResources.single,
        'nodes/compute-a/qemu/201/snapshot',
      );
      expect(session.postedFields.single, <String, String>{
        'snapname': 'before-upgrade',
        'description': 'Validate the upgrade path',
        'vmstate': '1',
      });
      expect(session.putResources, isEmpty);
    });

    test('posts an LXC snapshot without a VM memory-state field', () async {
      final _RecordingSession session = _RecordingSession(
        postResponse: 'UPID:edge-a:lxc-snapshot',
      );
      const PveGuest guest = PveGuest(
        vmid: 302,
        node: 'edge-a',
        kind: GuestKind.container,
        status: 'running',
      );

      await ProxmoxGuestRepository().createSnapshot(
        session,
        guest,
        name: 'before-config',
        includeMemoryState: true,
      );

      expect(session.postedResources.single, 'nodes/edge-a/lxc/302/snapshot');
      expect(session.postedFields.single, <String, String>{
        'snapname': 'before-config',
      });
    });
  });

  group('ProxmoxGuestRepository.updateConfiguration', () {
    test(
      'uses PUT for the intentionally narrow guest configuration update',
      () async {
        final _RecordingSession session = _RecordingSession();
        const PveGuest guest = PveGuest(
          vmid: 201,
          node: 'compute-a',
          kind: GuestKind.virtualMachine,
          status: 'running',
        );

        await ProxmoxGuestRepository().updateConfiguration(
          session,
          guest,
          const PveGuestConfigurationChange(
            cores: 6,
            memoryMiB: 12288,
            onBoot: true,
          ),
        );

        expect(session.putResources.single, 'nodes/compute-a/qemu/201/config');
        expect(session.putFields.single, <String, String>{
          'cores': '6',
          'memory': '12288',
          'onboot': '1',
        });
      },
    );
  });

  group('PveGuestSnapshotRequest', () {
    test('rejects reserved Proxmox snapshot names', () {
      expect(
        const PveGuestSnapshotRequest(name: 'current').hasValidName,
        isFalse,
      );
      expect(
        const PveGuestSnapshotRequest(name: 'VZDUMP').hasValidName,
        isFalse,
      );
      expect(
        const PveGuestSnapshotRequest(name: 'current').validationMessage,
        contains('reserved'),
      );
      expect(
        const PveGuestSnapshotRequest(name: 'before-upgrade').hasValidName,
        isTrue,
      );
    });
  });

  test(
    'rejects an unsafe snapshot name before constructing an action path',
    () async {
      final _RecordingSession session = _RecordingSession();
      const PveGuest guest = PveGuest(
        vmid: 201,
        node: 'compute-a',
        kind: GuestKind.virtualMachine,
        status: 'running',
      );

      await expectLater(
        ProxmoxGuestRepository().rollbackSnapshot(
          session,
          guest,
          const PveGuestSnapshot(name: '../outside', createdAt: null),
        ),
        throwsA(isA<ProxmoxResponseException>()),
      );

      expect(session.postedResources, isEmpty);
    },
  );
}

class _RecordingSession implements ProxmoxWritableSession {
  _RecordingSession({this.postResponse});

  final Object? postResponse;
  final List<String> postedResources = <String>[];
  final List<Map<String, String>> postedFields = <Map<String, String>>[];
  final List<String> putResources = <String>[];
  final List<Map<String, String>> putFields = <Map<String, String>>[];
  final List<String> deletedResources = <String>[];

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
    postedResources.add(resource);
    postedFields.add(Map<String, String>.from(fields));
    return postResponse;
  }

  @override
  Future<Object?> putForm(
    String resource, {
    required Map<String, String> fields,
  }) async {
    putResources.add(resource);
    putFields.add(Map<String, String>.from(fields));
    return null;
  }

  @override
  Future<Object?> deleteResource(
    String resource, {
    Map<String, String> query = const <String, String>{},
  }) async {
    deletedResources.add(resource);
    return null;
  }
}
