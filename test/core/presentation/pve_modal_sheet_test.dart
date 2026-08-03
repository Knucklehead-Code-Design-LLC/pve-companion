import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/core/presentation/pve_modal_sheet.dart';

void main() {
  testWidgets('keeps the workspace at its natural size while a sheet is open', (
    WidgetTester tester,
  ) async {
    final routeObserver = _RouteObserver();

    await tester.pumpWidget(
      CupertinoApp(
        navigatorObservers: <NavigatorObserver>[routeObserver],
        home: CupertinoPageScaffold(
          child: Builder(
            builder: (BuildContext context) => Stack(
              fit: StackFit.expand,
              children: <Widget>[
                const SizedBox(key: ValueKey<String>('workspace-surface')),
                Center(
                  child: CupertinoButton(
                    onPressed: () => showPveModalSheet<void>(
                      context: context,
                      scrollableBuilder:
                          (
                            BuildContext context,
                            ScrollController scrollController,
                          ) => CupertinoPageScaffold(
                            navigationBar: CupertinoNavigationBar(
                              middle: const Text('Sheet'),
                              trailing: CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Done'),
                              ),
                            ),
                            child: ListView(
                              controller: scrollController,
                              padding: EdgeInsets.zero,
                              children: const <Widget>[
                                SizedBox(
                                  key: ValueKey<String>('sheet-first-item'),
                                  height: 120,
                                ),
                              ],
                            ),
                          ),
                    ),
                    child: const Text('Show sheet'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final workspace = find.byKey(const ValueKey<String>('workspace-surface'));
    final workspaceRect = tester.getRect(workspace);

    await tester.tap(find.text('Show sheet'));
    await tester.pumpAndSettle();

    expect(
      routeObserver.pushedRoutes.whereType<CupertinoModalPopupRoute<void>>(),
      hasLength(1),
    );
    expect(
      routeObserver.pushedRoutes.whereType<CupertinoSheetRoute<void>>(),
      isEmpty,
    );
    expect(tester.getRect(workspace), workspaceRect);
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey<String>('sheet-first-item')))
          .dy,
      greaterThanOrEqualTo(
        tester.getBottomLeft(find.byType(CupertinoNavigationBar)).dy,
      ),
    );

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Sheet'), findsNothing);
    expect(tester.getRect(workspace), workspaceRect);
  });

  testWidgets('uses a roomy contained pane on desktop widths', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: Builder(
            builder: (BuildContext context) => Center(
              child: CupertinoButton(
                onPressed: () => showPveModalSheet<void>(
                  context: context,
                  scrollableBuilder:
                      (
                        BuildContext context,
                        ScrollController scrollController,
                      ) => ListView(
                        controller: scrollController,
                        children: const <Widget>[
                          SizedBox(
                            key: ValueKey<String>('desktop-sheet-content'),
                            height: 120,
                          ),
                        ],
                      ),
                ),
                child: const Text('Show sheet'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show sheet'));
    await tester.pumpAndSettle();

    final contentRect = tester.getRect(
      find.byKey(const ValueKey<String>('desktop-sheet-content')),
    );
    expect(contentRect.width, lessThanOrEqualTo(1110));
    expect(contentRect.center.dx, closeTo(720, 1));
    expect(contentRect.bottom, lessThan(1000));
  });

  testWidgets('Escape dismisses only the open modal sheet', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: Builder(
            builder: (BuildContext context) => CupertinoButton(
              onPressed: () => showPveModalSheet<void>(
                context: context,
                scrollableBuilder:
                    (BuildContext context, ScrollController scrollController) =>
                        ListView(
                          controller: scrollController,
                          children: const <Widget>[Text('Dismissible sheet')],
                        ),
              ),
              child: const Text('Show sheet'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show sheet'));
    await tester.pumpAndSettle();
    expect(find.text('Dismissible sheet'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('Dismissible sheet'), findsNothing);
    expect(find.text('Show sheet'), findsOneWidget);
  });
}

class _RouteObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushedRoutes = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route);
    super.didPush(route, previousRoute);
  }
}
