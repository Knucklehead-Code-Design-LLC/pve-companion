import 'package:flutter/cupertino.dart';

import '../../../core/api/proxmox_session.dart';
import '../../../core/presentation/pve_apple_ui.dart';
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
      return const PveLoadingState(label: 'Loading guests');
    }
    final List<PveGuest> guests = List<PveGuest>.of(
      snapshot.guests,
    )..sort((PveGuest left, PveGuest right) => left.vmid.compareTo(right.vmid));
    if (guests.isEmpty) {
      return const PveEmptyState(
        icon: CupertinoIcons.cube_box,
        title: 'No guests reported',
        message: 'This server did not report virtual machines or containers.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        PvePageHeader(
          title: 'Guests',
          subtitle:
              '${guests.length} ${guests.length == 1 ? 'workload' : 'workloads'} '
              'across the datacenter.',
        ),
        const SizedBox(height: 20),
        PveInsetGroup(
          child: Column(
            children: <Widget>[
              for (int index = 0; index < guests.length; index++) ...<Widget>[
                _GuestListItem(
                  guest: guests[index],
                  onTap: () => showGuestDetailSheet(
                    context,
                    guest: guests[index],
                    session: session,
                    onGuestPowerAction: onGuestPowerAction,
                  ),
                ),
                if (index < guests.length - 1) const PveRowSeparator(),
              ],
            ],
          ),
        ),
      ],
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
        ? PveAppleColors.success(context)
        : PveAppleColors.secondaryLabel(context);
    return PveListRow(
      onTap: onTap,
      leading: Icon(
        guest.kind == GuestKind.virtualMachine
            ? CupertinoIcons.desktopcomputer
            : CupertinoIcons.cube_box_fill,
      ),
      title: Text(guest.title),
      subtitle: Text(
        '${guest.kind.shortLabel} ${guest.vmid} · ${guest.node} · '
        '${formatPveBytes(guest.memoryBytes)} memory',
      ),
      trailing: PveStatusPill(
        label: guest.isTemplate ? 'Template' : _statusLabel(guest.status),
        color: statusColor,
      ),
    );
  }
}

String _statusLabel(String status) {
  if (status.isEmpty) {
    return 'Unknown';
  }
  return '${status[0].toUpperCase()}${status.substring(1)}';
}
