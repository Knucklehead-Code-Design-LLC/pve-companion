import 'package:flutter/cupertino.dart';

import '../../../core/presentation/pve_apple_ui.dart';
import '../../../core/presentation/pve_data_visualization.dart';
import '../../cluster_overview/domain/cluster_overview_snapshot.dart';

class TaskActivityInsights extends StatelessWidget {
  const TaskActivityInsights({super.key, required this.tasks});

  final List<ClusterTask> tasks;

  @override
  Widget build(BuildContext context) {
    final _TaskActivitySummary summary = _TaskActivitySummary.from(tasks);
    return PveAdaptiveCardGrid(
      children: <Widget>[
        KeyedSubtree(
          key: const ValueKey<String>('task-outcomes'),
          child: PveInsightCard(
            title: 'Task outcomes',
            subtitle: 'Latest ${tasks.length} reported operations',
            child: Row(
              children: <Widget>[
                PveRingChart(
                  segments: <PveChartSegment>[
                    PveChartSegment(
                      label: 'Successful',
                      value: summary.successfulCount.toDouble(),
                      color: PveAppleColors.success(context),
                    ),
                    PveChartSegment(
                      label: 'Running',
                      value: summary.runningCount.toDouble(),
                      color: PveAppleColors.warning(context),
                    ),
                    PveChartSegment(
                      label: 'Failed',
                      value: summary.failedCount.toDouble(),
                      color: PveAppleColors.destructive(context),
                    ),
                    PveChartSegment(
                      label: 'Unknown',
                      value: summary.unknownCount.toDouble(),
                      color: PveAppleColors.secondaryLabel(context),
                    ),
                  ],
                  centerValue: summary.completionRate == null
                      ? '—'
                      : '${(summary.completionRate! * 100).round()}%',
                  centerLabel: 'success',
                  semanticLabel:
                      '${summary.successfulCount} successful, '
                      '${summary.runningCount} running, '
                      '${summary.failedCount} failed, '
                      '${summary.unknownCount} with unknown status',
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      PveChartLegendItem(
                        label: 'Successful',
                        value: '${summary.successfulCount}',
                        color: PveAppleColors.success(context),
                      ),
                      const SizedBox(height: 12),
                      PveChartLegendItem(
                        label: 'Running',
                        value: '${summary.runningCount}',
                        color: PveAppleColors.warning(context),
                      ),
                      const SizedBox(height: 12),
                      PveChartLegendItem(
                        label: 'Failed',
                        value: '${summary.failedCount}',
                        color: PveAppleColors.destructive(context),
                      ),
                      const SizedBox(height: 12),
                      PveChartLegendItem(
                        label: 'Unknown',
                        value: '${summary.unknownCount}',
                        color: PveAppleColors.secondaryLabel(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        KeyedSubtree(
          key: const ValueKey<String>('task-activity-profile'),
          child: PveInsightCard(
            title: 'Activity profile',
            subtitle: 'Where recent operations are occurring',
            child: Column(
              children: <Widget>[
                _ActivityFact(
                  icon: CupertinoIcons.rectangle_stack,
                  label: 'Active nodes',
                  value: '${summary.nodeCount}',
                ),
                const PveRowSeparator(leadingIndent: 38),
                _ActivityFact(
                  icon: CupertinoIcons.person_2,
                  label: 'Operators',
                  value: '${summary.userCount}',
                ),
                const PveRowSeparator(leadingIndent: 38),
                _ActivityFact(
                  icon: CupertinoIcons.timer,
                  label: 'Average completed duration',
                  value: _durationLabel(summary.averageDuration),
                ),
                const PveRowSeparator(leadingIndent: 38),
                _ActivityFact(
                  icon: CupertinoIcons.square_list,
                  label: 'Most frequent operation',
                  value: summary.mostFrequentType ?? 'Not reported',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ActivityFact extends StatelessWidget {
  const _ActivityFact({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: PveAppleColors.primary(context)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: PveAppleText.caption(context))),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: PveAppleText.body(
                context,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskActivitySummary {
  const _TaskActivitySummary({
    required this.runningCount,
    required this.successfulCount,
    required this.failedCount,
    required this.unknownCount,
    required this.nodeCount,
    required this.userCount,
    required this.averageDuration,
    required this.mostFrequentType,
  });

  factory _TaskActivitySummary.from(List<ClusterTask> tasks) {
    int runningCount = 0;
    int successfulCount = 0;
    int failedCount = 0;
    int unknownCount = 0;
    int completedDurationMilliseconds = 0;
    int durationCount = 0;
    final Set<String> nodes = <String>{};
    final Set<String> users = <String>{};
    final Map<String, int> typeCounts = <String, int>{};
    for (final ClusterTask task in tasks) {
      nodes.add(task.node);
      users.add(task.user);
      typeCounts.update(task.type, (int count) => count + 1, ifAbsent: () => 1);
      switch (task.state) {
        case ClusterTaskState.running:
          runningCount += 1;
        case ClusterTaskState.successful:
          successfulCount += 1;
        case ClusterTaskState.failed:
          failedCount += 1;
        case ClusterTaskState.unknown:
          unknownCount += 1;
      }
      final DateTime? startedAt = task.startedAt;
      final DateTime? endedAt = task.endedAt;
      if (startedAt != null &&
          endedAt != null &&
          !endedAt.isBefore(startedAt)) {
        completedDurationMilliseconds += endedAt
            .difference(startedAt)
            .inMilliseconds;
        durationCount += 1;
      }
    }
    String? mostFrequentType;
    int mostFrequentCount = 0;
    for (final MapEntry<String, int> entry in typeCounts.entries) {
      if (entry.value > mostFrequentCount) {
        mostFrequentType = entry.key;
        mostFrequentCount = entry.value;
      }
    }
    return _TaskActivitySummary(
      runningCount: runningCount,
      successfulCount: successfulCount,
      failedCount: failedCount,
      unknownCount: unknownCount,
      nodeCount: nodes.length,
      userCount: users.length,
      averageDuration: durationCount == 0
          ? null
          : Duration(
              milliseconds: completedDurationMilliseconds ~/ durationCount,
            ),
      mostFrequentType: mostFrequentType,
    );
  }

  final int runningCount;
  final int successfulCount;
  final int failedCount;
  final int unknownCount;
  final int nodeCount;
  final int userCount;
  final Duration? averageDuration;
  final String? mostFrequentType;

  double? get completionRate {
    final int completedCount = successfulCount + failedCount + unknownCount;
    if (completedCount == 0) {
      return null;
    }
    return successfulCount / completedCount;
  }
}

String _durationLabel(Duration? duration) {
  if (duration == null) {
    return 'Not reported';
  }
  if (duration.inHours > 0) {
    return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
  }
  if (duration.inMinutes > 0) {
    return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
  }
  return '${duration.inSeconds}s';
}
