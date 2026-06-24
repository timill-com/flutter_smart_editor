import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_smart_editor/smart_editor.dart';
import 'package:flutter_smart_editor/smart_editor_controller.dart';
import 'package:flutter_smart_editor/src/models/editor_settings.dart';
import 'package:flutter_smart_editor/src/models/toolbar_settings.dart';
import 'package:flutter_smart_editor/src/models/enums.dart';
import 'package:flutter_smart_editor/src/models/image_render.dart';
import 'package:flutter_smart_editor/src/models/nodes/image_node_model.dart';

// A valid 1x1 transparent PNG.
const _png =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

/// Pumps a read-only editor and returns its controller. The caller MUST call
/// `controller.dispose()` inside the test body (before teardown) so the
/// controller's periodic clipboard timer is cancelled before the framework's
/// pending-timer invariant check runs.
Future<SmartEditorController> _pump(
  WidgetTester tester, {
  required String html,
  SmartEditorSettings Function(SmartEditorSettings base)? configure,
  double width = 400,
}) async {
  var settings = SmartEditorSettings(readOnly: true, initialText: html);
  if (configure != null) settings = configure(settings);
  final controller = SmartEditorController();
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: SmartEditor(
            controller: controller,
            toolbarSettings: const SmartToolbarSettings(
              toolbarPosition: SmartToolbarPosition.custom,
            ),
            editorSettings: settings,
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  testWidgets('12. valid data: PNG renders an Image', (tester) async {
    final controller = await _pump(tester, html: '<img src="$_png">');
    expect(find.byType(Image), findsOneWidget);
    expect(find.byIcon(Icons.broken_image_outlined), findsNothing);
    controller.dispose();
  });

  testWidgets('12. malformed data URI shows placeholder + fires onImageError',
      (tester) async {
    Object? errored;
    ImageNode? erroredNode;
    final controller = await _pump(
      tester,
      html: '<img src="data:image/png;base64,@@@not-base64@@@" alt="oops">',
      configure: (s) => SmartEditorSettings(
        readOnly: true,
        initialText: s.initialText,
        onImageError: (node, e) {
          erroredNode = node;
          errored = e;
        },
      ),
    );
    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    expect(find.text('oops'), findsOneWidget);
    expect(errored, isNotNull);
    expect(erroredNode, isA<ImageNode>());
    controller.dispose();
  });

  // The AVIF handler matches `ctx.isAvif` and renders a keyed sentinel.
  List<ImageFormatHandler> avifHandlers(List<String> matchedSrcs) => [
        ImageFormatHandler(
          matches: (c) => c.isAvif,
          build: (c) {
            matchedSrcs.add(c.src);
            return const SizedBox(key: ValueKey('avif-handled'));
          },
        ),
      ];

  testWidgets('12b. format handler fires for an AVIF URL', (tester) async {
    final matched = <String>[];
    final controller = await _pump(
      tester,
      html: '<img src="https://x/y.avif">',
      configure: (s) => SmartEditorSettings(
        readOnly: true,
        initialText: s.initialText,
        imageFormatHandlers: avifHandlers(matched),
      ),
    );
    expect(find.byKey(const ValueKey('avif-handled')), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    controller.dispose();
  });

  testWidgets('12b. format handler fires for a base64 AVIF (ctx.bytes path)',
      (tester) async {
    final matched = <String>[];
    final controller = await _pump(
      tester,
      html: '<img src="data:image/avif;base64,AAAA">',
      configure: (s) => SmartEditorSettings(
        readOnly: true,
        initialText: s.initialText,
        imageFormatHandlers: avifHandlers(matched),
      ),
    );
    expect(find.byKey(const ValueKey('avif-handled')), findsOneWidget);
    controller.dispose();
  });

  testWidgets('12b. AVIF handler is NOT invoked for a PNG (falls to built-in)',
      (tester) async {
    final matched = <String>[];
    final controller = await _pump(
      tester,
      html: '<img src="$_png">',
      configure: (s) => SmartEditorSettings(
        readOnly: true,
        initialText: s.initialText,
        imageFormatHandlers: avifHandlers(matched),
      ),
    );
    expect(find.byKey(const ValueKey('avif-handled')), findsNothing);
    expect(find.byType(Image), findsOneWidget);
    expect(matched, isEmpty);
    controller.dispose();
  });

  testWidgets('13. percent width lays out at the expected fraction',
      (tester) async {
    // Two images in the same editor: 50% and 100% of the same available width.
    final controller = await _pump(
      tester,
      html: '<img src="$_png" style="width:50%"><img src="$_png" style="width:100%">',
    );
    final imgs = tester.widgetList<Image>(find.byType(Image)).toList();
    expect(imgs.length, 2);
    final w50 = imgs[0].width!;
    final w100 = imgs[1].width!;
    expect(w50 / w100, closeTo(0.5, 0.001));
    controller.dispose();
  });

  testWidgets('14. tapping an image fires onImageTap with the node',
      (tester) async {
    ImageNode? tapped;
    final controller = await _pump(
      tester,
      // Explicit size so there's a real hit area (a 1×1 intrinsic image isn't
      // tappable).
      html: '<img src="$_png" alt="pic" width="120" height="80">',
      configure: (s) => SmartEditorSettings(
        readOnly: true,
        initialText: s.initialText,
        onImageTap: (node) => tapped = node,
      ),
    );
    await tester.tap(find.byType(Image));
    await tester.pump();
    expect(tapped, isA<ImageNode>());
    expect(tapped!.alt, 'pic');
    controller.dispose();
  });
}
