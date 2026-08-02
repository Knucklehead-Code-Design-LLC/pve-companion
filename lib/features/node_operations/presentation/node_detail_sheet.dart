import 'package:flutter/cupertino.dart';

import '../../../core/api/proxmox_session.dart';
import '../../../core/presentation/proxmox_task_status_card.dart';
import '../../../core/presentation/pve_apple_ui.dart';
import '../../../core/presentation/pve_modal_sheet.dart';
import '../../../core/presentation/pve_value_format.dart';
import '../application/node_operations_controller.dart';
import '../data/proxmox_node_repository.dart';
import '../domain/pve_node_details.dart';

Future<void> showNodeDetailSheet(
  BuildContext context, {
  required PveNodeDetailsSeed seed,
  required ProxmoxSession session,
  required Future<void> Function() onNodeOperation,
}) {
  return showPveModalSheet<void>(
    context: context,
    scrollableBuilder:
        (BuildContext sheetContext, ScrollController scrollController) =>
            _NodeDetailSheet(
              seed: seed,
              session: session,
              scrollController: scrollController,
              onNodeOperation: onNodeOperation,
            ),
  );
}

class _NodeDetailSheet extends StatefulWidget {
  const _NodeDetailSheet({
    required this.seed,
    required this.session,
    required this.scrollController,
    required this.onNodeOperation,
  });

  final PveNodeDetailsSeed seed;
  final ProxmoxSession session;
  final ScrollController scrollController;
  final Future<void> Function() onNodeOperation;

  @override
  State<_NodeDetailSheet> createState() => _NodeDetailSheetState();
}

class _NodeDetailSheetState extends State<_NodeDetailSheet> {
  late final NodeOperationsController _controller;

  @override
  void initState() {
    super.initState();
    _controller = NodeOperationsController(
      repository: ProxmoxNodeRepository(),
      session: widget.session,
      seed: widget.seed,
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
        middle: Text(widget.seed.node.name),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 7),
              minimumSize: const Size(44, 36),
              onPressed: _controller.hasRunningTask ? null : _controller.load,
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
              constraints: const BoxConstraints(maxWidth: 760),
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
      NodeOperationsLoadState.loading => const PveLoadingState(
        label: 'Loading node details',
      ),
      NodeOperationsLoadState.failed => PveEmptyState(
        icon: CupertinoIcons.exclamationmark_triangle,
        title: 'Node details unavailable',
        message:
            _controller.errorMessage ?? 'The node details could not be loaded.',
        actionLabel: 'Try Again',
        onAction: _controller.load,
        destructive: true,
      ),
      NodeOperationsLoadState.ready => _NodeDetailContent(
        controller: _controller,
        scrollController: widget.scrollController,
        onPowerAction: _handlePowerAction,
        onRestartService: _restartService,
        onRefreshPackageIndex: _refreshPackageIndex,
      ),
    };
  }

  Future<void> _handlePowerAction(PveNodePowerAction action) async {
    final bool approved = await _confirmNodePowerAction(action);
    if (!approved || !mounted) {
      return;
    }
    final bool submitted = switch (action) {
      PveNodePowerAction.reboot => await _controller.restartNode(),
      PveNodePowerAction.shutdown => await _controller.shutdownNode(),
    };
    if (submitted && mounted) {
      await widget.onNodeOperation();
    }
  }

  Future<void> _restartService(PveNodeService service) async {
    final bool? approved = await showCupertinoDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => CupertinoAlertDialog(
        title: Text('Restart ${service.name}?'),
        content: const Text(
          'Restarting a node service can briefly interrupt monitoring, networking, or cluster behavior. Continue only when you know the service’s impact.',
        ),
        actions: <Widget>[
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Restart'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) {
      return;
    }
    final bool submitted = await _controller.restartService(service);
    if (submitted && mounted) {
      await widget.onNodeOperation();
    }
  }

  Future<void> _refreshPackageIndex() async {
    final bool submitted = await _controller.refreshPackageIndex();
    if (submitted && mounted) {
      await widget.onNodeOperation();
    }
  }

  Future<bool> _confirmNodePowerAction(PveNodePowerAction action) async {
    final bool isShutdown = action == PveNodePowerAction.shutdown;
    final bool? approved = await showCupertinoDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => CupertinoAlertDialog(
        title: Text('${action.label}?'),
        content: Text(
          isShutdown
              ? 'This powers off ${widget.seed.node.name}. Running guests and cluster quorum can be affected.'
              : 'This restarts ${widget.seed.node.name}. Running guests and cluster quorum can be affected.',
        ),
        actions: <Widget>[
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(isShutdown ? 'Shut Down Node' : 'Restart Node'),
          ),
        ],
      ),
    );
    return approved == true;
  }
}

