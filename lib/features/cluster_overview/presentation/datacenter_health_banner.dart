import 'package:flutter/cupertino.dart';

import '../../../core/presentation/pve_apple_ui.dart';

import '../domain/datacenter_health.dart';
import 'datacenter_dashboard_visuals.dart';

class DatacenterHealthBanner extends StatelessWidget {
  const DatacenterHealthBanner({
    super.key,
    required this.health,
    required this.onViewNodes,
  });

  final DatacenterHealth health;
  final VoidCallback onViewNodes;

  @override
  Widget build(BuildContext context) {
    final DatacenterDashboardTone tone = dashboardToneForHealth(health.state);
    final Color foreground = dashboardToneOnSurfaceColor(context, tone);
    return PveInsetGroup(
      color: dashboardToneSurfaceColor(context, tone),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Semantics(
                label: 'Datacenter health: ${health.headline}',
                child: ExcludeSemantics(
                  child: Icon(
                    dashboardToneIcon(tone),
                    color: foreground,
                    size: 30,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      health.headline,
                      style: PveAppleText.title2(context).copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _healthSummary(health),
                      style: PveAppleText.secondary(
                        context,
                      ).copyWith(color: foreground),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (health.issues.isEmpty)
            Text(
              'No offline nodes, failed recent reported tasks, or elevated '
              'reported node pressure.',
              style: PveAppleText.body(context).copyWith(color: foreground),
            )
          else
            ...health.issues.map(
              (DatacenterHealthIssue issue) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _HealthIssueLine(issue: issue),
              ),
            ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              onPressed: onViewNodes,
              child: const Row(
                children: <Widget>[
                  Expanded(child: Text('View Nodes', textAlign: TextAlign.end)),
                  SizedBox(width: 5),
                  Icon(CupertinoIcons.chevron_forward, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthIssueLine extends StatelessWidget {
  const _HealthIssueLine({required this.issue});

  final DatacenterHealthIssue issue;

  @override
  Widget build(BuildContext context) {
    final DatacenterDashboardTone tone =
        issue.severity == DatacenterHealthIssueSeverity.critical
        ? DatacenterDashboardTone.critical
        : DatacenterDashboardTone.warning;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Semantics(
          label: issue.severity == DatacenterHealthIssueSeverity.critical
              ? 'Critical issue'
              : 'Attention needed',
          child: ExcludeSemantics(
            child: Icon(
              dashboardToneIcon(tone),
              size: 18,
              color: dashboardToneColor(context, tone),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(issue.message)),
      ],
    );
  }
}

String _healthSummary(DatacenterHealth health) {
  final int runningTaskCount = health.tasks.runningTaskCount;
  if (runningTaskCount == 0) {
    return 'Current cluster status from the latest reported snapshot.';
  }
  return '$runningTaskCount ${runningTaskCount == 1 ? 'task is' : 'tasks are'} '
      'currently in progress.';
}
