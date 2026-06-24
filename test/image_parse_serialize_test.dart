import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_smart_editor/src/core/document/document.dart';
import 'package:flutter_smart_editor/src/core/infra/html_parser.dart';
import 'package:flutter_smart_editor/src/core/infra/html_serializer.dart';
import 'package:flutter_smart_editor/src/models/enums.dart';
import 'package:flutter_smart_editor/src/models/image_size.dart';

void main() {
  late SmartHtmlParser parser;
  late SmartHtmlSerializer serializer;

  setUp(() {
    parser = SmartHtmlParser();
    serializer = SmartHtmlSerializer();
  });

  ImageNode onlyImage(Document doc) =>
      doc.blocks.whereType<ImageNode>().single;

  group('parse <img>', () {
    test('1. basic src + alt, no sizing', () {
      final doc = parser.parse('<img src="https://x/y.png" alt="hi">');
      final img = onlyImage(doc);
      expect(img.src, 'https://x/y.png');
      expect(img.alt, 'hi');
      expect(img.width, isNull);
      expect(img.height, isNull);
    });

    test('2. px attributes', () {
      final img = onlyImage(
          parser.parse('<img src="u" width="200" height="100">'));
      expect(img.width, const ImageSize.px(200));
      expect(img.height, const ImageSize.px(100));
    });

    test('3. percent via style', () {
      final img = onlyImage(parser.parse('<img src="u" style="width:50%">'));
      expect(img.width, const ImageSize.percent(50));
    });

    test('4. style beats attribute', () {
      final img = onlyImage(
          parser.parse('<img src="u" width="200" style="width:50%">'));
      expect(img.width, const ImageSize.percent(50));
    });

    test('5. data URI preserved verbatim', () {
      const data = 'data:image/png;base64,iVBORw0KGgo=';
      final img = onlyImage(parser.parse('<img src="$data">'));
      expect(img.src, data);
      expect(img.isDataUri, isTrue);
    });

    test('6. inline <img> promoted to its own block', () {
      final doc = parser.parse('<p>before <img src="u"> after</p>');
      expect(doc.blocks.length, 3);
      expect(doc.blocks[0], isA<ParagraphNode>());
      expect(doc.blocks[0].plainText.trim(), 'before');
      expect(doc.blocks[1], isA<ImageNode>());
      expect((doc.blocks[1] as ImageNode).src, 'u');
      expect(doc.blocks[2], isA<ParagraphNode>());
      expect(doc.blocks[2].plainText.trim(), 'after');
    });

    test('7. src-less <img> is dropped, no throw', () {
      final doc = parser.parse('<img alt="x">');
      expect(doc.blocks.whereType<ImageNode>(), isEmpty);
    });

    test('center alignment parsed from margin:0 auto', () {
      final img = onlyImage(parser.parse(
          '<img src="u" style="display:block;margin:0 auto">'));
      expect(img.alignment, SmartTextAlign.center);
    });

    test('all non-typed attributes round-trip into the bag', () {
      final img = onlyImage(parser.parse(
          '<img src="u" alt="a" loading="lazy" srcset="a 1x, b 2x" '
          'crossorigin="anonymous" ismap referrerpolicy="no-referrer">'));
      expect(img.attributes['loading'], 'lazy');
      expect(img.attributes['srcset'], 'a 1x, b 2x');
      expect(img.attributes['crossorigin'], 'anonymous');
      expect(img.attributes['referrerpolicy'], 'no-referrer');
      expect(img.attributes.containsKey('ismap'), isTrue);
      // Typed attrs must NOT leak into the bag.
      expect(img.attributes.containsKey('src'), isFalse);
      expect(img.attributes.containsKey('alt'), isFalse);
    });
  });

  group('serialize <img>', () {
    test('8. round-trip basic + px width, self-closing', () {
      final doc =
          parser.parse('<img src="https://x/y.png" alt="hi" width="200">');
      final html = serializer.serialize(doc);
      expect(html,
          '<img src="https://x/y.png" alt="hi" width="200" style="width: 200px"/>');
    });

    test('9. percent width round-trips', () {
      final doc = parser.parse('<img src="u" style="width:50%">');
      final html = serializer.serialize(doc);
      expect(html, contains('style="width: 50%"'));
      // re-parse to the same size
      expect(onlyImage(parser.parse(html)).width, const ImageSize.percent(50));
    });

    test('center alignment round-trips', () {
      final doc = parser
          .parse('<img src="u" style="display:block;margin:0 auto">');
      final html = serializer.serialize(doc);
      expect(html, contains('margin: 0 auto'));
      expect(onlyImage(parser.parse(html)).alignment, SmartTextAlign.center);
    });

    test('preserved attributes are re-emitted', () {
      final doc = parser
          .parse('<img src="u" loading="lazy" srcset="a 1x, b 2x">');
      final html = serializer.serialize(doc);
      expect(html, contains('loading="lazy"'));
      expect(html, contains('srcset="a 1x, b 2x"'));
    });

    test('10. onTagSerialize override wins for SmartTagType.image', () {
      final s = SmartHtmlSerializer(
        onTagSerialize: (type, tag, attrs, styles, content) =>
            type == SmartTagType.image ? '<custom-img/>' : null,
      );
      final doc = parser.parse('<img src="u">');
      expect(s.serialize(doc), '<custom-img/>');
    });
  });

  group('12c. inline SVG, tri-state parseInlineSvg', () {
    const svgHtml = '<p>x <svg viewBox="0 0 1 1"><path/></svg></p>';

    test('(a) no handler + unset -> dropped', () {
      final doc = SmartHtmlParser(parseInlineSvg: false).parse(svgHtml);
      expect(doc.blocks.whereType<ImageNode>(), isEmpty);
    });

    test('(b/d) capture enabled -> rawSvg captured + re-emitted verbatim', () {
      final doc = SmartHtmlParser(parseInlineSvg: true).parse(svgHtml);
      final img = doc.blocks.whereType<ImageNode>().single;
      expect(img.rawSvg, isNotNull);
      expect(img.rawSvg, contains('svg'));
      expect(img.rawSvg, contains('path'));
      // Serialize re-emits the raw <svg> verbatim, not rewritten to <img>.
      final html = serializer.serialize(doc);
      expect(html, contains(img.rawSvg!));
      expect(html, isNot(contains('<img')));
    });

    test('(c) disabled -> dropped even with markup present', () {
      final doc = SmartHtmlParser(parseInlineSvg: false).parse(svgHtml);
      expect(serializer.serialize(doc), isNot(contains('<svg')));
    });
  });
}
