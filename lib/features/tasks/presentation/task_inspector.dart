import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../core/api/proxmox_session.dart';
import '../../../core/presentation/pve_apple_ui.dart';
import '../../../core/presentation/pve_value_format.dart';
import '../../cluster_overview/domain/cluster_overview_snapshot.dart';
import '../../cluster_overview/presentation/datacenter_dashboard_visuals.dart';
import '../application/task_log_controller.dart';
import '../data/proxmox_task_log_repository.dart';
import '../domain/pve_task_log.dart';

class TaskInspector extends StatefulWidget {
  const TaskInspector({
    super.key,
    required this.task,
    required this.session,
    this.scrollController,
    this.inline = false,
  });

  final ClusterTask task;
  final ProxmoxSession? session;
  final ScrollController? scrollController;
  final bool inline;

  @override
  State<TaskInspector> createState() => _TaskInspectorState();
}

class _TaskInspectorState extends State<TaskInspector> {
  late final TaskLogController _logController = TaskLogController(
    repository: const ProxmoxTaskLogRepository(),
    session: widget.session,
    task: widget.task,
  );
  bool _copiedTaskId = false;

  @override
  void dispose() {
    _logController.dispose();
    super.dispose();
  }

  Future<void> _copyTaskId() async {
    await Clipboard.setData(ClipboardData(text: widget.task.upid));
    if (!mounted) return;
    setState(() => _copiedTaskId = true);
  }

  @override
  Widget build(BuildContext context) {
    final details = <Widget>[
      if (widget.inline) ...<Widget>[
        Text('Task details', style: PveAppleText.title3(context)),
        const SizedBox(height: 6),
      ] else ...<Widget>[
        Text(widget.task.type, style: PveAppleText.largeTitle(context)),
        const SizedBox(height: 6),
      ],
      Text(
        'Read-only details from the latest task list refresh. Load the server task log only when you need it.',
        style: PveAppleText.secondary(context),
      ),
      const SizedBox(height: 18),
      PveInsetGroup(
        padding: EdgeInsets.zero,
        child: Column(
          children: <Widget>[
            _InspectorRow(
              label: 'Status',
              value: dashboardTaskStateLabel(widget.task),
            ),
            const PveRowSeparator(leadingIndent: 16),
            _InspectorRow(label: 'Node', value: widget.task.node),
            const PveRowSeparator(leadingIndent: 16),
            _InspectorRow(label: 'Operator', value: widget.task.user),
            const PveRowSeparator(leadingIndent: 16),
            _InspectorRow(
              label: 'Started',
              value: formatPveDateTime(widget.task.startedAt),
            ),
            const PveRowSeparator(leadingIndent: 16),
            _InspectorRow(
              label: 'Finished',
              value: formatPveDateTime(widget.task.endedAt),
            ),
            const PveRowSeparator(leadingIndent: 16),
            _InspectorRow(
              label: 'Duration',
              value: taskDurationLabel(widget.task),
            ),
            const PveRowSeparator(leadingIndent: 16),
            CupertinoContextMenu(
              actions: <Widget>[
                CupertinoContextMenuAction(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _copyTaskId();
                  },
                  child: const Text('Copy task ID'),
                ),
              ],
              child: _InspectorRow(label: 'Task ID', value: widget.task.upid),
            ),
          ],
        ),
      ),
      CupertinoButton(
        padding: EdgeInsets.zero,
        alignment: Alignment.centerLeft,
        onPressed: _copyTaskId,
        child: Text(_copiedTaskId ? 'Task ID copied' : 'Copy task ID'),
      ),
      const SizedBox(height: 18),
      TaskLogSection(controller: _logController),
    ];
    if (widget.inline) {
      return PveInsetGroup(
        key: const ValueKey<String>('desktop-task-inspector'),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: details,
        ),
      );
    }
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        automaticallyImplyLeading: false,
        middle: const Text('Task details'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(PveActionLabels.close),
        ),
      ),
      child: SafeArea(
        child: ListView(
          controller: widget.scrollController,
          padding: const EdgeInsets.all(16),
          children: details,
        ),
      ),
    );
  }
}

class TaskInspectorPlaceholder extends StatelessWidget {
  const TaskInspectorPlaceholder({super.key});

