import 'package:flutter/material.dart';
import 'enums.dart';
import 'image_render.dart';
import 'image_insert.dart';
import 'image_size.dart';
import 'nodes/node_index.dart';

/// Comprehensive settings for the editor's behavior, style, and events.
///
/// This class merges what was previously split across Editor, Scroll,
/// Keyboard, Selection, Style, and Callbacks settings into a single
/// unified configuration object.
class SmartEditorSettings {
  const SmartEditorSettings({
    // Core & HTML
    this.hint,
    this.initialText,
    this.darkMode,
    this.disabled = false,
    this.readOnly = false,
    this.spellCheck = false,
    this.characterLimit,
    this.maxLines,
    this.processInputHtml = true,
    this.processOutputHtml = true,
    this.processNewLineAsBr = false,
    this.defaultFontSize = 16.0,

    // Scroll & Layout
    this.autoAdjustHeight = true,
    this.ensureVisible = false,
    this.scrollPhysics,

    // Keyboard
    this.inputType = SmartInputType.text,
    this.adjustForKeyboard = true,
    this.keyboardAppearance,
    this.textInputAction,
    this.autofocus = false,

    // Selection & Cursor
    this.selectionColor,
    this.cursorColor,
    this.cursorWidth = 2.0,
    this.cursorRadius,
    this.cursorHeight,
    this.showCursor = true,
    this.selectionHandleColor,
    this.enableInteractiveSelection = true,

    // Style & Decoration
    this.decoration,
    this.editorDecoration,
    this.editorPadding = const EdgeInsets.all(12),
    this.editorBackgroundColor,
    this.borderRadius,

    // Callbacks / Actions
    this.onChangeContent,
    this.onChangeSelection,
    this.onFocus,
    this.onBlur,
    this.onInit,
    this.onEnter,
    this.onKeyUp,
    this.onKeyDown,
    this.onPaste,
    this.onTagSerialize,

    // Links
    this.onLinkTap,
    this.onLinkLongPress,
    this.linkStyle,
    this.autoDetectLinks = true,
    this.linkTargetBlank = true,

    // Lists & HR
    this.maxListDepth = 3,
    this.defaultBulletStyle = SmartBulletStyle.filledCircle,
    this.hrStyle = const SmartHrStyle(),
    this.draggableBlockTypes,

    // Tables
    this.tableStyle = const SmartTableStyle(),

    // Images
    this.imageFormatHandlers = const [],
    this.imageProvider,
    this.onImageTap,
    this.onImageError,
    this.maxImageWidth,
    this.onImageInsert,
    this.onImagePickRequested,
    this.resolveDataUris = false,
    this.defaultImageWidth,
    this.parseInlineSvg,
    this.allowImageResize = true,
  });

  // ─── Core & HTML ──────────────────────────────────────────────

  /// The default font size for the editor
  final double defaultFontSize;

  /// Placeholder text shown when the editor is empty
  final String? hint;

  /// Initial HTML content to pre-fill the editor
  final String? initialText;

  /// Dark mode control (null = system theme)
  final bool? darkMode;

  /// Starts the editor in disabled (non-interactive) mode
  final bool disabled;

  /// Starts the editor in read-only mode (allows selection/copying)
  final bool readOnly;

  /// Enables browser/OS spell checking
  final bool spellCheck;

  /// Maximum number of characters allowed
  final int? characterLimit;

  /// Maximum number of lines (blocks) before the editor starts scrolling
  final int? maxLines;

  /// Whether to process input HTML (clean up quotes, newlines, etc.)
  final bool processInputHtml;

  /// Whether to process output HTML (return "" for empty editor)
  final bool processOutputHtml;

  /// Whether to convert `\n` to `<br>` in input HTML
  final bool processNewLineAsBr;

  // ─── Scroll & Layout ──────────────────────────────────────────

  /// Automatically adjusts editor height to fit content
  final bool autoAdjustHeight;

  /// Scrolls the editor into view when it gains focus
  final bool ensureVisible;

  /// Custom scroll physics for the editor's scroll view
  final ScrollPhysics? scrollPhysics;

  // ─── Keyboard ───────────────────────────────────────────────

  /// The type of virtual keyboard to display
  final SmartInputType inputType;

  /// Shrinks the editor when the keyboard appears
  final bool adjustForKeyboard;

  /// Keyboard brightness (iOS mostly)
  final Brightness? keyboardAppearance;

  /// The action button on the keyboard (done, search, etc.)
  final TextInputAction? textInputAction;

  /// Whether to automatically focus the editor on load
  final bool autofocus;

  // ─── Selection & Cursor ───────────────────────────────────────

