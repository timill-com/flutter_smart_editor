import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_smart_editor/smart_editor.dart';
import 'package:flutter_smart_editor/smart_editor_controller.dart';
import 'package:flutter_smart_editor/src/models/editor_settings.dart';
import 'package:flutter_smart_editor/src/models/toolbar_settings.dart';
import 'package:flutter_smart_editor/src/models/enums.dart';

void main() {
  testWidgets(
      'read-only link: tap opens, long-press copies to clipboard + fires callback',
      (tester) async {
    final controller = SmartEditorController();
    String? tapped;
    String? longPressed;
    final copied = <String>[];

    // Capture Clipboard.setData platform calls.
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SmartEditor(
          controller: controller,
          // No toolbar keeps the tree simple and SelectableText unique.
          toolbarSettings: const SmartToolbarSettings(
            toolbarPosition: SmartToolbarPosition.custom,
          ),
          editorSettings: SmartEditorSettings(
            readOnly: true,
            initialText: '<p><a href="https://x.com">https://x.com</a></p>',
            onLinkTap: (url) => tapped = url,
            onLinkLongPress: (url) => longPressed = url,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final linkFinder = find.textContaining('x.com', findRichText: true);
    expect(linkFinder, findsOneWidget);

    // Aim near the start of the (left-aligned) text — the block fills the full
    // width, so its center would be in empty space past the short link.
    final onText = tester.getTopLeft(linkFinder) + const Offset(20, 10);

    // Tap → opens the link.
    await tester.tapAt(onText);
    await tester.pump();
    expect(tapped, 'https://x.com');

    // Long-press → copies to clipboard and fires the callback.
    await tester.longPressAt(onText);
    await tester.pump();
    expect(longPressed, 'https://x.com');
    expect(copied, contains('https://x.com'));

    controller.dispose();
  });
}
