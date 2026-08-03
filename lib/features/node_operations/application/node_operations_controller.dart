import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/api/proxmox_api_exception.dart';
import '../../../core/api/proxmox_session.dart';
import '../../../core/api/proxmox_task.dart';
import '../data/proxmox_node_repository.dart';
import '../domain/pve_node_details.dart';

enum NodeOperationsLoadState { loading, ready, failed }

class NodeOperationsController extends ChangeNotifier {
  NodeOperationsController({
    required PveNodeRepository repository,
    required ProxmoxSession session,
    required PveNodeDetailsSeed seed,
    ProxmoxTaskClient? taskClient,
    Future<void> Function()? onTaskTerminal,
  }) : _repository = repository,
       _session = session,
       _seed = seed,
       _taskClient = taskClient ?? const ProxmoxTaskClient(),
       _onTaskTerminal = onTaskTerminal;

  final PveNodeRepository _repository;
  final ProxmoxSession _session;
  final PveNodeDetailsSeed _seed;
  final ProxmoxTaskClient _taskClient;
  final Future<void> Function()? _onTaskTerminal;

  NodeOperationsLoadState _state = NodeOperationsLoadState.loading;
  PveNodeDetails? _details;
  ProxmoxTaskStatus? _activeTask;
  String? _errorMessage;
  bool _operationInFlight = false;
  int _requestEpoch = 0;
  int _taskEpoch = 0;
  bool _isDisposed = false;

  PveNodeDetailsSeed get seed => _seed;

  NodeOperationsLoadState get state => _state;

  PveNodeDetails? get details => _details;

  ProxmoxTaskStatus? get activeTask => _activeTask;

  String? get errorMessage => _errorMessage;

  bool get operationInFlight => _operationInFlight;

  bool get hasRunningTask =>
      _operationInFlight || _activeTask?.state == ProxmoxTaskState.running;

  Future<void> load() async {
    final int requestEpoch = ++_requestEpoch;
    _state = NodeOperationsLoadState.loading;
    _errorMessage = null;
    _notify();
    try {
      final PveNodeDetails details = await _repository.loadDetails(
        _session,
        _seed,
      );
      if (_isRequestStale(requestEpoch)) {
        return;
      }
      _details = details;
      _state = NodeOperationsLoadState.ready;
      _notify();
    } on ProxmoxApiException catch (error) {
      _failLoad(requestEpoch, error.message);
    } catch (_) {
      _failLoad(requestEpoch, 'Node details could not be loaded.');
    }
  }

  Future<bool> restartNode() => _submitTask(
    operationLabel: PveNodePowerAction.reboot.label,
    submit: () =>
        _repository.runPowerAction(_session, _seed, PveNodePowerAction.reboot),
  );

  Future<bool> shutdownNode() => _submitTask(
    operationLabel: PveNodePowerAction.shutdown.label,
    submit: () => _repository.runPowerAction(
      _session,
      _seed,
      PveNodePowerAction.shutdown,
    ),
  );

  Future<bool> restartService(PveNodeService service) => _submitTask(
    operationLabel: 'Restart ${service.name}',
    submit: () => _repository.restartService(_session, _seed, service),
  );

  Future<bool> refreshPackageIndex() => _submitTask(
    operationLabel: 'Refresh package index',
    submit: () => _repository.refreshPackageIndex(_session, _seed),
  );

  Future<bool> _submitTask({
    required String operationLabel,
    required Future<ProxmoxTaskReference> Function() submit,
  }) async {
    if (hasRunningTask) {
      return false;
    }
    _operationInFlight = true;
    _errorMessage = null;
    _notify();
    try {
      final ProxmoxTaskReference task = await submit();
      if (_isDisposed) {
        return false;
      }
      _activeTask = ProxmoxTaskStatus(
        reference: task,
        state: ProxmoxTaskState.running,
      );
      _trackTask(task);
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

  void _failLoad(int requestEpoch, String message) {
    if (_isRequestStale(requestEpoch)) {
      return;
    }
    _state = NodeOperationsLoadState.failed;
    _errorMessage = message;
    _notify();
  }

  bool _isRequestStale(int requestEpoch) =>
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
