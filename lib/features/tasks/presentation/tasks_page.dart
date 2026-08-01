import 'package:flutter/cupertino.dart';

import '../../../core/presentation/pve_apple_ui.dart';
import '../../cluster_overview/application/cluster_overview_controller.dart';
import '../../cluster_overview/domain/cluster_overview_snapshot.dart';
import '../../cluster_overview/presentation/cluster_overview_format.dart';
import '../../cluster_overview/presentation/datacenter_dashboard_visuals.dart';

class TasksPage extends StatelessWidget {
  const TasksPage({super.key, required this.controller});

  final ClusterOverviewController controller;

  @override
  Widget build(BuildContext context) {
    final ClusterOverviewSnapshot? snapshot = controller.snapshot;
    if (snapshot == null) {
      return const PveLoadingState(label: 'Loading recent activity');
    }
    if (snapshot.tasks.isEmpty) {
      return const PveEmptyState(
        icon: CupertinoIcons.check_mark_circled,
        title: 'No recent activity',
        message: 'This server did not report recent cluster tasks.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        const PvePageHeader(
          title: 'Tasks',
          subtitle: 'Recent work reported across the datacenter.',
        ),
        const SizedBox(height: 20),
        PveInsetGroup(
          child: Column(
            children: <Widget>[
              for (
                int index = 0;
                index < snapshot.tasks.length;
                index++
              ) ...<Widget>[
                _TaskRow(task: snapshot.tasks[index]),
                if (index < snapshot.tasks.length - 1) const PveRowSeparator(),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task});

  final ClusterTask task;

  @override
  Widget build(BuildContext context) {
    final DatacenterDashboardTone tone = dashboardToneForTask(task);
    return PveListRow(
      leading: Icon(
        task.isRunning
            ? CupertinoIcons.arrow_2_circlepath
            : CupertinoIcons.check_mark_circled_solid,
      ),
      title: Text('${task.type} on ${task.node}'),
      subtitle: Text('${task.user} · ${formatPveDateTime(task.startedAt)}'),
      trailing: PveStatusPill(
        label: dashboardTaskStateLabel(task),
        color: dashboardToneColor(context, tone),
      ),
    );
  }
}
