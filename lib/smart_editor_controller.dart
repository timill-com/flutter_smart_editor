import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'src/core/document/document.dart';
import 'src/core/document/document_controller.dart';
import 'src/core/infra/html_parser.dart';
import 'src/core/infra/html_serializer.dart';
import 'src/core/document/undo_redo_manager.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'src/models/enums.dart';
import 'src/models/image_insert.dart';
import 'src/models/image_size.dart';
import 'src/widgets/editor/smart_editor_widget.dart';
import 'src/widgets/toolbar/smart_toolbar_widget.dart';
import 'dart:async';

/// The public controller for [SmartEditor].
///
/// Create an instance and pass it to [SmartEditor]. Use it to
/// programmatically get/set content, apply formatting, manage
/// undo/redo, and more.
///
/// ```dart
/// final controller = SmartEditorController();
///
/// // Get HTML
/// String html = await controller.getText();
///
/// // Set HTML
/// controller.setText('<p>Hello <b>World</b></p>');
/// ```
class SmartEditorController extends ChangeNotifier {
  SmartEditorController({
    this.processInputHtml = true,
    this.processOutputHtml = true,
    this.processNewLineAsBr = false,
  }) {
    _documentController = DocumentController(
      undoRedoManager: _undoRedoManager,
    );
    _documentController.addListener(_onDocumentChanged);
    _documentController.onMessage = (msg) => onMessage?.call(msg);
    _initClipboardListener();
  }

  final bool processInputHtml;
  final bool processOutputHtml;
  final bool processNewLineAsBr;

  bool _canPaste = false;

  /// Callback for providing user feedback (e.g., SnackBars).
  void Function(String message)? onMessage;

  final UndoRedoManager _undoRedoManager = UndoRedoManager();
  late final DocumentController _documentController;
  final SmartHtmlSerializer _serializer = SmartHtmlSerializer();

  /// Auto-convert bare URLs into links when parsing input HTML / plain text.
  /// Set by [SmartEditor] from `SmartEditorSettings.autoDetectLinks`.
  bool autoDetectLinks = true;

  /// Whether serialized `<a>` tags get `target="_blank" rel="noopener noreferrer"`.
  /// Set by [SmartEditor] from `SmartEditorSettings.linkTargetBlank`.
  bool linkTargetBlank = true;

  /// Resolved inline-`<svg>` capture flag. Set by [SmartEditor] from
  /// `SmartEditorSettings.parseInlineSvg` (after the auto/probe resolution).
  bool parseInlineSvg = false;

  /// The image upload/swap hook. Pushed by [SmartEditor] from
  /// `SmartEditorSettings.onImageInsert`.
  Future<ImageInsertResult?> Function(ImageInsertRequest request)? onImageInsert;

  /// The toolbar picture-button source callback. Pushed from
  /// `SmartEditorSettings.onImagePickRequested`.
  Future<ImageInsertRequest?> Function()? onImagePickRequested;

  /// Width applied to inserted images that declare none. Pushed from
  /// `SmartEditorSettings.defaultImageWidth`.
  ImageSize? defaultImageWidth;

  /// Whether parse-time `data:` URIs are routed through [onImageInsert]. Pushed
  /// from `SmartEditorSettings.resolveDataUris`.
  bool resolveDataUris = false;

  SmartHtmlParser get _parser => SmartHtmlParser(
        autoDetectLinks: autoDetectLinks,
        parseInlineSvg: parseInlineSvg,
      );

  Timer? _clipboardTimer;

  /// Custom tag serialization callback.
  String? Function(
      SmartTagType type,
      String tag,
      Map<String, String> attributes,
      Map<String, String> styles,
      String content)? onTagSerialize;

  /// Internal references set by the widget
  SmartEditorWidgetState? _editorWidgetState;
  SmartToolbarState? _toolbarState;

  bool _disabled = false;

