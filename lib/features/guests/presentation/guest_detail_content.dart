import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;

import '../../../core/presentation/proxmox_task_status_card.dart';
import '../../../core/presentation/pve_apple_ui.dart';
import '../../../core/presentation/pve_value_format.dart';
import '../application/guest_detail_controller.dart';
import '../domain/pve_guest.dart';

enum GuestSnapshotAction { rollback, delete }

class GuestDetailContent extends StatelessWidget {
  const GuestDetailContent({
    super.key,
    required this.controller,
    required this.scrollController,
    required this.backupStorageNames,
    required this.onPowerAction,
    required this.onCreateSnapshot,
    required this.onSnapshotAction,
    required this.onRunBackup,
    required this.onEditConfiguration,
    this.onOpenConsole,
  });

  final GuestDetailController controller;
  final ScrollController scrollController;
  final List<String> backupStorageNames;
  final Future<void> Function(GuestPowerAction action) onPowerAction;
  final Future<void> Function() onCreateSnapshot;
  final Future<void> Function(
    PveGuestSnapshot snapshot,
    GuestSnapshotAction action,
  )
  onSnapshotAction;
  final Future<void> Function() onRunBackup;
  final Future<void> Function() onEditConfiguration;
  final Future<void> Function()? onOpenConsole;

  @override
  Widget build(BuildContext context) {
    final PveGuest guest = controller.guest;
    final PveGuestDetails details = controller.details!;
    final bool controlsDisabled = controller.hasRunningTask || guest.isTemplate;
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: 32),
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '${guest.kind.label} ${guest.vmid} · ${guest.node}',
            style: PveAppleText.caption(context),
          ),
        ),
        const SizedBox(height: 10),
        _GuestDetailColumns(
          guest: guest,
          details: details,
          controller: controller,
          controlsDisabled: controlsDisabled,
          backupStorageNames: backupStorageNames,
          onPowerAction: onPowerAction,
          onCreateSnapshot: onCreateSnapshot,
          onSnapshotAction: onSnapshotAction,
          onRunBackup: onRunBackup,
          onEditConfiguration: onEditConfiguration,
          onOpenConsole: onOpenConsole,
        ),
      ],
    );
  }
}

class _GuestDetailColumns extends StatelessWidget {
  const _GuestDetailColumns({
    required this.guest,
    required this.details,
    required this.controller,
    required this.controlsDisabled,
    required this.backupStorageNames,
    required this.onPowerAction,
    required this.onCreateSnapshot,
    required this.onSnapshotAction,
    required this.onRunBackup,
    required this.onEditConfiguration,
    required this.onOpenConsole,
  });

  final PveGuest guest;
  final PveGuestDetails details;
  final GuestDetailController controller;
  final bool controlsDisabled;
  final List<String> backupStorageNames;
  final Future<void> Function(GuestPowerAction action) onPowerAction;
  final Future<void> Function() onCreateSnapshot;
  final Future<void> Function(PveGuestSnapshot, GuestSnapshotAction)
  onSnapshotAction;
  final Future<void> Function() onRunBackup;
  final Future<void> Function() onEditConfiguration;
  final Future<void> Function()? onOpenConsole;

