import 'package:flutter/cupertino.dart';

import '../../../core/api/proxmox_session.dart';
import '../../../core/presentation/pve_apple_ui.dart';
import '../../cluster_overview/application/cluster_overview_controller.dart';
import '../../cluster_overview/domain/cluster_overview_snapshot.dart';
import '../../cluster_overview/presentation/cluster_overview_format.dart';
import '../domain/pve_guest.dart';
import 'guest_detail_sheet.dart';

class GuestListPage extends StatefulWidget {
  const GuestListPage({
    super.key,
    required this.overviewController,
    required this.session,
    required this.onRefresh,
    required this.onGuestPowerAction,
    this.showsSliverNavigationBar = true,
    this.navigationLeading,
    this.navigationTrailing,
  });

  final ClusterOverviewController overviewController;
  final ProxmoxSession session;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onGuestPowerAction;
  final bool showsSliverNavigationBar;
  final Widget? navigationLeading;
  final Widget? navigationTrailing;

  @override
  State<GuestListPage> createState() => _GuestListPageState();
}

class _GuestListPageState extends State<GuestListPage> {
  final TextEditingController _searchController = TextEditingController();
  _GuestFilter _filter = _GuestFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ClusterOverviewSnapshot? snapshot =
        widget.overviewController.snapshot;
    final List<PveGuest> guests =
        List<PveGuest>.of(snapshot?.guests ?? const <PveGuest>[])..sort((
          PveGuest left,
          PveGuest right,
        ) {
          if (left.isRunning != right.isRunning) {
            return left.isRunning ? -1 : 1;
          }
          return left.title.toLowerCase().compareTo(right.title.toLowerCase());
        });

    return PvePrimaryScrollView(
      title: 'Guests',
      showsSliverNavigationBar: widget.showsSliverNavigationBar,
      navigationLeading: widget.navigationLeading,
      navigationTrailing: widget.navigationTrailing,
      onRefresh: widget.onRefresh,
      slivers: <Widget>[
        if (snapshot == null)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: PveLoadingState(label: 'Loading guests'),
          )
        else
          PveCenteredSliver(
            maxWidth: 980,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: _buildGuestContent(context, guests),
          ),
      ],
    );
  }

  Widget _buildGuestContent(BuildContext context, List<PveGuest> guests) {
    final List<PveGuest> visibleGuests = guests
        .where(_matchesFilter)
        .where(_matchesSearch)
        .toList(growable: false);
    final int runningCount = guests
        .where((PveGuest guest) => guest.isRunning)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '${guests.length} ${guests.length == 1 ? 'workload' : 'workloads'} · '
            '$runningCount running',
            style: PveAppleText.caption(context),
          ),
        ),
        const SizedBox(height: 12),
        CupertinoSearchTextField(
          controller: _searchController,
          placeholder: 'Search guests',
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        PveSlidingSegmentedControl<_GuestFilter>(
          groupValue: _filter,
          children: const <_GuestFilter, Widget>{
            _GuestFilter.all: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('All'),
            ),
            _GuestFilter.running: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('Running'),
            ),
            _GuestFilter.stopped: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('Stopped'),
            ),
          },
          onValueChanged: (_GuestFilter? value) {
            if (value != null) {
              setState(() => _filter = value);
            }
          },
        ),
        const SizedBox(height: 16),
        if (visibleGuests.isEmpty)
          PveInsetGroup(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: <Widget>[
                Icon(
                  CupertinoIcons.search,
                  size: 28,
                  color: PveAppleColors.secondaryLabel(context),
                ),
                const SizedBox(height: 10),
                Text('No matching guests', style: PveAppleText.title3(context)),
                const SizedBox(height: 4),
                Text(
                  'Try another search or status filter.',
                  style: PveAppleText.secondary(context),
                ),
              ],
            ),
          )
        else
          CupertinoListSection.insetGrouped(
            margin: EdgeInsets.zero,
            children: visibleGuests
                .map(
                  (PveGuest guest) => _GuestListItem(
                    guest: guest,
                    onTap: () => showGuestDetailSheet(
                      context,
                      guest: guest,
                      session: widget.session,
                      onGuestPowerAction: widget.onGuestPowerAction,
                    ),
                  ),
                )
                .toList(growable: false),
          ),
      ],
    );
  }

  bool _matchesFilter(PveGuest guest) => switch (_filter) {
    _GuestFilter.all => true,
    _GuestFilter.running => guest.isRunning,
    _GuestFilter.stopped => !guest.isRunning,
  };

  bool _matchesSearch(PveGuest guest) {
    final String query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return true;
    }
    return guest.title.toLowerCase().contains(query) ||
        guest.node.toLowerCase().contains(query) ||
        guest.vmid.toString().contains(query) ||
        guest.kind.label.toLowerCase().contains(query);
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
    return CupertinoListTile(
      leading: DecoratedBox(
        decoration: BoxDecoration(
          color: PveAppleColors.primary(context).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Icon(
            guest.kind == GuestKind.virtualMachine
                ? CupertinoIcons.desktopcomputer
                : CupertinoIcons.cube_box_fill,
            size: 19,
            color: PveAppleColors.primary(context),
          ),
        ),
      ),
      title: Text(guest.title),
      subtitle: Text(
        '${guest.kind.shortLabel} ${guest.vmid} · ${guest.node} · '
        '${formatPveBytes(guest.memoryBytes)} memory',
      ),
      additionalInfo: Text(
        guest.isTemplate ? 'Template' : _statusLabel(guest.status),
        style: PveAppleText.caption(
          context,
        ).copyWith(color: statusColor, fontWeight: FontWeight.w600),
      ),
      trailing: const CupertinoListTileChevron(),
      onTap: onTap,
    );
  }
}

enum _GuestFilter { all, running, stopped }

String _statusLabel(String status) {
  if (status.isEmpty) {
    return 'Unknown';
  }
  return '${status[0].toUpperCase()}${status.substring(1)}';
}
