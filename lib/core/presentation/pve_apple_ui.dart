import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Divider, Tooltip;

abstract final class PveAppleLayout {
  /// Named layout tiers keep desktop and tablet behavior consistent across pages.
  static const double compactBreakpoint = 760;
  static const double wideBreakpoint = 1280;

  static bool usesExpandedPresentation(BuildContext context) {
    return MediaQuery.sizeOf(context).width >= compactBreakpoint;
  }

  static bool usesWidePresentation(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= wideBreakpoint;

  static bool usesExpandedWidth(double width) => width >= compactBreakpoint;

  static bool usesWideWidth(double width) => width >= wideBreakpoint;
}

abstract final class PveAppleColors {
  static const Color accent = Color(0xFF007AFF);
  static const Color accentDark = Color(0xFF0A84FF);

  static Color primary(BuildContext context) {
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark
        ? accentDark
        : accent;
  }

  static Color page(BuildContext context) =>
      CupertinoColors.systemGroupedBackground.resolveFrom(context);

  static Color surface(BuildContext context) =>
      CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context);

  static Color label(BuildContext context) =>
      CupertinoColors.label.resolveFrom(context);

  static Color secondaryLabel(BuildContext context) =>
      CupertinoColors.secondaryLabel.resolveFrom(context);

  static Color separator(BuildContext context) =>
      CupertinoColors.separator.resolveFrom(context);

  static Color destructive(BuildContext context) =>
      CupertinoColors.systemRed.resolveFrom(context);

  static Color warning(BuildContext context) =>
      CupertinoColors.systemOrange.resolveFrom(context);

  static Color success(BuildContext context) =>
      CupertinoColors.systemGreen.resolveFrom(context);
}

abstract final class PveAppleText {
  static TextStyle largeTitle(BuildContext context) =>
      CupertinoTheme.of(context).textTheme.navLargeTitleTextStyle.copyWith(
        color: PveAppleColors.label(context),
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.7,
      );

  static TextStyle title1(BuildContext context) =>
      CupertinoTheme.of(context).textTheme.navTitleTextStyle.copyWith(
        color: PveAppleColors.label(context),
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      );

  static TextStyle title2(BuildContext context) =>
      CupertinoTheme.of(context).textTheme.navTitleTextStyle.copyWith(
        color: PveAppleColors.label(context),
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      );

  static TextStyle title3(BuildContext context) =>
      CupertinoTheme.of(context).textTheme.textStyle.copyWith(
        color: PveAppleColors.label(context),
        fontSize: 17,
        fontWeight: FontWeight.w600,
      );

  static TextStyle body(BuildContext context) =>
      CupertinoTheme.of(context).textTheme.textStyle.copyWith(
        color: PveAppleColors.label(context),
        fontSize: 15,
        height: 1.35,
      );

  static TextStyle secondary(BuildContext context) => body(context).copyWith(
    color: PveAppleColors.secondaryLabel(context),
    fontSize: PveAppleLayout.usesExpandedPresentation(context) ? 14.5 : 14,
    height: 1.4,
  );

  static TextStyle caption(BuildContext context) => body(context).copyWith(
    color: PveAppleColors.secondaryLabel(context),
    fontSize: PveAppleLayout.usesExpandedPresentation(context) ? 12.5 : 12,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );
}

/// Shared, descriptive labels for actions that recur throughout the app.
abstract final class PveActionLabels {
  static const String refresh = 'Refresh data';
  static const String close = 'Close';
  static const String retry = 'Try again';
  static const String viewAll = 'View all';
}

/// A consistently sized icon action with both a spoken label and desktop tooltip.
class PveIconAction extends StatelessWidget {
  const PveIconAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final Color color = isDestructive
        ? PveAppleColors.destructive(context)
        : PveAppleColors.primary(context);
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      child: Tooltip(
        message: label,
        child: CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: const Size(44, 44),
          onPressed: onPressed,
          child: Icon(icon, color: color),
        ),
      ),
    );
  }
}

/// Shows relative freshness visually while always exposing the exact time.
class PveFreshnessLabel extends StatelessWidget {
  const PveFreshnessLabel({
    super.key,
    required this.refreshedAt,
    this.prefix = 'Data refreshed',
  });

  final DateTime refreshedAt;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    final DateTime localTime = refreshedAt.toLocal();
    final String clock =
        '${localTime.hour.toString().padLeft(2, '0')}:${localTime.minute.toString().padLeft(2, '0')}';
    final String date = '${localTime.month}/${localTime.day}/${localTime.year}';
    final Duration age = DateTime.now().difference(refreshedAt);
    final String relative = _relativeAge(age);
    final String exact = '$prefix at $date, $clock';
    return Semantics(
      label: exact,
      child: Tooltip(
        message: exact,
        child: ExcludeSemantics(
          child: Text(
            '$prefix $relative',
            style: PveAppleText.caption(context),
          ),
        ),
      ),
    );
  }

  String _relativeAge(Duration age) {
    if (age.isNegative || age.inSeconds < 10) return 'just now';
    if (age.inMinutes < 1) return '${age.inSeconds}s ago';
    if (age.inHours < 1) return '${age.inMinutes}m ago';
    if (age.inDays < 1) return '${age.inHours}h ago';
    return '${age.inDays}d ago';
  }
}

