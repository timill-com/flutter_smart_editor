import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../models/editor_settings.dart';
import '../../models/image_render.dart';
import '../../models/nodes/image_node_model.dart';

/// Shared image-rendering helpers used by both the inline image block
/// ([BlockWidget]) and the full-screen preview viewer ([ImagePreviewView]), so
/// AVIF/SVG/handler/`imageProvider` images render identically in both places
/// (D-B3 — "the viewer must use the same resolution ladder").

/// Decodes a `data:` URI into bytes + MIME. Handles base64 and percent-encoded
/// payloads; returns null on malformed input (→ error placeholder).
({Uint8List bytes, String? mime})? decodeImageDataUri(String src) {
  try {
    final comma = src.indexOf(',');
    if (comma < 0) return null;
    final header = src.substring(5, comma); // strip leading 'data:'
    final payload = src.substring(comma + 1);
    final isBase64 = header.toLowerCase().contains(';base64');
    final mime = header.split(';').first.trim();
    final bytes = isBase64
        ? base64.decode(payload.trim())
        : Uint8List.fromList(utf8.encode(Uri.decodeComponent(payload)));
    return (bytes: bytes, mime: mime.isEmpty ? null : mime);
  } catch (_) {
    return null;
  }
}

/// The resolution ladder (shared by edit, read-only, and the preview viewer):
/// 1. first matching [ImageFormatHandler] (AVIF/SVG/…),
/// 2. host [SmartEditorSettings.imageProvider],
/// 3. built-in: decoded `data:` bytes → memory, `http(s)` → network,
/// 4. error placeholder.
///
/// [onError] is invoked when a built-in/provider image fails to load (the host
/// callback); the UI falls back to [imageErrorPlaceholder] regardless.
Widget resolveImageWidget({
  required SmartEditorSettings settings,
  required ImageRenderContext ctx,
  required bool isDarkMode,
  void Function(ImageNode node, Object error)? onError,
}) {
  for (final handler in settings.imageFormatHandlers) {
    if (handler.matches(ctx)) return handler.build(ctx);
  }

  final providerHook = settings.imageProvider;
  if (providerHook != null) {
    final provider = providerHook(ctx);
    if (provider != null) {
      return _imageFromProvider(ctx, provider, isDarkMode, onError);
    }
  }

  if (ctx.bytes != null) {
    return _imageFromProvider(ctx, MemoryImage(ctx.bytes!), isDarkMode, onError);
  }
  if (ctx.src.startsWith('http://') || ctx.src.startsWith('https://')) {
    return _imageFromProvider(ctx, NetworkImage(ctx.src), isDarkMode, onError);
  }
  return imageErrorPlaceholder(ctx, isDarkMode);
}

Widget _imageFromProvider(
  ImageRenderContext ctx,
  ImageProvider provider,
  bool isDarkMode,
  void Function(ImageNode node, Object error)? onError,
) {
  return Image(
    image: provider,
    width: ctx.width,
    height: ctx.height,
    fit: ctx.fit,
    errorBuilder: (context, error, stack) {
      onError?.call(ctx.node, error);
      return imageErrorPlaceholder(ctx, isDarkMode);
    },
    loadingBuilder: (context, child, progress) {
      if (progress == null) return child;
      return _loadingPlaceholder(ctx);
    },
  );
}

/// A bordered placeholder shown when an image can't be decoded/loaded,
/// surfacing the `alt` text.
Widget imageErrorPlaceholder(ImageRenderContext ctx, bool isDarkMode) {
  final border = isDarkMode ? Colors.white24 : Colors.black26;
  final fg = isDarkMode ? Colors.white54 : Colors.black45;
  final alt = ctx.node.alt;
  return Container(
    width: ctx.width,
    height: ctx.height,
    constraints: const BoxConstraints(minWidth: 80, minHeight: 60),
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      border: Border.all(color: border),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.broken_image_outlined, size: 20, color: fg),
        if (alt.isNotEmpty) ...[
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              alt,
              style: TextStyle(color: fg, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    ),
  );
}

Widget _loadingPlaceholder(ImageRenderContext ctx) {
  return SizedBox(
    width: ctx.width,
    height: ctx.height ?? 80,
    child: const Center(
      child: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );
}
