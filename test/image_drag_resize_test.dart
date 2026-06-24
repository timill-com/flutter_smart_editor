import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_smart_editor/smart_editor.dart';
import 'package:flutter_smart_editor/smart_editor_controller.dart';
import 'package:flutter_smart_editor/src/models/editor_settings.dart';
import 'package:flutter_smart_editor/src/models/toolbar_settings.dart';
import 'package:flutter_smart_editor/src/models/enums.dart';
import 'package:flutter_smart_editor/src/models/image_size.dart';
import 'package:flutter_smart_editor/src/models/nodes/image_node_model.dart';

// A valid 1x1 transparent PNG.
const _png =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

// Stable key the drag handle carries (block_widget.dart).
const _handleKey = ValueKey('imageDragHandle');

Future<SmartEditorController> _pump(
  WidgetTester tester, {
  required String html,
  bool allowImageResize = true,
  bool readOnly = false,
  double width = 400,
}) async {
  final controller = SmartEditorController();
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: width,
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

int _idx(SmartEditorController c) => c.document.blocks.indexOf(_img(c));

double _imageWidth(WidgetTester tester) =>
    tester.widget<Image>(find.byType(Image)).width!;

/// Selects the image (tap-to-select) so the drag handle appears.
Future<void> _select(WidgetTester tester) async {
  await tester.tap(find.byType(Image));
  await tester.pumpAndSettle();
}

/// Grabs the drag handle and performs an arming move. Inside the editor's
/// scrollable, the first pointer move after pointer-down resolves the gesture
/// arena and fires `onPanStart` (consumed, no delta); subsequent moves report
/// full 1:1 deltas. The arm must exceed the pan slop (~36px), so we move 40px
/// in [armDx]'s direction, then callers issue precise drag deltas.
Future<TestGesture> _grabHandle(WidgetTester tester, {double armDx = 40}) async {
  final g = await tester.startGesture(tester.getCenter(find.byKey(_handleKey)));
  await g.moveBy(Offset(armDx, 0)); // arming move (consumed)
  await tester.pump();
  return g;
}

/// Resizes to 100% and returns the resulting rendered px width — the available
/// container width, so tests can self-calibrate without hardcoding padding.
/// Keeps the existing height so the image stays a real (tappable) box.
Future<double> _availWidth(
    WidgetTester tester, SmartEditorController c) async {
  c.resizeImage(_idx(c),
      width: const ImageSize.percent(100), height: _img(c).height);
  await tester.pumpAndSettle();
  return _imageWidth(tester);
}

void main() {
  group('drag handle visibility', () {
    testWidgets('5. hidden until the image is selected', (tester) async {
      final controller = await _pump(tester,
          html: '<img src="$_png" width="200" height="120">');
      expect(find.byKey(_handleKey), findsNothing);
      await _select(tester);
      expect(find.byKey(_handleKey), findsOneWidget);
      // Deselect on a second tap.
      await tester.tap(find.byType(Image));
      await tester.pumpAndSettle();
      expect(find.byKey(_handleKey), findsNothing);
      controller.dispose();
    });

    testWidgets('5. hidden in read-only mode', (tester) async {
      final controller = await _pump(tester,
          html: '<img src="$_png" width="200" height="120">',
          readOnly: true);
      // Can't even select in read-only.
      await tester.tap(find.byType(Image));
      await tester.pumpAndSettle();
      expect(find.byKey(_handleKey), findsNothing);
      controller.dispose();
    });

    testWidgets('5. hidden when allowImageResize is false', (tester) async {
      final controller = await _pump(tester,
          html: '<img src="$_png" width="200" height="120">',
          allowImageResize: false);
      await tester.tap(find.byType(Image));
      await tester.pumpAndSettle();
      expect(find.byKey(_handleKey), findsNothing);
      controller.dispose();
    });
  });

  group('drag to resize', () {
    testWidgets(
        '1. drag grows width live; model updates only on pan end (one undo)',
        (tester) async {
      final controller = await _pump(tester,
          html: '<img src="$_png" width="120" height="80">');
      await _select(tester);

      final startW = _imageWidth(tester);
      expect(_img(controller).width, const ImageSize.px(120));

      final gesture = await _grabHandle(tester);
      await gesture.moveBy(const Offset(60, 0)); // real drag delta
      await tester.pump();

      // Live preview: rendered image grew, but the model is untouched.
      expect(_imageWidth(tester), greaterThan(startW));
      expect(_img(controller).width, const ImageSize.px(120));

      await gesture.up();
      await tester.pumpAndSettle();

      // Committed once: width changed and exactly one undo step recorded.
      expect(_img(controller).width, isNot(const ImageSize.px(120)));
      expect(controller.canUndo, isTrue);

      // 2. One undo step restores the prior size.
      controller.undo();
      await tester.pumpAndSettle();
      expect(_img(controller).width, const ImageSize.px(120));
      controller.dispose();
    });

    testWidgets('3. drag stores percent; ~half container → ~percent(50)',
        (tester) async {
      final controller =
          await _pump(tester, html: '<img src="$_png" width="120" height="80">');
      await _select(tester);

      final avail = await _availWidth(tester, controller); // now at 100%
      // Drag the handle left by half the available width → ~50%.
      final gesture = await _grabHandle(tester, armDx: -40);
      await gesture.moveBy(Offset(-avail / 2, 0));
      await tester.pump();

      // Live preview is ~half the container.
      final liveW = _imageWidth(tester);
      expect(liveW, closeTo(avail / 2, avail * 0.06));

      await gesture.up();
      await tester.pumpAndSettle();

      final w = _img(controller).width!;
      expect(w.unit, ImageSizeUnit.percent);
      // Committed percent reflects the actual live width, and is ~50%.
      expect(w.value!, closeTo(liveW / avail * 100, 2));
      expect(w.value!, closeTo(50, 6));
      controller.dispose();
    });

    testWidgets('3. drag near full width snaps to percent(100)',
        (tester) async {
      final controller =
          await _pump(tester, html: '<img src="$_png" width="140" height="90">');
      await _select(tester);

      final gesture = await _grabHandle(tester);
      await gesture.moveBy(const Offset(2000, 0)); // far past the edge
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(_img(controller).width, const ImageSize.percent(100));
      controller.dispose();
    });

    testWidgets('5. min clamp: drag far left floors width, never ≤0',
        (tester) async {
      final controller =
          await _pump(tester, html: '<img src="$_png" width="200" height="120">');
      await _select(tester);

      final gesture = await _grabHandle(tester, armDx: -40);
      await gesture.moveBy(const Offset(-2000, 0)); // far past the left edge
      await tester.pump();
      // Live preview clamps at the 32px floor, not a negative width.
      expect(_imageWidth(tester), 32);

      await gesture.up();
      await tester.pumpAndSettle();
      final w = _img(controller).width!;
      expect(w.unit, ImageSizeUnit.percent);
      expect(w.value!, greaterThan(0));
      controller.dispose();
    });
  });

  testWidgets('menu still works alongside the drag handle (D-A5)',
      (tester) async {
    final controller =
        await _pump(tester, html: '<img src="$_png" width="200" height="120">');
    // Menu is available without selecting.
    expect(find.byTooltip('Resize image'), findsOneWidget);
    await tester.tap(find.byTooltip('Resize image'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('50%').last);
    await tester.pumpAndSettle();
    expect(_img(controller).width, const ImageSize.percent(50));
    controller.dispose();
  });
}