class PvePrimaryScrollView extends StatelessWidget {
  const PvePrimaryScrollView({
    super.key,
    required this.title,
    required this.slivers,
    this.navigationLeading,
    this.navigationTrailing,
    this.onRefresh,
    this.showsSliverNavigationBar = true,
    this.scrollViewKey,
  });

  final String title;
  final List<Widget> slivers;
  final Widget? navigationLeading;
  final Widget? navigationTrailing;
  final Future<void> Function()? onRefresh;
  final bool showsSliverNavigationBar;
  final Key? scrollViewKey;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      key: scrollViewKey,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: <Widget>[
        if (showsSliverNavigationBar)
          CupertinoSliverNavigationBar(
            transitionBetweenRoutes: false,
            stretch: true,
            largeTitle: Text(title),
            leading: navigationLeading,
            trailing: navigationTrailing,
          ),
        if (onRefresh != null)
          CupertinoSliverRefreshControl(onRefresh: onRefresh),
        ...slivers,
      ],
    );
  }
}

class PveCenteredSliver extends StatelessWidget {
  const PveCenteredSliver({
    super.key,
    required this.child,
    this.maxWidth = 1360,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 28),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: padding,
      sliver: SliverToBoxAdapter(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: child,
          ),
        ),
      ),
    );
  }
}

class PveSlidingSegmentedControl<T extends Object> extends StatelessWidget {
  const PveSlidingSegmentedControl({
    super.key,
    required this.groupValue,
    required this.children,
    required this.onValueChanged,
    this.semanticLabels,
  });

  final T groupValue;
  final Map<T, Widget> children;
  final ValueChanged<T?> onValueChanged;
  final Map<T, String>? semanticLabels;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: CupertinoTheme.of(context).textTheme.textStyle.copyWith(
        color: PveAppleColors.label(context),
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
      ),
      child: CupertinoSlidingSegmentedControl<T>(
        groupValue: groupValue,
        children: <T, Widget>{
          for (final MapEntry<T, Widget> entry in children.entries)
            entry.key: Semantics(
              button: true,
              selected: entry.key == groupValue,
              label: semanticLabels?[entry.key],
              child: ExcludeSemantics(child: entry.value),
            ),
        },
        onValueChanged: onValueChanged,
      ),
    );
  }
}

class PveWideControlBar extends StatelessWidget {
  const PveWideControlBar({
    super.key,
    required this.primary,
    required this.secondary,
    this.secondaryWidth = 360,
  });

  final Widget primary;
  final Widget secondary;
  final double secondaryWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 700) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[primary, const SizedBox(height: 12), secondary],
          );
        }
        return Row(
          children: <Widget>[
            Expanded(child: primary),
            const SizedBox(width: 12),
            SizedBox(width: secondaryWidth, child: secondary),
          ],
        );
      },
    );
  }
}