  /// Register the editor widget (called internally by SmartEditor)
  void attachEditor(SmartEditorWidgetState editor) {
    _editorWidgetState = editor;
  }

  /// Register the toolbar widget (called internally by SmartEditor)
  void attachToolbar(SmartToolbarState toolbar) {
    _toolbarState = toolbar;
  }

  /// The internal document controller
  DocumentController get documentController => _documentController;

  /// The current document
  Document get document => _documentController.document;

  void _onDocumentChanged() {
    _updatePasteState(); // Refresh clipboard state immediately on internal changes
    _safeNotifyListeners();
  }

  void _safeNotifyListeners() {
    if (WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
    } else {
      notifyListeners();
    }
  }

  // ─── Content Methods ──────────────────────────────────────────

  /// Gets the HTML content from the editor.
  Future<String> getText() async {
    _serializer.onTagSerialize = onTagSerialize;
    _serializer.linkTargetBlank = linkTargetBlank;
    var html = _serializer.serialize(_documentController.document);

    if (processOutputHtml) {
      if (html == '<p></p>' || html == '<p><br></p>' || html.isEmpty) {
        html = '';
      }
    }

    return html;
  }

  /// Sets the editor content from an HTML string.
  void setText(String html) {
    if (processInputHtml) {
      html = _processInput(html);
    }

    final document = _parser.parse(html);
    _documentController.setDocument(document);
    _editorWidgetState?.rebuild();
    resolveDataUriImages();
  }

  /// Inserts plain text at the current cursor position.
  void insertText(String text) {
    final blockIndex = _editorWidgetState?.focusedBlockIndex ?? 0;
    final offset = _editorWidgetState?.cursorOffset ?? 0;
    final info = focusedTableInfo;
    if (info != null) {
      _documentController.insertCellText(
          info.blockIndex, info.row, info.col, offset, text);
    } else {
      _documentController.insertText(blockIndex, offset, text);
    }
    _editorWidgetState?.rebuild();
  }

  /// Inserts HTML at the current cursor position.
  /// Parses the HTML and inserts the resulting text content.
  void insertHtml(String html) {
    if (processInputHtml) {
      html = _processInput(html);
    }

    final parsed = _parser.parse(html);
    final blockIndex = _editorWidgetState?.focusedBlockIndex ?? 0;
    final offset = _editorWidgetState?.cursorOffset ?? 0;

    if (parsed.blocks.isNotEmpty) {
      final info = focusedTableInfo;
      if (info != null) {
        _documentController.insertCellParsedDocument(
            info.blockIndex, info.row, info.col, offset, parsed);
      } else {
        _documentController.insertParsedDocument(blockIndex, offset, parsed);
      }
      _editorWidgetState?.rebuild();
    }
  }

  /// Clears all content from the editor.
  void clear() {
    _documentController.clear();
    _editorWidgetState?.rebuild();
  }

  // ─── Formatting Methods ───────────────────────────────────────

  /// Toggles bold on the current selection.
  void toggleBold() => _toggleFormat(SmartButtonType.bold);

  /// Toggles italic on the current selection.
  void toggleItalic() => _toggleFormat(SmartButtonType.italic);

  /// Toggles underline on the current selection.
  void toggleUnderline() => _toggleFormat(SmartButtonType.underline);

  /// Toggles strikethrough on the current selection.
  void toggleStrikethrough() => _toggleFormat(SmartButtonType.strikethrough);

  void _toggleFormat(SmartButtonType format) {
    final blockIndex = _editorWidgetState?.focusedBlockIndex ?? 0;
    final selection = _editorWidgetState?.selection;
    if (selection == null || selection.isCollapsed) return;

    final start = selection.start;
    final end = selection.end;

    final info = focusedTableInfo;
    if (info != null) {
      _documentController.toggleCellFormat(
          info.blockIndex, info.row, info.col, start, end, format);
    } else {
      _documentController.toggleFormat(blockIndex, start, end, format);
    }
    _editorWidgetState?.rebuild();
  }

