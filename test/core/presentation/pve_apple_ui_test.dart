import 'package:flutter/cupertino.dart';
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

    final Rect rowRect = tester.getRect(find.byType(PveListRow));
    final Rect labelRect = tester.getRect(find.text('Kernel'));
    final Rect valueRect = tester.getRect(
      find.text('Linux 7.0.14-8-pve #1 SMP PREEMPT_DYNAMIC'),
    );

    expect(labelRect.width, greaterThan(40));
    expect(valueRect.width, lessThan(rowRect.width * 0.65));
    expect(tester.takeException(), isNull);
  });
}
