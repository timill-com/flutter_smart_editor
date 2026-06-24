import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_smart_editor/smart_editor.dart';
import 'package:flutter_smart_editor/smart_editor_controller.dart';
import 'package:flutter_smart_editor/src/models/editor_settings.dart';
import 'package:flutter_smart_editor/src/models/toolbar_settings.dart';
import 'package:flutter_smart_editor/src/models/toolbar/toolbar_index.dart';
import 'package:flutter_smart_editor/src/models/enums.dart';
import 'package:flutter_smart_editor/src/models/image_insert.dart';
import 'package:flutter_smart_editor/src/models/nodes/image_node_model.dart';

void main() {
  testWidgets('toolbar picture button → host picker → image inserted',
      (tester) async {
    final controller = SmartEditorController();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SmartEditor(
          controller: controller,
          toolbarSettings: const SmartToolbarSettings(
            toolbarPosition: SmartToolbarPosition.above,
            // Only the insert group with the picture button.
            defaultButtons: [SmartInsertButtons(table: false)],
          ),
          editorSettings: SmartEditorSettings(
            // Host picker returns a ready request — no dialog needed.
            onImagePickRequested: () async => const ImageInsertRequest(
                src: 'https://x/pick.png', origin: ImageInsertSource.toolbar),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Insert Image'));
    await tester.pumpAndSettle();

    final imgs = controller.document.blocks.whereType<ImageNode>().toList();
    expect(imgs.length, 1);
    expect(imgs.single.src, 'https://x/pick.png');
    controller.dispose();
  });

  testWidgets('toolbar picture button → built-in URL dialog fallback',
      (tester) async {
    final controller = SmartEditorController();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SmartEditor(
          controller: controller,
          toolbarSettings: const SmartToolbarSettings(
            toolbarPosition: SmartToolbarPosition.above,
            defaultButtons: [SmartInsertButtons(table: false)],
          ),
          editorSettings: const SmartEditorSettings(),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Insert Image'));
    await tester.pumpAndSettle();

    // The built-in dialog appears; type a URL and confirm.
    expect(find.text('Insert image'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, 'https://x/typed.png');
    await tester.tap(find.text('Insert'));
    await tester.pumpAndSettle();

    final imgs = controller.document.blocks.whereType<ImageNode>().toList();
    expect(imgs.length, 1);
    expect(imgs.single.src, 'https://x/typed.png');
    controller.dispose();
  });
}
