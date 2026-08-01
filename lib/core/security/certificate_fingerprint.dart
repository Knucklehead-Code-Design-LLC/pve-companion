import 'package:crypto/crypto.dart';

String sha256CertificateFingerprint(Iterable<int> certificateDer) {
  return sha256
      .convert(List<int>.from(certificateDer))
      .toString()
      .toUpperCase();
}