  /// Applies a specific format to the current selection.
  void applyFormat(SmartButtonType format, dynamic value) {
    final blockIndex = _editorWidgetState?.focusedBlockIndex ?? 0;
    final selection = _editorWidgetState?.selection;
    if (selection == null || selection.isCollapsed) return;

    final start = selection.start;
    final end = selection.end;

    final info = focusedTableInfo;
    if (info != null) {
      _documentController.applyCellFormat(
          info.blockIndex, info.row, info.col, start, end, format, value);
    } else {
      _documentController.applyFormat(blockIndex, start, end, format, value);
    }
    _editorWidgetState?.rebuild();
  }

  /// Sets alignment on the current block or table cell.
  void setAlignment(SmartTextAlign alignment) {
    final blockIndex = _editorWidgetState?.focusedBlockIndex ?? 0;
    final info = focusedTableInfo;
    if (info != null) {
      _documentController.setCellAlignment(
          info.blockIndex, info.row, info.col, alignment);
    } else {
      _documentController.setAlignment(blockIndex, alignment);
    }
    _editorWidgetState?.rebuild();
  }

  /// Clears formatting on the current selection.
  void clearFormatting() {
    final blockIndex = _editorWidgetState?.focusedBlockIndex ?? 0;
    final selection = _editorWidgetState?.selection;
    if (selection == null || selection.isCollapsed) return;

    final info = focusedTableInfo;
    if (info != null) {
      _documentController.clearCellFormat(
          info.blockIndex, info.row, info.col, selection.start, selection.end);
    } else {
      _documentController.clearFormat(
          blockIndex, selection.start, selection.end);
    }
    _editorWidgetState?.rebuild();
  }

  // ─── Block Type Methods ───────────────────────────────────────

  /// Changes the current block to a specific heading level (1-6)
  /// or back to paragraph.
  void setBlockType(BlockType type) {
    final blockIndex = _editorWidgetState?.focusedBlockIndex ?? 0;
    final info = focusedTableInfo;
    if (info != null) {
      _documentController.changeCellBlockType(
          info.blockIndex, info.row, info.col, type);
    } else {
      _documentController.changeBlockType(blockIndex, type);
    }
    _editorWidgetState?.rebuild();
  }

  // ─── Undo / Redo ──────────────────────────────────────────────

  /// Undoes the last action.
  void undo() {
    _documentController.undo();
    _editorWidgetState?.rebuild();
  }

  /// Redoes the last undone action.
  void redo() {
    _documentController.redo();
    _editorWidgetState?.rebuild();
  }

  /// Whether there are actions to undo.
  bool get canUndo => _undoRedoManager.canUndo;

  /// Whether there are actions to redo.
  bool get canRedo => _undoRedoManager.canRedo;

  // ─── Editor State ─────────────────────────────────────────────

  /// Enables the editor for editing.
  void enable() {
    _disabled = false;
    _toolbarState?.setEnabled(true);
    _editorWidgetState?.rebuild();
  }

  /// Disables the editor (read-only mode).
  void disable() {
    _disabled = true;
    _toolbarState?.setEnabled(false);
    _editorWidgetState?.rebuild();
  }

  /// Whether the editor is currently disabled.
  bool get isDisabled => _disabled;

  /// Sets focus to the editor.
  void setFocus() {
    _editorWidgetState?.rebuild();
  }

  /// Clears focus from the editor.
  void clearFocus() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  /// Sets the hint/placeholder text.
  void setHint(String text) {
    // Hint is set via SmartEditorSettings — dynamic updates
    // will be supported in a future version.
  }

  // ─── Character Count ──────────────────────────────────────────

  /// Returns the current character count.
  int get characterCount => _documentController.document.totalLength;

  // ─── Clipboard Methods ─────────────────────────────────────────

  /// Whether there is a selection available to copy.
  bool get canCopy {
    final selection = _editorWidgetState?.selection;
    return selection != null && !selection.isCollapsed;
  }

