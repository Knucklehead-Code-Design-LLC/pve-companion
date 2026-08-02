import '../../../core/api/proxmox_api_exception.dart';
import '../../../core/api/proxmox_session.dart';
import '../../guests/domain/pve_guest.dart';

abstract interface class PveGuestConsoleRepository {
  Future<ProxmoxConsoleTransport> open(ProxmoxSession session, PveGuest guest);
}

class ProxmoxGuestConsoleRepository implements PveGuestConsoleRepository {
  @override
  Future<ProxmoxConsoleTransport> open(
    ProxmoxSession session,
    PveGuest guest,
  ) async {
    if (guest.isTemplate) {
      throw const ProxmoxResponseException(
        statusCode: 400,
        message: 'Templates do not have an interactive guest console.',
      );
    }
    if (session is! ProxmoxConsoleSession) {
      throw const ProxmoxResponseException(
        statusCode: 501,
        message: 'This connection does not support an in-app guest console.',
      );
    }
    return session.openConsole(
      node: guest.node,
      resource: guest.resourceSegment,
      vmid: guest.vmid,
    );
  }
}
