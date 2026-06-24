import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_smart_editor/src/core/document/document.dart';
import 'package:flutter_smart_editor/src/models/enums.dart';
import 'package:flutter_smart_editor/src/models/image_size.dart';

void main() {
  group('ImageSize', () {
    test('parse "200px" -> px 200', () {
      final s = ImageSize.parse('200px');
      expect(s, isNotNull);
      expect(s!.unit, ImageSizeUnit.px);
      expect(s.value, 200);
    });

    test('parse "50%" -> percent 50', () {
      final s = ImageSize.parse('50%');
      expect(s!.unit, ImageSizeUnit.percent);
      expect(s.value, 50);
    });

    test('parse "auto" -> auto', () {
      final s = ImageSize.parse('auto');
      expect(s!.unit, ImageSizeUnit.auto);
      expect(s.value, isNull);
    });

    test('parse bare numeric "200" -> px 200', () {
      final s = ImageSize.parse('200');
      expect(s!.unit, ImageSizeUnit.px);
      expect(s.value, 200);
    });

    test('parse handles whitespace and case', () {
      expect(ImageSize.parse('  200PX ')!.unit, ImageSizeUnit.px);
      expect(ImageSize.parse(' AUTO ')!.unit, ImageSizeUnit.auto);
    });

    test('parse junk -> null', () {
      expect(ImageSize.parse(''), isNull);
      expect(ImageSize.parse('abc'), isNull);
      expect(ImageSize.parse('px'), isNull);
      expect(ImageSize.parse('%'), isNull);
    });

    test('toCss round-trips', () {
      expect(const ImageSize.px(200).toCss(), '200px');
      expect(const ImageSize.percent(50).toCss(), '50%');
      expect(const ImageSize.auto().toCss(), 'auto');
    });

    test('parse(toCss()) is identity for px/percent/auto', () {
      for (final s in const [
        ImageSize.px(200),
        ImageSize.percent(50),
        ImageSize.auto(),
      ]) {
        expect(ImageSize.parse(s.toCss()), s);
      }
    });

    test('value equality', () {
      expect(const ImageSize.px(200), const ImageSize.px(200));
      expect(const ImageSize.px(200), isNot(const ImageSize.px(201)));
      expect(const ImageSize.px(50), isNot(const ImageSize.percent(50)));
    });
  });

  group('ImageNode', () {
    test('is a leaf BlockNode with a single empty span', () {
      final node = ImageNode(src: 'https://x/y.png');
      expect(node, isA<BlockNode>());
      expect(node.tag, 'img');
      expect(node.blockType, BlockType.image);
      expect(node.spans.length, 1);
      expect(node.spans.first.text, '');
      expect(node.textLength, 0);
    });

    test('isDataUri reflects the src', () {
      expect(ImageNode(src: 'https://x/y.png').isDataUri, isFalse);
      expect(
        ImageNode(src: 'data:image/png;base64,iVBORw0KGgo=').isDataUri,
        isTrue,
      );
    });

    test('deepCopy preserves all fields', () {
      final node = ImageNode(
        src: 'u',
        alt: 'alt',
        title: 'title',
        alignment: SmartTextAlign.center,
        width: const ImageSize.px(200),
        height: const ImageSize.percent(50),
      );
      final copy = node.deepCopy() as ImageNode;
      expect(copy.id, node.id);
      expect(copy.src, 'u');
      expect(copy.alt, 'alt');
      expect(copy.title, 'title');
      expect(copy.alignment, SmartTextAlign.center);
      expect(copy.width, const ImageSize.px(200));
      expect(copy.height, const ImageSize.percent(50));
    });

    test('rawSvg defaults to null and round-trips through deepCopy', () {
      final node = ImageNode(src: '', rawSvg: '<svg></svg>');
      expect(ImageNode(src: 'u').rawSvg, isNull);
      expect((node.deepCopy() as ImageNode).rawSvg, '<svg></svg>');
    });

    test('attributes defaults to an empty, mutable map', () {
      final node = ImageNode(src: 'u');
      expect(node.attributes, isEmpty);
      node.attributes['loading'] = 'lazy';
      expect(node.attributes['loading'], 'lazy');
    });

    test('deepCopy clones attributes independently', () {
      final node = ImageNode(
        src: 'u',
        attributes: {'loading': 'lazy', 'srcset': 'a 1x, b 2x'},
      );
      final copy = node.deepCopy() as ImageNode;
      expect(copy.attributes, {'loading': 'lazy', 'srcset': 'a 1x, b 2x'});
      copy.attributes['loading'] = 'eager';
      // Mutating the copy must not leak back into the original.
      expect(node.attributes['loading'], 'lazy');
    });
  });
}
