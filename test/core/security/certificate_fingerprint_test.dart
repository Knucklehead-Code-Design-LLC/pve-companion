import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/core/security/certificate_fingerprint.dart';

void main() {
  test('derives an uppercase SHA-256 fingerprint for certificate bytes', () {
    expect(
      sha256CertificateFingerprint(utf8.encode('abc')),
      'BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD',
    );
  });
}
