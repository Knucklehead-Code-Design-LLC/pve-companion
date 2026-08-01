import 'package:flutter/material.dart';

import '../../cluster_overview/application/cluster_overview_controller.dart';
import '../../cluster_overview/domain/cluster_overview_snapshot.dart';
import '../../cluster_overview/presentation/cluster_overview_format.dart';

class TasksPage extends StatelessWidget {
  const TasksPage({super.key, required this.controller});

  final ClusterOverviewController controller;

  @override
  Widget build(BuildContext context) {
    final ClusterOverviewSnapshot? snapshot = controller.snapshot;
    if (snapshot == null) {
      return const Center(
        child: Text('Task data will appear after the overview loads.'),
      );
    }
    if (snapshot.tasks.isEmpty) {
      return const Center(
        child: Text('No recent tasks were reported by this server.'),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: snapshot.tasks.length + 1,
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Tasks', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 4),
                const Text(
                  'Read-only recent cluster activity in this milestone.',
                ),
              ],
            ),
          );
        }
        final ClusterTask task = snapshot.tasks[index - 1];
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Icon(
              task.isRunning ? Icons.sync_outlined : Icons.task_alt_outlined,
            ),
            title: Text('${task.type} on ${task.node}'),
            subtitle: Text(
              '${task.user} · ${formatPveDateTime(task.startedAt)}',
            ),
            trailing: SizedBox(
              width: 90,
              child: Text(
                task.status ?? 'Running',
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
      },
    );
  }
}
