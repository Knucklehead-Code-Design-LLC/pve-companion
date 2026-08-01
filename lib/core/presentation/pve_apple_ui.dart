import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Divider;

abstract final class PveAppleColors {
  static const Color accent = Color(0xFF087E8B);
  static const Color accentDark = Color(0xFF55D6DF);

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

  static TextStyle secondary(BuildContext context) => body(
    context,
  ).copyWith(color: PveAppleColors.secondaryLabel(context), fontSize: 13);

  static TextStyle caption(BuildContext context) => body(context).copyWith(
    color: PveAppleColors.secondaryLabel(context),
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );
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
    return Row(
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
          Expanded(child: Text(title, style: PveAppleText.title2(context))),
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
    final BorderRadius borderRadius = BorderRadius.circular(14);
    Widget content = DecoratedBox(
      decoration: BoxDecoration(
        color: color ?? PveAppleColors.surface(context),
        borderRadius: borderRadius,
        border: Border.all(
          color: PveAppleColors.separator(context).withValues(alpha: 0.35),
          width: 0.5,
        ),
      ),
      child: padding == null ? child : Padding(padding: padding!, child: child),
    );
    if (onTap != null) {
      content = CupertinoButton(
        padding: EdgeInsets.zero,
        borderRadius: borderRadius,
        pressedOpacity: 0.72,
        onPressed: onTap,
        child: DefaultTextStyle.merge(
          style: TextStyle(color: PveAppleColors.label(context)),
          child: content,
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
      child: Row(
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
            DefaultTextStyle.merge(
              style: PveAppleText.secondary(context),
              child: trailing!,
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
  const PveStatusPill({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: PveAppleText.caption(
          context,
        ).copyWith(color: color, fontWeight: FontWeight.w700),
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
    return Semantics(
      value: value == null ? 'Not reported' : '${(value! * 100).round()}%',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: SizedBox(
          height: 5,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              ColoredBox(color: color.withValues(alpha: 0.16)),
              if (value != null)
                FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: value!.clamp(0, 1),
                  child: ColoredBox(color: color),
                ),
            ],
          ),
        ),
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
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: PveAppleText.title2(context),
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
    );
  }
}