  /// Whether the system clipboard contains pasteable content.
  bool get canPaste => _canPaste;

  void _initClipboardListener() {
    // Start periodic polling as a fallback since SystemClipboard has no native listener on all platforms
    _clipboardTimer =
        Timer.periodic(const Duration(seconds: 2), (_) => _updatePasteState());
    _updatePasteState(); // Initial check
  }

  Future<void> _updatePasteState() async {
    bool hasContent;
    try {
      final reader = await SystemClipboard.instance?.read();
      hasContent = reader != null &&
          (reader.canProvide(Formats.htmlText) ||
              reader.canProvide(Formats.plainText));
    } catch (_) {
      // The clipboard channel can be unavailable (unit tests, or platforms
      // without the native plugin). Treat that as nothing pasteable instead
      // of letting the error escape and crash the polling timer.
      hasContent = false;
    }

    if (hasContent != _canPaste) {
      _canPaste = hasContent;
      _safeNotifyListeners();
    }
  }

  /// Copies the current selection to the system clipboard as HTML and Text.
  Future<void> copySelection() async {
    final selection = _editorWidgetState?.selection;
    final blockIndex = _editorWidgetState?.focusedBlockIndex;

    if (selection == null || selection.isCollapsed || blockIndex == null) {
      return;
    }

    final html = _documentController.getSelectedHtml(blockIndex, selection);
    final plainText =
        _documentController.getSelectedPlainText(blockIndex, selection);

    final item = DataWriterItem();
    if (html.isNotEmpty) {
      item.add(Formats.htmlText(html));
    }
    item.add(Formats.plainText(plainText));

    await SystemClipboard.instance?.write([item]);
    await _updatePasteState(); // Refresh canPaste state immediately
    onMessage?.call('Copied to clipboard');
  }

  /// Pastes content from the system clipboard into the editor.
  Future<void> pasteContent() async {
    final blockIndex = _editorWidgetState?.focusedBlockIndex;
    if (blockIndex == null) return;

    final reader = await SystemClipboard.instance?.read();
    if (reader == null) return;

    if (reader.canProvide(Formats.htmlText)) {
      final html = await reader.readValue(Formats.htmlText);
      if (html != null && html.isNotEmpty) {
        insertHtml(html);
        return;
      }
    }

    if (reader.canProvide(Formats.plainText)) {
      final text = await reader.readValue(Formats.plainText);
      if (text != null && text.isNotEmpty) {
        insertText(text);
      }
    }
  }

  @override
  void dispose() {
    _clipboardTimer?.cancel();
    _documentController.removeListener(_onDocumentChanged);
    super.dispose();
  }

  // ─── Internal Helpers ─────────────────────────────────────────

  String _processInput(String html) {
    html = html
        .replaceAll("'", "\\'")
        .replaceAll('"', '\\"')
        .replaceAll('\r', '')
        .replaceAll('\r\n', '');

    if (processNewLineAsBr) {
      html = html.replaceAll('\n', '<br/>');
    } else {
      html = html.replaceAll('\n', '');
    }

    return html;
  }

  // ─── Image Methods ─────────────────────────────────────────────

  /// Inserts an image after the currently focused block. Routes [request]
  /// through [onImageInsert] (or stores the source as-is when no hook is set),
  /// then inserts the resulting [ImageNode]. Returning null from the hook — or
  /// a request with nothing to store — cancels the insert.
  Future<void> insertImage(ImageInsertRequest request) async {
    final result =
        await resolveImageInsert(request, onImageInsert, defaultImageWidth);
    if (result == null) return;
    final blockIndex = _editorWidgetState?.focusedBlockIndex ?? 0;
    _documentController.insertImage(blockIndex, result);
    _editorWidgetState?.rebuild();
  }

