import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

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
        _BackupReadinessSummary(snapshot: snapshot),
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
        _BackupSchedulesCard(
          schedules: snapshot.schedules,
          dataState: snapshot.scheduleDataState,
        ),
        const SizedBox(height: 24),
        const PveSectionTitle(title: 'Latest backup copies'),
        const SizedBox(height: 8),
        _BackupRecordsCard(
          records: snapshot.records,
          dataState: snapshot.recordDataState,
        ),
        const SizedBox(height: 24),
        const PveSectionTitle(title: 'Recent backup activity'),
        const SizedBox(height: 8),
        _BackupTasksCard(tasks: snapshot.recentTasks),
      ],
    );
  }
}

class _BackupReadinessSummary extends StatelessWidget {
  const _BackupReadinessSummary({required this.snapshot});

  final PveBackupCenterSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final PveBackupReadiness readiness = snapshot.readiness;
    final ({String title, String detail, Color color, IconData icon})
    content = switch (readiness) {
      PveBackupReadiness.noDestination => (
        title: 'No backup destination reported',
        detail:
            'No storage accepting backup content is reported. Set up a destination before expecting scheduled copies.',
        color: PveAppleColors.warning(context),
        icon: CupertinoIcons.archivebox,
      ),
      PveBackupReadiness.configurationUnreadable => (
        title: 'Backup configuration unreadable',
        detail:
            'This account cannot read backup schedules, so readiness cannot be verified.',
        color: PveAppleColors.warning(context),
        icon: CupertinoIcons.lock,
      ),
      PveBackupReadiness.configurationUnavailable => (
        title: 'Backup configuration unavailable',
        detail:
            'The server did not make backup schedules available, so readiness cannot be verified.',
        color: PveAppleColors.warning(context),
        icon: CupertinoIcons.exclamationmark_triangle,
      ),
      PveBackupReadiness.noSchedule => (
        title: 'No backup schedule reported',
        detail:
            'A destination is reported, but no backup schedule is currently reported.',
        color: PveAppleColors.warning(context),
        icon: CupertinoIcons.calendar_badge_minus,
      ),
      PveBackupReadiness.copiesUnreadable => (
        title: 'Backup copies unreadable',
        detail:
            'This account cannot read stored backup copies. Access is needed to verify reported copies.',
        color: PveAppleColors.warning(context),
        icon: CupertinoIcons.lock,
      ),
      PveBackupReadiness.copiesUnavailable => (
        title: 'Backup copies unavailable',
        detail:
            'The server did not make stored backup copies available, so no copy coverage can be verified.',
        color: PveAppleColors.warning(context),
        icon: CupertinoIcons.exclamationmark_triangle,
      ),
      PveBackupReadiness.copiesPartiallyReported => (
        title: 'Backup copies only partially reported',
        detail:
            '${snapshot.records.length} ${snapshot.records.length == 1 ? 'copy is' : 'copies are'} reported, but one or more destinations could not be checked. Reported copies do not prove restore readiness.',
        color: PveAppleColors.warning(context),
        icon: CupertinoIcons.exclamationmark_triangle,
      ),
      PveBackupReadiness.copiesReported => (
        title: 'Backup copies reported',
        detail:
            '${snapshot.records.length} ${snapshot.records.length == 1 ? 'copy is' : 'copies are'} reported. Reported copies do not prove restore readiness.',
        color: PveAppleColors.success(context),
        icon: CupertinoIcons.check_mark_circled,
      ),
      PveBackupReadiness.copiesNotReported => (
        title: 'No backup copies reported',
        detail:
            'Backup configuration is reported, but no copies are currently reported by readable destinations.',
        color: PveAppleColors.warning(context),
        icon: CupertinoIcons.exclamationmark_triangle,
      ),
    };
    return PveInsetGroup(
      key: const ValueKey<String>('backup-readiness-summary'),
      color: content.color.withValues(alpha: 0.08),
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(content.icon, color: content.color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(content.title, style: PveAppleText.title3(context)),
                const SizedBox(height: 4),
                Text(content.detail, style: PveAppleText.secondary(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BackupDestinationCard extends StatelessWidget {
  const _BackupDestinationCard({required this.destinations});

  final List<PveBackupDestination> destinations;

  @override
  Widget build(BuildContext context) {
    if (destinations.isEmpty) {
      return const _BackupSetupChecklist();
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

class _BackupSetupChecklist extends StatefulWidget {
  const _BackupSetupChecklist();

  @override
  State<_BackupSetupChecklist> createState() => _BackupSetupChecklistState();
}

class _BackupSetupChecklistState extends State<_BackupSetupChecklist> {
  bool _copiedStoragePath = false;
  bool _copiedBackupPath = false;

  @override
  Widget build(BuildContext context) {
    return PveInsetGroup(
      color: PveAppleColors.warning(context).withValues(alpha: 0.08),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                CupertinoIcons.archivebox,
                color: PveAppleColors.warning(context),
              ),
              const SizedBox(width: 10),
              Text(
                'Set up backup storage',
                style: PveAppleText.title3(context),
              ),
              const Spacer(),
              PveStatusPill(
                label: 'Not configured',
                color: PveAppleColors.warning(context),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'This app cannot create storage or schedules. Complete these safe setup steps in the Proxmox web interface, then return here to verify what is reported.',
            style: PveAppleText.secondary(context),
          ),
          const SizedBox(height: 14),
          const _BackupSetupStep(
            number: '1',
            title: 'Open Datacenter → Storage',
            detail:
                'Add or enable a storage target that accepts backup content.',
          ),
          const SizedBox(height: 10),
          const _BackupSetupStep(
            number: '2',
            title: 'Open Datacenter → Backup',
            detail: 'Create a schedule and select the storage destination.',
          ),
          const SizedBox(height: 10),
          const _BackupSetupStep(
            number: '3',
            title: 'Return and refresh Backup Center',
            detail:
                'PVE Companion will show the destinations, schedules, and copies your account can read.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                minimumSize: const Size(44, 36),
                onPressed: () => _copyPath(
                  label: 'Datacenter → Storage',
                  onCopied: () => setState(() => _copiedStoragePath = true),
                ),
                child: Text(
                  _copiedStoragePath
                      ? 'Storage path copied'
                      : 'Copy storage path',
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                minimumSize: const Size(44, 36),
                onPressed: () => _copyPath(
                  label: 'Datacenter → Backup',
                  onCopied: () => setState(() => _copiedBackupPath = true),
                ),
                child: Text(
                  _copiedBackupPath ? 'Backup path copied' : 'Copy backup path',
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'These buttons copy navigation text; they do not open or change Proxmox.',
            style: PveAppleText.caption(context),
          ),
        ],
      ),
    );
  }

  Future<void> _copyPath({
    required String label,
    required VoidCallback onCopied,
  }) async {
    await Clipboard.setData(ClipboardData(text: label));
    if (mounted) {
      onCopied();
    }
  }
}

class _BackupSetupStep extends StatelessWidget {
  const _BackupSetupStep({
    required this.number,
    required this.title,
    required this.detail,
  });

  final String number;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: PveAppleColors.primary(context).withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: SizedBox.square(
            dimension: 24,
            child: Center(
              child: Text(number, style: PveAppleText.caption(context)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: PveAppleText.body(context)),
              const SizedBox(height: 2),
              Text(detail, style: PveAppleText.secondary(context)),
            ],
          ),
        ),
      ],
    );
  }
}

class _BackupSchedulesCard extends StatelessWidget {
  const _BackupSchedulesCard({
    required this.schedules,
    required this.dataState,
  });

  final List<PveBackupSchedule> schedules;
  final PveBackupDataState dataState;

  @override
  Widget build(BuildContext context) {
    if (schedules.isEmpty) {
      return PveInsetGroup(
        padding: EdgeInsets.all(16),
        child: Text(
          _emptyBackupDataMessage(
            dataState,
            emptyMessage: 'No backup schedules are configured.',
            notConfiguredMessage: 'Backup schedules are not configured.',
            unavailableMessage:
                'Backup schedules are not available from this server.',
            permissionMessage:
                'This account cannot read backup schedules. Ask an administrator to grant backup job access.',
            partiallyAvailableMessage:
                'Some backup schedules could not be read. Refresh to try again.',
          ),
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
  const _BackupRecordsCard({required this.records, required this.dataState});

  final List<PveBackupRecord> records;
  final PveBackupDataState dataState;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return PveInsetGroup(
        padding: EdgeInsets.all(16),
        child: Text(
          _emptyBackupDataMessage(
            dataState,
            emptyMessage:
                'No backup copies were found in the configured destinations.',
            notConfiguredMessage:
                'Configure a storage target that accepts backup content to view backup copies.',
            unavailableMessage:
                'Backup copies could not be loaded from the configured destinations.',
            permissionMessage:
                'This account cannot read backup copies. Ask an administrator to grant storage-content access.',
            partiallyAvailableMessage:
                'Some configured destinations could not be read, so this list may be incomplete.',
          ),
        ),
      );
    }
    return PveInsetGroup(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          if (dataState == PveBackupDataState.partiallyAvailable) ...<Widget>[
            PveListRow(
              leading: Icon(
                CupertinoIcons.exclamationmark_triangle,
                color: PveAppleColors.warning(context),
              ),
              title: const Text('Some backup destinations could not be read'),
              subtitle: const Text(
                'The copies shown may be incomplete. Check storage-content access, then refresh.',
              ),
            ),
            const PveRowSeparator(),
          ],
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

String _emptyBackupDataMessage(
  PveBackupDataState dataState, {
  required String emptyMessage,
  required String notConfiguredMessage,
  required String unavailableMessage,
  required String permissionMessage,
  required String partiallyAvailableMessage,
}) => switch (dataState) {
  PveBackupDataState.available => emptyMessage,
  PveBackupDataState.partiallyAvailable => partiallyAvailableMessage,
  PveBackupDataState.unavailable => unavailableMessage,
  PveBackupDataState.permissionLimited => permissionMessage,
  PveBackupDataState.notConfigured => notConfiguredMessage,
};

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
