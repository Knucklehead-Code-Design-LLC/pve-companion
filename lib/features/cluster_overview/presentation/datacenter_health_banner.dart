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
    final tone = dashboardToneForHealth(health.state);
    final accent = dashboardToneColor(context, tone);
    return PveInsetGroup(
      onTap: onViewNodes,
      semanticLabel:
          'Datacenter health. ${_healthTitle(health)}. '
          '${_healthSummary(health)}',
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Semantics(
                label: 'Datacenter health: ${_healthTitle(health)}',
                child: ExcludeSemantics(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.13),
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox.square(
                      dimension: 38,
                      child: Icon(
                        dashboardToneIcon(tone),
                        color: accent,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _healthTitle(health),
                      style: PveAppleText.title3(context),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _healthSummary(health),
                      style: PveAppleText.secondary(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                CupertinoIcons.chevron_forward,
                size: 14,
                color: PveAppleColors.secondaryLabel(context),
              ),
            ],
          ),
          if (health.issues.isNotEmpty) ...<Widget>[
            const SizedBox(height: 14),
            for (final issue in health.issues.take(2))
              Padding(
                padding: const EdgeInsets.only(left: 50, bottom: 7),
                child: _HealthIssueLine(issue: issue),
              ),
            if (health.issues.length > 2)
              Padding(
                padding: const EdgeInsets.only(left: 50),
                child: Text(
                  '${health.issues.length - 2} more reported '
                  '${health.issues.length - 2 == 1 ? 'issue' : 'issues'}',
                  style: PveAppleText.caption(context),
                ),
              ),
          ],
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
    final tone = issue.severity == DatacenterHealthIssueSeverity.critical
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
  final runningTaskCount = health.tasks.runningTaskCount;
  final onlineNodes = health.nodes.length - health.offlineNodeCount;
  final taskSummary = runningTaskCount == 0
      ? 'no active tasks'
      : '$runningTaskCount active ${runningTaskCount == 1 ? 'task' : 'tasks'}';
  return '$onlineNodes/${health.nodes.length} nodes online · '
      '${health.workload.runningGuests} guests running · $taskSummary';
}

String _healthTitle(DatacenterHealth health) => switch (health.state) {
  DatacenterHealthState.healthy => 'All systems operational',
  DatacenterHealthState.warning => 'Attention recommended',
  DatacenterHealthState.critical => 'Action required',
};
