import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/api/proxmox_api_exception.dart';
import '../../../core/api/proxmox_session.dart';
import '../../../core/api/proxmox_task.dart';
import '../data/proxmox_guest_repository.dart';
import '../domain/pve_guest.dart';

enum GuestDetailLoadState { loading, ready, failed }

class GuestDetailController extends ChangeNotifier {
  GuestDetailController({
    required PveGuestRepository repository,
    required ProxmoxSession session,
    required PveGuest guest,
    ProxmoxTaskClient? taskClient,
    Future<void> Function()? onTaskTerminal,
  }) : _repository = repository,
       _session = session,
       _guest = guest,
       _taskClient = taskClient ?? const ProxmoxTaskClient(),
       _onTaskTerminal = onTaskTerminal;

  final PveGuestRepository _repository;
  final ProxmoxSession _session;
  final PveGuest _guest;
  final ProxmoxTaskClient _taskClient;
  final Future<void> Function()? _onTaskTerminal;

  GuestDetailLoadState _state = GuestDetailLoadState.loading;
  PveGuestDetails? _details;
  String? _errorMessage;
  GuestPowerAction? _runningAction;
  bool _operationInFlight = false;
  ProxmoxTaskStatus? _activeTask;
  int _requestEpoch = 0;
  int _taskEpoch = 0;
  bool _isDisposed = false;

  PveGuest get guest => _guest;

  GuestDetailLoadState get state => _state;

  PveGuestDetails? get details => _details;

  String? get errorMessage => _errorMessage;

  GuestPowerAction? get runningAction => _runningAction;

  bool get operationInFlight => _operationInFlight;

  ProxmoxTaskStatus? get activeTask => _activeTask;

  bool get hasRunningTask =>
      _activeTask?.state == ProxmoxTaskState.running || _operationInFlight;

  Future<void> load() async {
    final int requestEpoch = ++_requestEpoch;
    _state = GuestDetailLoadState.loading;
    _errorMessage = null;
    _notify();

    try {
      final PveGuestDetails details = await _repository.loadDetails(
        _session,
        _guest,
      );
      if (_isStale(requestEpoch)) {
        return;
      }
      _details = details;
      _state = GuestDetailLoadState.ready;
      _notify();
    } on ProxmoxApiException catch (error) {
      _setFailure(requestEpoch, error.message);
    } catch (_) {
      _setFailure(requestEpoch, 'Guest details could not be loaded.');
    }
  }

  Future<bool> runPowerAction(GuestPowerAction action) {
    return _submitTask(
      operationLabel: action.label,
      runningAction: action,
      submit: () => _repository.runPowerAction(_session, _guest, action),
    );
  }

  Future<bool> createSnapshot({required PveGuestSnapshotRequest request}) {
    if (!request.hasValidName) {
      _errorMessage = request.validationMessage;
      _notify();
      return Future<bool>.value(false);
    }
    return _submitTask(
      operationLabel: 'Create snapshot',
      submit: () => _repository.createSnapshot(
        _session,
        _guest,
        name: request.normalizedName,
        description: request.normalizedDescription,
        includeMemoryState: request.includeMemoryState,
      ),
    );
  }

  Future<bool> rollbackSnapshot(PveGuestSnapshot snapshot) {
    return _submitTask(
      operationLabel: 'Rollback snapshot',
      submit: () => _repository.rollbackSnapshot(_session, _guest, snapshot),
    );
  }

  Future<bool> deleteSnapshot(PveGuestSnapshot snapshot) {
    return _submitTask(
      operationLabel: 'Delete snapshot',
      submit: () => _repository.deleteSnapshot(_session, _guest, snapshot),
    );
  }

  Future<bool> createBackup(PveGuestBackupRequest request) {
    return _submitTask(
      operationLabel: 'Run backup',
      submit: () => _repository.createBackup(_session, _guest, request),
    );
  }

  Future<bool> updateConfiguration(PveGuestConfigurationChange change) async {
    if (change.isEmpty || hasRunningTask) {
      return false;
    }
    _operationInFlight = true;
    _errorMessage = null;
    _notify();
    try {
      await _repository.updateConfiguration(_session, _guest, change);
      await load();
      return true;
    } on ProxmoxApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = 'Configuration changes could not be saved.';
      return false;
    } finally {
      if (!_isDisposed) {
        _operationInFlight = false;
        _notify();
      }
    }
  }

  Future<bool> _submitTask({
    required String operationLabel,
    GuestPowerAction? runningAction,
    required Future<ProxmoxTaskReference?> Function() submit,
  }) async {
    if (hasRunningTask) {
      return false;
    }
    _operationInFlight = true;
    _runningAction = runningAction;
    _errorMessage = null;
    _notify();

    try {
      final ProxmoxTaskReference? task = await submit();
      if (_isDisposed) {
        return false;
      }
      if (task != null) {
        _activeTask = ProxmoxTaskStatus(
          reference: task,
          state: ProxmoxTaskState.running,
        );
        _trackTask(task);
      } else {
        await load();
      }
      return true;
    } on ProxmoxApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = '$operationLabel could not be requested.';
      return false;
    } finally {
      if (!_isDisposed) {
        _operationInFlight = false;
        _runningAction = null;
        _notify();
      }
    }
  }

  void _trackTask(ProxmoxTaskReference reference) {
    final int taskEpoch = ++_taskEpoch;
    unawaited(_pollTask(reference, taskEpoch));
  }

  Future<void> _pollTask(ProxmoxTaskReference reference, int taskEpoch) async {
    final ProxmoxTaskPollResult? result = await pollProxmoxTask(
      _taskClient,
      _session,
      reference,
      isCancelled: () => _isTaskStale(taskEpoch),
      onStatus: (ProxmoxTaskStatus status) {
        if (_isTaskStale(taskEpoch)) {
          return;
        }
        _activeTask = status;
        _notify();
      },
    );
    if (result == null || _isTaskStale(taskEpoch)) {
      return;
    }
    _activeTask = result.status;
    _errorMessage = result.errorMessage;
    _notify();
    if (result.reachedTerminalState) {
      await load();
      if (_isTaskStale(taskEpoch)) {
        return;
      }
      await _notifyParentOfTerminalTask(taskEpoch);
    }
  }

  Future<void> _notifyParentOfTerminalTask(int taskEpoch) async {
    final Future<void> Function()? onTaskTerminal = _onTaskTerminal;
    if (onTaskTerminal == null) {
      return;
    }
    try {
      await onTaskTerminal();
    } catch (_) {
      if (_isTaskStale(taskEpoch)) {
        return;
      }
      _errorMessage ??= 'The workspace status could not be refreshed.';
      _notify();
    }
  }

  void _setFailure(int requestEpoch, String message) {
    if (_isStale(requestEpoch)) {
      return;
    }
    _state = GuestDetailLoadState.failed;
    _errorMessage = message;
    _notify();
  }

  bool _isStale(int requestEpoch) =>
      _isDisposed || requestEpoch != _requestEpoch;

  bool _isTaskStale(int taskEpoch) => _isDisposed || taskEpoch != _taskEpoch;

  void _notify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _requestEpoch += 1;
    _taskEpoch += 1;
    super.dispose();
  }
}