class _NodeDetailContent extends StatelessWidget {
  const _NodeDetailContent({
    required this.controller,
    required this.scrollController,
    required this.onPowerAction,
    required this.onRestartService,
    required this.onRefreshPackageIndex,
  });

  final NodeOperationsController controller;
  final ScrollController scrollController;
  final Future<void> Function(PveNodePowerAction) onPowerAction;
  final Future<void> Function(PveNodeService) onRestartService;
  final Future<void> Function() onRefreshPackageIndex;

  @override
  Widget build(BuildContext context) {
    final PveNodeDetails details = controller.details!;
    final bool controlsDisabled =
        controller.hasRunningTask || !details.node.isOnline;
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: 32),
      children: <Widget>[
        _NodeStatusCard(details: details),
        if (controller.activeTask != null) ...<Widget>[
          const SizedBox(height: 12),
          ProxmoxTaskStatusCard(task: controller.activeTask!),
        ],
        if (controller.errorMessage != null) ...<Widget>[
          const SizedBox(height: 10),
          _NodeInlineError(message: controller.errorMessage!),
        ],
        const SizedBox(height: 24),
        const PveSectionTitle(title: 'Node controls'),
        const SizedBox(height: 8),
        _NodePowerControls(enabled: !controlsDisabled, onAction: onPowerAction),
        if (!details.node.isOnline) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            'Node power controls are unavailable while Proxmox reports this node offline.',
            style: PveAppleText.secondary(context),
          ),
        ],
        const SizedBox(height: 24),
        const PveSectionTitle(title: 'System information'),
        const SizedBox(height: 8),
        _NodeSystemInformationCard(details: details),
        const SizedBox(height: 24),
        PveSectionHeader(
          title: 'Package updates',
          actionLabel: 'Refresh Index',
          actionSemanticsLabel: 'Refresh the package index on this node',
          onAction: controlsDisabled ? null : () => onRefreshPackageIndex(),
        ),
        _NodeUpdatesCard(updates: details.availablePackageUpdates),
        const SizedBox(height: 24),
        const PveSectionTitle(title: 'Node services'),
        const SizedBox(height: 8),
        _NodeServicesCard(
          services: details.services,
          restartEnabled: !controlsDisabled,
          onRestartService: onRestartService,
        ),
      ],
    );
  }
}

class _NodeInlineError extends StatelessWidget {
  const _NodeInlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return PveInsetGroup(
      color: PveAppleColors.destructive(context).withValues(alpha: 0.08),
      padding: const EdgeInsets.all(12),
      child: Text(
        message,
        style: PveAppleText.secondary(
          context,
        ).copyWith(color: PveAppleColors.destructive(context)),
      ),
    );
  }
}

class _NodeStatusCard extends StatelessWidget {
  const _NodeStatusCard({required this.details});

  final PveNodeDetails details;

  @override
  Widget build(BuildContext context) {
    final Color statusColor = details.node.isOnline
        ? PveAppleColors.success(context)
        : PveAppleColors.destructive(context);
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
                    CupertinoIcons.rectangle_stack,
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
                    Text(
                      details.node.name,
                      style: PveAppleText.title3(context),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      details.pveVersion ?? 'Proxmox version not reported',
                      style: PveAppleText.caption(context),
                    ),
                  ],
                ),
              ),
              PveStatusPill(
                label: details.node.isOnline ? 'Online' : 'Offline',
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 26,
            runSpacing: 16,
            children: <Widget>[
              _NodeMetric(
                label: 'CPU',
                value: formatPvePercent(details.node.cpuFraction),
              ),
              _NodeMetric(
                label: 'Memory',
                value:
                    '${formatPveBytes(details.node.memoryBytes)} / '
                    '${formatPveBytes(details.node.memoryLimitBytes)}',
              ),
              _NodeMetric(
                label: 'Root disk',
                value:
                    '${formatPveBytes(details.node.diskBytes)} / '
                    '${formatPveBytes(details.node.diskLimitBytes)}',
              ),
              _NodeMetric(
                label: 'Uptime',
                value: formatPveUptime(details.node.uptimeSeconds),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NodePowerControls extends StatelessWidget {
  const _NodePowerControls({required this.enabled, required this.onAction});

  final bool enabled;
  final Future<void> Function(PveNodePowerAction) onAction;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: <Widget>[
        CupertinoButton.tinted(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          minimumSize: const Size(44, 44),
          onPressed: enabled ? () => onAction(PveNodePowerAction.reboot) : null,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(CupertinoIcons.arrow_clockwise, size: 17),
              SizedBox(width: 7),
              Text('Restart'),
            ],
          ),
        ),
        CupertinoButton.tinted(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          minimumSize: const Size(44, 44),
          onPressed: enabled
              ? () => onAction(PveNodePowerAction.shutdown)
              : null,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(CupertinoIcons.power, size: 17),
              SizedBox(width: 7),
              Text('Shut Down'),
            ],
          ),
        ),
      ],
    );
  }
}

