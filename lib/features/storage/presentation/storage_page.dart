import 'package:flutter/cupertino.dart';

import '../../../core/api/proxmox_session.dart';
import '../../../core/presentation/pve_apple_ui.dart';
import '../../../core/presentation/pve_value_format.dart';
import '../../backups/presentation/backup_center_sheet.dart';
import '../../cluster_overview/application/cluster_overview_controller.dart';
import '../../cluster_overview/domain/cluster_overview_snapshot.dart';
import '../../cluster_overview/presentation/cluster_load_state_view.dart';
import 'storage_insights.dart';

class StoragePage extends StatefulWidget {
  const StoragePage({
    super.key,
    required this.controller,
    required this.onRefresh,
    this.showsSliverNavigationBar = true,
    this.navigationLeading,
    this.navigationTrailing,
    this.session,
  });

  final ClusterOverviewController controller;
  final Future<void> Function() onRefresh;
  final bool showsSliverNavigationBar;
  final Widget? navigationLeading;
  final Widget? navigationTrailing;
  final ProxmoxSession? session;

  @override
  State<StoragePage> createState() => _StoragePageState();
}

class _StoragePageState extends State<StoragePage> {
  _StorageFilter _filter = _StorageFilter.all;

  @override
  Widget build(BuildContext context) {
    final bool usesExpandedPresentation =
        PveAppleLayout.usesExpandedPresentation(context);
    final ClusterOverviewSnapshot? snapshot = widget.controller.snapshot;
    return PvePrimaryScrollView(
      title: 'Storage',
      showsSliverNavigationBar: widget.showsSliverNavigationBar,
      navigationLeading: widget.navigationLeading,
      navigationTrailing: widget.navigationTrailing,
      onRefresh: widget.onRefresh,
      slivers: <Widget>[
        if (snapshot == null)
          SliverFillRemaining(
            hasScrollBody: false,
            child: ClusterLoadStateView(
              controller: widget.controller,
              loadingLabel: 'Loading storage',
              onRetry: widget.onRefresh,
            ),
          )
        else
          PveCenteredSliver(
            maxWidth: 1100,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: _buildContent(
              context,
              snapshot.storages,
              usesExpandedPresentation: usesExpandedPresentation,
            ),
          ),
      ],
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<ClusterStorage> storages, {
    required bool usesExpandedPresentation,
  }) {
    final List<ClusterStorage> visibleStorages = storages
        .where(_matchesFilter)
        .toList(growable: false);
    final int fullyAvailableCount = storages
        .where(
          (ClusterStorage storage) =>
              storage.hasAvailabilityTelemetry && storage.isFullyAvailable,
        )
        .length;
    final int availabilityReportedCount = storages
        .where((ClusterStorage storage) => storage.hasAvailabilityTelemetry)
        .length;
    final bool hasCapacityTelemetry = storages.any(
      (ClusterStorage storage) =>
          storage.usedBytes != null && storage.capacityBytes != null,
    );
    final int aggregateUsedBytes = storages.fold<int>(
      0,
      (int total, ClusterStorage storage) => total + (storage.usedBytes ?? 0),
    );
    final int aggregateAvailableBytes = storages.fold<int>(
      0,
      (int total, ClusterStorage storage) =>
          total + (storage.availableBytes ?? 0),
    );
    final Widget filter = PveSlidingSegmentedControl<_StorageFilter>(
      key: const ValueKey<String>('storage-locality-filter'),
      groupValue: _filter,
      children: const <_StorageFilter, Widget>{
        _StorageFilter.all: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('All'),
        ),
        _StorageFilter.shared: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('Shared'),
        ),
        _StorageFilter.local: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text('Local'),
        ),
      },
      onValueChanged: (_StorageFilter? value) {
        if (value != null) {
          setState(() => _filter = value);
        }
      },
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (widget.controller.errorMessage != null) ...<Widget>[
          ClusterRefreshFailureBanner(
            message: widget.controller.errorMessage!,
            onRetry: widget.onRefresh,
          ),
          const SizedBox(height: 12),
        ],
        PveMetricStrip(
          items: <PveMetricStripItem>[
            PveMetricStripItem(
              label: 'Configured',
              value: '${storages.length}',
              icon: CupertinoIcons.tray_full_fill,
            ),
            PveMetricStripItem(
              label: 'Available',
              value: availabilityReportedCount == 0
                  ? '—'
                  : '$fullyAvailableCount/$availabilityReportedCount',
              icon: CupertinoIcons.check_mark_circled_solid,
              color: availabilityReportedCount == 0
                  ? PveAppleColors.secondaryLabel(context)
                  : fullyAvailableCount == availabilityReportedCount
                  ? PveAppleColors.success(context)
                  : PveAppleColors.warning(context),
            ),
            PveMetricStripItem(
              label: 'Used',
              value: hasCapacityTelemetry
                  ? formatPveBytes(aggregateUsedBytes)
                  : '—',
              icon: CupertinoIcons.chart_pie_fill,
            ),
            PveMetricStripItem(
              label: 'Free',
              value: hasCapacityTelemetry
                  ? formatPveBytes(aggregateAvailableBytes)
                  : '—',
              icon: CupertinoIcons.tray,
            ),
          ],
        ),
        if (widget.session != null) ...<Widget>[
          const SizedBox(height: 24),
          PveSectionHeader(
            title: 'Data protection',
            actionLabel: 'Backup Center',
            actionSemanticsLabel: 'Open Backup Center',
            onAction: _showBackupCenter,
          ),
          PveInsetGroup(
            onTap: _showBackupCenter,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: PveAppleColors.primary(
                      context,
                    ).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SizedBox.square(
                    dimension: 38,
                    child: Icon(
                      CupertinoIcons.archivebox,
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
                      Text(
                        'Backup Center',
                        style: PveAppleText.title3(context),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Review backup destinations, schedules, copies, and activity.',
                        style: PveAppleText.secondary(context),
                      ),
                    ],
                  ),
                ),
                Icon(
                  CupertinoIcons.chevron_forward,
                  size: 15,
                  color: PveAppleColors.secondaryLabel(context),
                ),
              ],
            ),
          ),
        ],
        if (usesExpandedPresentation) ...<Widget>[
          const SizedBox(height: 16),
          StorageInsights(storages: storages),
          const SizedBox(height: 24),
        ] else
          const SizedBox(height: 20),
        PveWideControlBar(
          primary: const PveSectionTitle(title: 'Storage pools'),
          secondary: filter,
        ),
        const SizedBox(height: 16),
        if (storages.isEmpty)
          const PveInsetGroup(
            padding: EdgeInsets.all(20),
            child: Text('No storage was reported by this server.'),
          )
        else if (visibleStorages.isEmpty)
          PveInsetGroup(
            padding: const EdgeInsets.all(22),
            child: Text(
              'No storage matches this filter.',
              textAlign: TextAlign.center,
              style: PveAppleText.secondary(context),
            ),
          )
        else
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool twoColumns = constraints.maxWidth >= 700;
              final double cardWidth = twoColumns
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: visibleStorages
                    .map(
                      (ClusterStorage storage) => SizedBox(
                        width: cardWidth,
                        child: _StorageCard(storage: storage),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        if (!usesExpandedPresentation) ...<Widget>[
          const SizedBox(height: 24),
          const PveSectionTitle(title: 'Storage analysis'),
          const SizedBox(height: 12),
          StorageInsights(storages: storages),
        ],
        if (storages.any(
          (ClusterStorage storage) => storage.resources.isNotEmpty,
        )) ...<Widget>[
          const SizedBox(height: 24),
          const PveSectionTitle(title: 'Node coverage'),
          const SizedBox(height: 12),
          StorageNodeCoverage(storages: storages),
        ],
      ],
    );
  }

  bool _matchesFilter(ClusterStorage storage) => switch (_filter) {
    _StorageFilter.all => true,
    _StorageFilter.shared => storage.shared,
    _StorageFilter.local => !storage.shared,
  };

  Future<void> _showBackupCenter() async {
    final ProxmoxSession? session = widget.session;
    final ClusterOverviewSnapshot? overview = widget.controller.snapshot;
    if (session == null || overview == null) {
      return;
    }
    await showBackupCenterSheet(context, session: session, overview: overview);
  }
}

