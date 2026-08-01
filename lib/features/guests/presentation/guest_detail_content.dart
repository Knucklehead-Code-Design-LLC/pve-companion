import 'package:flutter/material.dart';

import '../../cluster_overview/presentation/cluster_overview_format.dart';
import '../application/guest_detail_controller.dart';
import '../domain/pve_guest.dart';

class GuestTitleBar extends StatelessWidget {
  const GuestTitleBar({super.key, required this.guest});

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

class GuestDetailContent extends StatelessWidget {
  const GuestDetailContent({
    super.key,
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
        _GuestPowerControls(
          guest: guest,
          runningAction: runningAction,
          onPowerAction: onPowerAction,
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
        _GuestConfigurationCard(configuration: details.configuration),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _GuestPowerControls extends StatelessWidget {
  const _GuestPowerControls({
    required this.guest,
    required this.runningAction,
    required this.onPowerAction,
  });

  final PveGuest guest;
  final GuestPowerAction? runningAction;
  final Future<void> Function(GuestPowerAction action) onPowerAction;

  @override
  Widget build(BuildContext context) {
    return Wrap(
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
    );
  }
}

class _GuestConfigurationCard extends StatelessWidget {
  const _GuestConfigurationCard({required this.configuration});

  final Map<String, String> configuration;

  @override
  Widget build(BuildContext context) {
    if (configuration.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No safe configuration fields were reported.'),
        ),
      );
    }
    return Card(
      child: Column(
        children: configuration.entries
            .map(
              (MapEntry<String, String> entry) => ListTile(
                dense: true,
                title: Text(entry.key),
                subtitle: SelectableText(entry.value),
              ),
            )
            .toList(growable: false),
      ),
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
