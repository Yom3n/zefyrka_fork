import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_format/quill_format.dart';

import '../testing.dart';

void main() {
  testWidgets('keyboard replacing all text including last line break',
      (tester) async {
    final editor = EditorSandBox(tester: tester);
    await editor.pumpAndTap();
    // The platform text includes the last line break of the document.
    final text = editor.controller.plainTextEditingValue.text;

    // Client id -1 bypasses the client id verification in debug builds.
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.textInput.name,
      SystemChannels.textInput.codec.encodeMethodCall(MethodCall(
        'TextInputClient.updateEditingState',
        <dynamic>[
          -1,
          const TextEditingValue(
            text: 'x',
            selection: TextSelection.collapsed(offset: 1),
          ).toJSON(),
        ],
      )),
      (ByteData? _) {},
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(text, isNot('x'));
    expect(editor.document.toDelta(), Delta()..insert('x\n'));
  });
}