  @override
  Widget build(BuildContext context) {
    final List<Widget> primarySections = <Widget>[
      _GuestStatusCard(runtime: details.runtime, guest: guest),
      if (!guest.isTemplate && onOpenConsole != null)
        _GuestConsoleCard(onOpenConsole: onOpenConsole!),
      if (controller.activeTask != null)
        ProxmoxTaskStatusCard(task: controller.activeTask!),
      if (controller.errorMessage != null)
        _GuestInlineError(message: controller.errorMessage!),
      if (guest.isTemplate)
        const _GuestTemplateNotice()
      else
        _GuestPowerSection(
          guest: guest,
          runningAction: controller.runningAction,
          disabled: controlsDisabled,
          onPowerAction: onPowerAction,
        ),
      _GuestSnapshotsSection(
        snapshots: details.snapshots,
        enabled: !controlsDisabled,
        onCreateSnapshot: onCreateSnapshot,
        onSnapshotAction: onSnapshotAction,
      ),
    ];
    final List<Widget> secondarySections = <Widget>[
      _GuestBackupSection(
        destinationCount: backupStorageNames.length,
        enabled: !controlsDisabled,
        onRunBackup: onRunBackup,
      ),
      _GuestConfigurationSection(
        configuration: details.configuration,
        enabled: !controlsDisabled,
        onEditConfiguration: onEditConfiguration,
      ),
      _GuestActivitySection(tasks: details.recentTasks),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 760) {
          return _DetailSectionColumn(
            sections: <Widget>[...primarySections, ...secondarySections],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: _DetailSectionColumn(sections: primarySections)),
            const SizedBox(width: 24),
            Expanded(child: _DetailSectionColumn(sections: secondarySections)),
          ],
        );
      },
    );
  }
}

class _DetailSectionColumn extends StatelessWidget {
  const _DetailSectionColumn({required this.sections});

  final List<Widget> sections;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (int index = 0; index < sections.length; index++) ...<Widget>[
          if (index > 0) const SizedBox(height: 24),
          sections[index],
        ],
      ],
    );
  }
}

class _GuestPowerSection extends StatelessWidget {
  const _GuestPowerSection({
    required this.guest,
    required this.runningAction,
    required this.disabled,
    required this.onPowerAction,
  });

  final PveGuest guest;
  final GuestPowerAction? runningAction;
  final bool disabled;
  final Future<void> Function(GuestPowerAction action) onPowerAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const PveSectionTitle(title: 'Guest power'),
        const SizedBox(height: 8),
        _GuestPowerControls(
          guest: guest,
          runningAction: runningAction,
          disabled: disabled,
          onPowerAction: onPowerAction,
        ),
      ],
    );
  }
}

class _GuestTemplateNotice extends StatelessWidget {
  const _GuestTemplateNotice();

  @override
  Widget build(BuildContext context) {
    return PveInsetGroup(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            CupertinoIcons.doc_on_doc,
            size: 20,
            color: PveAppleColors.secondaryLabel(context),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Template', style: PveAppleText.title3(context)),
                const SizedBox(height: 2),
                Text(
                  'Templates are read-only. Power controls and the interactive console are unavailable.',
                  style: PveAppleText.secondary(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestSnapshotsSection extends StatelessWidget {
  const _GuestSnapshotsSection({
    required this.snapshots,
    required this.enabled,
    required this.onCreateSnapshot,
    required this.onSnapshotAction,
  });

  final List<PveGuestSnapshot> snapshots;
  final bool enabled;
  final Future<void> Function() onCreateSnapshot;
  final Future<void> Function(PveGuestSnapshot, GuestSnapshotAction)
  onSnapshotAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PveSectionHeader(
          title: 'Snapshots',
          actionLabel: 'New',
          actionSemanticsLabel: 'Create a new snapshot',
          onAction: enabled ? () => onCreateSnapshot() : null,
        ),
        _GuestSnapshotsCard(
          snapshots: snapshots,
          enabled: enabled,
          onAction: onSnapshotAction,
        ),
      ],
    );
  }
}

class _GuestBackupSection extends StatelessWidget {
  const _GuestBackupSection({
    required this.destinationCount,
    required this.enabled,
    required this.onRunBackup,
  });

  final int destinationCount;
  final bool enabled;
  final Future<void> Function() onRunBackup;

  @override
  Widget build(BuildContext context) {
    final bool hasDestination = destinationCount > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PveSectionHeader(
          title: 'Backup',
          actionLabel: 'Back Up Now',
          actionSemanticsLabel: 'Run a guest backup',
          onAction: enabled && hasDestination ? () => onRunBackup() : null,
        ),
        _GuestBackupCard(
          destinationCount: destinationCount,
          enabled: enabled,
          onRunBackup: onRunBackup,
        ),
      ],
    );
  }
}

