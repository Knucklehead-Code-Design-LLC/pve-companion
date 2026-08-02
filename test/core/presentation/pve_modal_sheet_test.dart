import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/core/presentation/pve_modal_sheet.dart';

void main() {
  testWidgets('keeps the workspace at its natural size while a sheet is open', (
    WidgetTester tester,
  ) async {
    final _RouteObserver routeObserver = _RouteObserver();

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
                              children: const <Widget>[SizedBox(height: 120)],
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

    final Finder workspace = find.byKey(
      const ValueKey<String>('workspace-surface'),
    );
    final Rect workspaceRect = tester.getRect(workspace);

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

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Sheet'), findsNothing);
    expect(tester.getRect(workspace), workspaceRect);
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
