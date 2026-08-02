import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';

import 'pve_apple_ui.dart';

class PveCommandMenuItem<T> {
  const PveCommandMenuItem({
    required this.value,
    required this.label,
    this.icon,
    this.selected = false,
    this.destructive = false,
    this.startsNewSection = false,
  });

  final T value;
  final String label;
  final IconData? icon;
  final bool selected;
  final bool destructive;
  final bool startsNewSection;
}

class PveCommandMenuButton<T> extends StatefulWidget {
  const PveCommandMenuButton({
    super.key,
    required this.semanticLabel,
    required this.items,
    required this.onSelected,
    required this.child,
    this.menuWidth = 260,
    this.padding = const EdgeInsets.all(8),
    this.minimumSize = const Size(44, 44),
  });

  final String semanticLabel;
  final List<PveCommandMenuItem<T>> items;
  final ValueChanged<T> onSelected;
  final Widget child;
  final double menuWidth;
  final EdgeInsetsGeometry padding;
  final Size minimumSize;

  @override
  State<PveCommandMenuButton<T>> createState() =>
      _PveCommandMenuButtonState<T>();
}

class _PveCommandMenuButtonState<T> extends State<PveCommandMenuButton<T>> {
  final GlobalKey _buttonKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: CupertinoButton(
        key: _buttonKey,
        padding: widget.padding,
        minimumSize: widget.minimumSize,
        onPressed: _showMenu,
        child: widget.child,
      ),
    );
  }

  Future<void> _showMenu() async {
    final RenderBox? button =
        _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (button == null) {
      return;
    }
    final Offset origin = button.localToGlobal(Offset.zero);
    final Rect anchor = origin & button.size;
    final Alignment transitionAlignment =
        anchor.center.dx < MediaQuery.sizeOf(context).width / 2
        ? Alignment.topLeft
        : Alignment.topRight;
    final T? selected = await showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: CupertinoLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: CupertinoColors.transparent,
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder:
          (
            BuildContext dialogContext,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
          ) {
            return _PveCommandMenuRoute<T>(
              anchor: anchor,
              width: widget.menuWidth,
              items: widget.items,
            );
          },
      transitionBuilder:
          (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondaryAnimation,
            Widget child,
          ) {
            final Animation<double> curved = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curved,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
                alignment: transitionAlignment,
                child: child,
              ),
            );
          },
    );
    if (selected != null && mounted) {
      widget.onSelected(selected);
    }
  }
}

class _PveCommandMenuRoute<T> extends StatelessWidget {
  const _PveCommandMenuRoute({
    required this.anchor,
    required this.width,
    required this.items,
  });

  final Rect anchor;
  final double width;
  final List<PveCommandMenuItem<T>> items;

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.sizeOf(context);
    final EdgeInsets safeArea = MediaQuery.paddingOf(context);
    final double resolvedWidth = math.min(width, screen.width - 24);
    final double left = (anchor.right - resolvedWidth).clamp(
      12,
      screen.width - resolvedWidth - 12,
    );
    final double top = math.max(anchor.bottom + 6, safeArea.top + 6);
    final double maxHeight = math.max(
      120,
      screen.height - top - safeArea.bottom - 12,
    );
    return Stack(
      children: <Widget>[
        Positioned(
          left: left,
          top: top,
          width: resolvedWidth,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: _PveCommandMenuPanel<T>(items: items),
          ),
        ),
      ],
    );
  }
}

class _PveCommandMenuPanel<T> extends StatelessWidget {
  const _PveCommandMenuPanel({required this.items});

  final List<PveCommandMenuItem<T>> items;

  @override
  Widget build(BuildContext context) {
    final BorderRadius borderRadius = BorderRadius.circular(14);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: CupertinoColors.black.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: PveAppleColors.surface(context).withValues(alpha: 0.92),
              borderRadius: borderRadius,
              border: Border.all(
                color: PveAppleColors.separator(context).withValues(alpha: 0.4),
                width: 0.5,
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (
                    int index = 0;
                    index < items.length;
                    index++
                  ) ...<Widget>[
                    if (items[index].startsNewSection)
                      const PveRowSeparator(leadingIndent: 0),
                    _PveCommandMenuRow<T>(item: items[index]),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PveCommandMenuRow<T> extends StatelessWidget {
  const _PveCommandMenuRow({required this.item});

  final PveCommandMenuItem<T> item;

  @override
  Widget build(BuildContext context) {
    final Color foreground = item.destructive
        ? PveAppleColors.destructive(context)
        : PveAppleColors.label(context);
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      minimumSize: const Size(44, 44),
      borderRadius: BorderRadius.zero,
      pressedOpacity: 0.58,
      onPressed: () => Navigator.of(context).pop(item.value),
      child: Row(
        children: <Widget>[
          if (item.icon != null) ...<Widget>[
            Icon(item.icon, size: 19, color: foreground),
            const SizedBox(width: 11),
          ],
          Expanded(
            child: Text(
              item.label,
              style: PveAppleText.body(
                context,
              ).copyWith(color: foreground, fontSize: 16),
            ),
          ),
          if (item.selected)
            Icon(
              CupertinoIcons.check_mark,
              size: 17,
              color: PveAppleColors.primary(context),
            ),
        ],
      ),
    );
  }
}