class PveMetricStripItem {
  const PveMetricStripItem({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
    this.scope,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  /// Clarifies the population behind a metric, for example "across 3 nodes".
  final String? scope;
}

class PveMetricStrip extends StatelessWidget {
  const PveMetricStrip({super.key, required this.items});

  final List<PveMetricStripItem> items;

  @override
  Widget build(BuildContext context) {
    return PveInsetGroup(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          if (constraints.maxWidth < 700) {
            final double cellWidth = constraints.maxWidth / 2;
            return Wrap(
              runSpacing: 14,
              children: items
                  .map(
                    (PveMetricStripItem item) => SizedBox(
                      width: cellWidth,
                      child: _PveMetricStripCell(item: item),
                    ),
                  )
                  .toList(growable: false),
            );
          }
          return Row(
            children: <Widget>[
              for (int index = 0; index < items.length; index++) ...<Widget>[
                if (index > 0)
                  Container(
                    width: 0.5,
                    height: 38,
                    color: PveAppleColors.separator(
                      context,
                    ).withValues(alpha: 0.65),
                  ),
                Expanded(child: _PveMetricStripCell(item: items[index])),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _PveMetricStripCell extends StatelessWidget {
  const _PveMetricStripCell({required this.item});

  final PveMetricStripItem item;

  @override
  Widget build(BuildContext context) {
    final Color color = item.color ?? PveAppleColors.primary(context);
    return Semantics(
      excludeSemantics: true,
      label: <String>[
        item.label,
        item.value,
        if (item.scope != null) item.scope!,
      ].join(': '),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: <Widget>[
            SizedBox.square(
              dimension: 28,
              child: Center(child: Icon(item.icon, size: 18, color: color)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(item.value, style: PveAppleText.title3(context)),
                  const SizedBox(height: 1),
                  Text(item.label, style: PveAppleText.caption(context)),
                  if (item.scope != null)
                    Text(item.scope!, style: PveAppleText.caption(context)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PvePageHeader extends StatelessWidget {
  const PvePageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.large = true,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final Widget header = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: large
                      ? PveAppleText.title1(context)
                      : PveAppleText.title2(context),
                ),
              ),
              if (subtitle != null) ...<Widget>[
                const SizedBox(height: 5),
                Text(subtitle!, style: PveAppleText.secondary(context)),
              ],
            ],
          ),
        ),
        if (trailing != null) ...<Widget>[const SizedBox(width: 16), trailing!],
      ],
    );
    if (!PveAppleLayout.usesExpandedPresentation(context)) return header;
    return Align(alignment: Alignment.centerLeft, child: header);
  }
}

class PveSectionHeader extends StatelessWidget {
  const PveSectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.actionSemanticsLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final String? actionSemanticsLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
      child: Row(
        children: <Widget>[
          Expanded(child: PveSectionTitle(title: title)),
          if (actionLabel != null && onAction != null)
            Semantics(
              button: true,
              label: actionSemanticsLabel,
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                minimumSize: const Size(44, 36),
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ),
        ],
      ),
    );
  }
}

class PveSectionTitle extends StatelessWidget {
  const PveSectionTitle({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(title, style: PveAppleText.title2(context)),
    );
  }
}

class PveInsetGroup extends StatelessWidget {
  const PveInsetGroup({
    super.key,
    required this.child,
    this.padding,
    this.color,
    this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? color;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final bool desktop = PveAppleLayout.usesExpandedPresentation(context);
    final BorderRadius borderRadius = BorderRadius.circular(desktop ? 12 : 14);
    final Color backgroundColor = color ?? PveAppleColors.surface(context);
    final BoxDecoration decoration = BoxDecoration(
      color: onTap == null ? backgroundColor : null,
      borderRadius: borderRadius,
      border: desktop && onTap == null && color == null
          ? null
          : Border.all(
              color: PveAppleColors.separator(context).withValues(alpha: 0.35),
              width: 0.5,
            ),
    );
    Widget content;
    if (onTap != null) {
      content = DecoratedBox(
        decoration: decoration,
        child: CupertinoButton(
          color: backgroundColor,
          padding: padding ?? EdgeInsets.zero,
          alignment: Alignment.centerLeft,
          borderRadius: borderRadius,
          pressedOpacity: 0.72,
          onPressed: onTap,
          child: DefaultTextStyle.merge(
            style: PveAppleText.body(context),
            child: child,
          ),
        ),
      );
    } else {
      content = DecoratedBox(
        decoration: decoration,
        child: DefaultTextStyle.merge(
          style: PveAppleText.body(context),
          child: padding == null
              ? child
              : Padding(padding: padding!, child: child),
        ),
      );
    }
    return Semantics(
      container: true,
      button: onTap != null,
      label: semanticLabel,
      child: content,
    );
  }
}

class PveListRow extends StatelessWidget {
  const PveListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final Widget row = Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double maxTrailingWidth = constraints.maxWidth * 0.6;
          return Row(
            children: <Widget>[
              if (leading != null) ...<Widget>[
                IconTheme(
                  data: IconThemeData(
                    color: PveAppleColors.primary(context),
                    size: 22,
                  ),
                  child: leading!,
                ),
                const SizedBox(width: 13),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    DefaultTextStyle.merge(
                      style: PveAppleText.body(context),
                      child: title,
                    ),
                    if (subtitle != null) ...<Widget>[
                      const SizedBox(height: 3),
                      DefaultTextStyle.merge(
                        style: PveAppleText.secondary(context),
                        child: subtitle!,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...<Widget>[
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxTrailingWidth),
                  child: Align(
                    alignment: Alignment.centerRight,
                    widthFactor: 1,
                    child: DefaultTextStyle.merge(
                      style: PveAppleText.secondary(context),
                      child: trailing!,
                    ),
                  ),
                ),
              ],
              if (onTap != null) ...<Widget>[
                const SizedBox(width: 6),
                Icon(
                  CupertinoIcons.chevron_forward,
                  size: 15,
                  color: PveAppleColors.secondaryLabel(context),
                ),
              ],
            ],
          );
        },
      ),
    );
    if (onTap == null) {
      return row;
    }
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(44, 44),
      pressedOpacity: 0.65,
      onPressed: onTap,
      child: DefaultTextStyle.merge(
        style: TextStyle(color: PveAppleColors.label(context)),
        child: row,
      ),
    );
  }
}

class PveRowSeparator extends StatelessWidget {
  const PveRowSeparator({super.key, this.leadingIndent = 52});

  final double leadingIndent;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 0.5,
      thickness: 0.5,
      indent: leadingIndent,
      color: PveAppleColors.separator(context).withValues(alpha: 0.5),
    );
  }
}

