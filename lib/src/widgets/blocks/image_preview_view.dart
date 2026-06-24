import 'package:flutter/material.dart';
import '../../models/editor_settings.dart';
import '../../models/image_render.dart';
import '../../models/nodes/image_node_model.dart';
import 'image_resolver.dart';

/// Hero tag shared by the inline image and its full-screen preview, so the
/// transition flies the same image. Stable per block via [ImageNode.id].
String imagePreviewHeroTag(ImageNode node) => 'smart_image_${node.id}';

/// Opens the built-in full-screen image preview (lightbox) for [node]: a dark
/// scrim with a pinch-zoom / pan [InteractiveViewer] and a [Hero] transition.
/// Dismissed by tapping the scrim, the ✕ button, system back, or a swipe down.
///
/// Built entirely from Flutter SDK widgets (zero dependency, codec-free): the
/// pixels come from the same [resolveImageWidget] ladder as the inline image,
/// so registered AVIF/SVG handlers and `imageProvider` images zoom too (D-B3).
Future<void> showImagePreview(
  BuildContext context, {
  required ImageNode node,
  required SmartEditorSettings settings,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) =>
          ImagePreviewView(node: node, settings: settings),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

/// The full-screen viewer route content. Public so it's testable in isolation.
class ImagePreviewView extends StatelessWidget {
  const ImagePreviewView({
    super.key,
    required this.node,
    required this.settings,
  });

  final ImageNode node;
  final SmartEditorSettings settings;

  @override
  Widget build(BuildContext context) {
    final decoded = node.isDataUri ? decodeImageDataUri(node.src) : null;

    // Full-screen geometry: let InteractiveViewer + BoxFit.contain use all the
    // space (no fixed width/height), and render in a dark context.
    final ctx = ImageRenderContext(
      node: node,
      src: node.src,
      bytes: decoded?.bytes,
      rawSvg: node.rawSvg,
      mimeType: decoded?.mime,
      width: null,
      height: null,
      fit: BoxFit.contain,
      readOnly: true,
    );

    final image = resolveImageWidget(
      settings: settings,
      ctx: ctx,
      isDarkMode: true,
      onError: settings.onImageError,
    );

    void dismiss() {
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: dismiss,
        // Swipe down to dismiss (a fling beyond the image's pan range).
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) > 300) dismiss();
        },
        child: Container(
          color: Colors.black.withValues(alpha: 0.9),
          child: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: Hero(
                    tag: imagePreviewHeroTag(node),
                    child: InteractiveViewer(
                      minScale: 1.0,
                      maxScale: settings.imagePreviewMaxScale,
                      boundaryMargin: const EdgeInsets.all(64),
                      child: image,
                    ),
                  ),
                ),
                if (node.alt.isNotEmpty)
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: IgnorePointer(
                      child: Text(
                        node.alt,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    tooltip: 'Close',
                    onPressed: dismiss,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