class _GuestConfigurationSection extends StatelessWidget {
  const _GuestConfigurationSection({
    required this.configuration,
    required this.enabled,
    required this.onEditConfiguration,
  });

  final Map<String, String> configuration;
  final bool enabled;
  final Future<void> Function() onEditConfiguration;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        PveSectionHeader(
          title: 'Configuration',
          actionLabel: 'Edit',
          actionSemanticsLabel: 'Edit safe guest configuration',
          onAction: enabled ? () => onEditConfiguration() : null,
        ),
        _GuestConfigurationCard(configuration: configuration),
      ],
    );
  }
}

class _GuestActivitySection extends StatelessWidget {
  const _GuestActivitySection({required this.tasks});

  final List<PveGuestTask> tasks;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const PveSectionTitle(title: 'Recent guest activity'),
        const SizedBox(height: 8),
        _GuestRecentTasksCard(tasks: tasks),
      ],
    );
  }
}

class _GuestInlineError extends StatelessWidget {
  const _GuestInlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return PveInsetGroup(
      color: PveAppleColors.destructive(context).withValues(alpha: 0.08),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            size: 17,
            color: PveAppleColors.destructive(context),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: PveAppleText.secondary(
                context,
              ).copyWith(color: PveAppleColors.destructive(context)),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestConsoleCard extends StatelessWidget {
  const _GuestConsoleCard({required this.onOpenConsole});

  final Future<void> Function() onOpenConsole;

  @override
  Widget build(BuildContext context) {
    return PveInsetGroup(
      onTap: onOpenConsole,
      semanticLabel: 'Open the guest console',
      color: PveAppleColors.primary(context).withValues(alpha: 0.1),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: PveAppleColors.primary(context).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: SizedBox.square(
              dimension: 38,
              child: Icon(
                CupertinoIcons.desktopcomputer,
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
                Text('Open Guest Console', style: PveAppleText.title3(context)),
                const SizedBox(height: 2),
                Text(
                  'Connect to this guest’s interactive console without leaving PVE Companion.',
                  style: PveAppleText.secondary(context),
                ),
              ],
            ),
          ),
          Icon(
            CupertinoIcons.chevron_forward,
            size: 18,
            color: PveAppleColors.secondaryLabel(context),
          ),
        ],
      ),
    );
  }
}

class _GuestPowerControls extends StatelessWidget {
  const _GuestPowerControls({
    required this.guest,
    required this.runningAction,
    required this.disabled,
    required this.onPowerAction,
  });

  final PveGuest guest;
  final GuestPowerAction? runningAction;
  final bool disabled;
  final Future<void> Function(GuestPowerAction action) onPowerAction;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton.tinted(
      key: const ValueKey<String>('guest-power-menu'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      minimumSize: const Size(44, 44),
      onPressed: disabled ? null : () => _showPowerActions(context),
      child: _PowerActionLabel(
        action: guest.isRunning
            ? GuestPowerAction.shutdown
            : GuestPowerAction.start,
        runningAction: runningAction,
        label: 'Power',
      ),
    );
  }