class PveStatusPill extends StatelessWidget {
  const PveStatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.semanticLabel,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel ?? label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: PveAppleText.caption(
                context,
              ).copyWith(color: color, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class PveProgressBar extends StatelessWidget {
  const PveProgressBar({super.key, required this.value, required this.color});

  final double? value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final double? normalizedValue =
        value != null && value!.isFinite && value! >= 0
        ? value!.clamp(0, 1).toDouble()
        : null;
    return Semantics(
      value: normalizedValue == null
          ? 'Not reported'
          : '${(normalizedValue * 100).round()}%',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: SizedBox(
          height: 5,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              ColoredBox(color: color.withValues(alpha: 0.16)),
              if (normalizedValue != null)
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: normalizedValue,
                  child: ColoredBox(color: color),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A desktop-first two-pane composition for a list/table and its inspector.
class PveInspectorLayout extends StatelessWidget {
  const PveInspectorLayout({
    super.key,
    required this.primary,
    required this.inspector,
    this.inspectorWidth = 360,
    this.spacing = 20,
  });

  final Widget primary;
  final Widget inspector;
  final double inspectorWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (!PveAppleLayout.usesExpandedWidth(constraints.maxWidth)) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              primary,
              SizedBox(height: spacing),
              inspector,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: primary),
            SizedBox(width: spacing),
            SizedBox(width: inspectorWidth, child: inspector),
          ],
        );
      },
    );
  }
}

/// A simple, accessible table shell for information-dense desktop screens.
class PveDataTable extends StatelessWidget {
  const PveDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.emptyState,
  });

  final List<String> columns;
  final List<List<Widget>> rows;
  final Widget? emptyState;

  @override
  Widget build(BuildContext context) {
    assert(
      rows.every((List<Widget> row) => row.length == columns.length),
      'Every table row must contain one cell per column.',
    );
    if (rows.isEmpty && emptyState != null) return emptyState!;
    return Semantics(
      label: '${rows.length} row data table',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 640),
          child: Column(
            children: <Widget>[
              _PveDataTableRow(
                header: true,
                children: columns
                    .map(
                      (String label) => Semantics(
                        header: true,
                        child: Text(
                          label,
                          style: PveAppleText.caption(context),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
              for (final List<Widget> row in rows)
                _PveDataTableRow(children: row),
            ],
          ),
        ),
      ),
    );
  }
}

class _PveDataTableRow extends StatelessWidget {
  const _PveDataTableRow({required this.children, this.header = false});

  final List<Widget> children;
  final bool header;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: header ? PveAppleColors.surface(context) : null,
        border: Border(
          bottom: BorderSide(
            color: PveAppleColors.separator(context).withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          for (final Widget child in children)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                child: DefaultTextStyle.merge(
                  style: header
                      ? PveAppleText.caption(context)
                      : PveAppleText.body(context),
                  child: child,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class PveDangerAction extends StatelessWidget {
  const PveDangerAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.explanation,
  });

  final String label;
  final VoidCallback? onPressed;
  final String? explanation;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: explanation == null ? label : '$label. $explanation',
      child: CupertinoButton(
        color: PveAppleColors.destructive(context),
        onPressed: onPressed,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Text(label),
      ),
    );
  }
}

class PveLoadingState extends StatelessWidget {
  const PveLoadingState({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: label,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const ExcludeSemantics(
              child: CupertinoActivityIndicator(radius: 14),
            ),
            const SizedBox(height: 12),
            ExcludeSemantics(
              child: Text(label, style: PveAppleText.secondary(context)),
            ),
          ],
        ),
      ),
    );
  }
}

class PveEmptyState extends StatelessWidget {
  const PveEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final Color color = destructive
        ? PveAppleColors.destructive(context)
        : PveAppleColors.primary(context);
    return Semantics(
      container: true,
      liveRegion: true,
      label: destructive ? 'Attention: $title. $message' : '$title. $message',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(icon, size: 40, color: color),
                const SizedBox(height: 16),
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: PveAppleText.title2(context),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: PveAppleText.secondary(context),
                ),
                if (actionLabel != null && onAction != null) ...<Widget>[
                  const SizedBox(height: 20),
                  CupertinoButton.filled(
                    onPressed: onAction,
                    child: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
