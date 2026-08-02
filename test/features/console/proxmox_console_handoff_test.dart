import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/features/console/domain/proxmox_console_handoff.dart';
import 'package:pve_companion/features/guests/domain/pve_guest.dart';

void main() {
  test('constructs a VM noVNC handoff without credentials or API paths', () {
    final Uri uri = ProxmoxConsoleHandoff.uriForGuest(
      endpoint: Uri.parse('https://pve.example.test:8006'),
      guest: const PveGuest(
        vmid: 101,
        node: 'pve-01',
        kind: GuestKind.virtualMachine,
        status: 'running',
        name: 'build-runner',
      ),
    );

    expect(uri.scheme, 'https');
    expect(uri.host, 'pve.example.test');
    expect(uri.path, '');
    expect(uri.queryParameters, <String, String>{
      'console': 'kvm',
      'novnc': '1',
      'node': 'pve-01',
      'resize': 'scale',
      'vmid': '101',
      'vmname': 'build-runner',
    });
  });

  test(
    'constructs an LXC console handoff and preserves a configured base path',
    () {
      final Uri uri = ProxmoxConsoleHandoff.uriForGuest(
        endpoint: Uri.parse('https://pve.example.test:8006/proxmox'),
        guest: const PveGuest(
          vmid: 202,
          node: 'edge-01',
          kind: GuestKind.container,
          status: 'running',
        ),
      );

      expect(uri.path, '/proxmox');
      expect(uri.queryParameters['console'], 'lxc');
      expect(uri.queryParameters['vmname'], isNull);
    },
  );
}