  Future<void> _showPowerActions(BuildContext context) async {
    final List<GuestPowerAction> actions = guest.isRunning
        ? <GuestPowerAction>[
            GuestPowerAction.shutdown,
            GuestPowerAction.reboot,
            GuestPowerAction.stop,
            if (GuestPowerAction.reset.supports(guest)) GuestPowerAction.reset,
          ]
        : <GuestPowerAction>[GuestPowerAction.start];
    final GuestPowerAction?
    selection = await showCupertinoModalPopup<GuestPowerAction>(
      context: context,
      builder: (BuildContext popupContext) => CupertinoActionSheet(
        title: const Text('Power actions'),
        message: const Text(
          'Normal actions are confirmed before they run. Force actions can interrupt writes and active users.',
        ),
        actions: actions
            .map(
              (GuestPowerAction action) => CupertinoActionSheetAction(
                isDestructiveAction: action.isPotentiallyDisruptive,
                onPressed: () => Navigator.of(popupContext).pop(action),
                child: Text(action.label),
              ),
            )
            .toList(growable: false),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(popupContext).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (selection != null) {
      await onPowerAction(selection);
    }
  }
}

class _GuestSnapshotsCard extends StatelessWidget {
  const _GuestSnapshotsCard({
    required this.snapshots,
    required this.enabled,
    required this.onAction,
  });

  final List<PveGuestSnapshot> snapshots;
  final bool enabled;
  final Future<void> Function(PveGuestSnapshot, GuestSnapshotAction) onAction;

  @override
  Widget build(BuildContext context) {
    if (snapshots.isEmpty) {
      return const PveInsetGroup(
        padding: EdgeInsets.all(16),
        child: Text('No snapshots are currently reported for this guest.'),
      );
    }
    return PveInsetGroup(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          for (int index = 0; index < snapshots.length; index++) ...<Widget>[
            _SnapshotRow(
              snapshot: snapshots[index],
              enabled: enabled,
              onAction: onAction,
            ),
            if (index < snapshots.length - 1) const PveRowSeparator(),
          ],
        ],
      ),
    );
  }
}

class _SnapshotRow extends StatelessWidget {
  const _SnapshotRow({
    required this.snapshot,
    required this.enabled,
    required this.onAction,
  });

  final PveGuestSnapshot snapshot;
  final bool enabled;
  final Future<void> Function(PveGuestSnapshot, GuestSnapshotAction) onAction;

