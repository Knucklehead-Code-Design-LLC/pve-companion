import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/app/pve_companion_metadata.dart';

void main() {
  test('app metadata stays synchronized with pubspec version', () {
    final String pubspec = File('pubspec.yaml').readAsStringSync();

    expect(
      pubspec,
      contains(
        'version: ${PveCompanionMetadata.version}+'
        '${PveCompanionMetadata.buildNumber}',
      ),
    );
  });
}
