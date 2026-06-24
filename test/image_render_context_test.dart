import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_smart_editor/src/models/image_render.dart';
import 'package:flutter_smart_editor/src/models/nodes/image_node_model.dart';

void main() {
  ImageRenderContext ctx({String src = '', String? mime}) =>
      ImageRenderContext(node: ImageNode(src: src), src: src, mimeType: mime);

  group('ImageRenderContext.isSvg / isAvif sniffing', () {
    test('by MIME type', () {
      expect(ctx(mime: 'image/svg+xml').isSvg, isTrue);
      expect(ctx(mime: 'image/avif').isAvif, isTrue);
      expect(ctx(mime: 'image/png').isSvg, isFalse);
      expect(ctx(mime: 'image/png').isAvif, isFalse);
    });

    test('by file extension', () {
      expect(ctx(src: 'https://x/y.svg').isSvg, isTrue);
      expect(ctx(src: 'https://x/y.svgz').isSvg, isTrue);
      expect(ctx(src: 'https://x/y.avif').isAvif, isTrue);
      expect(ctx(src: 'https://x/y.png').isSvg, isFalse);
      expect(ctx(src: 'https://x/y.png').isAvif, isFalse);
    });

    test('extension survives a query string / fragment', () {
      expect(ctx(src: 'https://x/y.svg?v=2').isSvg, isTrue);
      expect(ctx(src: 'https://x/y.avif?cache=1#frag').isAvif, isTrue);
    });

    test('data: URIs rely on MIME, not extension', () {
      expect(ctx(src: 'data:image/svg+xml,<svg/>', mime: 'image/svg+xml').isSvg,
          isTrue);
      // A data URI with no MIME and no extension is neither.
      expect(ctx(src: 'data:,abc').isSvg, isFalse);
    });
  });
}
