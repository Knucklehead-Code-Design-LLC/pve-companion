import 'dart:async';
import 'dart:ui' show Tristate;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/core/presentation/pve_apple_ui.dart';

void main() {
  testWidgets('PveInsetGroup supplies a readable body text style', (
    WidgetTester tester,
  ) async {
    TextStyle? effectiveStyle;

    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: PveInsetGroup(
            child: Builder(
              builder: (BuildContext context) {
                effectiveStyle = DefaultTextStyle.of(context).style;
                return const Text('Empty state message');
              },
            ),
          ),
        ),
      ),
    );

    expect(effectiveStyle?.fontSize, 15);
    expect(effectiveStyle?.color, isNotNull);
  });

  testWidgets('PveListRow keeps a long information value within its row', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: CupertinoPageScaffold(
          child: Center(
            child: SizedBox(
              width: 320,
              child: PveInsetGroup(
                child: PveListRow(
                  title: Text('Kernel'),
                  trailing: Text(
                    'Linux 7.0.14-8-pve #1 SMP PREEMPT_DYNAMIC',
                    textAlign: TextAlign.end,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final rowRect = tester.getRect(find.byType(PveListRow));
    final labelRect = tester.getRect(find.text('Kernel'));
    final valueRect = tester.getRect(
      find.text('Linux 7.0.14-8-pve #1 SMP PREEMPT_DYNAMIC'),
    );

    expect(labelRect.width, greaterThan(40));
    expect(valueRect.width, lessThan(rowRect.width * 0.65));
    expect(tester.takeException(), isNull);
  });

  testWidgets('icon actions provide a tooltip and an accessible name', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: PveIconAction(
            icon: CupertinoIcons.refresh,
            label: PveActionLabels.refresh,
            onPressed: () {},
          ),
        ),
      ),
    );

    expect(find.byTooltip(PveActionLabels.refresh), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(PveIconAction)).label,
      PveActionLabels.refresh,
    );
  });

  testWidgets('freshness labels expose their exact refresh timestamp', (
    WidgetTester tester,
  ) async {
    final refreshedAt = DateTime.now().subtract(const Duration(minutes: 2));
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: PveFreshnessLabel(refreshedAt: refreshedAt),
        ),
      ),
    );

    final semantics = tester.getSemantics(find.byType(PveFreshnessLabel)).label;
    expect(semantics, startsWith('Data refreshed at '));
    expect(find.byTooltip(semantics), findsOneWidget);
    expect(find.textContaining('Data refreshed'), findsOneWidget);
  });

  testWidgets('pulling down refreshes a mobile primary scroll view', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final refreshCompleter = Completer<void>();
      var refreshCount = 0;

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: PvePrimaryScrollView(
              title: 'Datacenter',
              onRefresh: () {
                refreshCount += 1;
                return refreshCompleter.future;
              },
              slivers: const <Widget>[
                SliverToBoxAdapter(child: SizedBox(height: 900)),
              ],
            ),
          ),
        ),
      );

      final scrollView = tester.widget<CustomScrollView>(
        find.byType(CustomScrollView),
      );
      expect(scrollView.physics, isA<BouncingScrollPhysics>());

      await tester.drag(
        find.byType(CustomScrollView),
        const Offset(0, 180),
        touchSlopY: 0,
      );
      await tester.pump();

      expect(refreshCount, 1);
      refreshCompleter.complete();
      await tester.pumpAndSettle();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('selected segmented options announce selection', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: CupertinoPageScaffold(
          child: PveSlidingSegmentedControl<int>(
            groupValue: 1,
            semanticLabels: <int, String>{
              1: 'All workloads',
              2: 'Running workloads',
            },
            children: <int, Widget>{1: Text('All'), 2: Text('Running')},
            onValueChanged: _ignoreSegment,
          ),
        ),
      ),
    );

    final all = tester.getSemantics(find.text('All'));
    expect(all.label, 'All workloads');
    expect(all.flagsCollection.isSelected, Tristate.isTrue);
  });

  testWidgets('segmented options retain their visible label by default', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: CupertinoPageScaffold(
          child: PveSlidingSegmentedControl<int>(
            groupValue: 1,
            children: <int, Widget>{1: Text('All'), 2: Text('Attention')},
            onValueChanged: _ignoreSegment,
          ),
        ),
      ),
    );

    expect(tester.getSemantics(find.text('All')).label, 'All');
    expect(tester.getSemantics(find.text('Attention')).label, 'Attention');
  });

  testWidgets('section headers stack their action with large compact text', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(350, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const CupertinoApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: CupertinoPageScaffold(
            child: PveSectionHeader(
              title: 'Recent reported activity',
              actionLabel: 'View tasks',
              actionSemanticsLabel: 'View all tasks',
              onAction: _ignoreAction,
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Recent reported activity'), findsOneWidget);
    expect(find.text('View tasks'), findsOneWidget);
  });

  testWidgets('section headers keep routine actions inline at compact width', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: CupertinoPageScaffold(
          child: SizedBox(
            width: 390,
            child: PveSectionHeader(
              title: 'Recent activity',
              actionLabel: 'View Tasks',
              actionSemanticsLabel: 'View all tasks',
              onAction: _ignoreAction,
            ),
          ),
        ),
      ),
    );

    final title = tester.getRect(find.text('Recent activity'));
    final action = tester.getRect(find.text('View Tasks'));
    expect(action.center.dy, lessThan(title.bottom + 15));
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact metric strips use one shared reporting note', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const CupertinoApp(
        home: CupertinoPageScaffold(
          child: PveMetricStrip(
            showsItemScopes: false,
            footer: 'Current guest inventory.',
            items: <PveMetricStripItem>[
              PveMetricStripItem(
                label: 'Workloads',
                value: '4',
                icon: CupertinoIcons.cube_box,
                scope: 'Non-template guests reported',
              ),
              PveMetricStripItem(
                label: 'Running',
                value: '3',
                icon: CupertinoIcons.play_fill,
                scope: 'Current reported guest state',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Non-template guests reported'), findsNothing);
    expect(find.text('Current guest inventory.'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('Workloads')).label,
      contains('Non-template guests reported'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide inventory toolbars place search beside the heading', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1100, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: SizedBox(
            width: 1000,
            child: PveInventoryToolbar(
              title: const PveSectionTitle(title: 'Guest inventory'),
              search: const CupertinoSearchTextField(
                key: ValueKey<String>('toolbar-search'),
              ),
              primaryControls: const Text('Status'),
              trailingControls: <Widget>[
                PveInventoryMenuButton(label: 'Sort: Status', onPressed: () {}),
              ],
            ),
          ),
        ),
      ),
    );

    final title = tester.getRect(find.text('Guest inventory'));
    final search = tester.getRect(
      find.byKey(const ValueKey<String>('toolbar-search')),
    );
    expect(search.left, greaterThan(title.right));
    expect((search.center.dy - title.center.dy).abs(), lessThan(16));
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop inspector layouts show primary content beside details', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: CupertinoPageScaffold(
          child: SizedBox(
            width: 1000,
            child: PveInspectorLayout(
              primary: Text('Primary'),
              inspector: Text('Inspector'),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getTopLeft(find.text('Primary')).dy,
      equals(tester.getTopLeft(find.text('Inspector')).dy),
    );
  });
}

void _ignoreSegment(int? _) {}

void _ignoreAction() {}
