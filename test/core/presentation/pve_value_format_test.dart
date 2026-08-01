import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/core/presentation/pve_value_format.dart';

void main() {
  test('formats valid PVE values without inventing invalid telemetry', () {
    expect(formatPveBytes(1536), '1.5 KiB');
    expect(formatPveBytes(1024 * 1024 * 1024 * 1024 * 1024), '1.0 PiB');
    expect(formatPveBytes(-1), '—');
    expect(formatPvePercent(0.755), '76%');
    expect(formatPvePercent(double.nan), '—');
    expect(formatPvePercent(-0.1), '—');
    expect(formatPveUptime(90061), '1d 1h');
  });

  test('uses an unavailable marker for a missing timestamp', () {
    expect(formatPveDateTime(null), '—');
    expect(formatPveDateTime(DateTime(2026, 8, 1, 9, 5)), '2026-08-01 09:05');
  });
}
