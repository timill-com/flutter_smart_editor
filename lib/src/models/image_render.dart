import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'nodes/image_node_model.dart';

/// What the render hooks ([SmartEditorSettings.imageProvider] /
/// [SmartEditorSettings.imageFormatHandlers]) receive. The package has already
/// resolved display geometry and decoded `data:` bytes, so a host handler only
/// decides *how* to turn the source into pixels.
class ImageRenderContext {
  ImageRenderContext({
    required this.node,
    required this.src,
    this.bytes,
    this.rawSvg,
    this.mimeType,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.readOnly = false,
  });

  /// The image block being rendered.
  final ImageNode node;

  /// The stored source — a URL or a `data:` URI.
  final String src;

  /// Decoded bytes when [src] is a `data:` URI (so base64-embedded AVIF/SVG
  /// work through a memory-based handler). `null` for URL sources.
  final Uint8List? bytes;

  /// Raw `<svg>` markup when the node came from inline SVG (Form 2). `null`
  /// otherwise.
  final String? rawSvg;

  /// MIME type sniffed from a `data:` prefix, when known. `null` for URLs
  /// (use [isSvg]/[isAvif], which also consult the file extension).
  final String? mimeType;

  /// Resolved display width in px (`%` already applied), or null for intrinsic.
  final double? width;

  /// Resolved display height in px, or null for intrinsic.
  final double? height;

  /// How the image should fit its box.
  final BoxFit fit;

  /// Whether the editor is in read-only mode.
  final bool readOnly;

  /// File extension of [src] (query string / fragment stripped, lower-cased),
  /// or `''` for `data:` URIs and extension-less URLs.
  String get _ext {
    if (src.startsWith('data:')) return '';
    var s = src;
    final q = s.indexOf('?');
    if (q >= 0) s = s.substring(0, q);
    final h = s.indexOf('#');
    if (h >= 0) s = s.substring(0, h);
    final dot = s.lastIndexOf('.');
    if (dot < 0 || dot == s.length - 1) return '';
    return s.substring(dot + 1).toLowerCase();
  }

  /// True when this image is an SVG (by MIME or extension).
  bool get isSvg =>
      mimeType == 'image/svg+xml' || _ext == 'svg' || _ext == 'svgz';

  /// True when this image is an AVIF (by MIME or extension).
  bool get isAvif =>
      mimeType == 'image/avif' || _ext == 'avif' || _ext == 'avifs';
}

/// A pluggable renderer for one image family (AVIF, SVG, Lottie, …). Lives in
/// *consumer* code, so the package never imports a codec. The first handler
/// whose [matches] is true renders the image via [build]. Registered through
/// [SmartEditorSettings.imageFormatHandlers].
class ImageFormatHandler {
  const ImageFormatHandler({required this.matches, required this.build});

  /// Returns true when this handler should render [ctx].
  final bool Function(ImageRenderContext ctx) matches;

  /// Produces the pixels for [ctx]. The package owns the surrounding chrome
  /// (alignment, sizing, tap, error placeholder).
  final Widget Function(ImageRenderContext ctx) build;
}

/// Resolves the tri-state `parseInlineSvg` flag to a concrete bool used by the
/// parser. Explicit `true`/`false` always wins; `null` (auto) probes [handlers]
/// with a representative SVG context and enables capture iff one matches —
/// so registering an SVG handler turns inline-`<svg>` capture on for free.
///
/// Contract: an SVG handler must key its `matches` off `ctx.isSvg` for the
/// probe to detect it (the recommended snippet does).
bool resolveParseInlineSvg(bool? flag, List<ImageFormatHandler> handlers) {
  if (flag != null) return flag;
  final probe = ImageRenderContext(
    node: ImageNode(src: 'probe.svg'),
    src: 'probe.svg',
    mimeType: 'image/svg+xml',
  );
  return handlers.any((h) => h.matches(probe));
}
