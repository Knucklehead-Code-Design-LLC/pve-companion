import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../core/api/proxmox_session.dart';
import '../../../core/presentation/pve_apple_ui.dart';
import '../../guests/domain/pve_guest.dart';
import '../application/guest_console_controller.dart';
import '../data/proxmox_guest_console_repository.dart';
import '../data/proxmox_rfb_client.dart';
import 'rfb_framebuffer_view.dart';

Future<void> showGuestConsolePage(
  BuildContext context, {
  required PveGuest guest,
  required ProxmoxSession session,
  PveGuestConsoleRepository? repository,
}) async {
  await Navigator.of(context, rootNavigator: true).push<void>(
    CupertinoPageRoute<void>(
      builder: (BuildContext pageContext) => GuestConsolePage(
        guest: guest,
        session: session,
        repository: repository,
      ),
    ),
  );
}

class GuestConsolePage extends StatefulWidget {
  const GuestConsolePage({
    super.key,
    required this.guest,
    required this.session,
    this.repository,
  });

  final PveGuest guest;
  final ProxmoxSession session;
  final PveGuestConsoleRepository? repository;

  @override
  State<GuestConsolePage> createState() => _GuestConsolePageState();
}

class _GuestConsolePageState extends State<GuestConsolePage>
    with WidgetsBindingObserver {
  late final GuestConsoleController _controller;
  final TextEditingController _textInputController = TextEditingController();
  final FocusNode _textInputFocusNode = FocusNode(
    debugLabel: 'guest-console-text-input',
  );
  String _previousTextInput = '';
  bool _clearingTextInput = false;
  bool _showsTextInput = false;
  bool _closedForBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = GuestConsoleController(
      repository: widget.repository ?? ProxmoxGuestConsoleRepository(),
      session: widget.session,
      guest: widget.guest,
    );
    unawaited(_controller.connect());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _textInputController.dispose();
    _textInputFocusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _closedForBackground = true;
        unawaited(_controller.disconnect());
        break;
      case AppLifecycleState.resumed:
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      navigationBar: CupertinoNavigationBar(
        backgroundColor: PveAppleColors.page(context),
        middle: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(widget.guest.title),
            Text(
              '${widget.guest.kind.shortLabel} ${widget.guest.vmid} · Console',
              style: PveAppleText.caption(context),
            ),
          ],
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
        trailing: CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          minimumSize: const Size(44, 36),
          onPressed: _controller.state == GuestConsoleConnectionState.connecting
              ? null
              : _reconnect,
          child: const Icon(CupertinoIcons.refresh, size: 19),
        ),
      ),
      child: SafeArea(
        top: false,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (BuildContext context, Widget? child) {
            return Column(
              children: <Widget>[
                Expanded(child: _buildConsoleSurface(context)),
                _ConsoleControlBar(
                  connected: _controller.isConnected,
                  guest: widget.guest,
                  showsTextInput: _showsTextInput,
                  textInputController: _textInputController,
                  textInputFocusNode: _textInputFocusNode,
                  onToggleTextInput: _toggleTextInput,
                  onTextChanged: _sendTypedText,
                  onTextSubmitted: (_) => _submitTypedText(),
                  onPaste: _pasteClipboard,
                  onKeyStroke: _controller.sendKeyStroke,
                  onCtrlAltDelete: _sendCtrlAltDelete,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildConsoleSurface(BuildContext context) {
    final PveConsoleFramebuffer? framebuffer = _controller.framebuffer;
    switch (_controller.state) {
      case GuestConsoleConnectionState.connecting:
        return const _ConsoleStatus(
          icon: CupertinoIcons.ellipsis,
          title: 'Connecting to guest console',
          message: 'Requesting a short-lived connection ticket.',
          loading: true,
        );
      case GuestConsoleConnectionState.connected:
        if (framebuffer == null) {
          return const _ConsoleStatus(
            icon: CupertinoIcons.desktopcomputer,
            title: 'Preparing guest display',
            message: 'Waiting for the guest’s first framebuffer update.',
            loading: true,
          );
        }
        return RfbFramebufferView(
          controller: _controller,
          framebuffer: framebuffer,
        );
      case GuestConsoleConnectionState.failed:
        return _ConsoleStatus(
          icon: CupertinoIcons.exclamationmark_triangle,
          title: 'Console unavailable',
          message:
              _controller.errorMessage ??
              'The guest console could not be connected.',
          actionLabel: 'Try Again',
          onAction: _reconnect,
        );
      case GuestConsoleConnectionState.disconnected:
        return _ConsoleStatus(
          icon: CupertinoIcons.lock,
          title: _closedForBackground
              ? 'Console closed for privacy'
              : 'Console disconnected',
          message: _closedForBackground
              ? 'The connection was closed when PVE Companion left the foreground. Reconnect to request a new ticket.'
              : 'Reconnect to request a new guest-console ticket.',
          actionLabel: 'Reconnect',
          onAction: _reconnect,
        );
    }
  }

  void _reconnect() {
    _closedForBackground = false;
    _clearTextInput();
    unawaited(_controller.connect());
  }

  void _toggleTextInput() {
    setState(() => _showsTextInput = !_showsTextInput);
    if (_showsTextInput) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _textInputFocusNode.requestFocus();
        }
      });
    }
  }

  void _sendTypedText(String currentText) {
    if (_clearingTextInput) {
      return;
    }
    final int sharedLength = _commonPrefixLength(
      _previousTextInput,
      currentText,
    );
    final int removedLength = _previousTextInput.length - sharedLength;
    for (int index = 0; index < removedLength; index += 1) {
      _controller.sendKeyStroke(0xff08);
    }
    final String addedText = currentText.substring(sharedLength);
    for (final int codePoint in addedText.runes) {
      _controller.sendKeyStroke(
        codePoint <= 0xff ? codePoint : 0x01000000 | codePoint,
      );
    }
    _previousTextInput = currentText;
  }

  void _submitTypedText() {
    _controller.sendKeyStroke(0xff0d);
    _clearTextInput();
  }

  Future<void> _pasteClipboard() async {
    final ClipboardData? clipboard = await Clipboard.getData(
      Clipboard.kTextPlain,
    );
    final String? text = clipboard?.text;
    if (text == null || text.isEmpty) {
      return;
    }
    try {
      _controller.sendClipboard(text);
    } on Object {
      if (!mounted) {
        return;
      }
      await showCupertinoDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) => CupertinoAlertDialog(
          title: const Text('Couldn’t Paste'),
          content: const Text(
            'The clipboard text could not be sent to the guest console.',
          ),
          actions: <Widget>[
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _sendCtrlAltDelete() {
    const int control = 0xffe3;
    const int alt = 0xffe9;
    const int delete = 0xffff;
    _controller.sendKey(keySym: control, down: true);
    _controller.sendKey(keySym: alt, down: true);
    _controller.sendKey(keySym: delete, down: true);
    _controller.sendKey(keySym: delete, down: false);
    _controller.sendKey(keySym: alt, down: false);
    _controller.sendKey(keySym: control, down: false);
  }

  void _clearTextInput() {
    _clearingTextInput = true;
    _previousTextInput = '';
    _textInputController.clear();
    _clearingTextInput = false;
  }

  int _commonPrefixLength(String left, String right) {
    final int limit = left.length < right.length ? left.length : right.length;
    int index = 0;
    while (index < limit && left.codeUnitAt(index) == right.codeUnitAt(index)) {
      index += 1;
    }
    return index;
  }
}

class _ConsoleStatus extends StatelessWidget {
  const _ConsoleStatus({
    required this.icon,
    required this.title,
    required this.message,
    this.loading = false,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool loading;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: CupertinoColors.black,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (loading)
                  const CupertinoActivityIndicator(color: CupertinoColors.white)
                else
                  Icon(icon, size: 32, color: CupertinoColors.white),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: CupertinoColors.systemGrey2,
                    fontSize: 14,
                  ),
                ),
                if (actionLabel != null && onAction != null) ...<Widget>[
                  const SizedBox(height: 18),
                  CupertinoButton.filled(
                    onPressed: onAction,
                    child: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConsoleControlBar extends StatelessWidget {
  const _ConsoleControlBar({
    required this.connected,
    required this.guest,
    required this.showsTextInput,
    required this.textInputController,
    required this.textInputFocusNode,
    required this.onToggleTextInput,
    required this.onTextChanged,
    required this.onTextSubmitted,
    required this.onPaste,
    required this.onKeyStroke,
    required this.onCtrlAltDelete,
  });

  final bool connected;
  final PveGuest guest;
  final bool showsTextInput;
  final TextEditingController textInputController;
  final FocusNode textInputFocusNode;
  final VoidCallback onToggleTextInput;
  final ValueChanged<String> onTextChanged;
  final ValueChanged<String> onTextSubmitted;
  final Future<void> Function() onPaste;
  final ValueChanged<int> onKeyStroke;
  final VoidCallback onCtrlAltDelete;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: CupertinoColors.black),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (showsTextInput) ...<Widget>[
                CupertinoTextField(
                  controller: textInputController,
                  focusNode: textInputFocusNode,
                  enabled: connected,
                  placeholder: 'Type into guest',
                  textInputAction: TextInputAction.done,
                  onChanged: onTextChanged,
                  onSubmitted: onTextSubmitted,
                  prefix: const Padding(
                    padding: EdgeInsets.only(left: 10),
                    child: Icon(CupertinoIcons.keyboard),
                  ),
                  suffix: CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: const Size(44, 34),
                    onPressed: connected
                        ? () => onTextSubmitted(textInputController.text)
                        : null,
                    child: const Text('Return'),
                  ),
                ),
                const SizedBox(height: 6),
              ],
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: <Widget>[
                    _ConsoleCommandButton(
                      icon: CupertinoIcons.keyboard,
                      label: showsTextInput ? 'Hide Keyboard' : 'Keyboard',
                      enabled: connected,
                      onPressed: onToggleTextInput,
                    ),
                    _ConsoleCommandButton(
                      label: 'Esc',
                      enabled: connected,
                      onPressed: () => onKeyStroke(0xff1b),
                    ),
                    _ConsoleCommandButton(
                      label: 'Tab',
                      enabled: connected,
                      onPressed: () => onKeyStroke(0xff09),
                    ),
                    _ConsoleCommandButton(
                      icon: CupertinoIcons.arrow_up,
                      label: 'Up',
                      enabled: connected,
                      onPressed: () => onKeyStroke(0xff52),
                    ),
                    _ConsoleCommandButton(
                      icon: CupertinoIcons.arrow_down,
                      label: 'Down',
                      enabled: connected,
                      onPressed: () => onKeyStroke(0xff54),
                    ),
                    _ConsoleCommandButton(
                      icon: CupertinoIcons.doc_on_clipboard,
                      label: 'Paste',
                      enabled: connected,
                      onPressed: () => unawaited(onPaste()),
                    ),
                    if (guest.kind == GuestKind.virtualMachine)
                      _ConsoleCommandButton(
                        label: 'Ctrl-Alt-Del',
                        enabled: connected,
                        onPressed: onCtrlAltDelete,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsoleCommandButton extends StatelessWidget {
  const _ConsoleCommandButton({
    this.icon,
    required this.label,
    required this.enabled,
    required this.onPressed,
  });

  final IconData? icon;
  final String label;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        minimumSize: const Size(44, 36),
        color: CupertinoColors.darkBackgroundGray,
        disabledColor: CupertinoColors.systemGrey5.darkColor,
        onPressed: enabled ? onPressed : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 15),
              const SizedBox(width: 5),
            ],
            Text(label),
          ],
        ),
      ),
    );
  }
}
