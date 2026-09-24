import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zefyrka/zefyrka.dart';

import '../testing.dart';

Future<void> _sendTextInputCall(
    WidgetTester tester, String method, List<dynamic> args) async {
  // Client id -1 bypasses the client id verification in debug builds.
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.textInput.name,
    SystemChannels.textInput.codec
        .encodeMethodCall(MethodCall(method, <dynamic>[-1, ...args])),
    (ByteData? _) {},
  );
  await tester.pump();
}

Future<void> _floatingCursor(WidgetTester tester, String state,
    [double x = 0, double y = 0]) {
  return _sendTextInputCall(
    tester,
    'TextInputClient.updateFloatingCursor',
    <dynamic>[
      'FloatingCursorDragState.$state',
      <String, dynamic>{'X': x, 'Y': y}
    ],
  );
}

/// Width of a single character. The test font renders every glyph with the
/// same width.
double _charWidth(WidgetTester tester) {
  final renderEditor = tester.allRenderObjects.whereType<RenderEditor>().first;
  double caretX(int offset) => renderEditor
      .getEndpointsForSelection(TextSelection.collapsed(offset: offset))
      .first
      .point
      .dx;
  return caretX(1) - caretX(0);
}

void main() {
  group('floating cursor', () {
    testWidgets('moves caret while dragging', (tester) async {
      final editor = EditorSandBox(tester: tester);
      await editor.pumpAndTap();
      await editor.updateSelection(base: 0, extent: 0);
      final w = _charWidth(tester);

      await _floatingCursor(tester, 'start');
      expect(tester.takeException(), isNull);
      expect(editor.selection, const TextSelection.collapsed(offset: 0));

      await _floatingCursor(tester, 'update', w * 5.25);
      expect(tester.takeException(), isNull);
      expect(editor.selection.isCollapsed, isTrue);
      expect(editor.selection.baseOffset, 5);

      await _floatingCursor(tester, 'update', w * 2.25);
      expect(editor.selection.baseOffset, 2);

      await _floatingCursor(tester, 'end');
      expect(tester.takeException(), isNull);
      expect(editor.selection, const TextSelection.collapsed(offset: 2));
    });

    testWidgets('resets origin after dragging out of bounds', (tester) async {
      final editor = EditorSandBox(tester: tester);
      await editor.pumpAndTap();
      await editor.updateSelection(base: 5, extent: 5);
      final w = _charWidth(tester);

      await _floatingCursor(tester, 'start');
      await _floatingCursor(tester, 'update', -500);
      await _floatingCursor(tester, 'update', -1000);
      expect(editor.selection.baseOffset, 0);

      // Dragging back right resets the origin at the edge of the editor, so
      // the caret moves immediately instead of waiting for the finger to cover
      // the 1000px dragged outside of the editor.
      await _floatingCursor(tester, 'update', -1000 + w);
      expect(editor.selection.baseOffset, 0);
      await _floatingCursor(tester, 'update', -1000 + w + w * 3.25);
      expect(editor.selection.baseOffset, 3);
      await _floatingCursor(tester, 'end');
    });

    testWidgets('does not collapse a non-collapsed selection', (tester) async {
      final editor = EditorSandBox(tester: tester);
      await editor.pumpAndTap();
      await editor.updateSelection(base: 0, extent: 4);
      final w = _charWidth(tester);

      await _floatingCursor(tester, 'start');
      await _floatingCursor(tester, 'update', w * 8.25);
      await _floatingCursor(tester, 'end');
      expect(tester.takeException(), isNull);
      expect(editor.selection,
          const TextSelection(baseOffset: 0, extentOffset: 4));
    });
  });

  testWidgets('showAutocorrectionPromptRect does not throw', (tester) async {
    final editor = EditorSandBox(tester: tester);
    await editor.pumpAndTap();
    await _sendTextInputCall(tester,
        'TextInputClient.showAutocorrectionPromptRect', <dynamic>[0, 4]);
    expect(tester.takeException(), isNull);
  });
}
