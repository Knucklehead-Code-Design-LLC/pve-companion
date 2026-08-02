import 'package:flutter/cupertino.dart';

import '../../../core/presentation/pve_apple_ui.dart';
import '../../../core/presentation/pve_modal_sheet.dart';
import '../../../core/presentation/pve_value_format.dart';
import '../../cluster_overview/domain/datacenter_health.dart';
import '../application/fleet_overview_controller.dart';
import '../domain/fleet_datacenter.dart';

Future<void> showFleetWorkspaceSheet(
  BuildContext context, {
  required FleetOverviewController controller,
  required String? activeProfileId,
  required Future<void> Function(String profileId) onOpenProfile,
}) {
  return showPveModalSheet<void>(
    context: context,
    scrollableBuilder:
        (BuildContext sheetContext, ScrollController scrollController) =>
            _FleetWorkspaceSheet(
              controller: controller,
              activeProfileId: activeProfileId,
              scrollController: scrollController,
              onOpenProfile: onOpenProfile,
            ),
  );
}

class _FleetWorkspaceSheet extends StatefulWidget {
  const _FleetWorkspaceSheet({
    required this.controller,
    required this.activeProfileId,
    required this.scrollController,
    required this.onOpenProfile,
  });

  final FleetOverviewController controller;
  final String? activeProfileId;
  final ScrollController scrollController;
  final Future<void> Function(String profileId) onOpenProfile;

  @override
  State<_FleetWorkspaceSheet> createState() => _FleetWorkspaceSheetState();
}

class _FleetWorkspaceSheetState extends State<_FleetWorkspaceSheet> {
  @override
  void initState() {
    super.initState();
    widget.controller.refresh();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: PveAppleColors.page(context),
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Datacenter Portfolio'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PveIconAction(
              icon: CupertinoIcons.refresh,
              label: 'Refresh datacenter portfolio',
              onPressed:
                  widget.controller.state == FleetOverviewLoadState.loading
                  ? null
                  : widget.controller.refresh,
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (BuildContext context, Widget? child) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: _FleetContent(
                  controller: widget.controller,
                  activeProfileId: widget.activeProfileId,
                  scrollController: widget.scrollController,
                  onOpenProfile: _openProfile,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openProfile(String profileId) async {
    Navigator.of(context).pop();
    await widget.onOpenProfile(profileId);
  }
}

class _FleetContent extends StatelessWidget {
  const _FleetContent({
    required this.controller,
    required this.activeProfileId,
    required this.scrollController,
    required this.onOpenProfile,
  });

  final FleetOverviewController controller;
  final String? activeProfileId;
  final ScrollController scrollController;
  final Future<void> Function(String profileId) onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final List<FleetDatacenter> datacenters = controller.datacenters;
    final int healthyCount = datacenters
        .where(
          (FleetDatacenter datacenter) =>
              datacenter.state == FleetDatacenterState.healthy,
        )
        .length;
    final int attentionCount = datacenters
        .where(
          (FleetDatacenter datacenter) =>
              datacenter.state == FleetDatacenterState.warning ||
              datacenter.state == FleetDatacenterState.critical,
        )
        .length;
    final int unavailableCount = datacenters
        .where(
          (FleetDatacenter datacenter) =>
              datacenter.state == FleetDatacenterState.unavailable,
        )
        .length;
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: 32),
      children: <Widget>[
        Text('All saved datacenters', style: PveAppleText.title2(context)),
        const SizedBox(height: 6),
        Text(
          'Each refresh opens a short-lived, read-only session using the credential already saved in your Keychain. It never changes your active workspace.',
          style: PveAppleText.secondary(context),
        ),
        const SizedBox(height: 18),
        PveMetricStrip(
          items: <PveMetricStripItem>[
            PveMetricStripItem(
              label: 'Saved',
              value: '${datacenters.length}',
              icon: CupertinoIcons.rectangle_stack_badge_person_crop,
            ),
            PveMetricStripItem(
              label: 'Healthy',
              value: '$healthyCount',
              icon: CupertinoIcons.check_mark_circled_solid,
              color: PveAppleColors.success(context),
            ),
            PveMetricStripItem(
              label: 'Attention',
              value: '$attentionCount',
              icon: CupertinoIcons.exclamationmark_triangle_fill,
              color: attentionCount == 0
                  ? PveAppleColors.success(context)
                  : PveAppleColors.warning(context),
            ),
            PveMetricStripItem(
              label: 'Unavailable',
              value: '$unavailableCount',
              icon: CupertinoIcons.wifi_slash,
              color: unavailableCount == 0
                  ? PveAppleColors.success(context)
                  : PveAppleColors.secondaryLabel(context),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (controller.state == FleetOverviewLoadState.loading &&
            datacenters.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 42),
            child: PveLoadingState(label: 'Checking saved datacenters'),
          )
        else if (datacenters.isEmpty)
          PveInsetGroup(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: <Widget>[
                Icon(
                  CupertinoIcons.rectangle_stack_badge_plus,
                  size: 32,
                  color: PveAppleColors.primary(context),
                ),
                const SizedBox(height: 10),
                Text(
                  'No saved datacenters',
                  style: PveAppleText.title3(context),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add a Proxmox server from Manage Servers to include it in this portfolio.',
                  textAlign: TextAlign.center,
                  style: PveAppleText.secondary(context),
                ),
              ],
            ),
          )
        else
          _FleetDatacentersCard(
            datacenters: datacenters,
            activeProfileId: activeProfileId,
            onOpenProfile: onOpenProfile,
          ),
        if (controller.lastUpdatedAt != null) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            'Last portfolio refresh: ${formatPveDateTime(controller.lastUpdatedAt)}',
            textAlign: TextAlign.center,
            style: PveAppleText.caption(context),
          ),
        ],
      ],
    );
  }
}