  @override
  Widget build(BuildContext context) {
    return PveListRow(
      leading: const Icon(CupertinoIcons.camera),
      title: Text(snapshot.name),
      subtitle: Text(_snapshotSubtitle(snapshot)),
      trailing: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        minimumSize: const Size(44, 34),
        onPressed: enabled ? () => _showActions(context) : null,
        child: const Icon(CupertinoIcons.ellipsis_circle, size: 20),
      ),
    );
  }

  Future<void> _showActions(BuildContext context) async {
    final GuestSnapshotAction?
    action = await showCupertinoModalPopup<GuestSnapshotAction>(
      context: context,
      builder: (BuildContext popupContext) => CupertinoActionSheet(
        title: Text(snapshot.name),
        message: const Text(
          'Rolling back replaces the guest’s current state. Create a current recovery snapshot first if needed.',
        ),
        actions: <Widget>[
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () =>
                Navigator.of(popupContext).pop(GuestSnapshotAction.rollback),
            child: const Text('Roll Back to Snapshot'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () =>
                Navigator.of(popupContext).pop(GuestSnapshotAction.delete),
            child: const Text('Delete Snapshot'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(popupContext).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
    if (action != null) {
      await onAction(snapshot, action);
    }
  }
}

class _GuestBackupCard extends StatelessWidget {
  const _GuestBackupCard({
    required this.destinationCount,
    required this.enabled,
    required this.onRunBackup,
  });

  final int destinationCount;
  final bool enabled;
  final Future<void> Function() onRunBackup;

  @override
  Widget build(BuildContext context) {
    final bool hasDestination = destinationCount > 0;
    return PveInsetGroup(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              color: PveAppleColors.primary(context).withValues(alpha: 0.12),
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
                  hasDestination
                      ? '$destinationCount backup ${destinationCount == 1 ? 'destination' : 'destinations'} available'
                      : 'No backup destination available',
                  style: PveAppleText.body(context),
                ),
                const SizedBox(height: 2),
                Text(
                  hasDestination
                      ? 'Select a configured Proxmox backup storage and mode.'
                      : 'Add a storage with backup content in Proxmox to run an on-demand backup.',
                  style: PveAppleText.secondary(context),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
            minimumSize: const Size(44, 38),
            onPressed: enabled && hasDestination ? onRunBackup : null,
            child: const Icon(CupertinoIcons.play_circle, size: 21),
          ),
        ],
      ),
    );
  }
}

class _GuestConfigurationCard extends StatelessWidget {
  const _GuestConfigurationCard({required this.configuration});

  final Map<String, String> configuration;

  @override
  Widget build(BuildContext context) {
    if (configuration.isEmpty) {
      return const PveInsetGroup(
        padding: EdgeInsets.all(16),
        child: Text('No safe configuration fields were reported.'),
      );
    }
    return CupertinoFormSection.insetGrouped(
      margin: EdgeInsets.zero,
      children: configuration.entries
          .map(
            (MapEntry<String, String> entry) => CupertinoFormRow(
              prefix: Text(_configurationLabel(entry.key)),
              child: SelectableText(
                _configurationValue(entry.key, entry.value),
                textAlign: TextAlign.end,
                style: PveAppleText.secondary(context),
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _GuestRecentTasksCard extends StatelessWidget {
  const _GuestRecentTasksCard({required this.tasks});

  final List<PveGuestTask> tasks;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const PveInsetGroup(
        padding: EdgeInsets.all(16),
        child: Text('No recent guest activity was reported.'),
      );
    }
    return PveInsetGroup(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          for (int index = 0; index < tasks.length; index++) ...<Widget>[
            PveListRow(
              leading: Icon(_guestTaskIcon(tasks[index].state)),
              title: Text(tasks[index].type),
              subtitle: Text(
                '${formatPveDateTime(tasks[index].startedAt)} · ${_guestTaskDuration(tasks[index])}',
              ),
              trailing: PveStatusPill(
                label: _guestTaskStateLabel(tasks[index].state),
                color: _guestTaskColor(context, tasks[index].state),
              ),
            ),
            if (index < tasks.length - 1) const PveRowSeparator(),
          ],
        ],
      ),
    );
  }
}

class _GuestStatusCard extends StatelessWidget {
  const _GuestStatusCard({required this.runtime, required this.guest});

  final PveGuestRuntime runtime;
  final PveGuest guest;

  @override
  Widget build(BuildContext context) {
    final Color statusColor = runtime.isRunning
        ? PveAppleColors.success(context)
        : PveAppleColors.secondaryLabel(context);
    return PveInsetGroup(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SizedBox.square(
                  dimension: 40,
                  child: Icon(
                    guest.kind == GuestKind.virtualMachine
                        ? CupertinoIcons.desktopcomputer
                        : CupertinoIcons.cube_box_fill,
                    size: 20,
                    color: statusColor,
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
              PveStatusPill(
                label: _titleCase(runtime.status),
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 26,
            runSpacing: 16,
            children: <Widget>[
              _GuestMetric(
                label: 'CPU',
                value: formatPvePercent(runtime.cpuFraction),
              ),
              _GuestMetric(
                label: 'Memory',
                value:
                    '${formatPveBytes(runtime.memoryBytes)} / '
                    '${formatPveBytes(runtime.memoryLimitBytes)}',
              ),
              _GuestMetric(
                label: 'Disk',
                value:
                    '${formatPveBytes(runtime.diskBytes)} / '
                    '${formatPveBytes(runtime.diskLimitBytes)}',
              ),
              _GuestMetric(
                label: 'Uptime',
                value: formatPveUptime(runtime.uptimeSeconds),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GuestMetric extends StatelessWidget {
  const _GuestMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 125,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: PveAppleText.caption(context)),
          const SizedBox(height: 3),
          Text(value, style: PveAppleText.title3(context)),
        ],
      ),
    );
  }
}

class _PowerActionIcon extends StatelessWidget {
  const _PowerActionIcon({required this.action, required this.runningAction});

  final GuestPowerAction action;
  final GuestPowerAction? runningAction;

  @override
  Widget build(BuildContext context) {
    if (runningAction == action) {
      return const SizedBox(
        height: 18,
        width: 18,
        child: CupertinoActivityIndicator(),
      );
    }
    return Icon(switch (action) {
      GuestPowerAction.start => CupertinoIcons.play_arrow_solid,
      GuestPowerAction.shutdown => CupertinoIcons.power,
      GuestPowerAction.reboot => CupertinoIcons.arrow_clockwise,
      GuestPowerAction.stop => CupertinoIcons.stop_fill,
      GuestPowerAction.reset => CupertinoIcons.arrow_counterclockwise,
    }, size: 17);
  }
}

class _PowerActionLabel extends StatelessWidget {
  const _PowerActionLabel({
    required this.action,
    required this.runningAction,
    required this.label,
  });

  final GuestPowerAction action;
  final GuestPowerAction? runningAction;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _PowerActionIcon(action: action, runningAction: runningAction),
        const SizedBox(width: 7),
        Text(label),
      ],
    );
  }
}

String _snapshotSubtitle(PveGuestSnapshot snapshot) {
  final List<String> fragments = <String>[
    formatPveDateTime(snapshot.createdAt),
    if (snapshot.includesMemoryState) 'Memory state',
    if (snapshot.description?.trim().isNotEmpty == true) snapshot.description!,
  ];
  return fragments.join(' · ');
}

String _configurationLabel(String key) => switch (key) {
  'cores' => 'CPU cores',
  'memory' => 'Memory',
  'onboot' => 'Start at boot',
  'net0' => 'Network',
  'rootfs' => 'Root disk',
  'scsi0' => 'Disk',
  'description' => 'Description',
  _ => key,
};

String _configurationValue(String key, String value) {
  if (key == 'memory') {
    final int? memory = int.tryParse(value);
    return memory == null ? value : '$memory MiB';
  }
  if (key == 'onboot') {
    return switch (value.trim().toLowerCase()) {
      '1' || 'true' || 'yes' => 'On',
      '0' || 'false' || 'no' => 'Off',
      _ => value,
    };
  }
  return value;
}

IconData _guestTaskIcon(PveGuestTaskState state) => switch (state) {
  PveGuestTaskState.running => CupertinoIcons.arrow_2_circlepath,
  PveGuestTaskState.successful => CupertinoIcons.check_mark_circled_solid,
  PveGuestTaskState.failed => CupertinoIcons.xmark_circle_fill,
  PveGuestTaskState.unknown => CupertinoIcons.question_circle,
};

String _guestTaskStateLabel(PveGuestTaskState state) => switch (state) {
  PveGuestTaskState.running => 'Running',
  PveGuestTaskState.successful => 'Completed',
  PveGuestTaskState.failed => 'Failed',
  PveGuestTaskState.unknown => 'Unknown',
};

Color _guestTaskColor(BuildContext context, PveGuestTaskState state) =>
    switch (state) {
      PveGuestTaskState.running => PveAppleColors.warning(context),
      PveGuestTaskState.successful => PveAppleColors.success(context),
      PveGuestTaskState.failed => PveAppleColors.destructive(context),
      PveGuestTaskState.unknown => PveAppleColors.secondaryLabel(context),
    };

String _guestTaskDuration(PveGuestTask task) {
  if (task.endedAt == null) {
    return task.state == PveGuestTaskState.running
        ? 'In progress'
        : 'Duration unavailable';
  }
  if (task.startedAt == null || task.endedAt!.isBefore(task.startedAt!)) {
    return 'Duration unavailable';
  }
  final Duration duration = task.endedAt!.difference(task.startedAt!);
  if (duration.inHours > 0) {
    return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
  }
  if (duration.inMinutes > 0) {
    return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
  }
  return '${duration.inSeconds}s';
}

String _titleCase(String value) {
  final String trimmed = value.trim();
  if (trimmed.isEmpty) {
    return 'Unknown';
  }
  return '${trimmed.substring(0, 1).toUpperCase()}${trimmed.substring(1)}';
}
