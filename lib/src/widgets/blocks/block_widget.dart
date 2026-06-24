import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../../core/document/document.dart';
import '../../models/enums.dart';
import '../../models/editor_settings.dart';
import '../../models/image_render.dart';
import '../../models/image_size.dart';
import 'rich_text_controller.dart';
import 'list_indicator.dart';

// ─── Block Widget ───────────────────────────────────────────────────────
class BlockWidget extends StatefulWidget {
  const BlockWidget({
    super.key,
    required this.block,
    required this.blockIndex,
    required this.focusNode,
    required this.editorSettings,
    required this.onTextChanged,
    required this.onEnter,
    required this.onBackspaceAtStart,
    required this.onDeleteAtEnd,
    required this.onFocusChanged,
    required this.onSelectionChanged,
    required this.onPaste,
    this.pendingFontSize,
    this.readOnly = false,
    this.hint,
    this.isDarkMode = false,
    this.cursorColor,
    this.cursorWidth,
    this.cursorRadius,
    this.selectionColor,
    this.onIncreaseIndent,
    this.onDecreaseIndent,
    this.onHrTap,
    this.orderedCount = 1,
    this.showDragHandle = true,
    this.dragIndex,
  });

  final BlockNode block;
  final int blockIndex;
  final FocusNode focusNode;
  final SmartEditorSettings editorSettings;
  final void Function(int blockIndex, String newText) onTextChanged;
  final void Function(int blockIndex, int offset) onEnter;
  final void Function(int blockIndex) onBackspaceAtStart;
  final void Function(int blockIndex) onDeleteAtEnd;
  final void Function(int blockIndex, bool hasFocus) onFocusChanged;
  final void Function(int blockIndex, int baseOffset, int extentOffset)
      onSelectionChanged;
  final void Function(int blockIndex) onPaste;

  final double? pendingFontSize;
  final bool readOnly;
  final String? hint;
  final bool isDarkMode;
  final Color? cursorColor;
  final double? cursorWidth;
  final Radius? cursorRadius;
  final Color? selectionColor;

  /// The index within the ReorderableListView (may differ from blockIndex due to grouping).
  final int? dragIndex;

  /// Whether to show the drag handle (used for list grouping).
  final bool showDragHandle;

  // List-specific callbacks
  final VoidCallback? onIncreaseIndent;
  final VoidCallback? onDecreaseIndent;

  // HR-specific callbacks
  final void Function(int blockIndex)? onHrTap;

  /// Pre-computed ordered list counter (computed by smart_editor_widget.dart).
  final int orderedCount;

  @override
  State<BlockWidget> createState() => BlockWidgetState();
}

class BlockWidgetState extends State<BlockWidget> {
  late SmartTextEditingController _textController;
  static const String _zwsp = '\u200B';
  bool _isInternalUpdate = false;
  TextSelection _lastReportedSelection =
      const TextSelection.collapsed(offset: 1);

  /// Tap recognizers for link spans in read-only mode. Rebuilt on each render
  /// and disposed to avoid leaks.
  final List<TapGestureRecognizer> _linkRecognizers = [];

  /// Key on the read-only rich text, used to hit-test long-press positions
  /// against the rendered paragraph so we know which link was pressed.
  final GlobalKey _readOnlyTextKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _textController =
        SmartTextEditingController(text: _zwsp + widget.block.plainText);
    _syncFormatSpans();
    _textController.addListener(_onControllerChanged);

