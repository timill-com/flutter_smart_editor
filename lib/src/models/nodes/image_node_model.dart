import '../../core/document/document.dart';
import '../enums.dart';
import '../image_size.dart';

/// An image block (`<img>`), modeled as a non-text leaf block — mirrors
/// [HorizontalRuleNode]. It carries a single empty span so the base-class
/// span invariants (and `normalizeSpans`) hold, plus image-specific fields.
///
/// Alignment reuses the inherited [BlockNode.alignment]: images honour
/// left/center/right exactly like text blocks.
class ImageNode extends BlockNode {
  ImageNode({
    super.id,
    super.alignment,
    required this.src,
    this.alt = '',
    this.title,
    this.width,
    this.height,
    this.rawSvg,
    Map<String, String>? attributes,
  })  : attributes = attributes ?? <String, String>{},
        super(spans: [TextFormatSpan.plain('')]);

  /// URL or `data:` URI. Mutable — the upload hook ([onImageInsert]) and the
  /// resize affordance rewrite it / the sizing fields in place.
  String src;

  /// Alternative text (`alt`).
  String alt;

  /// Tooltip text (`title`).
  String? title;

  /// Display width. `null` = intrinsic.
  ImageSize? width;

  /// Display height. `null` = intrinsic.
  ImageSize? height;

  /// Verbatim `<svg>…</svg>` markup when this block was captured from inline
  /// SVG (see D-formats, Form 2). `null` for ordinary `<img>` images.
  String? rawSvg;

  /// All `<img>` attributes not promoted to a typed field above — e.g.
  /// `crossorigin`, `ismap`, `loading`, `longdesc`, `referrerpolicy`, `sizes`,
  /// `srcset`, `usemap`, plus any custom/`data-*` attribute. Preserved verbatim
  /// for round-trip fidelity; this package does not act on them (no WebView, so
  /// `referrerpolicy`/`crossorigin`/`loading` have no effect on `dart:ui`
  /// decoding). Keys are lower-cased attribute names. `src`, `alt`, `title`,
  /// `width`, `height`, and `style` are excluded — they live in typed fields.
  Map<String, String> attributes;

  /// Whether [src] is a `data:` URI (base64-embedded) rather than a URL.
  bool get isDataUri => src.startsWith('data:');

  @override
  String get tag => 'img';

  @override
  BlockType get blockType => BlockType.image;

  @override
  BlockNode deepCopy() => ImageNode(
        id: id,
        alignment: alignment,
        src: src,
        alt: alt,
        title: title,
        width: width,
        height: height,
        rawSvg: rawSvg,
        attributes: Map<String, String>.from(attributes),
      );
}
