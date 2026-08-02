import 'package:flutter/cupertino.dart';

import '../../../core/presentation/pve_apple_ui.dart';
import '../../../core/presentation/pve_value_format.dart';
import '../domain/cluster_overview_snapshot.dart';
import 'datacenter_dashboard_section_header.dart';
import 'datacenter_dashboard_visuals.dart';

class DatacenterRecentActivitySection extends StatelessWidget {
  const DatacenterRecentActivitySection({
    super.key,
    required this.tasks,
    required this.onViewTasks,
  });

  final List<ClusterTask> tasks;
  final VoidCallback onViewTasks;

  @override
  Widget build(BuildContext context) {
    final List<ClusterTask> orderedTasks = List<ClusterTask>.of(tasks)
      ..sort(compareClusterTasksByRecency);
    final List<ClusterTask> visibleTasks = orderedTasks
        .take(5)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        DatacenterDashboardSectionHeader(
          title: 'Recent reported activity',
          actionLabel: 'View all',
          actionSemanticsLabel: 'View all tasks',
          onAction: onViewTasks,
        ),
        const SizedBox(height: 12),
        if (tasks.isEmpty)
          const PveInsetGroup(
            padding: EdgeInsets.all(18),
            child: Text('No recent tasks were reported by this server.'),
          )
        else
          PveInsetGroup(
            child: Column(
              key: const ValueKey<String>('dashboard-recent-activity'),
              children: <Widget>[
                for (
                  int index = 0;
                  index < visibleTasks.length;
                  index++
                ) ...<Widget>[
                  _DatacenterActivityItem(task: visibleTasks[index]),
                  if (index < visibleTasks.length - 1) const PveRowSeparator(),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _DatacenterActivityItem extends StatelessWidget {
  const _DatacenterActivityItem({required this.task});

  final ClusterTask task;

  @override
  Widget build(BuildContext context) {
    final DatacenterDashboardTone tone = dashboardToneForTask(task);
    final String statusLabel = dashboardTaskStateLabel(task);
    return Semantics(
      label: 'Task ${task.type} on ${task.node}: $statusLabel',
      child: PveListRow(
        leading: ExcludeSemantics(
          child: Icon(
            dashboardToneIcon(tone),
            color: dashboardToneColor(context, tone),
          ),
        ),
        title: Text('${task.type} on ${task.node}'),
        subtitle: Text('${task.user} · ${formatPveDateTime(task.startedAt)}'),
        trailing: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.25,
          child: PveStatusPill(
            label: statusLabel,
            color: dashboardToneColor(context, tone),
          ),
        ),
      ),
    );
  }
}
