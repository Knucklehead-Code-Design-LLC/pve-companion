import 'package:flutter/cupertino.dart';

import '../../../core/api/proxmox_session.dart';
import '../../../core/presentation/pve_apple_ui.dart';
import '../../../core/presentation/pve_value_format.dart';
import '../../backups/domain/pve_backup_center.dart';
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
    final List<ClusterStorage> visibleStorages =
        storages.where(_matchesFilter).toList(growable: false)
          ..sort(_compareStorageRisk);
    final int fullyAvailableCount = storages
        .where(
          (ClusterStorage storage) =>
              storage.hasAvailabilityTelemetry && storage.isFullyAvailable,
        )
        .length;
    final int availabilityReportedCount = storages
        .where((ClusterStorage storage) => storage.hasAvailabilityTelemetry)
        .length;
    final List<ClusterStorage> storagesWithCapacity = storages
        .where(
          (ClusterStorage storage) =>
              storage.usedBytes != null && storage.capacityBytes != null,
        )
        .toList(growable: false);
    final bool hasCapacityTelemetry = storagesWithCapacity.isNotEmpty;
    final int aggregateUsedBytes = storagesWithCapacity.fold<int>(
      0,
      (int total, ClusterStorage storage) => total + storage.usedBytes!,
    );
    final int aggregateAvailableBytes = storagesWithCapacity.fold<int>(
      0,
      (int total, ClusterStorage storage) => total + storage.availableBytes!,
    );
    final List<ClusterStorage> backupDestinations = storages
        .where(PveBackupDestination.supportsBackupContent)
        .toList(growable: false);
    final List<ClusterStorage> availableBackupDestinations = backupDestinations
        .where(PveBackupDestination.isAvailableForExecution)
        .toList(growable: false);
    final int backupDestinationsWithUnknownAvailability = backupDestinations
        .where((ClusterStorage storage) => !storage.hasAvailabilityTelemetry)
        .length;
    final PveMetricStripItem availabilityCoverageMetric =
        _availabilityCoverageMetric(
          context,
          fullyAvailableCount: fullyAvailableCount,
          availabilityReportedCount: availabilityReportedCount,
        );
    final Widget filter = PveSlidingSegmentedControl<_StorageFilter>(
      key: const ValueKey<String>('storage-locality-filter'),
      groupValue: _filter,
      semanticLabels: const <_StorageFilter, String>{
        _StorageFilter.all: 'All storage pools',
        _StorageFilter.shared: 'Shared storage pools',
        _StorageFilter.local: 'Local storage pools',
      },
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
              label: 'Configured pools',
              value: '${storages.length}',
              icon: CupertinoIcons.tray_full_fill,
              scope: 'Reported by this server',
            ),
            availabilityCoverageMetric,
            PveMetricStripItem(
              label: 'Capacity used now',
              value: hasCapacityTelemetry
                  ? formatPveBytes(aggregateUsedBytes)
                  : '—',
              icon: CupertinoIcons.chart_pie_fill,
              scope: _capacityCoverageLabel(
                reportingCount: storagesWithCapacity.length,
                totalCount: storages.length,
              ),
            ),
            PveMetricStripItem(
              label: 'Capacity free now',
              value: hasCapacityTelemetry
                  ? formatPveBytes(aggregateAvailableBytes)
                  : '—',
              icon: CupertinoIcons.tray,
              scope: _capacityCoverageLabel(
                reportingCount: storagesWithCapacity.length,
                totalCount: storages.length,
              ),
            ),
          ],
        ),
        if (widget.session != null) ...<Widget>[
          const SizedBox(height: 24),
          PveSectionHeader(
            title: 'Data protection',
            actionLabel: 'Open Backup Center',
            actionSemanticsLabel: 'Open Backup Center',
            onAction: _showBackupCenter,
          ),
          PveInsetGroup(
            onTap: _showBackupCenter,
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                      const SizedBox(height: 5),
                      _BackupDestinationReadiness(
                        configuredDestinations: backupDestinations.length,
                        availableDestinations:
                            availableBackupDestinations.length,
                        unknownAvailabilityDestinations:
                            backupDestinationsWithUnknownAvailability,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Destination availability is based on the latest storage report. Open Backup Center to review schedules, copies, and backup activity.',
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
        const SizedBox(height: 8),
        Text(
          _storageCountLabel(
            visibleCount: visibleStorages.length,
            totalCount: storages.length,
          ),
          key: const ValueKey<String>('storage-result-count'),
          style: PveAppleText.secondary(context),
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
              final bool twoColumns =
                  constraints.maxWidth >=
                  PveAppleLayout.controlBarStackBreakpoint;
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

  int _compareStorageRisk(ClusterStorage left, ClusterStorage right) {
    final int riskComparison = _storageRiskRank(
      left,
    ).compareTo(_storageRiskRank(right));
    if (riskComparison != 0) {
      return riskComparison;
    }
    final double leftUsage = left.usageFraction ?? -1;
    final double rightUsage = right.usageFraction ?? -1;
    final int usageComparison = rightUsage.compareTo(leftUsage);
    if (usageComparison != 0) {
      return usageComparison;
    }
    return left.name.toLowerCase().compareTo(right.name.toLowerCase());
  }

  Future<void> _showBackupCenter() async {
    final ProxmoxSession? session = widget.session;
    final ClusterOverviewSnapshot? overview = widget.controller.snapshot;
    if (session == null || overview == null) {
      return;
    }
    await showBackupCenterSheet(context, session: session, overview: overview);
  }
}

PveMetricStripItem _availabilityCoverageMetric(
  BuildContext context, {
  required int fullyAvailableCount,
  required int availabilityReportedCount,
}) {
  if (availabilityReportedCount == 0) {
    return PveMetricStripItem(
      label: 'Availability coverage',
      value: '—',
      icon: CupertinoIcons.check_mark_circled_solid,
      color: PveAppleColors.secondaryLabel(context),
      scope: 'No pool status reported',
    );
  }
  if (fullyAvailableCount == availabilityReportedCount) {
    return PveMetricStripItem(
      label: 'Availability coverage',
      value: '$fullyAvailableCount/$availabilityReportedCount',
      icon: CupertinoIcons.check_mark_circled_solid,
      color: PveAppleColors.success(context),
      scope: 'Fully available now',
    );
  }
  return PveMetricStripItem(
    label: 'Availability coverage',
    value: '$fullyAvailableCount/$availabilityReportedCount',
    icon: CupertinoIcons.check_mark_circled_solid,
    color: PveAppleColors.warning(context),
    scope: 'Fully available now',
  );
}

class _BackupDestinationReadiness extends StatelessWidget {
  const _BackupDestinationReadiness({
    required this.configuredDestinations,
    required this.availableDestinations,
    required this.unknownAvailabilityDestinations,
  });

  final int configuredDestinations;
  final int availableDestinations;
  final int unknownAvailabilityDestinations;

  @override
  Widget build(BuildContext context) {
    final _BackupDestinationReadinessPresentation presentation = _presentation(
      context,
    );
    return Row(
      children: <Widget>[
        PveStatusPill(label: presentation.label, color: presentation.color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            presentation.detail,
            style: PveAppleText.caption(context),
          ),
        ),
      ],
    );
  }

  _BackupDestinationReadinessPresentation _presentation(BuildContext context) {
    if (availableDestinations > 0) {
      final String noun = availableDestinations == 1
          ? 'available destination'
          : 'available destinations';
      return _BackupDestinationReadinessPresentation(
        label: 'Destination ready',
        detail: '$availableDestinations $noun reported.',
        color: PveAppleColors.success(context),
      );
    }
    if (unknownAvailabilityDestinations > 0) {
      final String verb = unknownAvailabilityDestinations == 1
          ? 'configured destination does'
          : 'configured destinations do';
      return _BackupDestinationReadinessPresentation(
        label: 'Availability not reported',
        detail:
            '$unknownAvailabilityDestinations $verb not report availability.',
        color: PveAppleColors.secondaryLabel(context),
      );
    }
    if (configuredDestinations > 0) {
      final String verb = configuredDestinations == 1
          ? 'configured destination is'
          : 'configured destinations are';
      return _BackupDestinationReadinessPresentation(
        label: 'Destination needs attention',
        detail:
            '$configuredDestinations $verb not currently reported available.',
        color: PveAppleColors.warning(context),
      );
    }
    return _BackupDestinationReadinessPresentation(
      label: 'Backup setup needed',
      detail: 'No storage reports backup content.',
      color: PveAppleColors.destructive(context),
    );
  }
}

class _BackupDestinationReadinessPresentation {
  const _BackupDestinationReadinessPresentation({
    required this.label,
    required this.detail,
    required this.color,
  });

  final String label;
  final String detail;
  final Color color;
}

class _StorageCard extends StatelessWidget {
  const _StorageCard({required this.storage});

  final ClusterStorage storage;

  @override
  Widget build(BuildContext context) {
    final double? usageFraction = storage.usageFraction;
    final Color accent = _storageAccent(context, storage, usageFraction);
    final _StorageAvailabilityPresentation availability =
        _storageAvailabilityPresentation(context, storage);
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
                label: availability.label,
                color: availability.color,
              ),
            ],
          ),
          const SizedBox(height: 17),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Capacity used now',
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

Color _storageAccent(
  BuildContext context,
  ClusterStorage storage,
  double? usageFraction,
) {
  if (storage.hasAvailabilityTelemetry && !storage.isAvailable) {
    return PveAppleColors.destructive(context);
  }
  if (storage.isPartiallyAvailable) {
    return PveAppleColors.warning(context);
  }
  if (usageFraction != null && usageFraction >= 0.9) {
    return PveAppleColors.destructive(context);
  }
  if (usageFraction != null && usageFraction >= 0.75) {
    return PveAppleColors.warning(context);
  }
  return PveAppleColors.primary(context);
}

_StorageAvailabilityPresentation _storageAvailabilityPresentation(
  BuildContext context,
  ClusterStorage storage,
) {
  if (!storage.hasAvailabilityTelemetry) {
    return _StorageAvailabilityPresentation(
      label: 'Not reported',
      color: PveAppleColors.secondaryLabel(context),
    );
  }
  if (storage.isFullyAvailable) {
    return _StorageAvailabilityPresentation(
      label: 'Available',
      color: PveAppleColors.success(context),
    );
  }
  if (storage.isPartiallyAvailable) {
    return _StorageAvailabilityPresentation(
      label: 'Partially available',
      color: PveAppleColors.warning(context),
    );
  }
  return _StorageAvailabilityPresentation(
    label: 'Unavailable',
    color: PveAppleColors.destructive(context),
  );
}

class _StorageAvailabilityPresentation {
  const _StorageAvailabilityPresentation({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;
}

int _storageRiskRank(ClusterStorage storage) {
  if (storage.hasAvailabilityTelemetry && !storage.isAvailable) {
    return 0;
  }
  if (storage.isPartiallyAvailable) {
    return 1;
  }
  final double? usage = storage.usageFraction;
  if (usage != null && usage >= 0.9) {
    return 2;
  }
  if (usage != null && usage >= 0.75) {
    return 3;
  }
  if (!storage.hasAvailabilityTelemetry || usage == null) {
    return 4;
  }
  return 5;
}

String _storageCountLabel({
  required int visibleCount,
  required int totalCount,
}) {
  final String noun = totalCount == 1 ? 'pool' : 'pools';
  if (visibleCount == totalCount) {
    return 'Showing all $totalCount storage $noun · highest risk first';
  }
  return 'Showing $visibleCount of $totalCount storage $noun · highest risk first';
}

String _capacityCoverageLabel({
  required int reportingCount,
  required int totalCount,
}) {
  if (reportingCount == 0) {
    return 'No capacity reported';
  }
  return '$reportingCount of $totalCount '
      '${totalCount == 1 ? 'pool reports capacity' : 'pools report capacity'}';
}
