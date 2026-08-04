import 'package:flutter/cupertino.dart';

import '../../../core/presentation/pve_apple_ui.dart';
import '../../../core/presentation/pve_data_visualization.dart';
import '../../../core/presentation/pve_value_format.dart';
import '../domain/datacenter_resource_history.dart';

/// Shows the last 24 hours of server-recorded node utilization when Proxmox
/// grants access to its RRD data. It never presents local refreshes as history.
class DatacenterResourceTrends extends StatelessWidget {
  const DatacenterResourceTrends({super.key, required this.history});

  final DatacenterResourceHistory history;

  @override
  Widget build(BuildContext context) {
    return PveInsetGroup(
      key: const ValueKey<String>('datacenter-resource-history'),
      padding: const EdgeInsets.all(16),
      child: history.isAvailable
          ? _AvailableResourceHistory(history: history)
          : _UnavailableResourceHistory(reason: history.unavailableReason),
    );
  }
}

class _AvailableResourceHistory extends StatelessWidget {
  const _AvailableResourceHistory({required this.history});

  final DatacenterResourceHistory history;

  @override
  Widget build(BuildContext context) {
    final samples = history.samples;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Icon(
              CupertinoIcons.chart_bar,
              size: 18,
              color: PveAppleColors.primary(context),
            ),
            const SizedBox(width: 8),
            Text('24-hour utilization', style: PveAppleText.title3(context)),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          'Last 24 hours · ${_historyCoverageLabel(history)}',
          style: PveAppleText.secondary(context),
        ),
        const SizedBox(height: 14),
        _ResourceHistoryRow(
          label: 'CPU use',
          values: samples
              .map((DatacenterResourceSample sample) => sample.cpuFraction)
              .toList(growable: false),
          color: PveAppleColors.primary(context),
        ),
        const SizedBox(height: 14),
        _ResourceHistoryRow(
          label: 'Memory use',
          values: samples
              .map((DatacenterResourceSample sample) => sample.memoryFraction)
              .toList(growable: false),
          color: CupertinoColors.systemPurple.resolveFrom(context),
        ),
        const SizedBox(height: 14),
        _ResourceHistoryRow(
          label: 'Disk use',
          values: samples
              .map((DatacenterResourceSample sample) => sample.diskFraction)
              .toList(growable: false),
          color: CupertinoColors.systemTeal.resolveFrom(context),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              'Start ${_timeLabel(samples.first.recordedAt)}',
              style: PveAppleText.caption(context),
            ),
            Text(
              'Latest ${_timeLabel(samples.last.recordedAt)}',
              style: PveAppleText.caption(context),
            ),
          ],
        ),
      ],
    );
  }
}

class _ResourceHistoryRow extends StatelessWidget {
  const _ResourceHistoryRow({
    required this.label,
    required this.values,
    required this.color,
  });

  final String label;
  final List<double?> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final latestValue = _latestReportedValue(values);
    final latestLabel = formatPvePercent(latestValue);
    final latestDescription = latestValue == null
        ? 'not reported'
        : latestLabel;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text(label, style: PveAppleText.caption(context))),
            Text(
              latestValue == null ? 'Not reported' : latestLabel,
              style: PveAppleText.caption(
                context,
              ).copyWith(color: color, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 5),
        PveSparkline(
          values: values,
          color: color,
          semanticLabel:
              '$label utilization over the past 24 hours. '
              'Latest $latestDescription.',
        ),
      ],
    );
  }
}

class _UnavailableResourceHistory extends StatelessWidget {
  const _UnavailableResourceHistory({required this.reason});

  final DatacenterResourceHistoryUnavailableReason? reason;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Text('24-hour utilization', style: PveAppleText.title3(context)),
      const SizedBox(height: 3),
      Text(
        _unavailableHistoryMessage(reason),
        style: PveAppleText.secondary(context),
      ),
    ],
  );
}

double? _latestReportedValue(List<double?> values) {
  for (var index = values.length - 1; index >= 0; index -= 1) {
    final value = values[index];
    if (value != null) {
      return value;
    }
  }
  return null;
}

String _historyCoverageLabel(DatacenterResourceHistory history) {
  final reportingNodeCount = history.reportingNodeCount;
  final requestedNodeCount = history.requestedNodeCount;
  if (reportingNodeCount == requestedNodeCount) {
    return '$reportingNodeCount '
        '${reportingNodeCount == 1 ? 'node' : 'nodes'} reporting';
  }
  return '$reportingNodeCount/$requestedNodeCount nodes reporting';
}

String _unavailableHistoryMessage(
  DatacenterResourceHistoryUnavailableReason? reason,
) => switch (reason) {
  DatacenterResourceHistoryUnavailableReason.noNodes =>
    'No nodes are reported by this server.',
  DatacenterResourceHistoryUnavailableReason.permissionDenied =>
    'Historical metrics need Sys.Audit access on this server.',
  DatacenterResourceHistoryUnavailableReason.unsupported =>
    'This Proxmox server does not provide node history.',
  DatacenterResourceHistoryUnavailableReason.requestFailed =>
    'Historical metrics could not be loaded. Refresh to try again.',
  DatacenterResourceHistoryUnavailableReason.noData ||
  null => 'No historical metrics are available yet.',
};

String _timeLabel(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