class _StorageCard extends StatelessWidget {
  const _StorageCard({required this.storage});

  final ClusterStorage storage;

  @override
  Widget build(BuildContext context) {
    final double? usageFraction = storage.usageFraction;
    final bool hasAvailability = storage.hasAvailabilityTelemetry;
    final Color accent = hasAvailability && !storage.isAvailable
        ? PveAppleColors.destructive(context)
        : storage.isPartiallyAvailable
        ? PveAppleColors.warning(context)
        : usageFraction != null && usageFraction >= 0.9
        ? PveAppleColors.destructive(context)
        : usageFraction != null && usageFraction >= 0.75
        ? PveAppleColors.warning(context)
        : PveAppleColors.primary(context);
    return PveInsetGroup(
      key: ValueKey<String>('ipad-storage-card-${storage.name}'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SizedBox.square(
                  dimension: 40,
                  child: Icon(
                    CupertinoIcons.tray_full_fill,
                    size: 20,
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(storage.name, style: PveAppleText.title3(context)),
                    const SizedBox(height: 3),
                    Text(
                      '${storage.type} · ${storage.shared ? 'Shared' : 'Local'}',
                      style: PveAppleText.caption(context),
                    ),
                  ],
                ),
              ),
              PveStatusPill(
                label: !hasAvailability
                    ? 'Not reported'
                    : storage.isFullyAvailable
                    ? 'Available'
                    : storage.isPartiallyAvailable
                    ? 'Partially available'
                    : 'Unavailable',
                color: !hasAvailability
                    ? PveAppleColors.secondaryLabel(context)
                    : storage.isFullyAvailable
                    ? PveAppleColors.success(context)
                    : storage.isPartiallyAvailable
                    ? PveAppleColors.warning(context)
                    : PveAppleColors.destructive(context),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Capacity used',
                  style: PveAppleText.caption(context),
                ),
              ),
              Text(
                usageFraction == null
                    ? 'Not reported'
                    : '${formatPveBytes(storage.usedBytes)} / '
                          '${formatPveBytes(storage.capacityBytes)}',
                style: PveAppleText.caption(
                  context,
                ).copyWith(color: accent, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 7),
          PveProgressBar(value: usageFraction, color: accent),
          const SizedBox(height: 12),
          Text(
            '${storage.content} · ${storage.reportedNodeCount} '
            '${storage.reportedNodeCount == 1 ? 'node' : 'nodes'} reporting',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: PveAppleText.caption(context),
          ),
        ],
      ),
    );
  }
}

enum _StorageFilter { all, shared, local }
