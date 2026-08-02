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
  final LayerLink _menuLayerLink = LayerLink();
  OverlayEntry? _menuEntry;

  @override
  void dispose() {
    _dismissMenu();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: CompositedTransformTarget(
        key: _buttonKey,
        link: _menuLayerLink,
        child: CupertinoButton(
          padding: widget.padding,
          minimumSize: widget.minimumSize,
          onPressed: _showMenu,
          child: widget.child,
        ),
      ),
    );
  }

  void _showMenu() {
    if (_menuEntry != null) {
      return;
    }
    final RenderObject? renderObject = _buttonKey.currentContext
        ?.findRenderObject();
    if (renderObject is! RenderBox) {
      return;
    }
    final OverlayState? overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return;
    }
    final RenderBox button = renderObject;
    final Offset origin = button.localToGlobal(Offset.zero);
    final Rect anchor = origin & button.size;
    final bool alignsToLeadingEdge =
        anchor.center.dx < MediaQuery.sizeOf(context).width / 2;
    final OverlayEntry entry = OverlayEntry(
      builder: (BuildContext overlayContext) => _PveCommandMenuOverlay<T>(
        layerLink: _menuLayerLink,
        alignsToLeadingEdge: alignsToLeadingEdge,
        width: widget.menuWidth,
        items: widget.items,
        onDismiss: _dismissMenu,
        onSelected: _select,
      ),
    );
    _menuEntry = entry;
    overlay.insert(entry);
  }

  void _dismissMenu() {
    final OverlayEntry? entry = _menuEntry;
    _menuEntry = null;
    entry?.remove();
    entry?.dispose();
  }

  void _select(T value) {
    _dismissMenu();
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted) {
        widget.onSelected(value);
      }
    });
  }
}

class _PveCommandMenuOverlay<T> extends StatelessWidget {
  const _PveCommandMenuOverlay({
    required this.layerLink,
    required this.alignsToLeadingEdge,
    required this.width,
    required this.items,
    required this.onDismiss,
    required this.onSelected,
  });

  final LayerLink layerLink;
  final bool alignsToLeadingEdge;
  final double width;
  final List<PveCommandMenuItem<T>> items;
  final VoidCallback onDismiss;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final EdgeInsets safeArea = MediaQuery.paddingOf(context);
        final double resolvedWidth = math.min(
          width,
          math.max(0, constraints.maxWidth - 24),
        );
        final double maxHeight = math.max(
          120,
          constraints.maxHeight - safeArea.top - safeArea.bottom - 18,
        );
        final Alignment targetAnchor = alignsToLeadingEdge
            ? Alignment.bottomLeft
            : Alignment.bottomRight;
        final Alignment followerAnchor = alignsToLeadingEdge
            ? Alignment.topLeft
            : Alignment.topRight;
        return Stack(
          children: <Widget>[
            Positioned.fill(
              child: Semantics(
                label: CupertinoLocalizations.of(
                  context,
                ).modalBarrierDismissLabel,
                button: true,
                onTap: onDismiss,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onDismiss,
                ),
              ),
            ),
            CompositedTransformFollower(
              link: layerLink,
              showWhenUnlinked: false,
              targetAnchor: targetAnchor,
              followerAnchor: followerAnchor,
              offset: const Offset(0, 6),
              child: SizedBox(
                width: resolvedWidth,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: _PveCommandMenuPanel<T>(
                    key: const ValueKey<String>('pve-command-menu-panel'),
                    items: items,
                    onSelected: onSelected,
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

class _PveCommandMenuPanel<T> extends StatelessWidget {
  const _PveCommandMenuPanel({
    super.key,
    required this.items,
    required this.onSelected,
  });

  final List<PveCommandMenuItem<T>> items;
  final ValueChanged<T> onSelected;

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
            child: ListView(
              primary: false,
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 6),
              children: <Widget>[
                for (int index = 0; index < items.length; index++) ...<Widget>[
                  if (items[index].startsNewSection)
                    const PveRowSeparator(leadingIndent: 0),
                  _PveCommandMenuRow<T>(
                    item: items[index],
                    onSelected: onSelected,
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

class _PveCommandMenuRow<T> extends StatelessWidget {
  const _PveCommandMenuRow({required this.item, required this.onSelected});

  final PveCommandMenuItem<T> item;
  final ValueChanged<T> onSelected;

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
      onPressed: () => onSelected(item.value),
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
