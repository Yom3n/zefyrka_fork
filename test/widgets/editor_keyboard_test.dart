import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_format/quill_format.dart';

import '../testing.dart';

void main() {
  group('hardware keyboard delete', () {
    testWidgets('after text is cleared without selection', (tester) async {
      final editor = EditorSandBox(tester: tester);
      await editor.pumpAndTap();
      editor.controller.replaceText(0, editor.document.length - 1, '');
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(editor.document.toDelta(), Delta()..insert('\n'));
    });
  });
}
