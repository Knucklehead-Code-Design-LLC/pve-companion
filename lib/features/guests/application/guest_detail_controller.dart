import 'package:flutter/foundation.dart';

import '../../../core/api/proxmox_api_exception.dart';
import '../../../core/api/proxmox_session.dart';
import '../data/proxmox_guest_repository.dart';
import '../domain/pve_guest.dart';

enum GuestDetailLoadState { loading, ready, failed }

class GuestDetailController extends ChangeNotifier {
  GuestDetailController({
    required PveGuestRepository repository,
    required ProxmoxSession session,
    required PveGuest guest,
  }) : _repository = repository,
       _session = session,
       _guest = guest;

  final PveGuestRepository _repository;
  final ProxmoxSession _session;
  final PveGuest _guest;

  GuestDetailLoadState _state = GuestDetailLoadState.loading;
  PveGuestDetails? _details;
  String? _errorMessage;
  GuestPowerAction? _runningAction;
  int _requestEpoch = 0;
  bool _isDisposed = false;

  PveGuest get guest => _guest;

  GuestDetailLoadState get state => _state;

  PveGuestDetails? get details => _details;

  String? get errorMessage => _errorMessage;

  GuestPowerAction? get runningAction => _runningAction;

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

  Future<bool> runPowerAction(GuestPowerAction action) async {
    if (_runningAction != null) {
      return false;
    }
    _runningAction = action;
    _errorMessage = null;
    _notify();

    try {
      await _repository.runPowerAction(_session, _guest, action);
      return true;
    } on ProxmoxApiException catch (error) {
      _errorMessage = error.message;
      return false;
    } catch (_) {
      _errorMessage = '${action.label} could not be requested.';
      return false;
    } finally {
      if (!_isDisposed) {
        _runningAction = null;
        _notify();
      }
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

  void _notify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _requestEpoch += 1;
    super.dispose();
  }
}
