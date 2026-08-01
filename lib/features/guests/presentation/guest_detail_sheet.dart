import 'package:flutter/cupertino.dart';

import '../../../core/api/proxmox_session.dart';
import '../../../core/presentation/pve_apple_ui.dart';
import '../application/guest_detail_controller.dart';
import '../data/proxmox_guest_repository.dart';
import '../domain/pve_guest.dart';
import 'guest_detail_content.dart';
import 'guest_power_action_dialog.dart';

Future<void> showGuestDetailSheet(
  BuildContext context, {
  required PveGuest guest,
  required ProxmoxSession session,
  required Future<void> Function() onGuestPowerAction,
}) {
  return showCupertinoSheet<void>(
    context: context,
    useNestedNavigation: true,
    scrollableBuilder:
        (BuildContext sheetContext, ScrollController scrollController) {
          return _GuestDetailSheet(
            guest: guest,
            session: session,
            scrollController: scrollController,
            onGuestPowerAction: onGuestPowerAction,
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
  });

  final PveGuest guest;
  final ProxmoxSession session;
  final ScrollController scrollController;
  final Future<void> Function() onGuestPowerAction;

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
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ),
      child: SafeArea(
        top: false,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? child) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: Column(
                    children: <Widget>[
                      GuestTitleBar(guest: widget.guest),
                      const SizedBox(height: 18),
                      Expanded(child: _buildContent(context)),
                    ],
                  ),
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
        onPowerAction: _confirmAndRunPowerAction,
      ),
    };
  }

  Future<void> _confirmAndRunPowerAction(GuestPowerAction action) async {
    final bool approved = await confirmGuestPowerAction(
      context,
      guest: widget.guest,
      action: action,
    );
    if (!approved || !mounted) {
      return;
    }
    final bool didRequestAction = await _controller.runPowerAction(action);
    if (!mounted) {
      return;
    }
    if (didRequestAction) {
      await widget.onGuestPowerAction();
      if (!mounted) {
        return;
      }
      await showCupertinoDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) => CupertinoAlertDialog(
          title: const Text('Request Sent'),
          content: Text('${action.label} was requested through Proxmox.'),
          actions: <Widget>[
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }
}
