import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_smart_editor/smart_editor.dart';
import 'package:flutter_smart_editor/smart_editor_controller.dart';
import 'package:flutter_smart_editor/src/models/editor_settings.dart';
import 'package:flutter_smart_editor/src/models/toolbar_settings.dart';
import 'package:flutter_smart_editor/src/models/enums.dart';
import 'package:flutter_smart_editor/src/models/image_size.dart';
import 'package:flutter_smart_editor/src/models/nodes/image_node_model.dart';

const _png =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

Future<SmartEditorController> _pump(
  WidgetTester tester, {
  required String html,
  bool allowImageResize = true,
  bool readOnly = false,
}) async {
  final controller = SmartEditorController();
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 400,
        child: SmartEditor(
          controller: controller,
          toolbarSettings: const SmartToolbarSettings(
            toolbarPosition: SmartToolbarPosition.custom,
          ),
          editorSettings: SmartEditorSettings(
            initialText: html,
            readOnly: readOnly,
            allowImageResize: allowImageResize,
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return controller;
}

ImageNode _img(SmartEditorController c) =>
    c.document.blocks.whereType<ImageNode>().single;

void main() {
  group('controller.resizeImage', () {
    testWidgets('sets width/height and is one undo step', (tester) async {
      final controller = await _pump(tester, html: '<img src="$_png">');
      final idx = controller.document.blocks.indexOf(_img(controller));

      controller.resizeImage(idx, width: const ImageSize.percent(50));
      await tester.pumpAndSettle();
      expect(_img(controller).width, const ImageSize.percent(50));
      expect(controller.canUndo, isTrue);

      controller.undo();
      await tester.pumpAndSettle();
      expect(_img(controller).width, isNull);
      controller.dispose();
    });

    testWidgets('serializes the new size', (tester) async {
      final controller = await _pump(tester, html: '<img src="$_png">');
      final idx = controller.document.blocks.indexOf(_img(controller));
      controller.resizeImage(idx, width: const ImageSize.px(300));
      await tester.pumpAndSettle();
      final html = await controller.getText();
      expect(html, contains('width="300"'));
      expect(html, contains('width: 300px'));
      controller.dispose();
    });
  });

  group('resize menu (edit mode)', () {
    testWidgets('preset 50% updates the image width', (tester) async {
      final controller = await _pump(tester,
          html: '<img src="$_png" width="200" height="120">');
      await tester.tap(find.byTooltip('Resize image'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('50%').last);
      await tester.pumpAndSettle();
      expect(_img(controller).width, const ImageSize.percent(50));
      controller.dispose();
    });

    testWidgets('Original clears the size back to intrinsic', (tester) async {
      final controller = await _pump(tester,
          html: '<img src="$_png" width="200" height="120">');
      expect(_img(controller).width, const ImageSize.px(200));
      await tester.tap(find.byTooltip('Resize image'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Original').last);
      await tester.pumpAndSettle();
      expect(_img(controller).width, isNull);
      controller.dispose();
    });

    testWidgets('Custom… dialog sets a px width', (tester) async {
      final controller = await _pump(tester,
          html: '<img src="$_png" width="200" height="120">');
      await tester.tap(find.byTooltip('Resize image'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Custom…').last);
      await tester.pumpAndSettle();

      expect(find.text('Custom size'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, '250');
      // px is selected by default; confirm.
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(_img(controller).width, const ImageSize.px(250));
      controller.dispose();
    });

    testWidgets('no resize affordance in read-only mode', (tester) async {
      final controller =
          await _pump(tester, html: '<img src="$_png">', readOnly: true);
      expect(find.byTooltip('Resize image'), findsNothing);
      controller.dispose();
    });

    testWidgets('no resize affordance when allowImageResize is false',
        (tester) async {
      final controller = await _pump(tester,
          html: '<img src="$_png">', allowImageResize: false);
      expect(find.byTooltip('Resize image'), findsNothing);
      controller.dispose();
    });
  });
}
