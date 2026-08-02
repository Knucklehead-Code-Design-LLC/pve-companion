import 'package:flutter/cupertino.dart';

import '../../../core/presentation/pve_apple_ui.dart';
import '../../incidents/domain/datacenter_incident_evaluator.dart';
import '../../incidents/presentation/datacenter_incident_center.dart';
import '../domain/cluster_overview_snapshot.dart';
import '../domain/datacenter_health.dart';
import 'cluster_load_state_view.dart';
import 'datacenter_activity_section.dart';
import 'datacenter_health_banner.dart';
import 'datacenter_nodes_section.dart';
import 'datacenter_operational_summary.dart';

class DatacenterDashboard extends StatelessWidget {
  const DatacenterDashboard({
    super.key,
    required this.snapshot,
    required this.health,
    this.showsSliverNavigationBar = true,
    this.navigationLeading,
    this.navigationTrailing,
    required this.onRefresh,
    required this.onViewGuests,
    required this.onViewNodes,
    required this.onViewStorage,
    required this.onViewTasks,
    this.refreshErrorMessage,
  });

  final ClusterOverviewSnapshot snapshot;
  final DatacenterHealth health;
  final bool showsSliverNavigationBar;
  final Widget? navigationLeading;
  final Widget? navigationTrailing;
  final Future<void> Function() onRefresh;
  final VoidCallback onViewGuests;
  final VoidCallback onViewNodes;
  final VoidCallback onViewStorage;
  final VoidCallback onViewTasks;
  final String? refreshErrorMessage;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wideLayout = constraints.maxWidth >= 760;
        final incidents = DatacenterIncidentEvaluator.evaluate(snapshot);
        final EdgeInsets padding = EdgeInsets.symmetric(
          horizontal: wideLayout ? 28 : 16,
          vertical: wideLayout ? 24 : 16,
        );
        return PvePrimaryScrollView(
          title: 'Datacenter',
          scrollViewKey: const ValueKey<String>('datacenter-dashboard'),
          showsSliverNavigationBar: showsSliverNavigationBar,
          navigationLeading: navigationLeading,
          navigationTrailing: navigationTrailing,
          onRefresh: onRefresh,
          slivers: <Widget>[
            SliverPadding(
              padding: padding,
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1360),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                          child: Text(
                            _versionContext(snapshot.version),
                            style: PveAppleText.caption(context),
                          ),
                        ),
                        if (refreshErrorMessage != null) ...<Widget>[
                          ClusterRefreshFailureBanner(
                            message: refreshErrorMessage!,
                            onRetry: onRefresh,
                          ),
                          const SizedBox(height: 12),
                        ],
                        DatacenterHealthBanner(
                          health: health,
                          onViewNodes: onViewNodes,
                        ),
                        const SizedBox(height: 28),
                        if (!incidents.isEmpty) ...<Widget>[
                          PveSectionHeader(
                            title: 'Needs attention',
                            actionLabel: 'View all',
                            actionSemanticsLabel:
                                'View all datacenter incidents',
                            onAction: () => showDatacenterIncidentCenter(
                              context,
                              snapshot: incidents,
                              onViewNodes: onViewNodes,
                              onViewStorage: onViewStorage,
                              onViewTasks: onViewTasks,
                            ),
                          ),
                          DatacenterIncidentHighlights(
                            snapshot: incidents,
                            onViewAll: () => showDatacenterIncidentCenter(
                              context,
                              snapshot: incidents,
                              onViewNodes: onViewNodes,
                              onViewStorage: onViewStorage,
                              onViewTasks: onViewTasks,
                            ),
                            onViewNodes: onViewNodes,
                            onViewStorage: onViewStorage,
                            onViewTasks: onViewTasks,
                          ),
                          const SizedBox(height: 28),
                        ],
                        const PveSectionHeader(title: 'Operational Summary'),
                        DatacenterOperationalSummary(
                          snapshot: snapshot,
                          health: health,
                          onViewGuests: onViewGuests,
                          onViewStorage: onViewStorage,
                        ),
                        const SizedBox(height: 28),
                        DatacenterNodesSection(
                          health: health,
                          onViewNodes: onViewNodes,
                        ),
                        const SizedBox(height: 28),
                        DatacenterRecentActivitySection(
                          tasks: snapshot.tasks,
                          onViewTasks: onViewTasks,
                        ),
                        const SizedBox(height: 28),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

String _versionContext(PveVersion version) {
  final String release = version.release?.trim() ?? '';
  final String releaseSuffix = release.isEmpty ? '' : ' · $release';
  return 'Proxmox VE ${version.version}$releaseSuffix';
}
