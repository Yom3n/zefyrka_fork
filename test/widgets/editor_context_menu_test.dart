import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zefyrka/zefyrka.dart';

void main() {
  String? clipboardText;

  setUp(() {
    clipboardText = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      switch (call.method) {
        case 'Clipboard.hasStrings':
          return {'value': clipboardText?.isNotEmpty ?? false};
        case 'Clipboard.getData':
          return clipboardText == null ? null : {'text': clipboardText};
        case 'Clipboard.setData':
          clipboardText = (call.arguments as Map)['text'] as String?;
          return null;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  Future<RawEditorState> pumpEditor(
      WidgetTester tester, ZefyrController controller) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ZefyrEditor(
          controller: controller,
          focusNode: FocusNode(),
          autofocus: true,
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return tester.state<RawEditorState>(find.byType(RawEditor));
  }

  group('context menu', () {
    testWidgets('does not offer "Select all" for an empty document',
        (tester) async {
      final controller = ZefyrController(NotusDocument());
      final editor = await pumpEditor(tester, controller);
      expect(editor.selectAllEnabled, isFalse);
    });

    testWidgets('offers "Select all" once the document has content',
        (tester) async {
      final controller = ZefyrController(NotusDocument());
      final editor = await pumpEditor(tester, controller);
      controller.replaceText(0, 0, 'Hello');
      await tester.pump();
      expect(editor.selectAllEnabled, isTrue);
    });

    testWidgets('shows only "Paste" on an empty document', (tester) async {
      final controller = ZefyrController(NotusDocument());
      final editor = await pumpEditor(tester, controller);

      // Clipboard gets filled after the editor was created.
      clipboardText = 'copied';
      editor.showToolbar();
      await tester.pumpAndSettle();

      expect(find.text('Paste'), findsOneWidget);
      expect(find.text('Select all'), findsNothing);
    });

    testWidgets('refreshes clipboard status after copying', (tester) async {
      final controller = ZefyrController(NotusDocument());
      final editor = await pumpEditor(tester, controller);
      controller.replaceText(0, 0, 'Hello');
      controller.updateSelection(
          const TextSelection(baseOffset: 0, extentOffset: 5));
      await tester.pump();

      editor.copySelection(SelectionChangedCause.keyboard);
      controller.updateSelection(const TextSelection.collapsed(offset: 5));
      await tester.pumpAndSettle();

      editor.showToolbar();
      await tester.pumpAndSettle();
      expect(clipboardText, 'Hello');
      expect(find.text('Paste'), findsOneWidget);
    });
  });
}
