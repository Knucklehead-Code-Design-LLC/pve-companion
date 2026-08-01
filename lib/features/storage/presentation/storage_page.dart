import 'package:flutter/cupertino.dart';

import '../../../core/presentation/pve_apple_ui.dart';
import '../../cluster_overview/application/cluster_overview_controller.dart';
import '../../cluster_overview/domain/cluster_overview_snapshot.dart';

class StoragePage extends StatefulWidget {
  const StoragePage({
    super.key,
    required this.controller,
    required this.onRefresh,
    this.showsSliverNavigationBar = true,
    this.navigationLeading,
    this.navigationTrailing,
  });

  final ClusterOverviewController controller;
  final Future<void> Function() onRefresh;
  final bool showsSliverNavigationBar;
  final Widget? navigationLeading;
  final Widget? navigationTrailing;

  @override
  State<StoragePage> createState() => _StoragePageState();
}

class _StoragePageState extends State<StoragePage> {
  _StorageFilter _filter = _StorageFilter.all;

  @override
  Widget build(BuildContext context) {
    final bool usesIpadPresentation = PveAppleLayout.usesIpadPresentation(
      context,
    );
    final ClusterOverviewSnapshot? snapshot = widget.controller.snapshot;
    return PvePrimaryScrollView(
      title: 'Storage',
      showsSliverNavigationBar: widget.showsSliverNavigationBar,
      navigationLeading: widget.navigationLeading,
      navigationTrailing: widget.navigationTrailing,
      onRefresh: widget.onRefresh,
      slivers: <Widget>[
        if (snapshot == null)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: PveLoadingState(label: 'Loading storage'),
          )
        else
          PveCenteredSliver(
            maxWidth: 900,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: _buildContent(
              context,
              snapshot.storages,
              usesIpadPresentation: usesIpadPresentation,
            ),
          ),
      ],
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<ClusterStorage> storages, {
    required bool usesIpadPresentation,
  }) {
    final List<ClusterStorage> visibleStorages = storages
        .where(_matchesFilter)
        .toList(growable: false);
    final int sharedCount = storages
        .where((ClusterStorage storage) => storage.shared)
        .length;
    final int localCount = storages.length - sharedCount;
    final int typeCount = storages
        .map((ClusterStorage storage) => storage.type)
        .toSet()
        .length;
    final Widget filter = PveSlidingSegmentedControl<_StorageFilter>(
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
        if (usesIpadPresentation)
          PveMetricStrip(
            items: <PveMetricStripItem>[
              PveMetricStripItem(
                label: 'Configured',
                value: '${storages.length}',
                icon: CupertinoIcons.tray_full_fill,
              ),
              PveMetricStripItem(
                label: 'Shared',
                value: '$sharedCount',
                icon: CupertinoIcons.arrow_2_circlepath,
              ),
              PveMetricStripItem(
                label: 'Local',
                value: '$localCount',
                icon: CupertinoIcons.device_desktop,
              ),
              PveMetricStripItem(
                label: 'Storage types',
                value: '$typeCount',
                icon: CupertinoIcons.square_stack_3d_up_fill,
              ),
            ],
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '${storages.length} configured · $sharedCount shared',
              style: PveAppleText.caption(context),
            ),
          ),
        const SizedBox(height: 12),
        if (usesIpadPresentation)
          PveWideControlBar(
            primary: Text('Storage pools', style: PveAppleText.title2(context)),
            secondary: filter,
          )
        else
          filter,
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
        else if (usesIpadPresentation)
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
          )
        else
          CupertinoListSection.insetGrouped(
            margin: EdgeInsets.zero,
            children: visibleStorages
                .map((ClusterStorage storage) => _StorageRow(storage: storage))
                .toList(growable: false),
          ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Capacity and utilization appear only when the connected Proxmox '
            'API account is allowed to report them.',
            style: PveAppleText.caption(context),
          ),
        ),
      ],
    );
  }

  bool _matchesFilter(ClusterStorage storage) => switch (_filter) {
    _StorageFilter.all => true,
    _StorageFilter.shared => storage.shared,
    _StorageFilter.local => !storage.shared,
  };
}

class _StorageCard extends StatelessWidget {
  const _StorageCard({required this.storage});

  final ClusterStorage storage;

  @override
  Widget build(BuildContext context) {
    final Color accent = PveAppleColors.primary(context);
    return PveInsetGroup(
      key: ValueKey<String>('ipad-storage-card-${storage.name}'),
      padding: const EdgeInsets.all(16),
      child: Row(
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
                Text(storage.type, style: PveAppleText.caption(context)),
                const SizedBox(height: 2),
                Text(storage.content, style: PveAppleText.caption(context)),
              ],
            ),
          ),
          Text(
            storage.shared ? 'Shared' : 'Local',
            style: PveAppleText.caption(context).copyWith(
              color: storage.shared
                  ? accent
                  : PveAppleColors.secondaryLabel(context),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StorageRow extends StatelessWidget {
  const _StorageRow({required this.storage});

  final ClusterStorage storage;

  @override
  Widget build(BuildContext context) {
    return CupertinoListTile(
      leading: DecoratedBox(
        decoration: BoxDecoration(
          color: PveAppleColors.primary(context).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Icon(
            CupertinoIcons.tray_full_fill,
            size: 19,
            color: PveAppleColors.primary(context),
          ),
        ),
      ),
      title: Text(storage.name),
      subtitle: Text('${storage.type} · ${storage.content}'),
      additionalInfo: Text(
        storage.shared ? 'Shared' : 'Local',
        style: PveAppleText.caption(context).copyWith(
          color: storage.shared
              ? PveAppleColors.primary(context)
              : PveAppleColors.secondaryLabel(context),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

enum _StorageFilter { all, shared, local }