  /// Background color of selected text
  final Color? selectionColor;

  /// Color of the blinking vertical cursor
  final Color? cursorColor;

  /// Width of the cursor in logical pixels
  final double cursorWidth;

  /// Rounded corners for the cursor
  final Radius? cursorRadius;

  /// Height of the cursor. `null` uses default.
  final double? cursorHeight;

  /// Whether to show the cursor
  final bool showCursor;

  /// Color of the selection drag handles on mobile
  final Color? selectionHandleColor;

  /// Whether the user can interactively select text
  final bool enableInteractiveSelection;

  // ─── Style & Decoration ───────────────────────────────────────

  /// Decoration around the entire editor container
  final BoxDecoration? decoration;

  /// Decoration around just the text input area
  final BoxDecoration? editorDecoration;

  /// Padding inside the text input area
  final EdgeInsets editorPadding;

  /// Background color of the editor area
  final Color? editorBackgroundColor;

  /// Default border radius if no decoration is provided
  final BorderRadius? borderRadius;

  // ─── Callbacks / Actions ──────────────────────────────────────

  /// Called whenever the HTML content of the editor changes
  final void Function(String?)? onChangeContent;

  /// Called whenever the cursor position or selection changes
  final void Function(Map<SmartButtonType, dynamic>)? onChangeSelection;

  /// Called when the editor gains focus
  final void Function()? onFocus;

  /// Called when the editor loses focus
  final void Function()? onBlur;

  /// Called when the editor is fully initialized
  final void Function()? onInit;

  /// Called when the Enter/Return key is pressed
  final void Function()? onEnter;

  /// Called when a key is released
  final void Function(String?)? onKeyUp;

  /// Called when a key is pressed down
  final void Function(String?)? onKeyDown;

  /// Called when text is pasted into the editor
  final void Function()? onPaste;

  /// Custom tag serialization callback.
  /// Allows users to intercept and modify any HTML tag before it's written.
  final String? Function(
          SmartTagType type,
          String tag,
          Map<String, String> attributes,
          Map<String, String> styles,
          String content)?
      onTagSerialize;

  // ─── Links ────────────────────────────────────────────────────

  /// Called with the `href` when a rendered link span is tapped in read-only
  /// mode. Taps inside the editable editor never fire (Flutter's `EditableText`
  /// consumes pointer events), so this only applies when `readOnly` is true.
  final void Function(String url)? onLinkTap;

  /// Called with the `href` when a link span is long-pressed in read-only mode.
  /// The url is always copied to the clipboard first; if this callback is null,
  /// a default "Link copied" SnackBar is shown (when a [ScaffoldMessenger] is
  /// available). Provide this to show your own toast/feedback instead.
  final void Function(String url)? onLinkLongPress;

  /// Optional style for link spans, merged over the default link appearance
  /// (blue `#1A73E8` + underline). Applies in both edit and read-only modes.
  final TextStyle? linkStyle;

  /// Auto-convert bare `http(s)://` / `www.` URLs in text into links.
  /// Applies on initial load, `setText`, `insertHtml`, and paste.
  /// Defaults to true. Set false to only honour explicit `<a>` tags.
  final bool autoDetectLinks;

  /// When true (default), serialized `<a>` tags open in a new tab:
  /// `target="_blank" rel="noopener noreferrer"`. Set false to omit both.
  final bool linkTargetBlank;

  // ─── Lists & HR ───────────────────────────────────────────────

  /// Maximum nesting depth for lists. Defaults to 3.
  /// Set higher (e.g. 5) if deeper nesting is needed.
  final int maxListDepth;

  /// Default bullet shape for unordered lists.
  /// Can be overridden per-list via the toolbar bullet style picker.
  final SmartBulletStyle defaultBulletStyle;

  /// Styling configuration for the horizontal rule (`<hr>`) divider.
  final SmartHrStyle hrStyle;

  /// Set of block types that are allowed to be dragged to reposition.
  /// If null or empty, no blocks can be dragged.
  /// Example: {BlockType.horizontalRule, BlockType.heading1}
  final Set<BlockType>? draggableBlockTypes;

  // ─── Tables ────────────────────────────────────────────────

  /// Styling configuration for table blocks.
  final SmartTableStyle tableStyle;

  // ─── Images ────────────────────────────────────────────────

