import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pve_companion/features/console/presentation/guest_console_page.dart';
import 'package:pve_companion/features/guests/domain/pve_guest.dart';

import 'console_test_fixtures.dart';

void main() {
  testWidgets('closes the in-app console when the app backgrounds', (
    WidgetTester tester,
  ) async {
    final repository = DeferredConsoleRepository();
    await tester.pumpWidget(
      CupertinoApp(
        home: GuestConsolePage(
          guest: _guest,
          session: FakeProxmoxSession(),
          repository: repository,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Connecting to console'), findsOneWidget);
    expect(find.byTooltip('Reconnect guest console'), findsOneWidget);
    expect(find.bySemanticsLabel('Reconnect guest console'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    await tester.pump();

    expect(find.text('Console closed for privacy'), findsOneWidget);
    final transport = MemoryConsoleTransport();
    repository.request.complete(transport);
    await tester.pump();
    await tester.pump();
    expect(transport.closed, isTrue);
  });

  testWidgets('sends complete Unicode code points when replacing typed text', (
    WidgetTester tester,
  ) async {
    final repository = DeferredConsoleRepository();
    final transport = MemoryConsoleTransport();
    repository.request.complete(transport);

    await tester.pumpWidget(
      CupertinoApp(
        home: GuestConsolePage(
          guest: _guest,
          session: FakeProxmoxSession(),
          repository: repository,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    transport.addBytes(rfbServerHandshake(width: 80, height: 24));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('Type'));
    await tester.pump();
    final textInput = find.byType(CupertinoTextField);
    expect(textInput, findsOneWidget);

    await tester.enterText(textInput, '😀');
    await tester.enterText(textInput, '😃');

    final keyMessages = transport.sent
        .where((Uint8List message) => message.first == 4)
        .toList(growable: false);
    expect(
      _keySymbols(keyMessages),
      orderedEquals(<int>[
        0x0101f600,
        0x0101f600,
        0xff08,
        0xff08,
        0x0101f603,
        0x0101f603,
      ]),
    );
    expect(
      keyMessages.map((Uint8List message) => message[1]),
      orderedEquals(<int>[1, 0, 1, 0, 1, 0]),
    );
  });
}

const PveGuest _guest = PveGuest(
  vmid: 101,
  node: 'node-a',
  kind: GuestKind.virtualMachine,
  status: 'running',
);

List<int> _keySymbols(List<Uint8List> messages) {
  return messages
      .map((Uint8List message) => ByteData.sublistView(message).getUint32(4))
      .toList(growable: false);
}
