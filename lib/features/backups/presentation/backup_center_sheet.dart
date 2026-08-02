import 'package:flutter/cupertino.dart';

import '../../../core/api/proxmox_session.dart';
import '../../../core/presentation/pve_apple_ui.dart';
import '../../../core/presentation/pve_modal_sheet.dart';
import '../../../core/presentation/pve_value_format.dart';
import '../../cluster_overview/domain/cluster_overview_snapshot.dart';
import '../application/backup_center_controller.dart';
import '../data/proxmox_backup_repository.dart';
import '../domain/pve_backup_center.dart';

Future<void> showBackupCenterSheet(
  BuildContext context, {
  required ProxmoxSession session,
  required ClusterOverviewSnapshot overview,
}) {
  return showPveModalSheet<void>(
    context: context,
    scrollableBuilder:
        (BuildContext sheetContext, ScrollController scrollController) =>
            _BackupCenterSheet(
              session: session,
              overview: overview,
              scrollController: scrollController,
            ),
  );
}

class _BackupCenterSheet extends StatefulWidget {
  const _BackupCenterSheet({
    required this.session,
    required this.overview,
    required this.scrollController,
  });

  final ProxmoxSession session;
  final ClusterOverviewSnapshot overview;
  final ScrollController scrollController;

  @override
  State<_BackupCenterSheet> createState() => _BackupCenterSheetState();
}

class _BackupCenterSheetState extends State<_BackupCenterSheet> {
  late final BackupCenterController _controller;

  @override
  void initState() {
    super.initState();
    _controller = BackupCenterController(
      repository: ProxmoxBackupRepository(),
      session: widget.session,
      overview: widget.overview,
    );
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: PveAppleColors.page(context),
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Backup Center'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 7),
              minimumSize: const Size(44, 36),
              onPressed: _controller.load,
              child: const Icon(CupertinoIcons.refresh, size: 19),
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
          animation: _controller,
          builder: (BuildContext context, Widget? child) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 850),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: _buildContent(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return switch (_controller.state) {
      BackupCenterLoadState.loading => const PveLoadingState(
        label: 'Loading backup center',
      ),
      BackupCenterLoadState.failed => PveEmptyState(
        icon: CupertinoIcons.archivebox,
        title: 'Backup data unavailable',
        message: _controller.errorMessage ?? 'Backup data could not be loaded.',
        actionLabel: 'Try Again',
        onAction: _controller.load,
        destructive: true,
      ),
      BackupCenterLoadState.ready => _BackupCenterContent(
        snapshot: _controller.snapshot!,
        scrollController: widget.scrollController,
      ),
    };
  }
}

class _BackupCenterContent extends StatelessWidget {
  const _BackupCenterContent({
    required this.snapshot,
    required this.scrollController,
  });

  final PveBackupCenterSnapshot snapshot;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final int protectedCount = snapshot.records
        .where((PveBackupRecord record) => record.protected)
        .length;
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: 32),
      children: <Widget>[
        Text('Data protection', style: PveAppleText.title2(context)),
        const SizedBox(height: 6),
        Text(
          'Run an on-demand backup from a guest. This center shows configured destinations, schedules, and backup copies without changing retention policy.',
          style: PveAppleText.secondary(context),
        ),
        const SizedBox(height: 18),
        PveMetricStrip(
          items: <PveMetricStripItem>[
            PveMetricStripItem(
              label: 'Destinations',
              value: '${snapshot.destinations.length}',
              icon: CupertinoIcons.archivebox,
            ),
            PveMetricStripItem(
              label: 'Schedules',
              value: '${snapshot.schedules.length}',
              icon: CupertinoIcons.calendar,
            ),
            PveMetricStripItem(
              label: 'Copies',
              value: '${snapshot.records.length}',
              icon: CupertinoIcons.doc_on_doc,
            ),
            PveMetricStripItem(
              label: 'Protected',
              value: '$protectedCount',
              icon: CupertinoIcons.lock_shield,
              color: protectedCount > 0
                  ? PveAppleColors.success(context)
                  : PveAppleColors.secondaryLabel(context),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const PveSectionTitle(title: 'Backup destinations'),
        const SizedBox(height: 8),
        _BackupDestinationCard(destinations: snapshot.destinations),
        const SizedBox(height: 24),
        const PveSectionTitle(title: 'Scheduled backups'),
        const SizedBox(height: 8),
        _BackupSchedulesCard(schedules: snapshot.schedules),
        const SizedBox(height: 24),
        const PveSectionTitle(title: 'Latest backup copies'),
        const SizedBox(height: 8),
        _BackupRecordsCard(records: snapshot.records),
        const SizedBox(height: 24),
        const PveSectionTitle(title: 'Recent backup activity'),
        const SizedBox(height: 8),
        _BackupTasksCard(tasks: snapshot.recentTasks),
      ],
    );
  }
}

class _BackupDestinationCard extends StatelessWidget {
  const _BackupDestinationCard({required this.destinations});

  final List<PveBackupDestination> destinations;

