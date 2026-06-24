import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

Future<SmartEditorController> _pump(
  WidgetTester tester, {
  required String html,
  SmartEditorSettings Function(SmartEditorSettings base)? configure,
  bool readOnly = true,
}) async {
  var settings = SmartEditorSettings(readOnly: readOnly, initialText: html);
  if (configure != null) settings = configure(settings);
  final controller = SmartEditorController();
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 400,
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
  // Image with an explicit size so it has a real long-press hit area.
  const sized = '<img src="$_png" alt="pic" width="160" height="100">';

  testWidgets('6. long-press opens the built-in viewer + fires a haptic',
      (tester) async {
    final haptics = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments as String? ?? 'vibrate');
        }
        return null;
      },
    );

    final controller = await _pump(tester, html: sized);
    expect(find.byType(InteractiveViewer), findsNothing);

    await tester.longPress(find.byType(Image));
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsOneWidget);
    // The medium-impact haptic was requested before opening.
    expect(haptics, contains('HapticFeedbackType.mediumImpact'));

    controller.dispose();
  });

  testWidgets('7. onImageLongPress override fires; no built-in viewer',
      (tester) async {
    ImageNode? pressed;
    final controller = await _pump(
      tester,
      html: sized,
      configure: (s) => SmartEditorSettings(
        readOnly: true,
        initialText: s.initialText,
        onImageLongPress: (node) => pressed = node,
      ),
    );

    await tester.longPress(find.byType(Image));
    await tester.pumpAndSettle();

    expect(pressed, isA<ImageNode>());
    expect(pressed!.alt, 'pic');
    expect(find.byType(InteractiveViewer), findsNothing);
    controller.dispose();
  });

  testWidgets('8. enableImagePreview:false → long-press does nothing',
      (tester) async {
    final controller = await _pump(
      tester,
      html: sized,
      configure: (s) => SmartEditorSettings(
        readOnly: true,
        initialText: s.initialText,
        enableImagePreview: false,
      ),
    );

    await tester.longPress(find.byType(Image));
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsNothing);
    controller.dispose();
  });

  testWidgets('9. viewer renders through a registered format handler',
      (tester) async {
    final matched = <String>[];
    final controller = await _pump(
      tester,
      html: '<img src="https://x/y.avif" alt="pic" width="160" height="100">',
      configure: (s) => SmartEditorSettings(
        readOnly: true,
        initialText: s.initialText,
        imageFormatHandlers: [
          ImageFormatHandler(
            matches: (c) => c.isAvif,
            build: (c) {
              matched.add('${c.src}|w=${c.width}|ro=${c.readOnly}');
              // Size it so it has a real long-press hit area; full-screen
              // (width null) falls back to a fixed box.
              return SizedBox(
                key: const ValueKey('avif-handled'),
                width: c.width ?? 200,
                height: c.height ?? 200,
              );
            },
          ),
        ],
      ),
    );

    // Inline render already used the handler once.
    final inlineMatches = matched.length;
    expect(inlineMatches, greaterThan(0));

    await tester.longPress(find.byKey(const ValueKey('avif-handled')));
    await tester.pumpAndSettle();

    // The viewer (InteractiveViewer) rendered via the SAME handler ladder…
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(matched.length, greaterThan(inlineMatches));
    // …with full-screen geometry (width null) and readOnly true.
    expect(
      matched.any((m) => m.contains('w=null') && m.contains('ro=true')),
      isTrue,
      reason: 'viewer should build ctx with width:null, readOnly:true',
    );
    expect(find.byType(Image), findsNothing); // built-in Image not used
    controller.dispose();
  });

  testWidgets('10. dismiss: tapping the close button pops the viewer',
      (tester) async {
    final controller = await _pump(tester, html: sized);
    await tester.longPress(find.byType(Image));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
    // Editor still intact.
    expect(find.byType(Image), findsOneWidget);
    controller.dispose();
  });

  testWidgets('10. dismiss: system back pops the viewer', (tester) async {
    final controller = await _pump(tester, html: sized);
    await tester.longPress(find.byType(Image));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);

    // Simulate the Android system back button.
    final widgetsBinding = tester.binding;
    await widgetsBinding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
    controller.dispose();
  });

  testWidgets('preview also works in edit mode (gated by enableImagePreview)',
      (tester) async {
    final controller = await _pump(tester, html: sized, readOnly: false);
    await tester.longPress(find.byType(Image));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    controller.dispose();
  });
}
