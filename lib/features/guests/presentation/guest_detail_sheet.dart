import 'package:flutter/material.dart';

import '../../../core/api/proxmox_session.dart';
import '../../cluster_overview/presentation/cluster_overview_format.dart';
import '../application/guest_detail_controller.dart';
import '../data/proxmox_guest_repository.dart';
import '../domain/pve_guest.dart';

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
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _GuestTitleBar(guest: widget.guest),
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
      GuestDetailLoadState.ready => _GuestDetailContent(
        controller: _controller,
        onPowerAction: _confirmAndRunPowerAction,
      ),
    };
  }

  Future<void> _confirmAndRunPowerAction(GuestPowerAction action) async {
    final bool? approved = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final String caution = action.isPotentiallyDisruptive
            ? 'This can interrupt workloads and active users.'
            : 'The guest will be started through the Proxmox API.';
        return AlertDialog(
          title: Text('${action.label} ${widget.guest.title}?'),
          content: Text('$caution No force action will be sent.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(action.label),
            ),
          ],
        );
      },
    );
    if (approved != true || !mounted) {
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

class _GuestTitleBar extends StatelessWidget {
  const _GuestTitleBar({required this.guest});

  final PveGuest guest;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(
          guest.kind == GuestKind.virtualMachine
              ? Icons.memory_outlined
              : Icons.inventory_2_outlined,
          size: 30,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(guest.title, style: Theme.of(context).textTheme.titleLarge),
              Text('${guest.kind.shortLabel} ${guest.vmid} · ${guest.node}'),
            ],
          ),
        ),
      ],
    );
  }
}

class _GuestDetailContent extends StatelessWidget {
  const _GuestDetailContent({
    required this.controller,
    required this.onPowerAction,
  });

  final GuestDetailController controller;
  final Future<void> Function(GuestPowerAction action) onPowerAction;

  @override
  Widget build(BuildContext context) {
    final PveGuest guest = controller.guest;
    final PveGuestDetails details = controller.details!;
    final GuestPowerAction? runningAction = controller.runningAction;
    return ListView(
      children: <Widget>[
        _GuestStatusCard(guest: guest),
        const SizedBox(height: 14),
        Text(
          'Safe power controls',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            if (!guest.isRunning)
              FilledButton.icon(
                onPressed: guest.isTemplate || runningAction != null
                    ? null
                    : () => onPowerAction(GuestPowerAction.start),
                icon: _PowerActionIcon(
                  action: GuestPowerAction.start,
                  runningAction: runningAction,
                ),
                label: const Text('Start'),
              ),
            if (guest.isRunning) ...<Widget>[
              OutlinedButton.icon(
                onPressed: runningAction != null
                    ? null
                    : () => onPowerAction(GuestPowerAction.shutdown),
                icon: _PowerActionIcon(
                  action: GuestPowerAction.shutdown,
                  runningAction: runningAction,
                ),
                label: const Text('Shut down'),
              ),
              OutlinedButton.icon(
                onPressed: runningAction != null
                    ? null
                    : () => onPowerAction(GuestPowerAction.reboot),
                icon: _PowerActionIcon(
                  action: GuestPowerAction.reboot,
                  runningAction: runningAction,
                ),
                label: const Text('Reboot'),
              ),
            ],
          ],
        ),
        if (controller.errorMessage != null) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            controller.errorMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 24),
        Text('Configuration', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (details.configuration.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No safe configuration fields were reported.'),
            ),
          )
        else
          Card(
            child: Column(
              children: details.configuration.entries
                  .map((MapEntry<String, String> entry) {
                    return ListTile(
                      dense: true,
                      title: Text(entry.key),
                      subtitle: SelectableText(entry.value),
                    );
                  })
                  .toList(growable: false),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _GuestStatusCard extends StatelessWidget {
  const _GuestStatusCard({required this.guest});

  final PveGuest guest;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 28,
          runSpacing: 16,
          children: <Widget>[
            _GuestMetric(label: 'Status', value: guest.status),
            _GuestMetric(
              label: 'CPU',
              value: formatPvePercent(guest.cpuFraction),
            ),
            _GuestMetric(
              label: 'Memory',
              value:
                  '${formatPveBytes(guest.memoryBytes)} / '
                  '${formatPveBytes(guest.memoryLimitBytes)}',
            ),
            _GuestMetric(
              label: 'Uptime',
              value: formatPveUptime(guest.uptimeSeconds),
            ),
          ],
        ),
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
      width: 135,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 3),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
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
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return Icon(switch (action) {
      GuestPowerAction.start => Icons.play_arrow_outlined,
      GuestPowerAction.shutdown => Icons.power_settings_new_outlined,
      GuestPowerAction.reboot => Icons.restart_alt_outlined,
    });
  }
}
