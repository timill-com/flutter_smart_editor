import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_smart_editor/flutter_smart_editor.dart';

/// Demonstrates the image feature end-to-end — insert (toolbar/URL dialog),
/// paste, base64 `data:` rendering, the upload/swap hook, px/% resize, and the
/// pluggable format-handler API.
///
/// This page runs with **no extra dependencies**: it renders the built-in
/// formats (JPEG/PNG/WebP/GIF/BMP) and shows the handler mechanism with a
/// dependency-free demo handler. The commented [_avifSvgHandlers] block below
/// is the real AVIF/SVG wiring — copy it into your app after adding
/// `flutter_avif` / `flutter_svg` to your pubspec.
class ImageDemoPage extends StatefulWidget {
  const ImageDemoPage({super.key});

  @override
  State<ImageDemoPage> createState() => _ImageDemoPageState();
}

class _ImageDemoPageState extends State<ImageDemoPage> {
  final SmartEditorController controller = SmartEditorController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Image demo')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SmartEditor(
          controller: controller,
          editorSettings: SmartEditorSettings(
            initialText: '<p>Tap the image to select it, then drag its '
                'bottom-right handle to resize (or use the corner menu). '
                'Tap-and-hold any image to open the full-screen viewer.</p>'
                '<img src="https://flutter.github.io/assets-for-api-docs/assets/widgets/owl.jpg" '
                'alt="An owl" width="320">',

            // ── Sizing ──────────────────────────────────────────────
            // Resize shows BOTH the corner menu and a freehand drag handle on
            // a tap-selected image. Drag stores `%` for cross-platform
            // proportional consistency; the serializer also caps every image
            // at `max-width: 100%` so nothing overflows a narrower viewport.
            allowImageResize: true,
            maxImageWidth: 600,
            defaultImageWidth: const ImageSize.percent(100),

            // ── Read-only preview / lightbox ────────────────────────
            // Long-press an image → haptic → full-screen pinch-zoom / pan
            // viewer (default on). Set onImageLongPress to fully override it.
            enableImagePreview: true,
            imagePreviewMaxScale: 5.0,
            // onImageLongPress: (node) => developer.log('long-press ${node.src}'),

            // ── Toolbar picker: returns a request for the URL dialog path,
            //    or wire image_picker/file_picker here in a real app. Returning
            //    null falls back to the built-in "image URL" dialog. ─────────
            // onImagePickRequested: () async => ImageInsertRequest(
            //   bytes: await pickBytes(), mimeType: 'image/jpeg',
            //   origin: ImageInsertSource.toolbar),

            // ── The upload/swap hook. Here we just echo the source; in a real
            //    app, upload req.bytes / req.src and return the CDN URL. ──────
            onImageInsert: (req) async {
              developer.log('onImageInsert: origin=${req.origin.name} '
                  'src=${req.src} bytes=${req.bytes?.length} mime=${req.mimeType}');
              if (req.src != null) return ImageInsertResult(src: req.src!);
              return null; // (bytes-only with no uploader → cancel in this demo)
            },

            onImageTap: (node) => developer.log('tapped image: ${node.src}'),
            onImageError: (node, e) => developer.log('image error: $e'),

            // ── Format handlers. The demo handler below is dependency-free and
            //    only illustrates the API; swap in [_avifSvgHandlers] for real
            //    AVIF/SVG support. ───────────────────────────────────────────
            imageFormatHandlers: _demoHandlers,
          ),
        ),
      ),
    );
  }
}

/// A dependency-free illustration of the handler API: renders a labeled box for
/// any AVIF/SVG image so you can see `matches`/`build`/`ctx` in action without
/// adding a codec. Replace with [_avifSvgHandlers] in a real app.
final List<ImageFormatHandler> _demoHandlers = [
  ImageFormatHandler(
    matches: (c) => c.isAvif || c.isSvg,
    build: (c) => Container(
      width: c.width ?? 200,
      height: c.height ?? 120,
      color: Colors.indigo.shade50,
      alignment: Alignment.center,
      child: Text('${c.isAvif ? 'AVIF' : 'SVG'} → register a real handler'),
    ),
  ),
];

// ── The real AVIF + SVG wiring ──────────────────────────────────────────────
// Copy into your app after adding to pubspec:
//
//   dependencies:
//     flutter_avif: ^x.y.z
//     flutter_svg: ^x.y.z
//
//   import 'package:flutter_avif/flutter_avif.dart';
//   import 'package:flutter_svg/flutter_svg.dart';
//
//   final List<ImageFormatHandler> avifSvgHandlers = [
//     // AVIF — render-side only, no parser flag needed.
//     ImageFormatHandler(
//       matches: (c) => c.isAvif,
//       build: (c) => c.bytes != null
//           ? AvifImage.memory(c.bytes!, width: c.width, height: c.height, fit: c.fit)
//           : AvifImage.network(c.src, width: c.width, height: c.height, fit: c.fit),
//     ),
//     // SVG — registering this auto-enables inline-<svg> capture (parseInlineSvg
//     // resolves true because `matches` keys off ctx.isSvg).
//     ImageFormatHandler(
//       matches: (c) => c.isSvg,
//       build: (c) {
//         if (c.rawSvg != null) return SvgPicture.string(c.rawSvg!, width: c.width, height: c.height);
//         if (c.bytes  != null) return SvgPicture.memory(c.bytes!, width: c.width, height: c.height);
//         return SvgPicture.network(c.src, width: c.width, height: c.height);
//       },
//     ),
//   ];