class _FleetDatacentersCard extends StatelessWidget {
  const _FleetDatacentersCard({
    required this.datacenters,
    required this.activeProfileId,
    required this.onOpenProfile,
  });

  final List<FleetDatacenter> datacenters;
  final String? activeProfileId;
  final Future<void> Function(String profileId) onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return PveInsetGroup(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          for (int index = 0; index < datacenters.length; index++) ...<Widget>[
            _FleetDatacenterRow(
              datacenter: datacenters[index],
              active: datacenters[index].profile.id == activeProfileId,
              onOpen: () => onOpenProfile(datacenters[index].profile.id),
            ),
            if (index < datacenters.length - 1) const PveRowSeparator(),
          ],
        ],
      ),
    );
  }
}

class _FleetDatacenterRow extends StatelessWidget {
  const _FleetDatacenterRow({
    required this.datacenter,
    required this.active,
    required this.onOpen,
  });

  final FleetDatacenter datacenter;
  final bool active;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final Color accent = _fleetColor(context, datacenter.state);
    return PveListRow(
      leading: Icon(_fleetIcon(datacenter.state), color: accent),
      title: Row(
        children: <Widget>[
          Flexible(child: Text(datacenter.profile.displayName)),
          if (active) ...<Widget>[
            const SizedBox(width: 7),
            PveStatusPill(
              label: 'Open',
              color: PveAppleColors.primary(context),
            ),
          ],
        ],
      ),
      subtitle: Text(_fleetSubtitle(datacenter)),
      trailing: PveStatusPill(
        label: _fleetLabel(datacenter.state),
        color: accent,
      ),
      onTap: onOpen,
    );
  }
}

Color _fleetColor(BuildContext context, FleetDatacenterState state) =>
    switch (state) {
      FleetDatacenterState.healthy => PveAppleColors.success(context),
      FleetDatacenterState.warning => PveAppleColors.warning(context),
      FleetDatacenterState.critical => PveAppleColors.destructive(context),
      FleetDatacenterState.unavailable => PveAppleColors.secondaryLabel(
        context,
      ),
    };

IconData _fleetIcon(FleetDatacenterState state) => switch (state) {
  FleetDatacenterState.healthy => CupertinoIcons.check_mark_circled_solid,
  FleetDatacenterState.warning => CupertinoIcons.exclamationmark_circle_fill,
  FleetDatacenterState.critical => CupertinoIcons.exclamationmark_triangle_fill,
  FleetDatacenterState.unavailable => CupertinoIcons.wifi_slash,
};

String _fleetLabel(FleetDatacenterState state) => switch (state) {
  FleetDatacenterState.healthy => 'Healthy',
  FleetDatacenterState.warning => 'Attention',
  FleetDatacenterState.critical => 'Critical',
  FleetDatacenterState.unavailable => 'Unavailable',
};

String _fleetSubtitle(FleetDatacenter datacenter) {
  final DatacenterHealth? health = datacenter.health;
  if (health == null) {
    return datacenter.message ?? 'No telemetry was reported.';
  }
  return '${health.workload.runningGuests}/${health.workload.totalGuests} workloads running · ${health.issues.length} ${health.issues.length == 1 ? 'issue' : 'issues'}';
}