class _NodeSystemInformationCard extends StatelessWidget {
  const _NodeSystemInformationCard({required this.details});

  final PveNodeDetails details;

  @override
  Widget build(BuildContext context) {
    final List<_NodeInfoRow> rows = <_NodeInfoRow>[
      _NodeInfoRow(label: 'Kernel', value: details.kernelVersion),
      _NodeInfoRow(label: 'CPU model', value: details.cpuModel),
      _NodeInfoRow(
        label: 'Load average',
        value: details.loadAverages.isEmpty
            ? null
            : details.loadAverages
                  .take(3)
                  .map((double value) => value.toStringAsFixed(2))
                  .join(' · '),
      ),
      _NodeInfoRow(
        label: 'Package updates',
        value: '${details.availablePackageUpdates.length} available',
      ),
    ].where((_NodeInfoRow row) => row.value != null).toList(growable: false);
    return PveInsetGroup(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          for (int index = 0; index < rows.length; index++) ...<Widget>[
            PveListRow(
              title: Text(rows[index].label),
              trailing: Text(
                rows[index].value!,
                textAlign: TextAlign.end,
                style: PveAppleText.secondary(context),
              ),
            ),
            if (index < rows.length - 1)
              const PveRowSeparator(leadingIndent: 16),
          ],
        ],
      ),
    );
  }
}

class _NodeUpdatesCard extends StatelessWidget {
  const _NodeUpdatesCard({required this.updates});

  final List<PveNodePackageUpdate> updates;

  @override
  Widget build(BuildContext context) {
    if (updates.isEmpty) {
      return const PveInsetGroup(
        padding: EdgeInsets.all(16),
        child: Text(
          'No package updates were reported. Refresh the package index to retrieve the latest available updates.',
        ),
      );
    }
    return PveInsetGroup(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          for (int index = 0; index < updates.length; index++) ...<Widget>[
            PveListRow(
              leading: const Icon(CupertinoIcons.cube_box),
              title: Text(updates[index].packageName),
              subtitle: Text(_packageUpdateSubtitle(updates[index])),
              trailing: const Icon(CupertinoIcons.chevron_forward, size: 14),
            ),
            if (index < updates.length - 1) const PveRowSeparator(),
          ],
        ],
      ),
    );
  }
}

class _NodeServicesCard extends StatelessWidget {
  const _NodeServicesCard({
    required this.services,
    required this.restartEnabled,
    required this.onRestartService,
  });

  final List<PveNodeService> services;
  final bool restartEnabled;
  final Future<void> Function(PveNodeService) onRestartService;

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) {
      return const PveInsetGroup(
        padding: EdgeInsets.all(16),
        child: Text('Service status was not reported by this Proxmox account.'),
      );
    }
    return PveInsetGroup(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          for (int index = 0; index < services.length; index++) ...<Widget>[
            PveListRow(
              leading: Icon(
                services[index].isRunning
                    ? CupertinoIcons.check_mark_circled_solid
                    : CupertinoIcons.exclamationmark_triangle_fill,
                color: services[index].isRunning
                    ? PveAppleColors.success(context)
                    : PveAppleColors.warning(context),
              ),
              title: Text(services[index].name),
              subtitle: Text(
                services[index].description ??
                    _nodeServiceState(services[index]),
              ),
              trailing: CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                minimumSize: const Size(44, 34),
                onPressed: restartEnabled
                    ? () => onRestartService(services[index])
                    : null,
                child: const Icon(CupertinoIcons.arrow_clockwise, size: 18),
              ),
            ),
            if (index < services.length - 1) const PveRowSeparator(),
          ],
        ],
      ),
    );
  }
}

class _NodeMetric extends StatelessWidget {
  const _NodeMetric({required this.label, required this.value});

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

class _NodeInfoRow {
  const _NodeInfoRow({required this.label, required this.value});

  final String label;
  final String? value;
}

String _packageUpdateSubtitle(PveNodePackageUpdate update) {
  final String? installed = update.installedVersion;
  final String? available = update.availableVersion;
  if (installed != null && available != null) {
    return '$installed → $available';
  }
  return update.title ?? 'Version details not reported';
}

String _nodeServiceState(PveNodeService service) =>
    service.isRunning ? 'Running' : service.state;
