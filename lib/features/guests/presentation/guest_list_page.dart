import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/services.dart';

import '../../../core/api/proxmox_session.dart';
import '../../../core/presentation/pve_apple_ui.dart';
import '../../../core/presentation/pve_value_format.dart';
import '../../cluster_overview/application/cluster_overview_controller.dart';
import '../../cluster_overview/domain/cluster_overview_snapshot.dart';
import '../../cluster_overview/presentation/cluster_load_state_view.dart';
import '../domain/pve_guest.dart';
import 'guest_detail_sheet.dart';
import 'guest_inventory_insights.dart';

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
  _GuestInventorySort _sort = _GuestInventorySort.status;
  int? _selectedGuestId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool usesExpandedPresentation =
        PveAppleLayout.usesExpandedPresentation(context);
    final bool usesDesktopInspector =
        Theme.of(context).platform == TargetPlatform.macOS &&
        PveAppleLayout.usesWidePresentation(context);
    final ClusterOverviewSnapshot? snapshot =
        widget.overviewController.snapshot;
    final List<PveGuest> guests = List<PveGuest>.of(
      snapshot?.guests ?? const <PveGuest>[],
    )..sort(_compareGuests);

    return PvePrimaryScrollView(
      title: 'Guests',
      showsSliverNavigationBar: widget.showsSliverNavigationBar,
      navigationLeading: widget.navigationLeading,
      navigationTrailing: widget.navigationTrailing,
      onRefresh: widget.onRefresh,
      slivers: <Widget>[
        if (snapshot == null)
          SliverFillRemaining(
            hasScrollBody: false,
            child: ClusterLoadStateView(
              controller: widget.overviewController,
              loadingLabel: 'Loading guests',
              onRetry: widget.onRefresh,
            ),
          )
        else
          PveCenteredSliver(
            maxWidth: 980,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: _buildGuestContent(
              context,
              guests,
              usesExpandedPresentation: usesExpandedPresentation,
              usesDesktopInspector: usesDesktopInspector,
            ),
          ),
      ],
    );
  }

  Widget _buildGuestContent(
    BuildContext context,
    List<PveGuest> guests, {
    required bool usesExpandedPresentation,
    required bool usesDesktopInspector,
  }) {
    final List<PveGuest> visibleGuests = guests
        .where(_matchesFilter)
        .where(_matchesSearch)
        .toList(growable: false);
    final List<PveGuest> workloads = guests
        .where((PveGuest guest) => !guest.isTemplate)
        .toList(growable: false);
    final int runningCount = workloads
        .where((PveGuest guest) => guest.isRunning)
        .length;
    final int virtualMachineCount = workloads
        .where((PveGuest guest) => guest.kind == GuestKind.virtualMachine)
        .length;
    final int containerCount = workloads.length - virtualMachineCount;
    final Widget filter = PveSlidingSegmentedControl<_GuestFilter>(
      key: const ValueKey<String>('guest-status-filter'),
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
        _GuestFilter.templates: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('Templates'),
        ),
      },
      onValueChanged: (_GuestFilter? value) {
        if (value != null) {
          setState(() => _filter = value);
        }
      },
    );
    final Widget search = CupertinoSearchTextField(
      controller: _searchController,
      placeholder: 'Search guests',
      onChanged: (_) => setState(() {}),
      onSubmitted: (_) => setState(() {}),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (widget.overviewController.errorMessage != null) ...<Widget>[
          ClusterRefreshFailureBanner(
            message: widget.overviewController.errorMessage!,
            onRetry: widget.onRefresh,
          ),
          const SizedBox(height: 12),
        ],
        PveMetricStrip(
          items: <PveMetricStripItem>[
            PveMetricStripItem(
              label: 'Workloads',
              value: '${workloads.length}',
              icon: CupertinoIcons.cube_box,
            ),
            PveMetricStripItem(
              label: 'Running',
              value: '$runningCount',
              icon: CupertinoIcons.play_fill,
              color: PveAppleColors.success(context),
            ),
            PveMetricStripItem(
              label: 'Virtual machines',
              value: '$virtualMachineCount',
              icon: CupertinoIcons.desktopcomputer,
            ),
            PveMetricStripItem(
              label: 'Containers',
              value: '$containerCount',
              icon: CupertinoIcons.cube_box_fill,
            ),
          ],
        ),
        if (usesExpandedPresentation) ...<Widget>[
          const SizedBox(height: 16),
          GuestInventoryInsights(guests: guests),
          const SizedBox(height: 24),
        ] else
          const SizedBox(height: 20),
        const PveSectionTitle(title: 'Guest inventory'),
        const SizedBox(height: 12),
        PveWideControlBar(primary: search, secondary: filter),
        Align(
          alignment: Alignment.centerRight,
          child: CupertinoButton(
            key: const ValueKey<String>('guest-inventory-sort'),
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            onPressed: () => _showSortPicker(context),
            child: Text('Sort: ${_sort.label}'),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _inventoryCountLabel(
            visibleCount: visibleGuests.length,
            totalCount: guests.length,
          ),
          key: const ValueKey<String>('guest-inventory-result-count'),
          style: PveAppleText.secondary(context),
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
        else if (usesExpandedPresentation)
          _buildExpandedInventory(
            visibleGuests,
            usesDesktopInspector: usesDesktopInspector,
          )
        else
          CupertinoListSection.insetGrouped(
            margin: EdgeInsets.zero,
            children: visibleGuests
                .map(
                  (PveGuest guest) => _GuestListItem(
                    guest: guest,
                    onTap: () => _showGuest(guest),
                  ),
                )
                .toList(growable: false),
          ),
        if (!usesExpandedPresentation) ...<Widget>[
          const SizedBox(height: 24),
          const PveSectionTitle(title: 'Workload analysis'),
          const SizedBox(height: 12),
          GuestInventoryInsights(guests: guests),
        ],
      ],
    );
  }

  Widget _buildExpandedInventory(
    List<PveGuest> visibleGuests, {
    required bool usesDesktopInspector,
  }) {
    final PveGuest selectedGuest = visibleGuests.firstWhere(
      (PveGuest guest) => guest.vmid == _selectedGuestId,
      orElse: () => visibleGuests.first,
    );
    final Widget cards = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool twoColumns = constraints.maxWidth >= 700;
        final double cardWidth = twoColumns
            ? (constraints.maxWidth - 12) / 2
            : constraints.maxWidth;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: visibleGuests
              .map(
                (PveGuest guest) => SizedBox(
                  width: cardWidth,
                  child: _GuestCard(
                    guest: guest,
                    selected:
                        usesDesktopInspector &&
                        guest.vmid == selectedGuest.vmid,
                    onTap: usesDesktopInspector
                        ? () => setState(() => _selectedGuestId = guest.vmid)
                        : () => _showGuest(guest),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
    if (!usesDesktopInspector) return cards;
    return PveInspectorLayout(
      primary: cards,
      inspector: _GuestInventoryInspector(
        guest: selectedGuest,
        onOpenDetails: () => _showGuest(selectedGuest),
      ),
    );
  }

  void _showGuest(PveGuest guest) {
    final List<String> backupStorageNames = widget
        .overviewController
        .snapshot!
        .storages
        .where((ClusterStorage storage) => _isAvailableBackupStorage(storage))
        .map((ClusterStorage storage) => storage.name)
        .toList(growable: false);
    showGuestDetailSheet(
      context,
      guest: guest,
      session: widget.session,
      onGuestPowerAction: widget.onGuestPowerAction,
      backupStorageNames: backupStorageNames,
    );
  }

  bool _matchesFilter(PveGuest guest) => switch (_filter) {
    _GuestFilter.all => true,
    _GuestFilter.running => !guest.isTemplate && guest.isRunning,
    _GuestFilter.stopped => !guest.isTemplate && !guest.isRunning,
    _GuestFilter.templates => guest.isTemplate,
  };

  int _compareGuests(PveGuest left, PveGuest right) {
    if (left.isTemplate != right.isTemplate) {
      return left.isTemplate ? 1 : -1;
    }
    final int result = switch (_sort) {
      _GuestInventorySort.status => _statusRank(
        left,
      ).compareTo(_statusRank(right)),
      _GuestInventorySort.name => left.title.toLowerCase().compareTo(
        right.title.toLowerCase(),
      ),
      _GuestInventorySort.host => left.node.compareTo(right.node),
      _GuestInventorySort.uptime => (right.uptimeSeconds ?? -1).compareTo(
        left.uptimeSeconds ?? -1,
      ),
      _GuestInventorySort.resource => _resourceUse(
        right,
      ).compareTo(_resourceUse(left)),
    };
    return result == 0
        ? left.title.toLowerCase().compareTo(right.title.toLowerCase())
        : result;
  }

  int _statusRank(PveGuest guest) => guest.isRunning ? 0 : 1;

  double _resourceUse(PveGuest guest) {
    final double memory =
        _resourceFraction(guest.memoryBytes, guest.memoryLimitBytes) ?? -1;
    return guest.cpuFraction ?? memory;
  }

  Future<void> _showSortPicker(BuildContext context) async {
    final _GuestInventorySort? sort =
        await showCupertinoModalPopup<_GuestInventorySort>(
          context: context,
          builder: (BuildContext popupContext) => CupertinoActionSheet(
            title: const Text('Sort guest inventory'),
            actions: _GuestInventorySort.values
                .map(
                  (_GuestInventorySort value) => CupertinoActionSheetAction(
                    isDefaultAction: value == _sort,
                    onPressed: () => Navigator.of(popupContext).pop(value),
                    child: Text(value.label),
                  ),
                )
                .toList(growable: false),
            cancelButton: CupertinoActionSheetAction(
              onPressed: () => Navigator.of(popupContext).pop(),
              child: const Text('Cancel'),
            ),
          ),
        );
    if (sort != null && mounted) {
      setState(() => _sort = sort);
    }
  }

  bool _isAvailableBackupStorage(ClusterStorage storage) {
    final bool supportsBackup = storage.content
        .toLowerCase()
        .split(',')
        .map((String item) => item.trim())
        .contains('backup');
    return supportsBackup &&
        (!storage.hasAvailabilityTelemetry || storage.isAvailable);
  }

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

class _GuestCard extends StatelessWidget {
  const _GuestCard({
    required this.guest,
    required this.onTap,
    this.selected = false,
  });

  final PveGuest guest;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final Color statusColor = guest.isTemplate
        ? PveAppleColors.primary(context)
        : guest.isRunning
        ? PveAppleColors.success(context)
        : PveAppleColors.secondaryLabel(context);
    return Semantics(
      selected: selected,
      label:
          '${guest.title}, ${guest.kind.label} ${guest.vmid} on ${guest.node}',
      child: PveInsetGroup(
        key: ValueKey<String>('ipad-guest-card-${guest.vmid}'),
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        color: selected
            ? PveAppleColors.primary(context).withValues(alpha: 0.09)
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: PveAppleColors.primary(
                      context,
                    ).withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SizedBox.square(
                    dimension: 40,
                    child: Icon(
                      guest.kind == GuestKind.virtualMachine
                          ? CupertinoIcons.desktopcomputer
                          : CupertinoIcons.cube_box_fill,
                      size: 20,
                      color: PveAppleColors.primary(context),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(guest.title, style: PveAppleText.title3(context)),
                      const SizedBox(height: 3),
                      Text(
                        '${guest.kind.shortLabel} ${guest.vmid} · ${guest.node}',
                        style: PveAppleText.caption(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  guest.isTemplate ? 'Template' : _statusLabel(guest.status),
                  style: PveAppleText.caption(
                    context,
                  ).copyWith(color: statusColor, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),
                Icon(
                  CupertinoIcons.chevron_forward,
                  size: 14,
                  color: PveAppleColors.secondaryLabel(context),
                ),
              ],
            ),
            const SizedBox(height: 17),
            Row(
              children: <Widget>[
                Expanded(
                  child: _GuestCardMeter(
                    label: 'CPU',
                    value: formatPvePercent(guest.cpuFraction),
                    progress: guest.cpuFraction,
                    color: PveAppleColors.primary(context),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _GuestCardMeter(
                    label: 'Memory',
                    value: _resourcePercent(
                      guest.memoryBytes,
                      guest.memoryLimitBytes,
                    ),
                    progress: _resourceFraction(
                      guest.memoryBytes,
                      guest.memoryLimitBytes,
                    ),
                    color: PveAppleColors.primary(context),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _GuestCardMeter(
                    label: 'Disk',
                    value: _resourcePercent(
                      guest.diskBytes,
                      guest.diskLimitBytes,
                    ),
                    progress: _resourceFraction(
                      guest.diskBytes,
                      guest.diskLimitBytes,
                    ),
                    color: PveAppleColors.primary(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GuestInventoryInspector extends StatefulWidget {
  const _GuestInventoryInspector({
    required this.guest,
    required this.onOpenDetails,
  });

  final PveGuest guest;
  final VoidCallback onOpenDetails;

  @override
  State<_GuestInventoryInspector> createState() =>
      _GuestInventoryInspectorState();
}

class _GuestInventoryInspectorState extends State<_GuestInventoryInspector> {
  String? _copiedLabel;

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) setState(() => _copiedLabel = label);
  }

  @override
  Widget build(BuildContext context) {
    final PveGuest guest = widget.guest;
    final String status = guest.isTemplate
        ? 'Template'
        : _statusLabel(guest.status);
    return CupertinoContextMenu(
      actions: <Widget>[
        CupertinoContextMenuAction(
          child: const Text('Copy guest ID'),
          onPressed: () {
            Navigator.of(context).pop();
            _copy('${guest.vmid}', 'Guest ID');
          },
        ),
        CupertinoContextMenuAction(
          child: const Text('Copy host'),
          onPressed: () {
            Navigator.of(context).pop();
            _copy(guest.node, 'Host');
          },
        ),
      ],
      child: PveInsetGroup(
        key: ValueKey<String>('desktop-guest-inspector-${guest.vmid}'),
        padding: const EdgeInsets.all(18),
        semanticLabel: 'Guest inspector for ${guest.title}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text('Selected guest', style: PveAppleText.caption(context)),
            const SizedBox(height: 4),
            Text(guest.title, style: PveAppleText.title2(context)),
            const SizedBox(height: 6),
            Text(
              '${guest.kind.label} ${guest.vmid} · $status',
              style: PveAppleText.secondary(context),
            ),
            const SizedBox(height: 18),
            _InspectorValue(label: 'Host', value: guest.node),
            _InspectorValue(
              label: 'CPU now',
              value: formatPvePercent(guest.cpuFraction),
            ),
            _InspectorValue(
              label: 'Memory now',
              value: _resourcePercent(
                guest.memoryBytes,
                guest.memoryLimitBytes,
              ),
            ),
            _InspectorValue(
              label: 'Disk now',
              value: _resourcePercent(guest.diskBytes, guest.diskLimitBytes),
            ),
            _InspectorValue(
              label: 'Uptime',
              value: formatPveUptime(guest.uptimeSeconds),
            ),
            const SizedBox(height: 12),
            CupertinoButton.filled(
              onPressed: widget.onOpenDetails,
              child: const Text('Open operational details'),
            ),
            const SizedBox(height: 6),
            CupertinoButton(
              onPressed: () => _copy('${guest.vmid}', 'Guest ID'),
              child: Text(
                _copiedLabel == 'Guest ID'
                    ? 'Guest ID copied'
                    : 'Copy guest ID',
              ),
            ),
            CupertinoButton(
              onPressed: () => _copy(guest.node, 'Host'),
              child: Text(_copiedLabel == 'Host' ? 'Host copied' : 'Copy host'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InspectorValue extends StatelessWidget {
  const _InspectorValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: <Widget>[
        Expanded(child: Text(label, style: PveAppleText.caption(context))),
        Text(value, style: PveAppleText.body(context)),
      ],
    ),
  );
}

class _GuestCardMeter extends StatelessWidget {
  const _GuestCardMeter({
    required this.label,
    required this.value,
    required this.progress,
    required this.color,
  });

  final String label;
  final String value;
  final double? progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text(label, style: PveAppleText.caption(context))),
            Text(value, style: PveAppleText.caption(context)),
          ],
        ),
        const SizedBox(height: 6),
        PveProgressBar(value: progress, color: color),
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
    final Color statusColor = guest.isTemplate
        ? PveAppleColors.primary(context)
        : guest.isRunning
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

enum _GuestFilter { all, running, stopped, templates }

enum _GuestInventorySort {
  status('Status'),
  name('Name'),
  host('Host'),
  uptime('Uptime'),
  resource('Resource use');

  const _GuestInventorySort(this.label);

  final String label;
}

String _inventoryCountLabel({
  required int visibleCount,
  required int totalCount,
}) {
  final String noun = totalCount == 1 ? 'guest' : 'guests';
  if (visibleCount == totalCount) {
    return 'Showing all $totalCount $noun';
  }
  return 'Showing $visibleCount of $totalCount $noun';
}

String _statusLabel(String status) {
  if (status.isEmpty) {
    return 'Unknown';
  }
  return '${status[0].toUpperCase()}${status.substring(1)}';
}

double? _resourceFraction(int? used, int? capacity) {
  if (used == null || capacity == null || capacity <= 0) {
    return null;
  }
  return used / capacity;
}

String _resourcePercent(int? used, int? capacity) {
  return formatPvePercent(_resourceFraction(used, capacity));
}
