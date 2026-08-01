import 'package:flutter_test/flutter_test.dart';
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
}

class _RecordingSession implements ProxmoxSession {
  final List<String> postedResources = <String>[];
  final List<Map<String, String>> postedFields = <Map<String, String>>[];

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
    return null;
  }
}
