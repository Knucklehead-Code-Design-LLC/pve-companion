import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import '../application/guest_console_controller.dart';
import '../data/proxmox_rfb_client.dart';

class RfbFramebufferView extends StatefulWidget {
  const RfbFramebufferView({
    super.key,
    required this.controller,
    required this.framebuffer,
  });

  final GuestConsoleController controller;
  final PveConsoleFramebuffer framebuffer;

  @override
  State<RfbFramebufferView> createState() => _RfbFramebufferViewState();
}

class _RfbFramebufferViewState extends State<RfbFramebufferView> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'guest-console');
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _replaceImage();
  }

  @override
  void didUpdateWidget(covariant RfbFramebufferView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.framebuffer.revision != widget.framebuffer.revision) {
      _replaceImage();
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ui.Image? image = _image;
    if (image == null) {
      return const ColoredBox(color: CupertinoColors.black);
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return Focus(
          autofocus: true,
          focusNode: _focusNode,
          onKeyEvent: _handleKeyEvent,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (PointerDownEvent event) {
              _focusNode.requestFocus();
              _sendPointer(
                event.localPosition,
                constraints,
                buttons: _rfbButtonMask(event.buttons),
              );
            },
            onPointerMove: (PointerMoveEvent event) => _sendPointer(
              event.localPosition,
              constraints,
              buttons: _rfbButtonMask(event.buttons),
            ),
            onPointerUp: (PointerUpEvent event) =>
                _sendPointer(event.localPosition, constraints, buttons: 0),
            onPointerCancel: (PointerCancelEvent event) =>
                _sendPointer(event.localPosition, constraints, buttons: 0),
            onPointerSignal: (PointerSignalEvent event) {
              if (event is! PointerScrollEvent || event.scrollDelta.dy == 0) {
                return;
              }
              final int wheelButton = event.scrollDelta.dy < 0 ? 8 : 16;
              _sendPointer(
                event.localPosition,
                constraints,
                buttons: wheelButton,
              );
              _sendPointer(event.localPosition, constraints, buttons: 0);
            },
            child: Semantics(
              label: 'Interactive guest console',
              child: ColoredBox(
                color: CupertinoColors.black,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: widget.framebuffer.width.toDouble(),
                      height: widget.framebuffer.height.toDouble(),
                      child: RawImage(
                        image: image,
                        filterQuality: FilterQuality.none,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _replaceImage() {
    final PveConsoleFramebuffer framebuffer = widget.framebuffer;
    final ui.Image nextImage = ui.decodeImageFromPixelsSync(
      framebuffer.rgbaPixels,
      framebuffer.width,
      framebuffer.height,
      ui.PixelFormat.rgba8888,
    );
    final ui.Image? previousImage = _image;
    _image = nextImage;
    previousImage?.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final int? keySym = _keySymFor(event);
    if (keySym == null) {
      return KeyEventResult.ignored;
    }
    widget.controller.sendKey(
      keySym: keySym,
      down: event is KeyDownEvent || event is KeyRepeatEvent,
    );
    return KeyEventResult.handled;
  }

  void _sendPointer(
    Offset position,
    BoxConstraints constraints, {
    required int buttons,
  }) {
    final Size targetSize = Size(constraints.maxWidth, constraints.maxHeight);
    if (targetSize.isEmpty ||
        !targetSize.width.isFinite ||
        !targetSize.height.isFinite) {
      return;
    }
    final Size sourceSize = Size(
      widget.framebuffer.width.toDouble(),
      widget.framebuffer.height.toDouble(),
    );
    final FittedSizes fitted = applyBoxFit(
      BoxFit.contain,
      sourceSize,
      targetSize,
    );
    final Size destination = fitted.destination;
    final Offset offset = Offset(
      (targetSize.width - destination.width) / 2,
      (targetSize.height - destination.height) / 2,
    );
    final int x =
        ((position.dx - offset.dx) * sourceSize.width / destination.width)
            .floor();
    final int y =
        ((position.dy - offset.dy) * sourceSize.height / destination.height)
            .floor();
    widget.controller.sendPointer(x: x, y: y, buttons: buttons);
  }

  int _rfbButtonMask(int buttons) {
    int mask = 0;
    if (buttons & kPrimaryMouseButton != 0) {
      mask |= 1;
    }
    if (buttons & kMiddleMouseButton != 0) {
      mask |= 2;
    }
    if (buttons & kSecondaryMouseButton != 0) {
      mask |= 4;
    }
    return mask;
  }

  int? _keySymFor(KeyEvent event) {
    final LogicalKeyboardKey key = event.logicalKey;
    final int? special = switch (key) {
      LogicalKeyboardKey.backspace => 0xff08,
      LogicalKeyboardKey.tab => 0xff09,
      LogicalKeyboardKey.enter => 0xff0d,
      LogicalKeyboardKey.escape => 0xff1b,
      LogicalKeyboardKey.insert => 0xff63,
      LogicalKeyboardKey.delete => 0xffff,
      LogicalKeyboardKey.home => 0xff50,
      LogicalKeyboardKey.end => 0xff57,
      LogicalKeyboardKey.pageUp => 0xff55,
      LogicalKeyboardKey.pageDown => 0xff56,
      LogicalKeyboardKey.arrowLeft => 0xff51,
      LogicalKeyboardKey.arrowUp => 0xff52,
      LogicalKeyboardKey.arrowRight => 0xff53,
      LogicalKeyboardKey.arrowDown => 0xff54,
      LogicalKeyboardKey.shiftLeft || LogicalKeyboardKey.shiftRight => 0xffe1,
      LogicalKeyboardKey.controlLeft ||
      LogicalKeyboardKey.controlRight => 0xffe3,
      LogicalKeyboardKey.altLeft || LogicalKeyboardKey.altRight => 0xffe9,
      LogicalKeyboardKey.metaLeft || LogicalKeyboardKey.metaRight => 0xffe7,
      LogicalKeyboardKey.capsLock => 0xffe5,
      LogicalKeyboardKey.f1 => 0xffbe,
      LogicalKeyboardKey.f2 => 0xffbf,
      LogicalKeyboardKey.f3 => 0xffc0,
      LogicalKeyboardKey.f4 => 0xffc1,
      LogicalKeyboardKey.f5 => 0xffc2,
      LogicalKeyboardKey.f6 => 0xffc3,
      LogicalKeyboardKey.f7 => 0xffc4,
      LogicalKeyboardKey.f8 => 0xffc5,
      LogicalKeyboardKey.f9 => 0xffc6,
      LogicalKeyboardKey.f10 => 0xffc7,
      LogicalKeyboardKey.f11 => 0xffc8,
      LogicalKeyboardKey.f12 => 0xffc9,
      _ => null,
    };
    if (special != null) {
      return special;
    }
    final String? character = event.character;
    if (character == null || character.isEmpty) {
      return null;
    }
    final int codePoint = character.runes.first;
    return codePoint <= 0xff ? codePoint : 0x01000000 | codePoint;
  }
}