  /// Sets the display size of the image at [blockIndex] (null = intrinsic).
  /// One undo step.
  void resizeImage(int blockIndex, {ImageSize? width, ImageSize? height}) {
    _documentController.resizeImage(blockIndex, width, height);
    _editorWidgetState?.rebuild();
  }

  Future<void>? _dataUriResolve;

  /// Post-parse async pass: when [resolveDataUris] is on and [onImageInsert] is
  /// set, walks the document for `data:` URI images, routes each through
  /// [onImageInsert], and swaps `src` in place (one undo-free model edit).
  /// No-op otherwise. Concurrent calls share a single in-flight pass.
  Future<void> resolveDataUriImages() {
    if (!resolveDataUris || onImageInsert == null) return Future.value();
    return _dataUriResolve ??=
        _doResolveDataUriImages().whenComplete(() => _dataUriResolve = null);
  }

  Future<void> _doResolveDataUriImages() async {
    final hook = onImageInsert;
    if (hook == null) return;
    final images = _documentController.document.blocks
        .whereType<ImageNode>()
        .where((n) => n.isDataUri)
        .toList();
    var changed = false;
    for (final node in images) {
      final mime = _mimeFromDataUri(node.src);
      final result = await hook(ImageInsertRequest(
        src: node.src,
        mimeType: mime,
        origin: ImageInsertSource.parse,
      ));
      if (result != null) {
        node.src = result.src;
        if (result.alt != null) node.alt = result.alt!;
        if (result.width != null) node.width = result.width;
        if (result.height != null) node.height = result.height;
        changed = true;
      }
    }
    if (changed) {
      _editorWidgetState?.rebuild();
      _safeNotifyListeners();
    }
  }

  /// Extracts the MIME type from a `data:<mime>[;...],...` URI, or null.
  String? _mimeFromDataUri(String src) {
    if (!src.startsWith('data:')) return null;
    final comma = src.indexOf(',');
    if (comma < 0) return null;
    final mime = src.substring(5, comma).split(';').first.trim();
    return mime.isEmpty ? null : mime;
  }

  // ─── Table Methods ─────────────────────────────────────────────

  /// Returns info about the currently focused table cell, or null.
  ({int blockIndex, int row, int col})? get focusedTableInfo =>
      _editorWidgetState?.focusedTableInfo;

  /// Whether the cursor is currently inside a table cell.
  bool get isInsideTable => focusedTableInfo != null;

  /// Inserts a new table after the currently focused block.
  void insertTable({int rows = 2, int cols = 2}) {
    final blockIndex = _editorWidgetState?.focusedBlockIndex ?? 0;
    _documentController.insertTable(blockIndex, rows: rows, cols: cols);
    _editorWidgetState?.rebuild();
  }

  /// Inserts a row below the currently focused cell.
  void insertRow() {
    final info = focusedTableInfo;
    if (info == null) return;
    _documentController.insertTableRow(info.blockIndex, info.row + 1);
    _editorWidgetState?.rebuild();
  }

  /// Inserts a column to the right of the currently focused cell.
  void insertColumn() {
    final info = focusedTableInfo;
    if (info == null) return;
    _documentController.insertTableColumn(info.blockIndex, info.col + 1);
    _editorWidgetState?.rebuild();
  }

  /// Removes the row at the currently focused cell.
  void deleteRow() {
    final info = focusedTableInfo;
    if (info == null) return;
    _documentController.removeTableRow(info.blockIndex, info.row);
    _editorWidgetState?.rebuild();
  }

  /// Removes the column at the currently focused cell.
  void deleteColumn() {
    final info = focusedTableInfo;
    if (info == null) return;
    _documentController.removeTableColumn(info.blockIndex, info.col);
    _editorWidgetState?.rebuild();
  }

  /// Deletes the entire table at the currently focused block.
  void deleteTable() {
    final info = focusedTableInfo;
    if (info == null) return;
    _documentController.deleteTable(info.blockIndex);
    _editorWidgetState?.rebuild();
  }
}
