import 'package:flutter/cupertino.dart';

import '../../../core/presentation/pve_apple_ui.dart';
import '../../../core/presentation/pve_modal_sheet.dart';
import '../domain/datacenter_incident.dart';

Future<void> showDatacenterIncidentCenter(
  BuildContext context, {
  required DatacenterIncidentSnapshot snapshot,
  required VoidCallback onViewNodes,
  required VoidCallback onViewStorage,
  required VoidCallback onViewTasks,
}) {
  return showPveModalSheet<void>(
    context: context,
    scrollableBuilder:
        (BuildContext sheetContext, ScrollController scrollController) =>
            _DatacenterIncidentCenterSheet(
              snapshot: snapshot,
              scrollController: scrollController,
              onViewNodes: onViewNodes,
              onViewStorage: onViewStorage,
              onViewTasks: onViewTasks,
            ),
  );
}

class DatacenterIncidentHighlights extends StatelessWidget {
  const DatacenterIncidentHighlights({
    super.key,
    required this.snapshot,
    required this.onViewAll,
    required this.onViewNodes,
    required this.onViewStorage,
    required this.onViewTasks,
  });

  final DatacenterIncidentSnapshot snapshot;
  final VoidCallback onViewAll;
  final VoidCallback onViewNodes;
  final VoidCallback onViewStorage;
  final VoidCallback onViewTasks;

  @override
  Widget build(BuildContext context) {
    if (snapshot.isEmpty) return const SizedBox.shrink();
    final List<DatacenterIncident> visible = snapshot.incidents
        .take(3)
        .toList(growable: false);
    return PveInsetGroup(
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          for (int index = 0; index < visible.length; index++) ...<Widget>[
            _IncidentRow(
              incident: visible[index],
              onTap: () => _navigate(visible[index].target),
            ),
            if (index < visible.length - 1) const PveRowSeparator(),
          ],
          if (snapshot.incidents.length > visible.length) ...<Widget>[
            const PveRowSeparator(leadingIndent: 16),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              alignment: Alignment.centerLeft,
              onPressed: onViewAll,
              child: Text(
                'View ${snapshot.incidents.length - visible.length} more ${snapshot.incidents.length - visible.length == 1 ? 'incident' : 'incidents'}',
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _navigate(DatacenterIncidentTarget target) {
    switch (target) {
      case DatacenterIncidentTarget.nodes:
        onViewNodes();
      case DatacenterIncidentTarget.storage:
        onViewStorage();
      case DatacenterIncidentTarget.tasks:
        onViewTasks();
    }
  }
}

class _DatacenterIncidentCenterSheet extends StatelessWidget {
  const _DatacenterIncidentCenterSheet({
    required this.snapshot,
    required this.scrollController,
    required this.onViewNodes,
    required this.onViewStorage,
    required this.onViewTasks,
  });

  final DatacenterIncidentSnapshot snapshot;
  final ScrollController scrollController;
  final VoidCallback onViewNodes;
  final VoidCallback onViewStorage;
  final VoidCallback onViewTasks;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: PveAppleColors.page(context),
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Incident Center'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.only(bottom: 32),
                children: <Widget>[
                  Text(
                    'Operational attention',
                    style: PveAppleText.title2(context),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    snapshot.isEmpty
                        ? 'No active incidents are derived from the latest datacenter refresh.'
                        : 'Prioritized from node availability, capacity pressure, storage availability, and failed tasks.',
                    style: PveAppleText.secondary(context),
                  ),
                  const SizedBox(height: 18),
                  PveMetricStrip(
                    items: <PveMetricStripItem>[
                      PveMetricStripItem(
                        label: 'Critical',
                        value: '${snapshot.criticalCount}',
                        icon: CupertinoIcons.exclamationmark_triangle_fill,
                        color: snapshot.criticalCount == 0
                            ? PveAppleColors.success(context)
                            : PveAppleColors.destructive(context),
                      ),
                      PveMetricStripItem(
                        label: 'Attention',
                        value: '${snapshot.warningCount}',
                        icon: CupertinoIcons.exclamationmark_circle_fill,
                        color: snapshot.warningCount == 0
                            ? PveAppleColors.success(context)
                            : PveAppleColors.warning(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (snapshot.isEmpty)
                    PveInsetGroup(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        children: <Widget>[
                          Icon(
                            CupertinoIcons.check_mark_circled_solid,
                            size: 32,
                            color: PveAppleColors.success(context),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Everything looks healthy',
                            style: PveAppleText.title3(context),
                          ),
                        ],
                      ),
                    )
                  else
                    PveInsetGroup(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: <Widget>[
                          for (
                            int index = 0;
                            index < snapshot.incidents.length;
                            index++
                          ) ...<Widget>[
                            _IncidentRow(
                              incident: snapshot.incidents[index],
                              onTap: () => _navigate(
                                context,
                                snapshot.incidents[index].target,
                              ),
                            ),
                            if (index < snapshot.incidents.length - 1)
                              const PveRowSeparator(),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _navigate(BuildContext context, DatacenterIncidentTarget target) {
    Navigator.of(context).pop();
    switch (target) {
      case DatacenterIncidentTarget.nodes:
        onViewNodes();
      case DatacenterIncidentTarget.storage:
        onViewStorage();
      case DatacenterIncidentTarget.tasks:
        onViewTasks();
    }
  }
}

class _IncidentRow extends StatelessWidget {
  const _IncidentRow({required this.incident, required this.onTap});

  final DatacenterIncident incident;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = incident.severity == DatacenterIncidentSeverity.critical
        ? PveAppleColors.destructive(context)
        : PveAppleColors.warning(context);
    return PveListRow(
      leading: Icon(
        incident.severity == DatacenterIncidentSeverity.critical
            ? CupertinoIcons.exclamationmark_triangle_fill
            : CupertinoIcons.exclamationmark_circle_fill,
        color: color,
      ),
      title: Text(incident.title),
      subtitle: Text(incident.detail),
      trailing: MediaQuery.withClampedTextScaling(
        // The short status tag stays legible beside the incident title at
        // very large text sizes; the actionable title and detail still scale.
        maxScaleFactor: 1.25,
        child: PveStatusPill(
          label: incident.severity == DatacenterIncidentSeverity.critical
              ? 'Critical'
              : 'Attention',
          color: color,
        ),
      ),
      onTap: onTap,
    );
  }
}
