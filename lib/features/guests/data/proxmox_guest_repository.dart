import '../../../core/api/proxmox_api_exception.dart';
import '../../../core/api/proxmox_session.dart';
import '../domain/pve_guest.dart';

abstract interface class PveGuestRepository {
  Future<PveGuestDetails> loadDetails(ProxmoxSession session, PveGuest guest);

  Future<void> runPowerAction(
    ProxmoxSession session,
    PveGuest guest,
    GuestPowerAction action,
  );
}

class ProxmoxGuestRepository implements PveGuestRepository {
  static const Set<String> _visibleConfigurationKeys = <String>{
    'agent',
    'arch',
    'boot',
    'cores',
    'cpu',
    'description',
    'hostname',
    'memory',
    'net0',
    'onboot',
    'ostype',
    'rootfs',
    'scsi0',
    'sockets',
    'startdate',
    'tags',
    'template',
    'vmgenid',
  };

  @override
  Future<PveGuestDetails> loadDetails(
    ProxmoxSession session,
    PveGuest guest,
  ) async {
    final Object? response = await session.getData(
      'nodes/${guest.node}/${guest.resourceSegment}/${guest.vmid}/config',
    );
    if (response is! Map<Object?, Object?>) {
      throw const ProxmoxMalformedResponseException(
        'The guest configuration response was not an object.',
      );
    }

    final Map<String, String> configuration = <String, String>{};
    for (final MapEntry<Object?, Object?> entry in response.entries) {
      final String key = entry.key.toString();
      if (_visibleConfigurationKeys.contains(key) && entry.value != null) {
        configuration[key] = entry.value.toString();
      }
    }
    return PveGuestDetails(guest: guest, configuration: configuration);
  }

  @override
  Future<void> runPowerAction(
    ProxmoxSession session,
    PveGuest guest,
    GuestPowerAction action,
  ) async {
    if (guest.isTemplate) {
      throw const ProxmoxResponseException(
        statusCode: 400,
        message: 'Templates cannot be powered on or off.',
      );
    }
    await session.postForm(
      'nodes/${guest.node}/${guest.resourceSegment}/${guest.vmid}/status/'
      '${action.apiPathSegment}',
      fields: const <String, String>{},
    );
  }
}