  @override
  Widget build(BuildContext context) => PveInsetGroup(
    key: const ValueKey<String>('desktop-task-inspector-placeholder'),
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Task details', style: PveAppleText.title3(context)),
        const SizedBox(height: 8),
        Text(
          'Select a task or interactive session to inspect its reported details and request its server log.',
          style: PveAppleText.secondary(context),
        ),
      ],
    ),
  );
}

class TaskLogSection extends StatelessWidget {
  const TaskLogSection({super.key, required this.controller});

  final TaskLogController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (BuildContext context, Widget? child) {
      if (controller.isLoading) {
        return _TaskLogPanel(
          content: const Center(child: CupertinoActivityIndicator()),
        );
      }

      final result = controller.result;
      if (result == null) {
        return _TaskLogPanel(content: _TaskLogPrompt(controller: controller));
      }
      if (result.state == PveTaskLogState.available) {
        return _TaskLogPanel(
          content: _AvailableTaskLog(result: result, controller: controller),
        );
      }
      return _TaskLogPanel(
        content: _UnavailableTaskLog(result: result, controller: controller),
      );
    },
  );
}

class _TaskLogPanel extends StatelessWidget {
  const _TaskLogPanel({required this.content});

  final Widget content;

  @override
  Widget build(BuildContext context) => PveInsetGroup(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Server log', style: PveAppleText.title3(context)),
        const SizedBox(height: 8),
        content,
      ],
    ),
  );
}

class _TaskLogPrompt extends StatelessWidget {
  const _TaskLogPrompt({required this.controller});

  final TaskLogController controller;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(
        controller.canLoad
            ? 'Load the log from this server when you need it.'
            : 'Reconnect to this server to request its task log.',
        style: PveAppleText.secondary(context),
      ),
      const SizedBox(height: 10),
      CupertinoButton.filled(
        key: const ValueKey<String>('load-task-log'),
        onPressed: controller.canLoad ? controller.load : null,
        child: const Text('Load server log'),
      ),
    ],
  );
}

class _AvailableTaskLog extends StatelessWidget {
  const _AvailableTaskLog({required this.result, required this.controller});

  final PveTaskLogResult result;
  final TaskLogController controller;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      DecoratedBox(
        decoration: BoxDecoration(
          color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
          borderRadius: BorderRadius.circular(10),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 260),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Text(
              result.lines
                  .map(
                    (PveTaskLogLine line) =>
                        '${line.sequence == null ? '' : '${line.sequence}: '}${line.text}',
                  )
                  .join('\n'),
              style: PveAppleText.caption(
                context,
              ).copyWith(fontFamily: 'monospace', height: 1.45),
            ),
          ),
        ),
      ),
      const SizedBox(height: 6),
      CupertinoButton(
        padding: EdgeInsets.zero,
        alignment: Alignment.centerRight,
        onPressed: controller.load,
        child: const Text('Reload log'),
      ),
    ],
  );
}

class _UnavailableTaskLog extends StatelessWidget {
  const _UnavailableTaskLog({required this.result, required this.controller});

  final PveTaskLogResult result;
  final TaskLogController controller;

  @override
  Widget build(BuildContext context) {
    final label = switch (result.state) {
      PveTaskLogState.empty =>
        'No server log lines were reported for this task.',
      PveTaskLogState.permissionLimited =>
        'This account cannot read this task log.',
      PveTaskLogState.unavailable =>
        'This server does not make this task log available.',
      PveTaskLogState.failed =>
        result.message ?? 'The task log could not be loaded.',
      PveTaskLogState.available => 'The task log is unavailable.',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: PveAppleText.secondary(context)),
        if (result.state == PveTaskLogState.failed) ...<Widget>[
          const SizedBox(height: 10),
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: controller.load,
            child: const Text('Try again'),
          ),
        ],
      ],
    );
  }
}

class _InspectorRow extends StatelessWidget {
  const _InspectorRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => PveListRow(
    title: Text(label),
    trailing: SizedBox(
      width: 200,
      child: Text(
        value,
        textAlign: TextAlign.end,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}

String taskDurationLabel(ClusterTask task) {
  final startedAt = task.startedAt;
  final endedAt = task.endedAt;
  if (endedAt == null) {
    return task.isRunning ? 'In progress' : 'Duration unavailable';
  }
  if (startedAt == null || endedAt.isBefore(startedAt)) {
    return 'Duration unavailable';
  }
  final duration = endedAt.difference(startedAt);
  if (duration.inHours > 0) {
    return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
  }
  if (duration.inMinutes > 0) {
    return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
  }
  return '${duration.inSeconds}s';
}
