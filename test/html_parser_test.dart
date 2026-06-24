import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_smart_editor/src/core/document/document.dart';
import 'package:flutter_smart_editor/src/core/infra/html_parser.dart';
import 'package:flutter_smart_editor/src/models/enums.dart';

void main() {
  late SmartHtmlParser parser;

  setUp(() {
    parser = SmartHtmlParser();
  });

  group('SmartHtmlParser', () {
    test('parses empty string into document with one empty paragraph', () {
      final doc = parser.parse('');
      expect(doc.blocks.length, 1);
      expect(doc.blocks[0], isA<ParagraphNode>());
      expect(doc.blocks[0].plainText, '');
    });

    test('parses null into document with one empty paragraph', () {
      final doc = parser.parse(null);
      expect(doc.blocks.length, 1);
    });

    test('parses a simple paragraph', () {
      final doc = parser.parse('<p>Hello World</p>');
      expect(doc.blocks.length, 1);
      expect(doc.blocks[0], isA<ParagraphNode>());
      expect(doc.blocks[0].plainText, 'Hello World');
    });

    test('parses multiple paragraphs', () {
      final doc = parser.parse('<p>First</p><p>Second</p><p>Third</p>');
      expect(doc.blocks.length, 3);
      expect(doc.blocks[0].plainText, 'First');
      expect(doc.blocks[1].plainText, 'Second');
      expect(doc.blocks[2].plainText, 'Third');
    });

    test('parses headings H1-H6', () {
      for (int i = 1; i <= 6; i++) {
        final doc = parser.parse('<h$i>Heading $i</h$i>');
        expect(doc.blocks.length, 1);
        expect(doc.blocks[0], isA<HeadingNode>());
        expect((doc.blocks[0] as HeadingNode).level, i);
        expect(doc.blocks[0].plainText, 'Heading $i');
      }
    });

    test('parses bold text', () {
      final doc = parser.parse('<p><b>Bold</b></p>');
      expect(doc.blocks[0].spans.length, 1);
      expect(doc.blocks[0].spans[0].isBold, true);
      expect(doc.blocks[0].spans[0].text, 'Bold');
    });

    test('parses italic text', () {
      final doc = parser.parse('<p><i>Italic</i></p>');
      expect(doc.blocks[0].spans[0].isItalic, true);
    });

    test('parses underline text', () {
      final doc = parser.parse('<p><u>Underline</u></p>');
      expect(doc.blocks[0].spans[0].isUnderline, true);
    });

    test('parses strikethrough text', () {
      final doc = parser.parse('<p><s>Strikethrough</s></p>');
      expect(doc.blocks[0].spans[0].isStrikethrough, true);
    });

    test('parses <strong> as bold', () {
      final doc = parser.parse('<p><strong>Strong</strong></p>');
      expect(doc.blocks[0].spans[0].isBold, true);
    });

    test('parses <em> as italic', () {
      final doc = parser.parse('<p><em>Emphasis</em></p>');
      expect(doc.blocks[0].spans[0].isItalic, true);
    });

    test('parses nested formatting: bold + italic', () {
      final doc = parser.parse('<p><b><i>BoldItalic</i></b></p>');
      expect(doc.blocks[0].spans[0].isBold, true);
      expect(doc.blocks[0].spans[0].isItalic, true);
    });

    test('parses mixed content: plain + bold + plain', () {
      final doc = parser.parse('<p>Hello <b>World</b> End</p>');
      expect(doc.blocks[0].spans.length, 3);
      expect(doc.blocks[0].spans[0].text, 'Hello ');
      expect(doc.blocks[0].spans[0].isBold, false);
      expect(doc.blocks[0].spans[1].text, 'World');
      expect(doc.blocks[0].spans[1].isBold, true);
      expect(doc.blocks[0].spans[2].text, ' End');
      expect(doc.blocks[0].spans[2].isBold, false);
    });

    test('parses text-align center style', () {
      final doc = parser.parse('<p style="text-align: center;">Centered</p>');
      expect(doc.blocks[0].alignment, SmartTextAlign.center);
    });

    test('parses link tag', () {
      final doc =
          parser.parse('<p><a href="https://google.com">Google</a></p>');
      expect(doc.blocks[0].spans[0].linkUrl, 'https://google.com');
      expect(doc.blocks[0].spans[0].text, 'Google');
    });

    test('parses div as paragraph', () {
      final doc = parser.parse('<div>In a div</div>');
      expect(doc.blocks.length, 1);
      expect(doc.blocks[0], isA<ParagraphNode>());
      expect(doc.blocks[0].plainText, 'In a div');
    });

    test('parses bare text as paragraph', () {
      final doc = parser.parse('Just some text');
      expect(doc.blocks.length, 1);
      expect(doc.blocks[0].plainText, 'Just some text');
    });
  });

  group('SmartHtmlParser - URL auto-detection', () {
    test('detects a bare https URL mid-sentence', () {
      final doc = parser.parse('<p>see https://x.com now</p>');
      final spans = doc.blocks[0].spans;
      expect(spans.length, 3);
      expect(spans[0].text, 'see ');
      expect(spans[0].linkUrl, isNull);
      expect(spans[1].text, 'https://x.com');
      expect(spans[1].linkUrl, 'https://x.com');
      expect(spans[2].text, ' now');
      expect(spans[2].linkUrl, isNull);
    });

    test('injects https scheme for www. URLs', () {
      final doc = parser.parse('<p>www.x.com</p>');
      expect(doc.blocks[0].spans[0].text, 'www.x.com');
      expect(doc.blocks[0].spans[0].linkUrl, 'https://www.x.com');
    });

    test('trims trailing sentence punctuation', () {
      final doc = parser.parse('<p>see https://x.com.</p>');
      final spans = doc.blocks[0].spans;
      expect(spans[1].text, 'https://x.com');
      expect(spans[1].linkUrl, 'https://x.com');
      expect(spans.last.text, '.');
      expect(spans.last.linkUrl, isNull);
    });

    test('excludes a closing parenthesis around the URL', () {
      final doc = parser.parse('<p>(https://x.com)</p>');
      final link = doc.blocks[0].spans.firstWhere((s) => s.linkUrl != null);
      expect(link.text, 'https://x.com');
      expect(link.linkUrl, 'https://x.com');
    });

    test('does not double-wrap an explicit <a> link', () {
      final doc = parser.parse('<p><a href="https://x.com">x</a></p>');
      final spans = doc.blocks[0].spans;
      expect(spans.length, 1);
      expect(spans[0].text, 'x');
      expect(spans[0].linkUrl, 'https://x.com');
    });

    test('preserves formatting on an auto-detected link', () {
      final doc = parser.parse('<p><b>https://x.com</b></p>');
      final span = doc.blocks[0].spans[0];
      expect(span.linkUrl, 'https://x.com');
      expect(span.isBold, true);
    });

    test('does nothing when autoDetectLinks is false', () {
      final off = SmartHtmlParser(autoDetectLinks: false);
      final doc = off.parse('<p>https://x.com</p>');
      expect(doc.blocks[0].spans.length, 1);
      expect(doc.blocks[0].spans[0].linkUrl, isNull);
    });

    test('containsUrl detects presence', () {
      expect(SmartHtmlParser.containsUrl('go to https://x.com'), true);
      expect(SmartHtmlParser.containsUrl('no links here'), false);
    });

    test('parsePlainText autolinks bare URLs', () {
      final doc = parser.parsePlainText('see https://x.com');
      final link = doc.blocks[0].spans.firstWhere((s) => s.linkUrl != null);
      expect(link.linkUrl, 'https://x.com');
    });

    test('parsePlainText leaves text plain when detection is off', () {
      final off = SmartHtmlParser(autoDetectLinks: false);
      final doc = off.parsePlainText('https://x.com');
      expect(doc.blocks[0].spans.length, 1);
      expect(doc.blocks[0].spans[0].linkUrl, isNull);
    });
  });
}
