import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import 'pve_apple_ui.dart';

class PveChartSegment {
  const PveChartSegment({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PveChartSegment &&
            other.label == label &&
            other.value == value &&
            other.color == color;
  }

  @override
  int get hashCode => Object.hash(label, value, color);
}

class PveRingChart extends StatelessWidget {
  const PveRingChart({
    super.key,
    required this.segments,
    required this.centerValue,
    required this.centerLabel,
    required this.semanticLabel,
    this.size = 112,
    this.strokeWidth = 11,
  });

  final List<PveChartSegment> segments;
  final String centerValue;
  final String centerLabel;
  final String semanticLabel;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              CustomPaint(
                painter: _PveRingChartPainter(
                  segments: segments,
                  trackColor: PveAppleColors.separator(
                    context,
                  ).withValues(alpha: 0.24),
                  strokeWidth: strokeWidth,
                ),
              ),
              Center(
                child: Padding(
                  padding: EdgeInsets.all(strokeWidth + 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        centerValue,
                        maxLines: 1,
                        style: PveAppleText.title3(context),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        centerLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PveAppleText.caption(context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PveRingChartPainter extends CustomPainter {
  const _PveRingChartPainter({
    required this.segments,
    required this.trackColor,
    required this.strokeWidth,
  });

  final List<PveChartSegment> segments;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final Rect bounds = Rect.fromCircle(center: center, radius: radius);
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    canvas.drawCircle(center, radius, paint..color = trackColor);

    final List<PveChartSegment> visibleSegments = segments
        .where(
          (PveChartSegment segment) =>
              segment.value.isFinite && segment.value > 0,
        )
        .toList(growable: false);
    final double total = visibleSegments.fold<double>(
      0,
      (double value, PveChartSegment segment) => value + segment.value,
    );
    if (total <= 0) {
      return;
    }

    const double gap = 0.025;
    double startAngle = -math.pi / 2;
    for (final PveChartSegment segment in visibleSegments) {
      final double sweep = (segment.value / total) * math.pi * 2;
      final double visibleSweep = math.max(0, sweep - gap);
      canvas.drawArc(
        bounds,
        startAngle + gap / 2,
        visibleSweep,
        false,
        paint..color = segment.color,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(_PveRingChartPainter oldDelegate) {
    return !_segmentsMatch(oldDelegate.segments, segments) ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

bool _segmentsMatch(List<PveChartSegment> left, List<PveChartSegment> right) {
  if (left.length != right.length) {
    return false;
  }
  for (int index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

class PveInsightCard extends StatelessWidget {
  const PveInsightCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.footer,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return PveInsetGroup(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Semantics(
                      header: true,
                      child: Text(title, style: PveAppleText.title3(context)),
                    ),
                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: 3),
                      Text(subtitle!, style: PveAppleText.caption(context)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...<Widget>[
                const SizedBox(width: 12),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: 18),
          child,
          if (footer != null) ...<Widget>[const SizedBox(height: 16), footer!],
        ],
      ),
    );
  }
}

class PveAdaptiveCardGrid extends StatelessWidget {
  const PveAdaptiveCardGrid({
    super.key,
    required this.children,
    this.breakpoint = 700,
    this.spacing = 12,
  });

  final List<Widget> children;
  final double breakpoint;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool supportsColumns =
            constraints.maxWidth >= breakpoint &&
            MediaQuery.textScalerOf(context).scale(17) < 24;
        if (!supportsColumns || children.length < 2) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (int index = 0; index < children.length; index++) ...<Widget>[
                if (index > 0) SizedBox(height: spacing),
                children[index],
              ],
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (int index = 0; index < children.length; index++) ...<Widget>[
                if (index > 0) SizedBox(width: spacing),
                Expanded(child: children[index]),
              ],
            ],
          ),
        );
      },
    );
  }
}

class PveResourceMeter extends StatelessWidget {
  const PveResourceMeter({
    super.key,
    required this.label,
    required this.value,
    required this.progress,
    required this.color,
    this.detail,
  });

  final String label;
  final String value;
  final double? progress;
  final Color color;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      excludeSemantics: true,
      label: '$label: $value${detail == null ? '' : ', $detail'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Text(label, style: PveAppleText.caption(context)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: PveAppleText.caption(
                    context,
                  ).copyWith(color: color, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          PveProgressBar(value: progress, color: color),
          if (detail != null) ...<Widget>[
            const SizedBox(height: 5),
            Text(detail!, style: PveAppleText.caption(context)),
          ],
        ],
      ),
    );
  }
}

class PveChartLegendItem extends StatelessWidget {
  const PveChartLegendItem({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: const SizedBox.square(dimension: 8),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: PveAppleText.caption(context))),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: PveAppleText.caption(context),
          ),
        ),
      ],
    );
  }
}
