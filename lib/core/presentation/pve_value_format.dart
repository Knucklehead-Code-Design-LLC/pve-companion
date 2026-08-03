String formatPveBytes(int? bytes) {
  if (bytes == null || bytes < 0) {
    return '—';
  }
  const units = <String>['B', 'KiB', 'MiB', 'GiB', 'TiB', 'PiB', 'EiB'];
  var value = bytes.toDouble();
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex += 1;
  }
  final decimals = value >= 10 || unitIndex == 0 ? 0 : 1;
  return '${value.toStringAsFixed(decimals)} ${units[unitIndex]}';
}

String formatPvePercent(double? fraction) {
  if (fraction == null || !fraction.isFinite || fraction < 0) {
    return '—';
  }
  return '${(fraction * 100).clamp(0, 100).toStringAsFixed(0)}%';
}

String formatPveUptime(int? seconds) {
  if (seconds == null || seconds < 0) {
    return '—';
  }
  final uptime = Duration(seconds: seconds);
  if (uptime.inDays > 0) {
    return '${uptime.inDays}d ${uptime.inHours.remainder(24)}h';
  }
  if (uptime.inHours > 0) {
    return '${uptime.inHours}h ${uptime.inMinutes.remainder(60)}m';
  }
  return '${uptime.inMinutes}m';
}

String formatPveDateTime(DateTime? value) {
  if (value == null) {
    return '—';
  }
  final twoDigitMonth = value.month.toString().padLeft(2, '0');
  final twoDigitDay = value.day.toString().padLeft(2, '0');
  final twoDigitHour = value.hour.toString().padLeft(2, '0');
  final twoDigitMinute = value.minute.toString().padLeft(2, '0');
  return '${value.year}-$twoDigitMonth-$twoDigitDay $twoDigitHour:$twoDigitMinute';
}
