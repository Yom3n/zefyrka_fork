import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zefyrka/zefyrka.dart';

import '../testing.dart';

void main() {
  group('$RawEditor post-frame callbacks', () {
    testWidgets('do not throw when editor is removed after text change',
        (tester) async {
      final editor = EditorSandBox(tester: tester);
      await editor.pumpAndTap();

      // Schedules post-frame callbacks (caret reveal, selection overlay).
      editor.controller.replaceText(0, 0, 'a');
      // Remove the editor in the same frame, before the callbacks run.
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });

    testWidgets('do not throw when editor is removed after focus change',
        (tester) async {
      final editor = EditorSandBox(tester: tester);
      await editor.pump();

      editor.focusNode.requestFocus();
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  });
}