  @override
  Widget build(BuildContext context) {
    if (destinations.isEmpty) {
      return const PveInsetGroup(
        padding: EdgeInsets.all(16),
        child: Text(
          'No Proxmox storage configured for backup content was reported.',
        ),
      );
    }
    return PveInsetGroup(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          for (int index = 0; index < destinations.length; index++) ...<Widget>[
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(CupertinoIcons.archivebox),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          destinations[index].name,
                          style: PveAppleText.title3(context),
                        ),
                      ),
                      PveStatusPill(
                        label: destinations[index].isAvailable
                            ? 'Available'
                            : 'Unavailable',
                        color: destinations[index].isAvailable
                            ? PveAppleColors.success(context)
                            : PveAppleColors.destructive(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          destinations[index].capacityBytes == null
                              ? 'Capacity not reported'
                              : '${formatPveBytes(destinations[index].usedBytes)} used of ${formatPveBytes(destinations[index].capacityBytes)}',
                          style: PveAppleText.caption(context),
                        ),
                      ),
                      Text(
                        destinations[index].storage.shared ? 'Shared' : 'Local',
                        style: PveAppleText.caption(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  PveProgressBar(
                    value: destinations[index].usageFraction,
                    color: destinations[index].isAvailable
                        ? PveAppleColors.primary(context)
                        : PveAppleColors.destructive(context),
                  ),
                ],
              ),
            ),
            if (index < destinations.length - 1)
              const PveRowSeparator(leadingIndent: 16),
          ],
        ],
      ),
    );
  }
}

class _BackupSchedulesCard extends StatelessWidget {
  const _BackupSchedulesCard({required this.schedules});

  final List<PveBackupSchedule> schedules;

  @override
  Widget build(BuildContext context) {
    if (schedules.isEmpty) {
      return const PveInsetGroup(
        padding: EdgeInsets.all(16),
        child: Text(
          'No backup schedules were reported, or this account cannot read them.',
        ),
      );
    }
    return PveInsetGroup(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          for (int index = 0; index < schedules.length; index++) ...<Widget>[
            PveListRow(
              leading: const Icon(CupertinoIcons.calendar),
              title: Text(schedules[index].id),
              subtitle: Text(_scheduleSubtitle(schedules[index])),
              trailing: PveStatusPill(
                label: schedules[index].enabled == false ? 'Paused' : 'Active',
                color: schedules[index].enabled == false
                    ? PveAppleColors.secondaryLabel(context)
                    : PveAppleColors.success(context),
              ),
            ),
            if (index < schedules.length - 1) const PveRowSeparator(),
          ],
        ],
      ),
    );
  }
}

class _BackupRecordsCard extends StatelessWidget {
  const _BackupRecordsCard({required this.records});

  final List<PveBackupRecord> records;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const PveInsetGroup(
        padding: EdgeInsets.all(16),
        child: Text(
          'No backup copies were reported by the configured destinations.',
        ),
      );
    }
    return PveInsetGroup(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          for (int index = 0; index < records.length; index++) ...<Widget>[
            PveListRow(
              leading: Icon(
                records[index].protected
                    ? CupertinoIcons.lock_shield
                    : CupertinoIcons.archivebox,
              ),
              title: Text(_backupRecordTitle(records[index])),
              subtitle: Text(_backupRecordSubtitle(records[index])),
              trailing: Text(
                formatPveBytes(records[index].sizeBytes),
                style: PveAppleText.caption(context),
              ),
            ),
            if (index < records.length - 1) const PveRowSeparator(),
          ],
        ],
      ),
    );
  }
}

class _BackupTasksCard extends StatelessWidget {
  const _BackupTasksCard({required this.tasks});

  final List<ClusterTask> tasks;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const PveInsetGroup(
        padding: EdgeInsets.all(16),
        child: Text('No recent backup tasks were reported.'),
      );
    }
    return PveInsetGroup(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          for (int index = 0; index < tasks.length; index++) ...<Widget>[
            PveListRow(
              leading: Icon(
                _taskIcon(tasks[index]),
                color: _taskColor(context, tasks[index]),
              ),
              title: Text('${tasks[index].type} on ${tasks[index].node}'),
              subtitle: Text(
                '${tasks[index].user} · ${formatPveDateTime(tasks[index].startedAt)}',
              ),
              trailing: PveStatusPill(
                label: _taskLabel(tasks[index]),
                color: _taskColor(context, tasks[index]),
              ),
            ),
            if (index < tasks.length - 1) const PveRowSeparator(),
          ],
        ],
      ),
    );
  }
}

String _scheduleSubtitle(PveBackupSchedule schedule) {
  final List<String> fragments = <String>[
    if (schedule.storage != null) schedule.storage!,
    if (schedule.schedule != null) schedule.schedule!,
    if (schedule.guestSelection != null) 'Guests: ${schedule.guestSelection!}',
  ];
  return fragments.isEmpty
      ? 'Schedule details not reported'
      : fragments.join(' · ');
}

String _backupRecordTitle(PveBackupRecord record) {
  final int? guestId = record.guestId;
  return guestId == null ? record.volumeId : 'Guest $guestId';
}

String _backupRecordSubtitle(PveBackupRecord record) {
  final List<String> fragments = <String>[
    record.storage,
    formatPveDateTime(record.createdAt),
    if (record.format != null) record.format!,
    if (record.protected) 'Protected',
  ];
  return fragments.join(' · ');
}

IconData _taskIcon(ClusterTask task) => switch (task.state) {
  ClusterTaskState.running => CupertinoIcons.arrow_2_circlepath,
  ClusterTaskState.successful => CupertinoIcons.check_mark_circled_solid,
  ClusterTaskState.failed => CupertinoIcons.xmark_circle_fill,
  ClusterTaskState.unknown => CupertinoIcons.question_circle,
};

Color _taskColor(BuildContext context, ClusterTask task) =>
    switch (task.state) {
      ClusterTaskState.running => PveAppleColors.warning(context),
      ClusterTaskState.successful => PveAppleColors.success(context),
      ClusterTaskState.failed => PveAppleColors.destructive(context),
      ClusterTaskState.unknown => PveAppleColors.secondaryLabel(context),
    };

String _taskLabel(ClusterTask task) => switch (task.state) {
  ClusterTaskState.running => 'Running',
  ClusterTaskState.successful => 'Completed',
  ClusterTaskState.failed => 'Failed',
  ClusterTaskState.unknown => 'Unknown',
};
