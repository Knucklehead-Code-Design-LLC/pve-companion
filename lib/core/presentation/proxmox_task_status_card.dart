import 'package:flutter/cupertino.dart';

import '../api/proxmox_task.dart';
import 'pve_apple_ui.dart';

/// A compact, truthful task status card shared by every operational surface.
/// It represents Proxmox's task state, not an optimistic client-side result.
class ProxmoxTaskStatusCard extends StatelessWidget {
  const ProxmoxTaskStatusCard({super.key, required this.task});

  final ProxmoxTaskStatus task;

  @override
  Widget build(BuildContext context) {
    final Color accent = switch (task.state) {
      ProxmoxTaskState.running => PveAppleColors.primary(context),
      ProxmoxTaskState.successful => PveAppleColors.success(context),
      ProxmoxTaskState.failed => PveAppleColors.destructive(context),
      ProxmoxTaskState.unknown => PveAppleColors.warning(context),
    };
    final IconData icon = switch (task.state) {
      ProxmoxTaskState.running => CupertinoIcons.arrow_2_circlepath,
      ProxmoxTaskState.successful => CupertinoIcons.check_mark_circled_solid,
      ProxmoxTaskState.failed => CupertinoIcons.xmark_circle_fill,
      ProxmoxTaskState.unknown => CupertinoIcons.exclamationmark_circle_fill,
    };
    return PveInsetGroup(
      color: accent.withValues(alpha: 0.09),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: <Widget>[
          if (task.state == ProxmoxTaskState.running)
            CupertinoActivityIndicator(color: accent)
          else
            Icon(icon, color: accent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  task.reference.operationLabel,
                  style: PveAppleText.body(context),
                ),
                const SizedBox(height: 2),
                Text(
                  task.displayStatus,
                  style: PveAppleText.secondary(
                    context,
                  ).copyWith(color: accent),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