    // Initial selection should be at 1
    _textController.selection = const TextSelection.collapsed(offset: 1);
  }

  @override
  void didUpdateWidget(BlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFormatSpans();

    final newText = _zwsp + widget.block.plainText;
    if (_textController.text != newText && !_isInternalUpdate) {
      _isInternalUpdate = true;
      final cursorPos = _textController.selection.baseOffset;
      _textController.text = newText;
      if (cursorPos <= newText.length) {
        _textController.selection = TextSelection.collapsed(
          offset: cursorPos < 1 ? 1 : cursorPos,
        );
      }
      _isInternalUpdate = false;
    }
  }

  void _syncFormatSpans() {
    final defaultColor = widget.isDarkMode ? Colors.white : Colors.black;
    _textController.formatSpans = List.from(widget.block.spans);
    _textController.baseFontSize = _getBlockBaseFontSize();
    _textController.baseFontWeight = _getFontWeight();
    _textController.defaultColor = defaultColor;
    _textController.linkStyle = widget.editorSettings.linkStyle;
    _textController.refresh();

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final r in _linkRecognizers) {
      r.dispose();
    }
    _linkRecognizers.clear();
    _textController.removeListener(_onControllerChanged);
    _textController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (_isInternalUpdate) return;

    final currentText = _textController.text;

    // Detect backspace at start (ZWSP was deleted)
    if (!currentText.startsWith(_zwsp)) {
      _isInternalUpdate = true;
      // Re-add ZWSP and restore cursor
      _textController.text = _zwsp + currentText;
      _textController.selection = const TextSelection.collapsed(offset: 1);
      _isInternalUpdate = false;

      widget.onBackspaceAtStart(widget.blockIndex);
      return;
    }

    // Snap cursor to prevent moving before ZWSP
    if (_textController.selection.baseOffset == 0) {
      _isInternalUpdate = true;
      _textController.selection = const TextSelection.collapsed(offset: 1);
      _isInternalUpdate = false;
    }

    final plainText = currentText.substring(1); // Exclude ZWSP

    if (plainText != widget.block.plainText) {
      if (plainText.isEmpty && widget.block.plainText.isEmpty) {
        return;
      }

      if (plainText.contains('\n')) {
        final indexOfNewline = plainText.indexOf('\n');
        final cleanedText = plainText.replaceAll('\n', '');

        _isInternalUpdate = true;
        _textController.text = _zwsp + widget.block.plainText;
        _textController.selection =
            TextSelection.collapsed(offset: indexOfNewline + 1);
        _isInternalUpdate = false;

        if (cleanedText != widget.block.plainText) {
          widget.onTextChanged(widget.blockIndex, cleanedText);
        }

        widget.onEnter(widget.blockIndex, indexOfNewline);
        return;
      }

      _isInternalUpdate = true;
      widget.onTextChanged(widget.blockIndex, plainText);
      _isInternalUpdate = false;

      _syncFormatSpans();
    }

    final currentSelection = _textController.selection;
    if (currentSelection != _lastReportedSelection &&
        currentSelection.isValid) {
      _lastReportedSelection = currentSelection;
      widget.onSelectionChanged(
        widget.blockIndex,
        currentSelection.baseOffset,
        currentSelection.extentOffset,
      );
    }
  }

  void setCursorPosition(int offset) {
    final clamped = offset.clamp(0, _textController.text.length);
    _isInternalUpdate = true;
    _textController.selection = TextSelection.collapsed(offset: clamped);
    _lastReportedSelection = _textController.selection;
    _isInternalUpdate = false;
  }

  int get cursorOffset => _textController.selection.baseOffset;
  TextSelection get selection => _textController.selection;
  int get textLength => _textController.text.length;

  void setTextSilently(String text, {int? cursorOffset}) {
    _isInternalUpdate = true;
    _textController.text = text;
    if (cursorOffset != null) {
      _textController.selection =
          TextSelection.collapsed(offset: cursorOffset.clamp(0, text.length));
    }
    _isInternalUpdate = false;
  }

  void refreshFormatting() {
    _syncFormatSpans();
    setState(() {});
  }

  /// Returns the inherent base font size for the block (paragraphs vs headings).
  double _getBlockBaseFontSize() {
    if (widget.block is HeadingNode) {
      final heading = (widget.block as HeadingNode);
      switch (heading.level) {
        case 1:
          return 32;
        case 2:
          return 28;
        case 3:
          return 24;
        case 4:
          return 20;
        case 5:
          return 18;
        case 6:
          return 16;
        default:
          return widget.editorSettings.defaultFontSize;
      }
    }
    return widget.editorSettings.defaultFontSize;
  }

  /// Returns the font size specifically for the cursor/strut position.
  double _getCursorFontSize() {
    if (_textController.selection.isCollapsed) {
      final offset = _textController.selection.baseOffset;
      final loc = widget.block.getSpanAt(offset);
      final span = widget.block.spans[loc.spanIndex];
      if (span.fontSize != null) return span.fontSize!;
    }
    return _getBlockBaseFontSize();
  }

  FontWeight _getFontWeight() {
    return (widget.block is HeadingNode) ? FontWeight.bold : FontWeight.normal;
  }

  double _getEffectiveCursorHeight() {
    return widget.editorSettings.cursorHeight ??
        (widget.pendingFontSize ?? _getCursorFontSize());
  }

  TextAlign _getTextAlign() {
    switch (widget.block.alignment) {
      case SmartTextAlign.left:
        return TextAlign.left;
      case SmartTextAlign.center:
        return TextAlign.center;
      case SmartTextAlign.right:
        return TextAlign.right;
      case SmartTextAlign.justify:
        return TextAlign.justify;
    }
  }

  TextStyle _getTextStyle(double defaultFontSize, Color defaultColor) {
    return TextStyle(
      fontSize: _getBlockBaseFontSize(),
      fontWeight: _getFontWeight(),
      height: 1.2,
      color: defaultColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.block is HorizontalRuleNode) {
      return _buildHrWidget(context);
    }

    if (widget.block is ImageNode) {
      return _buildImageWidget(context);
    }

    final defaultColor = widget.isDarkMode ? Colors.white : Colors.black;
    final hintColor = widget.isDarkMode ? Colors.grey[600] : Colors.grey[400];

    final textField = Focus(
      onFocusChange: (hasFocus) {
        widget.onFocusChanged(widget.blockIndex, hasFocus);
      },
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final isCmdPressed = HardwareKeyboard.instance.isMetaPressed;
          final isCtrlPressed = HardwareKeyboard.instance.isControlPressed;
          if ((isCmdPressed || isCtrlPressed) &&
              event.logicalKey == LogicalKeyboardKey.keyV) {
            widget.onPaste(widget.blockIndex);
            return KeyEventResult.handled;
          }
          if (event.logicalKey == LogicalKeyboardKey.tab &&
              widget.block is ListItemNode) {
            if (HardwareKeyboard.instance.isShiftPressed) {
              widget.onDecreaseIndent?.call();
            } else {
              widget.onIncreaseIndent?.call();
            }
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (event is! KeyDownEvent) return;

          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.numpadEnter) {
            if (HardwareKeyboard.instance.logicalKeysPressed
                .contains(LogicalKeyboardKey.enter)) {
              widget.onEnter(
                  widget.blockIndex, _textController.selection.baseOffset);
            }
          } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
            if (_textController.selection.baseOffset == 0 &&
                _textController.selection.extentOffset == 0) {
              widget.onBackspaceAtStart(widget.blockIndex);
            }
          } else if (event.logicalKey == LogicalKeyboardKey.delete) {
            if (_textController.selection.baseOffset ==
                _textController.text.length) {
              widget.onDeleteAtEnd(widget.blockIndex);
            }
          }
        },
        child: Theme(
          data: Theme.of(context).copyWith(
            textSelectionTheme: TextSelectionThemeData(
              selectionColor: widget.selectionColor,
              cursorColor: widget.cursorColor,
              selectionHandleColor: widget.editorSettings.selectionHandleColor,
            ),
          ),
          child: TextField(
            controller: _textController,
            focusNode: widget.focusNode,
            readOnly: widget.readOnly,
            maxLines: null,
            textAlign: _getTextAlign(),
            cursorColor: widget.cursorColor,
            cursorWidth: widget.cursorWidth ?? 2.0,
            cursorRadius: widget.cursorRadius,
            cursorHeight: _getEffectiveCursorHeight(),
            strutStyle: widget.pendingFontSize != null
                ? StrutStyle(fontSize: widget.pendingFontSize)
                : StrutStyle(fontSize: _getCursorFontSize()),
            style: _getTextStyle(
                widget.editorSettings.defaultFontSize, defaultColor),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
              hintText: widget.hint,
              hintStyle: TextStyle(
                fontSize: _getBlockBaseFontSize(),
                fontWeight: _getFontWeight(),
                color: hintColor,
                height: 1.2,
              ),
            ),
            onTap: () {
              final sel = _textController.selection;
              widget.onSelectionChanged(
                widget.blockIndex,
                sel.baseOffset,
                sel.extentOffset,
              );
            },
            contextMenuBuilder: (context, editableTextState) {
              return AdaptiveTextSelectionToolbar.buttonItems(
                anchors: editableTextState.contextMenuAnchors,
                buttonItems:
                    editableTextState.contextMenuButtonItems.map((item) {
                  if (item.type == ContextMenuButtonType.paste) {
                    return ContextMenuButtonItem(
                      onPressed: () {
                        editableTextState.hideToolbar();
                        widget.onPaste(widget.blockIndex);
                      },
                      type: ContextMenuButtonType.paste,
                    );
                  }
                  return item;
                }).toList(),
              );
            },
          ),
        ),
      ),
    );

    // In read-only mode, render a non-editable rich-text leaf so link spans can
    // be styled AND tapped (a TapGestureRecognizer inside a TextField never
    // fires). The list-item / drag wrappers below are unchanged.
    final Widget leaf =
        widget.readOnly ? _buildReadOnlyContent(defaultColor) : textField;

    Widget content;
    if (widget.block is ListItemNode) {
      content = _buildListItemWrapper(context, leaf);
    } else {
      content = leaf;
    }

    final isBlockTypeDraggable = widget.editorSettings.draggableBlockTypes
            ?.contains(widget.block.blockType) ??
        false;

    final isDraggable = widget.showDragHandle && isBlockTypeDraggable;
    final needsHandleSpace =
        isDraggable || (widget.block is ListItemNode && isBlockTypeDraggable);

    if (!needsHandleSpace) {
      return content;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 32,
          child: isDraggable ? _buildDragHandle() : const SizedBox.shrink(),
        ),
        Expanded(child: content),
      ],
    );
  }

  /// Builds a non-editable, selectable rich-text view of the block for
  /// read-only mode. Link spans get a [TapGestureRecognizer] wired to
  /// [SmartEditorSettings.onLinkTap]; selection/copy is preserved.
  Widget _buildReadOnlyContent(Color defaultColor) {
    for (final r in _linkRecognizers) {
      r.dispose();
    }
    _linkRecognizers.clear();

    final baseFontSize = _getBlockBaseFontSize();
    final baseWeight = _getFontWeight();
    final onLinkTap = widget.editorSettings.onLinkTap;

    var hasLink = false;
    final children = <InlineSpan>[];
    for (final span in widget.block.spans) {
      final isLink = span.linkUrl != null && span.linkUrl!.isNotEmpty;
      TapGestureRecognizer? recognizer;
      if (isLink) {
        hasLink = true;
        // Tap-to-open is a span recognizer (also exposes link a11y semantics).
        // Long-press-to-copy is handled by the wrapping GestureDetector below,
        // because a TextSpan supports only one recognizer.
        if (onLinkTap != null) {
          final url = span.linkUrl!;
          recognizer = TapGestureRecognizer()..onTap = () => onLinkTap(url);
          _linkRecognizers.add(recognizer);
        }
      }
      children.add(TextSpan(
        text: span.text,
        style: buildSpanTextStyle(
          span,
          baseFontSize: baseFontSize,
          baseFontWeight: baseWeight,
          defaultColor: defaultColor,
          linkStyle: widget.editorSettings.linkStyle,
        ),
        recognizer: recognizer,
      ));
    }

    final root = TextSpan(
      style: _getTextStyle(widget.editorSettings.defaultFontSize, defaultColor),
      children: children,
    );

    // Link-free blocks stay drag-selectable. Link-bearing blocks use a plain
    // rich text we can hit-test, so a long press anywhere on a link copies it
    // (a TextSpan supports only one recognizer, so long-press can't also be a
    // span recognizer alongside the tap one).
    if (!hasLink) {
      return SelectableText.rich(root, textAlign: _getTextAlign());
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPressStart: (details) =>
          _handleLinkLongPressAt(details.globalPosition),
      child: Text.rich(root, key: _readOnlyTextKey, textAlign: _getTextAlign()),
    );
  }

  /// Hit-tests a long-press position against the rendered paragraph and, if it
  /// landed on a link span, copies it.
  void _handleLinkLongPressAt(Offset globalPosition) {
    final renderObject = _readOnlyTextKey.currentContext?.findRenderObject();
    if (renderObject is! RenderParagraph) return;
    final local = renderObject.globalToLocal(globalPosition);
    final offset = renderObject.getPositionForOffset(local).offset;
    final url = _linkUrlAtOffset(offset);
    if (url != null) _handleLinkLongPress(url);
  }

  /// Returns the `linkUrl` of the span containing the given text [offset], or
  /// null if that position isn't part of a link.
  String? _linkUrlAtOffset(int offset) {
    var cursor = 0;
    for (final span in widget.block.spans) {
      final len = span.text.length;
      if (offset >= cursor && offset < cursor + len) {
        return (span.linkUrl?.isNotEmpty ?? false) ? span.linkUrl : null;
      }
      cursor += len;
    }
    return null;
  }

  /// Copies a long-pressed link to the clipboard, then either invokes the
  /// host's [SmartEditorSettings.onLinkLongPress] callback or shows a default
  /// "Link copied" SnackBar when a [ScaffoldMessenger] is available.
  void _handleLinkLongPress(String url) {
    Clipboard.setData(ClipboardData(text: url));

    final onLongPress = widget.editorSettings.onLinkLongPress;
    if (onLongPress != null) {
      onLongPress(url);
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('Link copied'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildDragHandle() {
    return ReorderableDragStartListener(
      index: widget.dragIndex ?? widget.blockIndex,
      child: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: Icon(
          Icons.drag_indicator,
          size: 18,
          color: widget.isDarkMode ? Colors.white38 : Colors.black26,
        ),
      ),
    );
  }

  Widget _buildListItemWrapper(BuildContext context, Widget textField) {
    final item = widget.block as ListItemNode;
    final depth = item.depth.clamp(0, 3);
    final indent = depth * 24.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: indent),
        SizedBox(
          width: 28,
          child: Padding(
            padding: const EdgeInsets.only(top: 3.0),
            child: ListItemIndicator(
              item: item,
              orderedCount: widget.orderedCount,
              editorSettings: widget.editorSettings,
              isDarkMode: widget.isDarkMode,
            ),
          ),
        ),
        Expanded(child: textField),
      ],
    );
  }

  Widget _buildHrWidget(BuildContext context) {
    final hrStyle = widget.editorSettings.hrStyle;
    final defaultColor = widget.isDarkMode
        ? Colors.white24
        : Colors.black.withValues(alpha: 0.15);
    final dividerColor = hrStyle.color ?? defaultColor;

    final divider = GestureDetector(
      onTap: () => widget.onHrTap?.call(widget.blockIndex),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: hrStyle.verticalSpacing),
        child: Container(
          height: hrStyle.thickness,
          decoration: BoxDecoration(
            color: dividerColor,
            borderRadius: hrStyle.borderRadius,
          ),
        ),
      ),
    );

    final isDraggable = widget.editorSettings.draggableBlockTypes
            ?.contains(BlockType.horizontalRule) ??
        false;

    if (!isDraggable) return divider;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildDragHandle(),
        Expanded(child: divider),
      ],
    );
  }

  // ─── Image rendering ──────────────────────────────────────────

  /// Renders an [ImageNode] in both edit and read-only mode. The package owns
  /// the chrome (sizing, alignment, tap, error placeholder); the actual pixels
  /// come from the resolution ladder in [_resolveImageWidget].
  Widget _buildImageWidget(BuildContext context) {
    final node = widget.block as ImageNode;
    final decoded = node.isDataUri ? _decodeDataUri(node.src) : null;

    // A data: URI that won't decode is a load failure — notify once, after the
    // frame so we don't call back into the host during build.
    if (node.isDataUri && decoded == null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _notifyImageError(node, const FormatException('Invalid data URI')),
      );
    }

    final sized = LayoutBuilder(
      builder: (context, constraints) {
        final maxAvail =
            constraints.maxWidth.isFinite ? constraints.maxWidth : null;
        var width = _resolveDimension(node.width, maxAvail);
        final height = _resolveDimension(node.height, maxAvail);

        final maxImg = widget.editorSettings.maxImageWidth;
        if (width != null && maxImg != null && width > maxImg) width = maxImg;

        final ctx = ImageRenderContext(
          node: node,
          src: node.src,
          bytes: decoded?.bytes,
          rawSvg: node.rawSvg,
          mimeType: decoded?.mime,
          width: width,
          height: height,
          fit: BoxFit.contain,
          readOnly: widget.readOnly,
        );

        Widget img = _resolveImageWidget(ctx);
        // Intrinsic width but a global clamp set → cap without forcing a size.
        if (width == null && maxImg != null) {
          img = ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxImg),
            child: img,
          );
        }
        return img;
      },
    );

    final onTap = widget.editorSettings.onImageTap;
    Widget result = sized;
    if (onTap != null) {
      result = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(node),
        child: result,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: _imageAlignment(node.alignment),
        child: result,
      ),
    );
  }

  /// The resolution ladder (shared by edit + read-only):
  /// 1. first matching [ImageFormatHandler] (AVIF/SVG/…),
  /// 2. host [SmartEditorSettings.imageProvider],
  /// 3. built-in: decoded `data:` bytes → memory, `http(s)` → network,
  /// 4. error placeholder.
  Widget _resolveImageWidget(ImageRenderContext ctx) {
    for (final handler in widget.editorSettings.imageFormatHandlers) {
      if (handler.matches(ctx)) return handler.build(ctx);
    }

    final providerHook = widget.editorSettings.imageProvider;
    if (providerHook != null) {
      final provider = providerHook(ctx);
      if (provider != null) return _imageFromProvider(ctx, provider);
    }

    if (ctx.bytes != null) {
      return _imageFromProvider(ctx, MemoryImage(ctx.bytes!));
    }
    if (ctx.src.startsWith('http://') || ctx.src.startsWith('https://')) {
      return _imageFromProvider(ctx, NetworkImage(ctx.src));
    }
    return _errorPlaceholder(ctx);
  }

  Widget _imageFromProvider(ImageRenderContext ctx, ImageProvider provider) {
    return Image(
      image: provider,
      width: ctx.width,
      height: ctx.height,
      fit: ctx.fit,
      errorBuilder: (context, error, stack) {
        _notifyImageError(ctx.node, error);
        return _errorPlaceholder(ctx);
      },
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _loadingPlaceholder(ctx);
      },
    );
  }

  /// A bordered placeholder shown when an image can't be decoded/loaded,
  /// surfacing the `alt` text.
  Widget _errorPlaceholder(ImageRenderContext ctx) {
    final isDark = widget.isDarkMode;
    final border = isDark ? Colors.white24 : Colors.black26;
    final fg = isDark ? Colors.white54 : Colors.black45;
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

  void _notifyImageError(ImageNode node, Object error) {
    widget.editorSettings.onImageError?.call(node, error);
  }

  Alignment _imageAlignment(SmartTextAlign align) {
    switch (align) {
      case SmartTextAlign.center:
        return Alignment.center;
      case SmartTextAlign.right:
        return Alignment.centerRight;
      case SmartTextAlign.left:
      case SmartTextAlign.justify:
        return Alignment.centerLeft;
    }
  }

  /// Resolves an [ImageSize] to px against [pctBase] (the available width).
  /// `auto`/null → null (intrinsic).
  double? _resolveDimension(ImageSize? size, double? pctBase) {
    if (size == null) return null;
    switch (size.unit) {
      case ImageSizeUnit.px:
        return size.value;
      case ImageSizeUnit.percent:
        if (pctBase == null) return null;
        return pctBase * (size.value! / 100.0);
      case ImageSizeUnit.auto:
        return null;
    }
  }

  /// Decodes a `data:` URI into bytes + MIME. Handles base64 and percent-encoded
  /// payloads; returns null on malformed input (→ error placeholder).
  ({Uint8List bytes, String? mime})? _decodeDataUri(String src) {
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
}

