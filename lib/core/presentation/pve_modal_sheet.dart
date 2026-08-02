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
    final BorderRadius borderRadius = const BorderRadius.vertical(
      top: Radius.circular(18),
    );
    return Align(
      alignment: Alignment.bottomCenter,
      child: FractionallySizedBox(
        heightFactor: 0.92,
        widthFactor: 1,
        child: ClipRRect(
          borderRadius: borderRadius,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: CupertinoColors.systemGroupedBackground.resolveFrom(
                context,
              ),
            ),
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: widget.scrollableBuilder(context, _scrollController),
            ),
          ),
        ),
      ),
    );
  }
}
