import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/core/presentation/pve_data_visualization.dart';

void main() {
  testWidgets('sparkline renders reported samples and exposes their purpose', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: CupertinoPageScaffold(
          child: SizedBox(
            width: 280,
            child: PveSparkline(
              values: <double?>[0.2, null, 0.6, 0.4],
              color: CupertinoColors.systemBlue,
              semanticLabel: 'CPU utilization over the past 24 hours.',
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.byType(PveSparkline)).label,
      'CPU utilization over the past 24 hours.',
    );
    expect(tester.takeException(), isNull);
  });
}
