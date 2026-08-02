import '../../guests/domain/pve_guest.dart';

/// Constructs the official Proxmox noVNC console route without leaking the
/// app's API token, password, or short-lived ticket into another process.
/// The browser presents its own Proxmox sign-in flow when needed.
abstract final class ProxmoxConsoleHandoff {
  static Uri uriForGuest({required Uri endpoint, required PveGuest guest}) {
    return endpoint.replace(
      queryParameters: <String, String>{
        'console': guest.kind == GuestKind.virtualMachine ? 'kvm' : 'lxc',
        'novnc': '1',
        'node': guest.node,
        'resize': 'scale',
        'vmid': '${guest.vmid}',
        if (guest.name?.trim().isNotEmpty == true) 'vmname': guest.name!.trim(),
      },
    );
  }
}
