import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_smart_editor/smart_editor.dart';
import 'package:flutter_smart_editor/smart_editor_controller.dart';
import 'package:flutter_smart_editor/src/core/document/document.dart';
import 'package:flutter_smart_editor/src/models/editor_settings.dart';
import 'package:flutter_smart_editor/src/models/toolbar_settings.dart';
import 'package:flutter_smart_editor/src/models/enums.dart';
import 'package:flutter_smart_editor/src/models/image_insert.dart';
import 'package:flutter_smart_editor/src/models/image_size.dart';

/// Pumps an editable editor and returns the controller (dispose in-body).
Future<SmartEditorController> _pump(
  WidgetTester tester,
  SmartEditorSettings settings,
) async {
  final controller = SmartEditorController();
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SmartEditor(
        controller: controller,
        toolbarSettings: const SmartToolbarSettings(
          toolbarPosition: SmartToolbarPosition.custom,
        ),
        editorSettings: settings,
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  testWidgets('15. insertImage with no hook adds an ImageNode + trailing para',
      (tester) async {
    final controller = await _pump(tester, const SmartEditorSettings());
    await controller.insertImage(
        const ImageInsertRequest(src: 'u', origin: ImageInsertSource.toolbar));
    await tester.pumpAndSettle();

    final imgs = controller.document.blocks.whereType<ImageNode>().toList();
    expect(imgs.length, 1);
    expect(imgs.single.src, 'u');
    // trailing empty paragraph after the image so the caret can continue
    final imgIndex = controller.document.blocks.indexOf(imgs.single);
    expect(controller.document.blocks[imgIndex + 1], isA<ParagraphNode>());

    final html = await controller.getText();
    expect(html, contains('<img src="u"'));
    controller.dispose();
  });

  testWidgets('16. onImageInsert swaps the stored src', (tester) async {
    final controller = await _pump(
      tester,
      SmartEditorSettings(
        onImageInsert: (req) async =>
            const ImageInsertResult(src: 'https://cdn/swapped.png'),
      ),
    );
    await controller.insertImage(const ImageInsertRequest(
        src: 'original', origin: ImageInsertSource.toolbar));
    await tester.pumpAndSettle();

    final html = await controller.getText();
    expect(html, contains('https://cdn/swapped.png'));
    expect(html, isNot(contains('"original"')));
    controller.dispose();
  });

  testWidgets('16. onImageInsert returning null cancels the insert',
      (tester) async {
    final controller = await _pump(
      tester,
      SmartEditorSettings(onImageInsert: (req) async => null),
    );
    await controller.insertImage(const ImageInsertRequest(
        src: 'original', origin: ImageInsertSource.toolbar));
    await tester.pumpAndSettle();

    expect(controller.document.blocks.whereType<ImageNode>(), isEmpty);
    controller.dispose();
  });

  testWidgets('no hook + raw bytes embeds a base64 data URI', (tester) async {
    final controller = await _pump(tester, const SmartEditorSettings());
    await controller.insertImage(ImageInsertRequest(
      bytes: Uint8List.fromList(const [1, 2, 3, 4]),
      mimeType: 'image/png',
      origin: ImageInsertSource.paste,
    ));
    await tester.pumpAndSettle();
    final img = controller.document.blocks.whereType<ImageNode>().single;
    expect(img.src, startsWith('data:image/png;base64,'));
    expect(img.isDataUri, isTrue);
    controller.dispose();
  });

  test('byte paste embeds SVG/AVIF with the right MIME (consumer-handler bridge)',
      () async {
    // No hook → bytes become a data: URI carrying the source MIME, which is
    // exactly what an SVG/AVIF ImageFormatHandler keys on (isSvg/isAvif).
    final svg = await resolveImageInsert(
      ImageInsertRequest(
        bytes: Uint8List.fromList(const [60, 115, 118, 103]), // "<svg"
        mimeType: 'image/svg+xml',
        origin: ImageInsertSource.paste,
      ),
      null,
      null,
    );
    expect(svg!.src, startsWith('data:image/svg+xml;base64,'));

    final avif = await resolveImageInsert(
      ImageInsertRequest(
        bytes: Uint8List.fromList(const [0, 0, 0, 1]),
        mimeType: 'image/avif',
        origin: ImageInsertSource.paste,
      ),
      null,
      null,
    );
    expect(avif!.src, startsWith('data:image/avif;base64,'));
  });

  testWidgets('defaultImageWidth applies when the result declares none',
      (tester) async {
    final controller = await _pump(
      tester,
      const SmartEditorSettings(defaultImageWidth: ImageSize.percent(50)),
    );
    await controller.insertImage(const ImageInsertRequest(
        src: 'u', origin: ImageInsertSource.toolbar));
    await tester.pumpAndSettle();
    expect(controller.document.blocks.whereType<ImageNode>().single.width,
        const ImageSize.percent(50));
    controller.dispose();
  });

  testWidgets('17. resolveDataUris uploads-and-swaps embedded data URIs',
      (tester) async {
    final received = <String>[];
    final controller = await _pump(
      tester,
      SmartEditorSettings(
        resolveDataUris: true,
        initialText: '<img src="data:image/png;base64,iVBORw0KGgo=" alt="x">',
        onImageInsert: (req) async {
          received.add(req.origin.name);
          return const ImageInsertResult(src: 'https://cdn/uploaded.png');
        },
      ),
    );
    // Drive the post-parse async pass to completion.
    await controller.resolveDataUriImages();
    await tester.pumpAndSettle();

    final html = await controller.getText();
    expect(html, contains('https://cdn/uploaded.png'));
    expect(html, isNot(contains('data:image/png')));
    expect(received, contains('parse'));
    controller.dispose();
  });

  testWidgets('resolveDataUris off leaves data URIs untouched', (tester) async {
    var called = false;
    final controller = await _pump(
      tester,
      SmartEditorSettings(
        resolveDataUris: false,
        initialText: '<img src="data:image/png;base64,iVBORw0KGgo=">',
        onImageInsert: (req) async {
          called = true;
          return const ImageInsertResult(src: 'https://cdn/uploaded.png');
        },
      ),
    );
    await controller.resolveDataUriImages();
    await tester.pumpAndSettle();
    final html = await controller.getText();
    expect(html, contains('data:image/png'));
    expect(called, isFalse);
    controller.dispose();
  });
}