  /// Ordered list of pluggable renderers for formats Flutter's `dart:ui`
  /// decoder can't handle (AVIF, SVG, Lottie, …). The first handler whose
  /// `matches(ctx)` is true renders the image; an empty list (default) means
  /// only the built-in formats (JPEG/PNG/WebP/GIF/BMP) are supported.
  ///
  /// This is the declarative "enable a format" API — see the README
  /// **"Enabling AVIF / SVG / other formats"** section for copy-paste recipes.
  /// The package never bundles a codec, so the handler (and its dependency,
  /// e.g. `flutter_avif`/`flutter_svg`) lives in app code. Resolution order:
  /// `imageFormatHandlers` → [imageProvider] → built-in (network / `data:` /
  /// memory) → error placeholder.
  final List<ImageFormatHandler> imageFormatHandlers;

  /// Host override mapping a stored image to a Flutter [ImageProvider] — for
  /// formats Flutter *can* decode but loaded differently (auth'd / cached /
  /// file / asset, e.g. `CachedNetworkImageProvider`). Return null to fall
  /// through to the built-in resolver. Consulted after [imageFormatHandlers].
  final ImageProvider? Function(ImageRenderContext context)? imageProvider;

  /// Called when a rendered image is tapped (read-only and edit). Null = inert.
  final void Function(ImageNode node)? onImageTap;

  /// Notified when an image fails to load (broken URL, malformed base64). The
  /// UI falls back to a placeholder regardless.
  final void Function(ImageNode node, Object error)? onImageError;

  /// Clamp for rendered display width in px, independent of the stored size.
  /// Null = no clamp.
  final double? maxImageWidth;

  /// **The upload/swap hook.** Called when a user adds an image (toolbar pick,
  /// paste, or a `data:` URI at parse time when [resolveDataUris] is on).
  /// Receives the source (URL / bytes / data-URI) and returns the canonical
  /// `src` (+ optional alt/size) to store. Returning null cancels the insert.
  /// Null hook = store the source as-is (raw bytes become a base64 `data:` URI).
  final Future<ImageInsertResult?> Function(ImageInsertRequest request)?
      onImageInsert;

  /// Invoked by the toolbar picture button to obtain an image. The host shows
  /// its own picker / URL dialog (the package stays free of
  /// `image_picker`/`file_picker`) and returns an [ImageInsertRequest], or null
  /// to cancel. When null, the toolbar falls back to a built-in "image URL"
  /// dialog.
  final Future<ImageInsertRequest?> Function()? onImagePickRequested;

  /// When true **and** [onImageInsert] is set, `data:` URIs found at parse/paste
  /// time are routed through [onImageInsert] (a post-parse async pass) so the
  /// host can upload-and-swap embedded base64 to a URL. Default false renders
  /// the data URI in place.
  final bool resolveDataUris;

  /// Width applied to inserted images that declare none.
  final ImageSize? defaultImageWidth;

  /// Input-side SVG switch, tri-state. `null` = auto (capture inline `<svg>`
  /// iff an SVG-capable [ImageFormatHandler] is registered); `true` = always
  /// capture; `false` = never. See [resolveParseInlineSvg] and the README
  /// "Enabling AVIF / SVG" recipes (note the two SVG shapes: `<img src=*.svg>`
  /// vs inline `<svg>` markup — only the latter needs this flag).
  final bool? parseInlineSvg;

  /// Whether edit mode shows the interactive resize affordance.
  final bool allowImageResize;
}

/// Styling configuration for the `<hr>` horizontal rule block.
class SmartHrStyle {
  /// Color of the divider line. Defaults to the theme's divider color.
  final Color? color;

  /// Thickness of the divider line in logical pixels. Defaults to 1.0.
  final double thickness;

  /// Vertical space above and below the divider. Defaults to 8.0.
  final double verticalSpacing;

  /// Border radius for rounded dividers. Defaults to null (no rounding).
  final BorderRadius? borderRadius;

  const SmartHrStyle({
    this.color,
    this.thickness = 1.0,
    this.verticalSpacing = 8.0,
    this.borderRadius,
  });
}

/// Styling configuration for table blocks.
class SmartTableStyle {
  /// Color of the table border lines. Defaults to light grey.
  final Color borderColor;

  /// Width of the table border lines in logical pixels. Defaults to 1.0.
  final double borderWidth;

  /// Padding inside each table cell. Defaults to 8px on all sides.
  final EdgeInsets cellPadding;

  /// Background color for the header row (first row when `hasHeaderRow` is true).
  /// If null, uses the same background as other cells.
  final Color? headerBackgroundColor;

  /// Whether to show grid lines between cells. Defaults to true.
  final bool showGridLines;

  const SmartTableStyle({
    this.borderColor = const Color(0xFFDDDDDD),
    this.borderWidth = 1.0,
    this.cellPadding = const EdgeInsets.all(8),
    this.headerBackgroundColor,
    this.showGridLines = true,
  });
}
