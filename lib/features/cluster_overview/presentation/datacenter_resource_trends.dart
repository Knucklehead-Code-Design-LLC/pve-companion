import 'package:flutter/cupertino.dart';

import '../../../core/presentation/pve_apple_ui.dart';
import '../../../core/presentation/pve_value_format.dart';
import '../domain/datacenter_resource_history.dart';

/// Shows a comparison between the most recent two local refresh samples.
/// The connected server does not supply historical monitoring data here.
class DatacenterResourceTrends extends StatelessWidget {
  const DatacenterResourceTrends({super.key, required this.samples});

  final List<DatacenterResourceSample> samples;

  @override
  Widget build(BuildContext context) {
    final DatacenterResourceSample? current = samples.isEmpty
        ? null
        : samples.last;
    final DatacenterResourceSample? previous = samples.length < 2
        ? null
        : samples[samples.length - 2];
    return PveInsetGroup(
      key: const ValueKey<String>('datacenter-local-resource-trends'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Refresh comparison', style: PveAppleText.title3(context)),
          const SizedBox(height: 3),
          Text(
            previous == null
                ? 'Refresh again to compare current utilization. Samples stay only in this app session (up to 24).'
                : 'Current refresh compared with the previous local refresh. Samples stay only in this app session (up to 24).',
            style: PveAppleText.secondary(context),
          ),
          const SizedBox(height: 12),
          _TrendRow(
            label: 'CPU',
            current: current?.cpuFraction,
            previous: previous?.cpuFraction,
          ),
          const PveRowSeparator(),
          _TrendRow(
            label: 'Memory',
            current: current?.memoryFraction,
            previous: previous?.memoryFraction,
          ),
          const PveRowSeparator(),
          _TrendRow(
            label: 'Root disk',
            current: current?.diskFraction,
            previous: previous?.diskFraction,
          ),
          const PveRowSeparator(),
          _TrendRow(
            label: 'Storage',
            current: current?.storageFraction,
            previous: previous?.storageFraction,
          ),
        ],
      ),
    );
  }
}

class _TrendRow extends StatelessWidget {
  const _TrendRow({
    required this.label,
    required this.current,
    required this.previous,
  });

  final String label;
  final double? current;
  final double? previous;

  @override
  Widget build(BuildContext context) {
    final double? change = current == null || previous == null
        ? null
        : current! - previous!;
    final Color color = change == null
        ? PveAppleColors.secondaryLabel(context)
        : change > 0
        ? PveAppleColors.warning(context)
        : change < 0
        ? PveAppleColors.success(context)
        : PveAppleColors.secondaryLabel(context);
    final String trend = change == null
        ? 'Comparison unavailable'
        : change == 0
        ? 'Unchanged'
        : '${change > 0 ? 'Up' : 'Down'} ${formatPvePercent(change.abs())}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: PveAppleText.body(context))),
          Text(
            current == null ? 'Not reported' : formatPvePercent(current),
            style: PveAppleText.body(
              context,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 118,
            child: Text(
              trend,
              textAlign: TextAlign.end,
              style: PveAppleText.caption(context).copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
