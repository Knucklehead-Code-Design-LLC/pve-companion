import 'package:flutter/cupertino.dart';

import '../../../core/api/proxmox_session.dart';
import '../../../core/presentation/pve_apple_ui.dart';
import '../../../core/presentation/pve_modal_sheet.dart';
import '../../console/presentation/guest_console_page.dart';
import '../application/guest_detail_controller.dart';
import '../data/proxmox_guest_repository.dart';
import '../domain/pve_guest.dart';
import 'guest_detail_content.dart';
import 'guest_operation_forms.dart';
import 'guest_power_action_dialog.dart';

Future<void> showGuestDetailSheet(
  BuildContext context, {
  required PveGuest guest,
  required ProxmoxSession session,
  required Future<void> Function() onGuestPowerAction,
  required List<String> backupStorageNames,
}) {
  return showPveModalSheet<void>(
    context: context,
    scrollableBuilder:
        (BuildContext sheetContext, ScrollController scrollController) {
          return _GuestDetailSheet(
            guest: guest,
            session: session,
            scrollController: scrollController,
            onGuestPowerAction: onGuestPowerAction,
            backupStorageNames: backupStorageNames,
          );
        },
  );
}

class _GuestDetailSheet extends StatefulWidget {
  const _GuestDetailSheet({
    required this.guest,
    required this.session,
    required this.scrollController,
    required this.onGuestPowerAction,
    required this.backupStorageNames,
  });

  final PveGuest guest;
  final ProxmoxSession session;
  final ScrollController scrollController;
  final Future<void> Function() onGuestPowerAction;
  final List<String> backupStorageNames;

  @override
  State<_GuestDetailSheet> createState() => _GuestDetailSheetState();
}

class _GuestDetailSheetState extends State<_GuestDetailSheet> {
  late final GuestDetailController _controller;

  @override
  void initState() {
    super.initState();
    _controller = GuestDetailController(
      repository: ProxmoxGuestRepository(),
      session: widget.session,
      guest: widget.guest,
      onTaskTerminal: widget.onGuestPowerAction,
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
        middle: Text(widget.guest.title),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            PveIconAction(
              icon: CupertinoIcons.refresh,
              label: 'Refresh guest details',
              onPressed: _controller.hasRunningTask ? null : _controller.load,
            ),
            Semantics(
              button: true,
              label: 'Close guest details',
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? child) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: _buildContent(context),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return switch (_controller.state) {
      GuestDetailLoadState.loading => const PveLoadingState(
        label: 'Loading guest details',
      ),
      GuestDetailLoadState.failed => PveEmptyState(
        icon: CupertinoIcons.exclamationmark_triangle,
        title: 'Guest details unavailable',
        message:
            _controller.errorMessage ??
            'The guest details could not be loaded.',
        actionLabel: 'Try Again',
        onAction: _controller.load,
        destructive: true,
      ),
      GuestDetailLoadState.ready => GuestDetailContent(
        controller: _controller,
        scrollController: widget.scrollController,
        backupStorageNames: widget.backupStorageNames,
        onPowerAction: _confirmAndRunPowerAction,
        onCreateSnapshot: _createSnapshot,
        onSnapshotAction: _handleSnapshotAction,
        onRunBackup: _runBackup,
        onEditConfiguration: _editConfiguration,
        onOpenConsole: widget.session is ProxmoxConsoleSession
            ? _openConsole
            : null,
      ),
    };
  }

  Future<void> _confirmAndRunPowerAction(GuestPowerAction action) async {
    final approved = await confirmGuestPowerAction(
      context,
      guest: widget.guest,
      action: action,
    );
    if (!approved || !mounted) {
      return;
    }
    await _controller.runPowerAction(action);
  }

  Future<void> _createSnapshot() async {
    final request = await showGuestSnapshotForm(context, guest: widget.guest);
    if (request == null || !mounted) {
      return;
    }
    await _controller.createSnapshot(request: request);
  }

  Future<void> _handleSnapshotAction(
    PveGuestSnapshot snapshot,
    GuestSnapshotAction action,
  ) async {
    final approved = await _confirmSnapshotAction(snapshot, action);
    if (!approved || !mounted) {
      return;
    }
    switch (action) {
      case GuestSnapshotAction.rollback:
        await _controller.rollbackSnapshot(snapshot);
      case GuestSnapshotAction.delete:
        await _controller.deleteSnapshot(snapshot);
    }
  }

  Future<void> _runBackup() async {
    if (widget.backupStorageNames.isEmpty) {
      return;
    }
    final request = await showGuestBackupForm(
      context,
      storageNames: widget.backupStorageNames,
    );
    if (request == null || !mounted) {
      return;
    }
    if (request.mode == PveGuestBackupMode.stop) {
      final approved = await _confirmBackupStopMode();
      if (!approved || !mounted) {
        return;
      }
    }
    await _controller.createBackup(request);
  }

  Future<void> _editConfiguration() async {
    final details = _controller.details;
    if (details == null) {
      return;
    }
    final change = await showGuestConfigurationForm(
      context,
      configuration: details.configuration,
    );
    if (change == null || !mounted) {
      return;
    }
    final saved = await _controller.updateConfiguration(change);
    if (saved && mounted) {
      await widget.onGuestPowerAction();
    }
  }

  Future<bool> _confirmSnapshotAction(
    PveGuestSnapshot snapshot,
    GuestSnapshotAction action,
  ) async {
    final rollback = action == GuestSnapshotAction.rollback;
    final approved = await showCupertinoDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => CupertinoAlertDialog(
        title: Text(
          rollback
              ? 'Roll back ${widget.guest.title}?'
              : 'Delete ${snapshot.name}?',
        ),
        content: Text(
          rollback
              ? 'Proxmox will replace the current guest state with snapshot “${snapshot.name}”. This cannot be undone.'
              : 'This permanently removes the “${snapshot.name}” snapshot from Proxmox.',
        ),
        actions: <Widget>[
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(rollback ? 'Roll Back' : 'Delete'),
          ),
        ],
      ),
    );
    return approved == true;
  }

  Future<bool> _confirmBackupStopMode() async {
    final approved = await showCupertinoDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => CupertinoAlertDialog(
        title: const Text('Stop guest for backup?'),
        content: const Text(
          'Stop mode powers down the guest before the backup begins. Active users and workloads will be interrupted.',
        ),
        actions: <Widget>[
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Stop and Back Up'),
          ),
        ],
      ),
    );
    return approved == true;
  }

  Future<void> _openConsole() async {
    if (!mounted) {
      return;
    }
    await showGuestConsolePage(
      context,
      guest: widget.guest,
      session: widget.session,
    );
  }
}
