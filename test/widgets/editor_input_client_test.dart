import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_format/quill_format.dart';
import 'package:zefyrka/zefyrka.dart';

import '../testing.dart';

Future<void> _updateEditingState(
    WidgetTester tester, TextEditingValue value) async {
  // Client id -1 bypasses the client id verification in debug builds.
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.textInput.name,
    SystemChannels.textInput.codec.encodeMethodCall(MethodCall(
      'TextInputClient.updateEditingState',
      <dynamic>[-1, value.toJSON()],
    )),
    (ByteData? _) {},
  );
  await tester.pump();
}

void main() {
  testWidgets('keyboard replacing all text including last line break',
      (tester) async {
    final editor = EditorSandBox(tester: tester);
    await editor.pumpAndTap();
    // The platform text includes the last line break of the document.
    final text = editor.controller.plainTextEditingValue.text;

    await _updateEditingState(
      tester,
      const TextEditingValue(
        text: 'x',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(text, isNot('x'));
    expect(editor.document.toDelta(), Delta()..insert('x\n'));
  });

  testWidgets('keyboard deleting all text keeps the editor usable',
      (tester) async {
    final editor = EditorSandBox(tester: tester);
    await editor.pumpAndTap();

    // Select all and delete on the keyboard removes the last line break too.
    await _updateEditingState(
      tester,
      const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(editor.document.toDelta(), Delta()..insert('\n'));

    await tester.tapAt(tester.getCenter(find.byType(ZefyrField)));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
