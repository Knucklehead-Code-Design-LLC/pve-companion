import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'store_screenshot_preview.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadStoreScreenshotFonts);

  testWidgets('warms the production preview assets', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(await createStoreScreenshotPreview('overview'));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  });

  for (final MapEntry<String, String> scene in <String, String>{
    'overview': '01-datacenter-overview.png',
    'guests': '02-guest-inventory.png',
    'nodes': '03-node-health.png',
  }.entries) {
    testWidgets('renders the ${scene.key} Mac App Store preview', (
      WidgetTester tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: Image.asset('assets/brand/pve_companion_mark.png'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      await tester.pumpWidget(await createStoreScreenshotPreview(scene.key));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      await expectLater(
        find.byKey(ValueKey<String>('store-screenshot-capture-${scene.key}')),
        matchesGoldenFile('mac_store_screenshots/${scene.value}'),
      );
    });
  }
}

Future<void> _loadStoreScreenshotFonts() async {
  await Future.wait(<Future<void>>[
    _loadFileFont('.SF Pro Text', '/System/Library/Fonts/SFNS.ttf'),
    _loadFileFont('.SF Pro Display', '/System/Library/Fonts/SFNS.ttf'),
    (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
          rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'),
        ))
        .load(),
  ]);
}

Future<void> _loadFileFont(String family, String path) async {
  final Uint8List bytes = await File(path).readAsBytes();
  await (FontLoader(
    family,
  )..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)))).load();
}
