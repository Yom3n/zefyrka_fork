import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quill_format/quill_format.dart';
import 'package:zefyrka/zefyrka.dart';

void main() {
  group('$ZefyrController', () {
    late ZefyrController controller;

    setUp(() {
      var doc = NotusDocument();
      controller = ZefyrController(doc);
    });

    test('dispose', () {
      controller.dispose();
      expect(controller.document.isClosed, true);
    });

    test('selection', () {
      var notified = false;
      controller.addListener(() {
        notified = true;
      });
      controller.updateSelection(TextSelection.collapsed(offset: 0));
      expect(notified, true);
      expect(controller.selection, TextSelection.collapsed(offset: 0));
      // expect(controller.lastChangeSource, ChangeSource.remote);
    });

    test('compose', () {
      var notified = false;
      controller.addListener(() {
        notified = true;
      });
      var selection = TextSelection.collapsed(offset: 5);
      var change = Delta()..insert('Words');
      controller.compose(change, selection: selection);
      expect(notified, true);
      expect(controller.selection, selection);
      expect(controller.document.toDelta(), Delta()..insert('Words\n'));
      // expect(controller.lastChangeSource, ChangeSource.remote);
    });

    test('compose and transform position', () {
      var notified = false;
      controller.addListener(() {
        notified = true;
      });
      var selection = TextSelection.collapsed(offset: 5);
      var change = Delta()..insert('Words');
      controller.compose(change, selection: selection);
      var change2 = Delta()..insert('More ');
      controller.compose(change2);
      expect(notified, true);
      var expectedSelection = TextSelection.collapsed(offset: 10);
      expect(controller.selection, expectedSelection);
      expect(controller.document.toDelta(), Delta()..insert('More Words\n'));
      // expect(controller.lastChangeSource, ChangeSource.remote);
    });

    test('replaceText', () {
      var notified = false;
      controller.addListener(() {
        notified = true;
      });
      var selection = TextSelection.collapsed(offset: 5);
      controller.replaceText(0, 0, 'Words', selection: selection);
      expect(notified, true);
      expect(controller.selection, selection);
      expect(controller.document.toDelta(), Delta()..insert('Words\n'));
      // expect(controller.lastChangeSource, ChangeSource.local);
    });

    group('replaceText touching the last line break', () {
      setUp(() {
        controller.replaceText(0, 0, 'abc');
      });

      test('inserts after the last line break', () {
        controller.replaceText(4, 0, 'x',
            selection: TextSelection.collapsed(offset: 5));
        expect(controller.document.toDelta(), Delta()..insert('abcx\n'));
        expect(controller.selection, TextSelection.collapsed(offset: 4));
      });

      test('inserts past the end of the document', () {
        controller.replaceText(10, 0, 'x');
        expect(controller.document.toDelta(), Delta()..insert('abcx\n'));
      });

      test('replaces all text including the last line break', () {
        controller.replaceText(0, 4, 'x',
            selection: TextSelection.collapsed(offset: 1));
        expect(controller.document.toDelta(), Delta()..insert('x\n'));
        expect(controller.selection, TextSelection.collapsed(offset: 1));
      });

      test('replaces the last line break', () {
        controller.replaceText(3, 1, 'x');
        expect(controller.document.toDelta(), Delta()..insert('abcx\n'));
      });

      test('replaces the last line break with text ending with a line break',
          () {
        controller.replaceText(2, 2, 'x\n');
        expect(controller.document.toDelta(), Delta()..insert('abx\n'));
      });

      test('deletes the last line break', () {
        controller.replaceText(3, 1, '');
        expect(controller.document.toDelta(), Delta()..insert('abc\n'));
      });
    });

    test('formatText', () {
      var notified = false;
      controller.addListener(() {
        notified = true;
      });
      controller.replaceText(0, 0, 'Words');
      controller.formatText(0, 5, NotusAttribute.bold);
      expect(notified, true);
      expect(
        controller.document.toDelta(),
        Delta()
          ..insert('Words', NotusAttribute.bold.toJson())
          ..insert('\n'),
      );
      // expect(controller.lastChangeSource, ChangeSource.local);
    });

    test('formatText with toggled style enabled', () {
      var notified = false;
      controller.addListener(() {
        notified = true;
      });
      controller.replaceText(0, 0, 'Words');
      controller.formatText(2, 0, NotusAttribute.bold);
      // Test that doing nothing does reset the toggledStyle.
      controller.replaceText(2, 0, '');
      controller.replaceText(2, 0, 'n');
      controller.formatText(3, 0, NotusAttribute.bold);
      controller.replaceText(3, 0, 'B');
      expect(notified, true);

      expect(
        controller.document.toDelta(),
        Delta()
          ..insert('Won')
          ..insert('B', NotusAttribute.bold.toJson())
          ..insert('rds')
          ..insert('\n'),
      );
      // expect(controller.lastChangeSource, ChangeSource.local);
    });

    test('insert text with toggled style unset', () {
      var notified = false;
      controller.addListener(() {
        notified = true;
      });
      controller.replaceText(0, 0, 'Words');
      controller.formatText(1, 0, NotusAttribute.bold);
      controller.replaceText(1, 0, 'B');
      controller.formatText(2, 0, NotusAttribute.bold.unset);
      controller.replaceText(2, 0, 'u');

      expect(notified, true);
      expect(
        controller.document.toDelta(),
        Delta()
          ..insert('W')
          ..insert('B', NotusAttribute.bold.toJson())
          ..insert('uords')
          ..insert('\n'),
      );
      // expect(controller.lastChangeSource, ChangeSource.local);
    });

    test('formatSelection', () {
      var notified = false;
      controller.addListener(() {
        notified = true;
      });
      var selection = TextSelection(baseOffset: 0, extentOffset: 5);
      controller.replaceText(0, 0, 'Words', selection: selection);
      controller.formatSelection(NotusAttribute.bold);
      expect(notified, true);
      expect(
        controller.document.toDelta(),
        Delta()
          ..insert('Words', NotusAttribute.bold.toJson())
          ..insert('\n'),
      );
      // expect(controller.lastChangeSource, ChangeSource.local);
    });

    test('getSelectionStyle', () {
      var selection = TextSelection.collapsed(offset: 3);
      controller.replaceText(0, 0, 'Words', selection: selection);
      controller.formatText(0, 5, NotusAttribute.bold);
      var result = controller.getSelectionStyle();
      expect(result.values, [NotusAttribute.bold]);
    });

    group('stale selection', () {
      setUp(() {
        controller.replaceText(0, 0, 'Hello world',
            selection: TextSelection.collapsed(offset: 10));
      });

      test('is clamped when document is replaced', () {
        controller.document = NotusDocument();
        expect(controller.selection, TextSelection.collapsed(offset: 0));
        expect(controller.getSelectionStyle(), NotusStyle());
      });

      test('getSelectionStyle when document is modified directly', () {
        controller.document.delete(0, 8);
        expect(controller.getSelectionStyle(), NotusStyle());
      });

      test('getSelectionStyle keeps block style of the last line', () {
        controller.document.format(0, 0, NotusAttribute.ul);
        controller.document.delete(0, 8);
        expect(controller.getSelectionStyle(),
            NotusStyle().put(NotusAttribute.ul));
      });
    });

    test('getSelectionStyle with toggled style', () {
      var selection = TextSelection.collapsed(offset: 3);
      controller.replaceText(0, 0, 'Words', selection: selection);
      controller.formatText(3, 0, NotusAttribute.bold);

      var result = controller.getSelectionStyle();
      expect(result.values, [NotusAttribute.bold]);
    });

    test('preserve inline format when replacing text from the first character',
        () {
      var notified = false;
      controller.addListener(() {
        notified = true;
      });
      controller.formatText(0, 0, NotusAttribute.bold);
      controller.replaceText(0, 0, 'Word');
      expect(notified, true);
      expect(
        controller.document.toDelta(),
        Delta()
          ..insert('Word', NotusAttribute.bold.toJson())
          ..insert('\n'),
      );
      // expect(controller.lastChangeSource, ChangeSource.local);
    });
  });
}
