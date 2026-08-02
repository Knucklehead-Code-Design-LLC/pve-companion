enum PveTaskLogState {
  available,
  empty,
  permissionLimited,
  unavailable,
  failed,
}

class PveTaskLogLine {
  const PveTaskLogLine({required this.sequence, required this.text});

  final int? sequence;
  final String text;
}

class PveTaskLogResult {
  const PveTaskLogResult._(
    this.state, {
    this.lines = const <PveTaskLogLine>[],
    this.message,
  });

  const PveTaskLogResult.available(List<PveTaskLogLine> lines)
    : this._(PveTaskLogState.available, lines: lines);

  const PveTaskLogResult.empty() : this._(PveTaskLogState.empty);

  const PveTaskLogResult.permissionLimited(String message)
    : this._(PveTaskLogState.permissionLimited, message: message);

  const PveTaskLogResult.unavailable(String message)
    : this._(PveTaskLogState.unavailable, message: message);

  const PveTaskLogResult.failed(String message)
    : this._(PveTaskLogState.failed, message: message);

  final PveTaskLogState state;
  final List<PveTaskLogLine> lines;
  final String? message;
}
