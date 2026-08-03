import 'proxmox_api_exception.dart';
import 'proxmox_session.dart';

enum ProxmoxTaskState { running, successful, failed, unknown }

class ProxmoxTaskReference {
  const ProxmoxTaskReference({
    required this.upid,
    required this.node,
    required this.operationLabel,
    required this.submittedAt,
  });

  factory ProxmoxTaskReference.fromResponse({
    required Object? response,
    required String node,
    required String operationLabel,
    DateTime? submittedAt,
  }) {
    if (response is! String || response.trim().isEmpty) {
      throw const ProxmoxMalformedResponseException(
        'The server did not return an operation task ID.',
      );
    }
    final upid = response.trim();
    if (!RegExp(r'^[A-Za-z0-9._:@!+=-]+$').hasMatch(upid)) {
      throw const ProxmoxMalformedResponseException(
        'The server returned an unsafe operation task ID.',
      );
    }
    return ProxmoxTaskReference(
      upid: upid,
      node: node,
      operationLabel: operationLabel,
      submittedAt: submittedAt ?? DateTime.now(),
    );
  }

  final String upid;
  final String node;
  final String operationLabel;
  final DateTime submittedAt;
}

class ProxmoxTaskStatus {
  const ProxmoxTaskStatus({
    required this.reference,
    required this.state,
    this.exitStatus,
    this.endedAt,
  });

  final ProxmoxTaskReference reference;
  final ProxmoxTaskState state;
  final String? exitStatus;
  final DateTime? endedAt;

  bool get isComplete => state != ProxmoxTaskState.running;

  bool get isSuccessful => state == ProxmoxTaskState.successful;

  String get displayStatus => switch (state) {
    ProxmoxTaskState.running => 'Running',
    ProxmoxTaskState.successful => 'Completed',
    ProxmoxTaskState.failed => exitStatus ?? 'Failed',
    ProxmoxTaskState.unknown => exitStatus ?? 'Status unavailable',
  };
}

class ProxmoxTaskLogLine {
  const ProxmoxTaskLogLine({required this.line, required this.text});

  final int line;
  final String text;
}

/// The result of a bounded task status poll. A task may be left in an
/// [unknown] state when the server cannot be reached again or when it is still
/// running after the bounded observation window. Callers can then leave the
/// operation visible without blocking every other control indefinitely.
class ProxmoxTaskPollResult {
  const ProxmoxTaskPollResult({
    required this.status,
    required this.reachedTerminalState,
    this.errorMessage,
  });

  final ProxmoxTaskStatus status;
  final bool reachedTerminalState;
  final String? errorMessage;
}

/// Maps Proxmox's common node task endpoints into a small cross-feature
/// contract. Guest, backup, service, and maintenance actions all use these
/// endpoints once a server has accepted a command.
class ProxmoxTaskClient {
  const ProxmoxTaskClient();

  Future<ProxmoxTaskStatus> loadStatus(
    ProxmoxSession session,
    ProxmoxTaskReference reference,
  ) async {
    final response = await session.getData(
      'nodes/${reference.node}/tasks/${reference.upid}/status',
    );
    if (response is! Map<Object?, Object?>) {
      throw const ProxmoxMalformedResponseException(
        'The task status response was not an object.',
      );
    }
    final status = _string(response['status']);
    final exitStatus = _string(response['exitstatus']);
    final endedAt = _date(response['endtime']);
    return ProxmoxTaskStatus(
      reference: reference,
      state: _stateFor(status: status, exitStatus: exitStatus),
      exitStatus: exitStatus,
      endedAt: endedAt,
    );
  }

  Future<List<ProxmoxTaskLogLine>> loadLog(
    ProxmoxSession session,
    ProxmoxTaskReference reference, {
    int start = 0,
    int limit = 200,
  }) async {
    final response = await session.getData(
      'nodes/${reference.node}/tasks/${reference.upid}/log',
      query: <String, String>{'start': '$start', 'limit': '$limit'},
    );
    if (response is! List<Object?>) {
      throw const ProxmoxMalformedResponseException(
        'The task log response was not a list.',
      );
    }
    return response
        .whereType<Map<Object?, Object?>>()
        .map((Map<Object?, Object?> line) {
          final lineNumber = line['n'];
          final text = _string(line['t']);
          if (lineNumber is! num || text == null) {
            throw const ProxmoxMalformedResponseException(
              'The task log response contained an invalid line.',
            );
          }
          return ProxmoxTaskLogLine(line: lineNumber.toInt(), text: text);
        })
        .toList(growable: false);
  }

  ProxmoxTaskState _stateFor({
    required String? status,
    required String? exitStatus,
  }) {
    if (status?.toLowerCase() == 'running') {
      return ProxmoxTaskState.running;
    }
    if (exitStatus?.toUpperCase() == 'OK') {
      return ProxmoxTaskState.successful;
    }
    if (exitStatus != null && exitStatus.isNotEmpty) {
      return ProxmoxTaskState.failed;
    }
    return ProxmoxTaskState.unknown;
  }

  String? _string(Object? value) {
    return value is String && value.trim().isNotEmpty ? value : null;
  }

  DateTime? _date(Object? value) {
    if (value is! num) {
      return null;
    }
    return DateTime.fromMillisecondsSinceEpoch(
      value.toInt() * 1000,
      isUtc: true,
    ).toLocal();
  }
}

/// Poll a Proxmox task for a bounded period.
///
/// Proxmox actions return quickly with a UPID, so all state-changing features
/// use this shared polling behavior instead of treating request acceptance as
/// completion. [isCancelled] lets a disposed controller stop safely without
/// retaining a page or session.
Future<ProxmoxTaskPollResult?> pollProxmoxTask(
  ProxmoxTaskClient client,
  ProxmoxSession session,
  ProxmoxTaskReference reference, {
  required bool Function() isCancelled,
  void Function(ProxmoxTaskStatus status)? onStatus,
  int maxAttempts = 30,
  Duration interval = const Duration(seconds: 2),
}) async {
  for (var attempt = 0; attempt < maxAttempts; attempt += 1) {
    if (attempt > 0) {
      await Future<void>.delayed(interval);
    }
    if (isCancelled()) {
      return null;
    }
    try {
      final status = await client.loadStatus(session, reference);
      if (isCancelled()) {
        return null;
      }
      onStatus?.call(status);
      if (status.isComplete) {
        return ProxmoxTaskPollResult(
          status: status,
          reachedTerminalState: true,
        );
      }
    } on ProxmoxApiException catch (error) {
      return ProxmoxTaskPollResult(
        status: ProxmoxTaskStatus(
          reference: reference,
          state: ProxmoxTaskState.unknown,
          exitStatus: 'Status check failed; refresh to check Proxmox.',
        ),
        reachedTerminalState: false,
        errorMessage: error.message,
      );
    } catch (_) {
      return ProxmoxTaskPollResult(
        status: ProxmoxTaskStatus(
          reference: reference,
          state: ProxmoxTaskState.unknown,
          exitStatus: 'Status check failed; refresh to check Proxmox.',
        ),
        reachedTerminalState: false,
        errorMessage: 'The operation status could not be checked.',
      );
    }
  }
  return ProxmoxTaskPollResult(
    status: ProxmoxTaskStatus(
      reference: reference,
      state: ProxmoxTaskState.unknown,
      exitStatus: 'Still running; refresh to check the latest status.',
    ),
    reachedTerminalState: false,
  );
}
