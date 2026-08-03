import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/core/api/proxmox_api_exception.dart';
import 'package:pve_companion/core/api/proxmox_session.dart';
import 'package:pve_companion/core/api/proxmox_task.dart';

void main() {
  group('ProxmoxTaskReference', () {
    test('rejects an accepted action without a usable task identifier', () {
      expect(
        () => ProxmoxTaskReference.fromResponse(
          response: const <String, Object?>{'accepted': true},
          node: 'pve-01',
          operationLabel: 'Restart node',
        ),
        throwsA(isA<ProxmoxMalformedResponseException>()),
      );
    });

    test('rejects a task identifier that could change the request path', () {
      expect(
        () => ProxmoxTaskReference.fromResponse(
          response: 'UPID:pve-01/../other',
          node: 'pve-01',
          operationLabel: 'Restart node',
        ),
        throwsA(isA<ProxmoxMalformedResponseException>()),
      );
    });
  });

  group('ProxmoxTaskClient', () {
    final ProxmoxTaskReference reference = ProxmoxTaskReference(
      upid: 'UPID:pve-01:001',
      node: 'pve-01',
      operationLabel: 'Create snapshot',
      submittedAt: DateTime(2026),
    );

    test(
      'maps an OK terminal task and uses the task status endpoint',
      () async {
        final _RecordingTaskSession session = _RecordingTaskSession(
          response: <String, Object?>{
            'status': 'stopped',
            'exitstatus': 'OK',
            'endtime': 1767225600,
          },
        );

        final ProxmoxTaskStatus status = await const ProxmoxTaskClient()
            .loadStatus(session, reference);

        expect(status.state, ProxmoxTaskState.successful);
        expect(status.isComplete, isTrue);
        expect(status.endedAt, isNotNull);
        expect(session.resources, <String>[
          'nodes/pve-01/tasks/UPID:pve-01:001/status',
        ]);
      },
    );

    test('exposes a failed Proxmox exit status', () async {
      final _RecordingTaskSession session = _RecordingTaskSession(
        response: <String, Object?>{
          'status': 'stopped',
          'exitstatus': 'TASK ERROR: backup failed',
        },
      );

      final ProxmoxTaskStatus status = await const ProxmoxTaskClient()
          .loadStatus(session, reference);

      expect(status.state, ProxmoxTaskState.failed);
      expect(status.displayStatus, 'TASK ERROR: backup failed');
    });

    test(
      'returns a completed poll result without delaying a terminal task',
      () async {
        final _RecordingTaskSession session = _RecordingTaskSession(
          response: <String, Object?>{'status': 'stopped', 'exitstatus': 'OK'},
        );

        final List<ProxmoxTaskState> observedStates = <ProxmoxTaskState>[];
        final ProxmoxTaskPollResult? result = await pollProxmoxTask(
          const ProxmoxTaskClient(),
          session,
          reference,
          isCancelled: () => false,
          interval: Duration.zero,
          onStatus: (ProxmoxTaskStatus status) =>
              observedStates.add(status.state),
        );

        expect(result, isNotNull);
        expect(result!.reachedTerminalState, isTrue);
        expect(result.status.state, ProxmoxTaskState.successful);
        expect(observedStates, <ProxmoxTaskState>[ProxmoxTaskState.successful]);
        expect(session.resources, hasLength(1));
      },
    );

    test(
      'does not request task status when polling is already cancelled',
      () async {
        final _RecordingTaskSession session = _RecordingTaskSession(
          response: <String, Object?>{'status': 'running'},
        );

        final ProxmoxTaskPollResult? result = await pollProxmoxTask(
          const ProxmoxTaskClient(),
          session,
          reference,
          isCancelled: () => true,
          interval: Duration.zero,
        );

        expect(result, isNull);
        expect(session.resources, isEmpty);
      },
    );

    test('returns an unknown status when a status request fails', () async {
      const ProxmoxNetworkException error = ProxmoxNetworkException(
        'The server cannot be reached.',
      );
      final _ThrowingTaskSession session = _ThrowingTaskSession(error);

      final ProxmoxTaskPollResult? result = await pollProxmoxTask(
        const ProxmoxTaskClient(),
        session,
        reference,
        isCancelled: () => false,
        interval: Duration.zero,
      );

      expect(result, isNotNull);
      expect(result!.reachedTerminalState, isFalse);
      expect(result.status.state, ProxmoxTaskState.unknown);
      expect(result.errorMessage, error.message);
      expect(session.resources, hasLength(1));
    });

    test(
      'returns safe guidance when a status request fails unexpectedly',
      () async {
        final _UnexpectedFailureTaskSession session =
            _UnexpectedFailureTaskSession();

        final ProxmoxTaskPollResult? result = await pollProxmoxTask(
          const ProxmoxTaskClient(),
          session,
          reference,
          isCancelled: () => false,
          interval: Duration.zero,
        );

        expect(result, isNotNull);
        expect(result!.reachedTerminalState, isFalse);
        expect(result.status.state, ProxmoxTaskState.unknown);
        expect(
          result.errorMessage,
          'The operation status could not be checked.',
        );
        expect(session.resources, hasLength(1));
      },
    );

    test(
      'bounds running task polling by the requested attempt count',
      () async {
        final _RecordingTaskSession session = _RecordingTaskSession(
          response: <String, Object?>{'status': 'running'},
        );
        final List<ProxmoxTaskState> observedStates = <ProxmoxTaskState>[];

        final ProxmoxTaskPollResult? result = await pollProxmoxTask(
          const ProxmoxTaskClient(),
          session,
          reference,
          isCancelled: () => false,
          interval: Duration.zero,
          maxAttempts: 3,
          onStatus: (ProxmoxTaskStatus status) =>
              observedStates.add(status.state),
        );

        expect(result, isNotNull);
        expect(result!.reachedTerminalState, isFalse);
        expect(result.status.state, ProxmoxTaskState.unknown);
        expect(session.resources, hasLength(3));
        expect(observedStates, <ProxmoxTaskState>[
          ProxmoxTaskState.running,
          ProxmoxTaskState.running,
          ProxmoxTaskState.running,
        ]);
      },
    );
  });
}

class _RecordingTaskSession implements ProxmoxSession {
  _RecordingTaskSession({required this.response});

  final Object? response;
  final List<String> resources = <String>[];

  @override
  void close() {}

  @override
  Future<Object?> getData(
    String resource, {
    Map<String, String> query = const <String, String>{},
  }) async {
    resources.add(resource);
    return response;
  }

  @override
  Future<Object?> postForm(
    String resource, {
    required Map<String, String> fields,
  }) async => null;
}

class _ThrowingTaskSession implements ProxmoxSession {
  _ThrowingTaskSession(this.error);

  final ProxmoxApiException error;
  final List<String> resources = <String>[];

  @override
  void close() {}

  @override
  Future<Object?> getData(
    String resource, {
    Map<String, String> query = const <String, String>{},
  }) async {
    resources.add(resource);
    throw error;
  }

  @override
  Future<Object?> postForm(
    String resource, {
    required Map<String, String> fields,
  }) async => null;
}

class _UnexpectedFailureTaskSession implements ProxmoxSession {
  final List<String> resources = <String>[];

  @override
  void close() {}

  @override
  Future<Object?> getData(
    String resource, {
    Map<String, String> query = const <String, String>{},
  }) async {
    resources.add(resource);
    throw StateError('Unexpected decoding failure');
  }

  @override
  Future<Object?> postForm(
    String resource, {
    required Map<String, String> fields,
  }) async => null;
}
