import 'package:flutter/material.dart';

import '../../../core/api/proxmox_session.dart';
import '../../cluster_overview/application/cluster_overview_controller.dart';
import '../../cluster_overview/domain/cluster_overview_snapshot.dart';
import '../../cluster_overview/presentation/cluster_overview_format.dart';
import '../domain/pve_guest.dart';
import 'guest_detail_sheet.dart';

class GuestListPage extends StatelessWidget {
  const GuestListPage({
    super.key,
    required this.overviewController,
    required this.session,
    required this.onGuestPowerAction,
  });

  final ClusterOverviewController overviewController;
  final ProxmoxSession session;
  final Future<void> Function() onGuestPowerAction;

  @override
  Widget build(BuildContext context) {
    final ClusterOverviewSnapshot? snapshot = overviewController.snapshot;
    if (snapshot == null) {
      return const Center(
        child: Text('Guest inventory will appear after the overview loads.'),
      );
    }
    final List<PveGuest> guests = List<PveGuest>.of(
      snapshot.guests,
    )..sort((PveGuest left, PveGuest right) => left.vmid.compareTo(right.vmid));
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: guests.length + 1,
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) {
        if (index == 0) {
          return _GuestPageHeader(totalGuests: guests.length);
        }
        final PveGuest guest = guests[index - 1];
        return _GuestListItem(
          guest: guest,
          onTap: () => showGuestDetailSheet(
            context,
            guest: guest,
            session: session,
            onGuestPowerAction: onGuestPowerAction,
          ),
        );
      },
    );
  }
}

class _GuestPageHeader extends StatelessWidget {
  const _GuestPageHeader({required this.totalGuests});

  final int totalGuests;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              'Guests',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          Text(
            '$totalGuests total',
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ],
      ),
    );
  }
}

class _GuestListItem extends StatelessWidget {
  const _GuestListItem({required this.guest, required this.onTap});

  final PveGuest guest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color statusColor = guest.isRunning
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.outline;
    return Card(
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Icon(
          guest.kind == GuestKind.virtualMachine
              ? Icons.memory_outlined
              : Icons.inventory_2_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(guest.title),
        subtitle: Text(
          '${guest.kind.shortLabel} ${guest.vmid} · ${guest.node} · '
          '${formatPveBytes(guest.memoryBytes)} memory',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              guest.isTemplate ? 'Template' : guest.status,
              style: TextStyle(color: statusColor, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
