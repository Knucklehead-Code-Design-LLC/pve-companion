import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show SelectableText;

import '../../../core/presentation/pve_apple_ui.dart';
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
              ? CupertinoIcons.desktopcomputer
              : CupertinoIcons.cube_box_fill,
          size: 30,
          color: PveAppleColors.primary(context),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(guest.title, style: PveAppleText.title2(context)),
              Text(
                '${guest.kind.shortLabel} ${guest.vmid} · ${guest.node}',
                style: PveAppleText.secondary(context),
              ),
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
        Text('Power', style: PveAppleText.title3(context)),
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
            style: PveAppleText.secondary(
              context,
            ).copyWith(color: PveAppleColors.destructive(context)),
          ),
        ],
        const SizedBox(height: 24),
        Text('Configuration', style: PveAppleText.title3(context)),
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
          CupertinoButton.filled(
            onPressed: guest.isTemplate || runningAction != null
                ? null
                : () => onPowerAction(GuestPowerAction.start),
            child: _PowerActionLabel(
              action: GuestPowerAction.start,
              runningAction: runningAction,
              label: 'Start',
            ),
          ),
        if (guest.isRunning) ...<Widget>[
          CupertinoButton.tinted(
            onPressed: runningAction != null
                ? null
                : () => onPowerAction(GuestPowerAction.shutdown),
            child: _PowerActionLabel(
              action: GuestPowerAction.shutdown,
              runningAction: runningAction,
              label: 'Shut Down',
            ),
          ),
          CupertinoButton.tinted(
            onPressed: runningAction != null
                ? null
                : () => onPowerAction(GuestPowerAction.reboot),
            child: _PowerActionLabel(
              action: GuestPowerAction.reboot,
              runningAction: runningAction,
              label: 'Restart',
            ),
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
      return const PveInsetGroup(
        padding: EdgeInsets.all(16),
        child: Text('No safe configuration fields were reported.'),
      );
    }
    return PveInsetGroup(
      child: Column(
        children: <Widget>[
          for (
            int index = 0;
            index < configuration.entries.length;
            index++
          ) ...<Widget>[
            PveListRow(
              title: Text(configuration.entries.elementAt(index).key),
              subtitle: SelectableText(
                configuration.entries.elementAt(index).value,
              ),
            ),
            if (index < configuration.entries.length - 1)
              const PveRowSeparator(leadingIndent: 16),
          ],
        ],
      ),
    );
  }
}

class _GuestStatusCard extends StatelessWidget {
  const _GuestStatusCard({required this.guest});

  final PveGuest guest;

  @override
  Widget build(BuildContext context) {
    return PveInsetGroup(
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
    });
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
