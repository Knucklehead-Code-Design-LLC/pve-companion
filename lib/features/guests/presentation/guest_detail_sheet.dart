import 'package:flutter/material.dart';

import '../../../core/api/proxmox_session.dart';
import '../../../core/presentation/modal_sheet_grabber.dart';
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
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext sheetContext) {
      return _GuestDetailSheet(
        guest: guest,
        session: session,
        onGuestPowerAction: onGuestPowerAction,
      );
    },
  );
}

class _GuestDetailSheet extends StatefulWidget {
  const _GuestDetailSheet({
    required this.guest,
    required this.session,
    required this.onGuestPowerAction,
  });

  final PveGuest guest;
  final ProxmoxSession session;
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
    return SafeArea(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, Widget? child) {
          return ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.88,
              maxWidth: 720,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                children: <Widget>[
                  const ModalSheetGrabber(),
                  const SizedBox(height: 16),
                  GuestTitleBar(guest: widget.guest),
                  const SizedBox(height: 16),
                  Expanded(child: _buildContent(context)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return switch (_controller.state) {
      GuestDetailLoadState.loading => const Center(
        child: CircularProgressIndicator(),
      ),
      GuestDetailLoadState.failed => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              _controller.errorMessage ?? 'Guest details could not be loaded.',
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _controller.load,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
      GuestDetailLoadState.ready => GuestDetailContent(
        controller: _controller,
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${action.label} was requested.')));
    }
  }
}
