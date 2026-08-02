import 'package:flutter/cupertino.dart';

typedef PveModalSheetBuilder =
    Widget Function(BuildContext context, ScrollController scrollController);

/// Presents a full-height modal surface without transforming the workspace.
///
/// Flutter's [showCupertinoSheet] stacks and scales the route beneath it. That
/// presentation is useful for a sheet stack, but app sheets use a standard
/// Cupertino modal popup so the workspace always remains at its natural size.
Future<T?> showPveModalSheet<T>({
  required BuildContext context,
  required PveModalSheetBuilder scrollableBuilder,
}) {
  return showCupertinoModalPopup<T>(
    context: context,
    semanticsDismissible: true,
    builder: (BuildContext popupContext) =>
        _PveModalSheet(scrollableBuilder: scrollableBuilder),
  );
}

class _PveModalSheet extends StatefulWidget {
  const _PveModalSheet({required this.scrollableBuilder});

  final PveModalSheetBuilder scrollableBuilder;

  @override
  State<_PveModalSheet> createState() => _PveModalSheetState();
}

class _PveModalSheetState extends State<_PveModalSheet> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool usesDesktopPresentation =
        MediaQuery.sizeOf(context).width >= 760;
    final Color backgroundColor = CupertinoColors.systemGroupedBackground
        .resolveFrom(context);
    final BorderRadius borderRadius = usesDesktopPresentation
        ? BorderRadius.circular(20)
        : const BorderRadius.vertical(top: Radius.circular(24));
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(bottom: usesDesktopPresentation ? 16 : 0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: FractionallySizedBox(
            heightFactor: usesDesktopPresentation ? 0.9 : 0.94,
            widthFactor: usesDesktopPresentation ? 0.94 : 1,
            child: ClipRRect(
              borderRadius: borderRadius,
              child: DecoratedBox(
                decoration: BoxDecoration(color: backgroundColor),
                child: CupertinoTheme(
                  data: CupertinoTheme.of(
                    context,
                  ).copyWith(barBackgroundColor: backgroundColor),
                  child: MediaQuery.removePadding(
                    context: context,
                    removeTop: true,
                    child: widget.scrollableBuilder(context, _scrollController),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
