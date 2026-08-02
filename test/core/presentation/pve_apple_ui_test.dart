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
}
