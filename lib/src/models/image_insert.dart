import 'dart:convert';
import 'dart:typed_data';
import 'image_size.dart';

/// Where an image insert originated — upload policy may differ per source.
enum ImageInsertSource { toolbar, paste, parse }

/// What the host receives in [SmartEditorSettings.onImageInsert]: the raw thing
/// the user added (a URL / `data:` URI in [src], or clipboard/picked [bytes]).
class ImageInsertRequest {
  const ImageInsertRequest({
    this.src,
    this.bytes,
    this.mimeType,
    required this.origin,
  });

  /// Set for URL or `data:` URI sources.
  final String? src;

  /// Set for clipboard/picked raw bytes (which have no URL).
  final Uint8List? bytes;

  /// e.g. `image/png`, when known.
  final String? mimeType;

  /// Toolbar pick, paste, or a parse-time `data:` URI.
  final ImageInsertSource origin;
}

/// What the host returns from [SmartEditorSettings.onImageInsert]: the canonical
/// `src` to store (e.g. an uploaded CDN URL), plus optional metadata.
class ImageInsertResult {
  const ImageInsertResult({
    required this.src,
    this.alt,
    this.width,
    this.height,
  });

  final String src;
  final String? alt;
  final ImageSize? width;
  final ImageSize? height;

  ImageInsertResult copyWith({ImageSize? width}) => ImageInsertResult(
        src: src,
        alt: alt,
        width: width ?? this.width,
        height: height,
      );
}

/// Resolves an [ImageInsertRequest] into the [ImageInsertResult] to store,
/// applying the host [onImageInsert] hook when present. The single source of
/// truth shared by the toolbar/programmatic insert path and the paste path.
///
/// With no hook: a [ImageInsertRequest.src] is stored as-is; raw [bytes] are
/// embedded as a base64 `data:` URI (so paste works out-of-the-box). Returns
/// null when there is nothing to store or the host cancelled.
/// [defaultWidth] is applied only when the result declares no width.
Future<ImageInsertResult?> resolveImageInsert(
  ImageInsertRequest request,
  Future<ImageInsertResult?> Function(ImageInsertRequest)? onImageInsert,
  ImageSize? defaultWidth,
) async {
  ImageInsertResult? result;
  if (onImageInsert != null) {
    result = await onImageInsert(request);
  } else if (request.src != null) {
    result = ImageInsertResult(src: request.src!);
  } else if (request.bytes != null) {
    final mime = request.mimeType ?? 'image/png';
    result = ImageInsertResult(
        src: 'data:$mime;base64,${base64.encode(request.bytes!)}');
  }

  if (result == null) return null;
  if (result.width == null && defaultWidth != null) {
    result = result.copyWith(width: defaultWidth);
  }
  return result;
}
