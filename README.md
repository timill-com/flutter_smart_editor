# Flutter Smart Editor

A highly customizable, **pure Dart and Flutter** rich text HTML editor. No WebViews, no JavaScript—built entirely for native performance and full control.

[![Pub Version](https://img.shields.io/pub/v/flutter_smart_editor)](https://pub.dev/packages/flutter_smart_editor)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

`flutter_smart_editor` is a full-featured WYSIWYG editor designed from scratch to eliminate the overhead and bugs associated with WebView-based editors. It provides a premium, Material 3 experience with clean HTML input/output.

## 📌 Table of Contents

- [✨ Features](#-features)
- [🚀 Getting Started](#-getting-started)
- [📖 Basic Usage](#-basic-usage)
- [⚙️ Detailed Configuration](#️-detailed-configuration)
  - [1. SmartEditorSettings](#1-smarteditorsettings)
    - [Core & HTML](#core--html)
    - [Scroll & Layout](#scroll--layout)
    - [Keyboard](#keyboard)
    - [Selection & Cursor](#selection--cursor)
    - [Style & Decoration](#style--decoration)
    - [Lists & Horizontal Rules](#lists--horizontal-rules)
    - [Links](#links)
    - [Callbacks](#callbacks)
  - [🔗 Links & URL Detection](#-links--url-detection)
  - [🖼️ Images](#️-images)
    - [Inserting images](#inserting-images)
    - [The upload / swap hook](#the-upload--swap-hook-onimageinsert)
    - [Sizing & resize](#sizing--resize)
    - [Supported formats](#supported-formats)
    - [Enabling AVIF / SVG / other formats](#enabling-avif--svg--other-formats)
  - [2. SmartToolbarSettings](#2-smarttoolbarsettings)
    - [Layout & Position](#layout--position)
    - [Content](#content)
    - [Container Styling](#container-styling)
    - [Button & Text Styling](#button--text-styling)
    - [Dropdown Styling](#dropdown-styling)
    - [Interceptors](#interceptors)
  - [3. Interactive List Customization](#3-interactive-list-customization)
    - [Enabling the Bullet Picker](#enabling-the-bullet-picker)
    - [Customizing Available Styles](#customizing-available-styles)
    - [Custom Serialization Example](#custom-serialization-example)
  - [4. Programmatic Table & List APIs](#4-programmatic-table--list-apis)
- [🎛️ Toolbar Customization](#️-toolbar-customization)
- [🏃 Migration Guide](#-migration-guide-v10x--v200)
- [🛠️ Upcoming Features](#️-upcoming-features)
- [❓ Troubleshooting](#-troubleshooting)
- [📄 License](#-license)

## ✨ Features

### 🎨 Formatting & Styling

- **Inline Styles**: Bold, Italic, Underline, and Strikethrough.
- **Dynamic Fonts**: Custom Font Family and Font Size selection.
- **Rich Colors**: Foreground (text) and Highlight (background) color pickers.
- **Block Types**: Paragraphs and Headings (H1–H6).
- **Alignment**: Left, Center, Right, and Justify.
- **Smart Links**: Auto-detects bare URLs (no `<a>` needed), renders them tappable in read-only mode (long-press to copy), and serializes `target="_blank"` by default. All toggleable.

### 🧩 Core Editor Capabilities

- **Pure HTML**: Clean output and robust parsing of existing HTML content.
- **Dynamic Height**: The editor expands as you type and can be limited via `maxLines`.
- **Native Paste**: Premium clipboard support—paste rich text/HTML from browsers and other apps.
- **Lists (v2.1+)**: Robust, atomic Bullet and Numbered lists with smart reordering.
- **Tables (v2.1+)**: Full support for HTML tables with dynamic row/column management (insertion, deletion, and cell updates).
- **Images**: First-class `<img>` support — render remote URLs, base64 `data:` URIs, and pasted/clipboard bytes; insert from the toolbar or paste; an async upload/swap hook; px/% sizing with an in-editor resize menu; and a pluggable codec API for AVIF/SVG/etc. (WebView-free).
- **Mobile Optimized**: Smart backspace bridge for soft keyboards and accessory bar avoidance.
- **Undo/Redo**: Built-in history management.
- **Material 3 Toolbar**: **Scrollable**, **Grid**, or **Expandable** layouts.

---

## 🚀 Getting Started

Add `flutter_smart_editor` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_smart_editor: ^2.1.0
```

## 📖 Basic Usage

```dart
import 'package:flutter_smart_editor/flutter_smart_editor.dart';

// ... inside your widget ...
SmartEditor(
  controller: _controller,
  editorSettings: const SmartEditorSettings(
    hint: 'Start typing...',
    initialText: '<p>Hello <b>World</b></p>',
  ),
  toolbarSettings: const SmartToolbarSettings(
    toolbarType: SmartToolbarType.scrollable,
  ),
)
```

---

## ⚙️ Detailed Configuration

### 1. `SmartEditorSettings`

#### Core & HTML

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `initialText` | `String?` | `null` | The starting HTML content in the editor. |
| `hint` | `String?` | `null` | Placeholder text shown when the editor is empty. |
| `defaultFontSize` | `double` | `16.0` | The base font size for paragraph text. |
| `darkMode` | `bool?` | `null` | Force light or dark mode. If null, follows system brightness. |
| `disabled` | `bool` | `false` | Completely disables interaction and grays out the editor. |
| `readOnly` | `bool` | `false` | Disables text input but allows selection and copying. |
| `maxLines` | `int?` | `null` | Max height in lines before scrolling. `null` = grows indefinitely. |
| `characterLimit` | `int?` | `null` | Max number of characters allowed in the editor. |
| `spellCheck` | `bool` | `false` | Enables browser/OS native spell checking. |
| `processInputHtml` | `bool` | `true` | Sanitizes and prepares input HTML string. |
| `processOutputHtml` | `bool` | `true` | Cleans up empty tags in the produced HTML output. |
| `processNewLineAsBr` | `bool` | `false` | Converts `\n` to `<br>` in input strings. |

#### Scroll & Layout

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `autoAdjustHeight` | `bool` | `true` | Allows the editor to grow vertically as the user types. |
| `ensureVisible` | `bool` | `false` | Scrolls the editor into view when it gains focus. |
| `scrollPhysics` | `ScrollPhysics?` | `null` | Custom physics for the editor's scroll view. |

#### Keyboard

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `inputType` | `SmartInputType` | `.text` | The type of virtual keyboard to display. |
| `autofocus` | `bool` | `false` | Opens the keyboard immediately on mount. |
| `textInputAction` | `TextInputAction?` | `null` | The action button on the keyboard (e.g. Done, Search). |
| `keyboardAppearance` | `Brightness?` | `null` | Force a dark or light keyboard on iOS. |
| `adjustForKeyboard` | `bool` | `true` | Automatically shrinks the editor when the keyboard appears. |

#### Selection & Cursor

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `cursorColor` | `Color?` | `Theme` | The color of the blinking vertical text cursor. |
| `cursorWidth` | `double` | `2.0` | Width of the cursor in logical pixels. |
| `cursorRadius` | `Radius?` | `Circular(2)` | Corner rounding of the cursor tip. |
| `cursorHeight` | `double?` | `null` | Fixed height for the cursor. |
| `showCursor` | `bool` | `true` | Whether to show the blinking cursor at all. |
| `selectionColor` | `Color?` | `Theme` | Background color for highlighted text. |
| `selectionHandleColor` | `Color?` | `Theme` | Color of the drag handles on mobile. |
| `enableInteractiveSelection` | `bool` | `true` | Allows users to select text via tap/hold. |

#### Style & Decoration

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `decoration` | `BoxDecoration?` | `null` | Decoration around the **entire editor container**. |
| `editorDecoration` | `BoxDecoration?` | `null` | Decoration around **just the text input area**. |
| `editorPadding` | `EdgeInsets` | `all(12)` | Internal padding of the text input area. |
| `editorBackgroundColor` | `Color?` | `null` | Background color of the editing area. |
| `borderRadius` | `BorderRadius?` | `null` | Rounded corners for the default editor border. |

#### Lists & Horizontal Rules

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `maxListDepth` | `int` | `3` | Maximum nesting depth for lists (1-5 recommended). |
| `defaultBulletStyle` | `SmartBulletStyle` | `.filledCircle` | Default bullet shape for unordered lists. |
| `hrStyle` | `SmartHrStyle` | `(defaults)` | Visual configuration for Horizontal Rule dividers. |
| `draggableBlockTypes` | `Set<BlockType>` | `null` | Types of blocks that show reordering handles (e.g. `{BlockType.bulletList}`). |

#### Links

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `autoDetectLinks` | `bool` | `true` | Auto-converts bare `http(s)://` / `www.` URLs into links on load, `setText`, `insertHtml`, and paste. Set `false` to honour only explicit `<a>` tags. |
| `onLinkTap` | `void Function(String url)?` | `null` | Called with the `href` when a link is tapped in **read-only** mode. `null` = links are styled but inert. (Taps never fire inside the editable editor — a Flutter limitation.) |
| `onLinkLongPress` | `void Function(String url)?` | `null` | Called when a link is **long-pressed** in read-only mode. The url is always copied to the clipboard first; if this is `null`, a default "Link copied" SnackBar is shown. Provide it to show your own toast/feedback. |
| `linkStyle` | `TextStyle?` | `null` | Style merged over the default link appearance (blue `#1A73E8` + underline). Applies in both edit and read-only modes. |
| `linkTargetBlank` | `bool` | `true` | When `true`, serialized `<a>` tags get `target="_blank" rel="noopener noreferrer"`. Set `false` to omit both. |

#### Callbacks

| Callback | Signature | Description |
| --- | --- | --- |
| `onChangeContent` | `(String? html)` | Triggered whenever text or formatting changes. |
| `onFocus` | `()` | Triggered when the editor gains focus. |
| `onBlur` | `()` | Triggered when the editor loses focus. |
| `onInit` | `()` | Triggered when the editor is fully initialized. |
| `onEnter` | `()` | Triggered when the Enter/Return key is pressed. |
| `onChangeSelection` | `(Map<String, dynamic>)` | Triggered when cursor moves; provides active formatting state. |
| `onPaste` | `()` | Triggered when content is pasted into the editor. |
| `onLinkTap` | `(String url)` | Triggered when a link is tapped in read-only mode (see [Links & URL Detection](#-links--url-detection)). |
| `onLinkLongPress` | `(String url)` | Triggered when a link is long-pressed in read-only mode (the url is copied first). |
| `onTagSerialize` | `(Type, Tag, Attr, Styles, Content)` | Custom tag serialization interceptor (see below). |
| `onKeyUp` / `onKeyDown` | `(String? key)` | Raw key event callbacks. |

### 🛠️ Interactive List Customization

Version 2.1.0 introduces the ability for users to live-change their bullet point symbols (pointers).

#### Enabling the Bullet Picker

To show the bullet style picker in your toolbar, ensure `listStyles` is enabled in your `SmartListButtons` group:

```dart
SmartToolbarSettings(
  defaultButtons: [
    const SmartListButtons(
      ul: true,
      ol: true,
      listStyles: true, // Enables the style picker button
    ),
  ],
)
```

#### Customizing Available Styles

You can filter which pointers are available to the user:

```dart
SmartListButtons(
  listStyles: true,
  availableStyles: [
    SmartBulletStyle.filledCircle,
    SmartBulletStyle.diamond,
    SmartBulletStyle.star,
  ],
)
```

#### Custom Serialization Example

You can intercept any HTML tag before it is written to the output. The `styles` map allows you to precisely modify inline CSS properties without string parsing.

```dart
SmartEditorSettings(
  onTagSerialize: (type, tag, attributes, styles, content) {
    if (type == SmartTagType.bold) {
      // Add custom inline style to bold tags
      styles['color'] = 'royal-blue';
      return null; // Return null to let the editor build the final HTML using modified styles
    }
    
    if (type == SmartTagType.heading1) {
      // Completely replace h1 with a styled div
      return '<div class="h1-alternate" style="text-shadow: 1px 1px #eee;">$content</div>';
    }
    
    return null;
  },
)
```

### 🔗 Links & URL Detection

The editor understands links end-to-end — parsing, auto-detection, styling, clickable rendering, and serialization.

#### Automatic detection

With `autoDetectLinks` enabled (the default), bare URLs are turned into real links automatically — no `<a>` tag required:

- `https://example.com` and `www.example.com` are recognised (the `www.` form gets an `https://` scheme in the `href`).
- Detection runs on initial `initialText`, `setText`, `insertHtml`, **and on paste** — pasting a URL into the editor "promotes" it to a link.
- Trailing sentence punctuation (`.`, `,`, `)`, …) is kept out of the link.
- Text already inside an `<a>` is never double-wrapped.

Because detected links live in the document model, they round-trip to `<a href="…">` on output. Set `autoDetectLinks: false` to honour only explicit `<a>` tags.

#### Clickable links in read-only mode

Links render blue + underlined in both edit and read-only modes. They become **tappable in read-only mode** — provide an `onLinkTap` callback to handle the tap (open a browser, route in-app, etc.):

```dart
SmartEditor(
  controller: controller,
  editorSettings: SmartEditorSettings(
    readOnly: true,
    initialText: '<p>Visit https://flutter.dev for docs.</p>',
    onLinkTap: (url) async {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri); // e.g. via the url_launcher package
      }
    },
  ),
)
```

> **Note:** taps only fire in **read-only** mode. Inside the editable editor, Flutter's `EditableText` consumes pointer events, so links there are styled but not tappable — the standard behavior for rich-text editors.

#### Long-press to copy

Long-pressing a link in read-only mode **copies its URL to the clipboard**. By default a small "Link copied" SnackBar is shown (when a `ScaffoldMessenger` is in the tree). Provide `onLinkLongPress` to show your own feedback instead — e.g. a native OS toast:

```dart
SmartEditorSettings(
  readOnly: true,
  onLinkLongPress: (url) {
    // The url has already been copied to the clipboard.
    Fluttertoast.showToast(msg: 'Link copied'); // your own toast
  },
)
```

> **Selection trade-off:** a Flutter `TextSpan` supports only one gesture recognizer, so a link can't carry both tap and long-press at the span level. Blocks **containing a link** are therefore rendered as non-selectable rich text (tap opens, long-press copies); link-free blocks remain fully drag-selectable.

#### Styling and `target="_blank"`

```dart
SmartEditorSettings(
  // Customize link appearance (merged over the blue + underline default).
  linkStyle: const TextStyle(color: Colors.deepPurple),

  // Output <a> tags open in a new tab by default:
  //   <a href="…" target="_blank" rel="noopener noreferrer">
  // Set false for plain <a href="…">.
  linkTargetBlank: true,
)
```

### 🖼️ Images

Images are first-class, modeled as a standalone block (`ImageNode`) — not an inline glyph — so they render with a real `Image` widget and sidestep the caret/selection fragility of `WidgetSpan`s inside an editable `TextField`. An `<img>` met mid-paragraph is **promoted** to its own block (surrounding text is preserved).

Everything round-trips through parse → model → serialize: `src`, `alt`, `title`, sizing (px **and** %), alignment, and **every other `<img>` attribute** (`loading`, `srcset`, `crossorigin`, `usemap`, `data-*`, …) is preserved verbatim.

```dart
// Rendering existing content needs no configuration — URLs and data: URIs just work.
SmartEditor(
  controller: controller,
  editorSettings: SmartEditorSettings(
    initialText: '<img src="https://example.com/photo.jpg" alt="A photo" width="320">',
  ),
)
```

#### Inserting images

Three ways in, all routed through the same pipeline:

- **Toolbar** — the picture button (`SmartInsertButtons(picture: true)`, on by default). It calls your `onImagePickRequested` (wire it to `image_picker`/`file_picker`/your gallery) or, if you provide none, falls back to a built-in **"image URL"** dialog. The package ships no picker dependency.
- **Paste** — pasting image bytes from the clipboard inserts an image block; pasting HTML containing `<img>` goes through the parser.
- **Programmatically** — `await controller.insertImage(ImageInsertRequest(src: 'https://…', origin: ImageInsertSource.toolbar))`.

```dart
SmartEditorSettings(
  // Host-supplied picker for the toolbar button. Return null to cancel.
  onImagePickRequested: () async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return null;
    return ImageInsertRequest(
      bytes: await file.readAsBytes(),
      mimeType: 'image/jpeg',
      origin: ImageInsertSource.toolbar,
    );
  },
)
```

> With **no** `onImageInsert` hook, pasted/picked **bytes** are embedded as a base64 `data:` URI so images work out-of-the-box. Provide the hook below to upload instead.

#### The upload / swap hook (`onImageInsert`)

This is the central integration point: intercept every inserted image, do whatever you want (upload to a CDN/S3, resize, moderate), and return the canonical `src` to store. Returning `null` cancels the insert.

```dart
SmartEditorSettings(
  onImageInsert: (req) async {
    // req.bytes (paste/pick) or req.src (URL / data: URI); req.origin tells you which path.
    final bytes = req.bytes ?? await fetchOrDecode(req.src!);
    final url = await myUploader.upload(bytes, mime: req.mimeType); // → CDN URL
    return ImageInsertResult(src: url); // optionally alt / width / height too
  },

  // Also rewrite base64 data: URIs found in *loaded* HTML (upload-and-swap on load).
  resolveDataUris: true,
)
```

`ImageInsertRequest.origin` is `toolbar`, `paste`, or `parse` (the last for `resolveDataUris`), so upload policy can differ per source.

#### Sizing & resize

Width/height support **px**, **%**, and `auto`, round-tripped through both the legacy `width="…"` attribute and CSS `style="width:…"` (CSS wins when both are present). In edit mode, a resize menu on each image offers **Original / 25% / 50% / 75% / 100% / custom px or %** (each change is one undo step).

```dart
SmartEditorSettings(
  allowImageResize: true,                       // show the in-editor resize menu (default)
  defaultImageWidth: const ImageSize.percent(100), // applied to inserts that declare no size
  maxImageWidth: 600,                           // clamp rendered display width (px)
)

// …or resize programmatically:
controller.resizeImage(blockIndex, width: const ImageSize.percent(50));
```

Tap handling and load failures:

```dart
SmartEditorSettings(
  onImageTap: (node) => print('tapped ${node.src}'),     // read-only and edit
  onImageError: (node, error) => log('image failed', error), // UI shows a placeholder regardless
)
```

#### Supported formats

This package is **WebView-free**, so images decode through Flutter's `dart:ui` codec. With **no extra dependencies** you get, for both remote URLs and base64 `data:` URIs:

| Format | Built-in | Notes |
| --- | --- | --- |
| JPEG | ✅ | |
| PNG | ✅ | |
| GIF | ✅ | animated plays automatically |
| WebP | ✅ | animated + lossless |
| BMP / WBMP | ✅ | |
| **AVIF, SVG, HEIC, TIFF, ICO, Lottie** | ⚙️ handler | no `dart:ui` decoder — register a handler (below) |

> **Paste note:** clipboard image bytes for any of the above are detected and embedded; handler-required formats then render only if a handler is registered (otherwise they're stored + round-tripped, shown as the placeholder). Raw **AVIF on the clipboard** is best-effort — most OSes transcode pasted raster images to PNG, so AVIF normally arrives via URL/`data:`/HTML instead.

#### Enabling AVIF / SVG / other formats

Because there's no WebView, the package can't decode AVIF/SVG itself (that would drag in FFI/native codecs). Instead you plug a codec in your **app** via `imageFormatHandlers` — an ordered list of `(matches, build)` pairs; the first whose `matches(ctx)` is true renders the image. The package keeps the chrome (sizing, alignment, resize, tap, error placeholder); the handler only produces the pixels.

**AVIF** (add `flutter_avif` to your app) — render-side only, no parser flag:

```dart
SmartEditorSettings(
  imageFormatHandlers: [
    ImageFormatHandler(
      matches: (c) => c.isAvif,
      build: (c) => c.bytes != null
          ? AvifImage.memory(c.bytes!, width: c.width, height: c.height, fit: c.fit)
          : AvifImage.network(c.src, width: c.width, height: c.height, fit: c.fit),
    ),
  ],
)
```

`ctx.bytes` is pre-decoded for `data:` URIs, so a base64-embedded `data:image/avif;…` works through the same handler.

**SVG has two shapes**, and one registered handler wires both:

1. **SVG as an image** — `<img src="x.svg">` or `data:image/svg+xml;…`.
2. **Inline `<svg>…</svg>` markup** — sitting directly in the HTML, not inside an `<img>`.

```dart
SmartEditorSettings(
  // Registering an isSvg handler auto-enables inline-<svg> capture — no flag needed.
  // (Opt out with parseInlineSvg: false; force capture without a handler with true.)
  imageFormatHandlers: [
    ImageFormatHandler(
      matches: (c) => c.isSvg,
      build: (c) {
        if (c.rawSvg != null) return SvgPicture.string(c.rawSvg!, width: c.width, height: c.height);
        if (c.bytes  != null) return SvgPicture.memory(c.bytes!, width: c.width, height: c.height);
        return SvgPicture.network(c.src, width: c.width, height: c.height);
      },
    ),
  ],
)
```

> **Why inline `<svg>` needs the parser, but `<img src=*.svg>` doesn't:** the parser only dispatches `<img>` by default, so raw inline `<svg>` markup would be dropped. To preserve it (captured verbatim into `ImageNode.rawSvg` and re-serialized), capture must be enabled — which a registered `isSvg` handler does automatically (`parseInlineSvg` is tri-state: `null` = auto, `true`/`false` = explicit). An SVG handler must key its `matches` off `ctx.isSvg` for the auto-probe to detect it.

> If you only have a Flutter-decodable format but a custom **loader** (auth'd / cached / file / asset), use `imageProvider` instead — return any `ImageProvider` (e.g. `CachedNetworkImageProvider`) and the package handles the rest. It's consulted after `imageFormatHandlers`.

A complete runnable wiring (AVIF + SVG) lives in [`example/`](example/).

### 4. Programmatic Table & List APIs

`SmartEditorController` provides a rich set of programmatic APIs to manipulate tables and lists dynamically from your parent widgets, custom toolbar buttons, or keyboard listeners.

#### 📊 Table Management APIs

When the user is interacting with tables, you can use these controller methods to perform programmatic modifications:

| Method / Getter | Return Type | Description |
| :--- | :--- | :--- |
| `insertTable({int rows, int cols})` | `void` | Inserts a new responsive HTML table grid with specified dimensions after the active block. |
| `insertRow()` | `void` | Inserts a new table row below the currently focused table cell. |
| `insertColumn()` | `void` | Inserts a new table column to the right of the currently focused table cell. |
| `deleteRow()` | `void` | Deletes the row containing the currently focused table cell. |
| `deleteColumn()` | `void` | Deletes the column containing the currently focused table cell. |
| `deleteTable()` | `void` | Deletes the entire focused table block. |
| `isInsideTable` | `bool` | Returns `true` if the caret/cursor is currently inside a table cell. |
| `focusedTableInfo` | `({int blockIndex, int row, int col})?` | Returns the exact coordinate position of the focused cell, or `null`. |

##### Code Example: Context-Aware Table Modification
```dart
final controller = SmartEditorController();

// 1. Insert a 3x3 table programmatically
controller.insertTable(rows: 3, cols: 3);

// 2. perform context-aware row addition
if (controller.isInsideTable) {
  print("Focused cell coordinates: ${controller.focusedTableInfo}");
  
  // Add a new row below the focused cell
  controller.insertRow();
}
```

#### 🔢 List & Numbered List APIs

To toggle lists and adjust indentation programmatically:

| Method / Getter | Arguments | Description |
| :--- | :--- | :--- |
| `setBlockType(BlockType type)` | `BlockType.bulletList` | Converts the active block to an Unordered Bullet List (`<ul>`). |
| `setBlockType(BlockType type)` | `BlockType.orderedList` | Converts the active block to an Ordered Numbered List (`<ol>`). |
| `setBlockType(BlockType type)` | `BlockType.paragraph` | Converts a list item back to standard paragraph text (`<p>`). |
| `documentController.increaseIndent(int blockIndex)` | `blockIndex` | Increases list nesting depth/indentation (supports up to 3 levels). |
| `documentController.decreaseIndent(int blockIndex)` | `blockIndex` | Decreases list nesting depth/outdents the list block. |

##### Code Example: Programmatic List Customization
```dart
final controller = SmartEditorController();

// Convert current block to a Bullet List
controller.setBlockType(BlockType.bulletList);

// Convert current block to a Numbered List
controller.setBlockType(BlockType.orderedList);

// Increase Indentation on the active block index
final activeIndex = controller.documentController.focusedBlockIndex;
controller.documentController.increaseIndent(activeIndex);
```

---

## 🎛️ Toolbar Customization

The toolbar is built using modular button groups. You can fully customize which groups appear and which specific buttons within those groups are active.

### Full Toolbar Example

Here is how you would configure a toolbar with **every available group** active:

```dart
SmartToolbarSettings(
  toolbarType: SmartToolbarType.expandable,
  defaultButtons: [
    const SmartStyleButtons(),      // Heading 1-6 & Paragraph
    const SmartFontButtons(
      strikethrough: true,
      fontSize: true,
      clearAll: true,
    ),
    const SmartColorButtons(
      foregroundColor: true,
      highlightColor: true,
    ),
    const SmartListButtons(
      ul: true,
      ol: true,
      hr: true,
      listStyles: true,             // Enables interactive bullet picker
    ),
    const SmartFontFamilyButtons(),
    const SmartParagraphButtons(),    // Alignment: Left, Center, Right, Justify
    const SmartOtherButtons(
      undo: true,
      redo: true,
      copy: true,
      paste: true,
    ),
  ],
)
```

### Breakdown of Button Groups

| Group Class | Description |
| --- | --- |
| `SmartStyleButtons` | Controls the paragraph style dropdown (Heading 1 to Heading 6 and Normal text). |
| `SmartFontButtons` | Standard formatting: Bold, Italic, Underline, Strikethrough, Font Size, and Clear Formatting. |
| `SmartColorButtons` | Integrated color pickers for text color and background highlight color. |
| `SmartFontFamilyButtons` | A dropdown for selecting from your application's available font families. |
| `SmartListButtons` | Bullet/Numbered list toggles, horizontal dividers (HR), and the premium Bullet Style Picker. |
| `SmartParagraphButtons` | Text alignment controls: Left, Center, Right, and Full Justify. |
| `SmartOtherButtons` | Utility actions: Undo, Redo, Copy to Clipboard, and Paste. |

---

### 2. `SmartToolbarSettings`

#### Layout & Position

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `toolbarType` | `SmartToolbarType` | `.scrollable` | Layout: `.scrollable`, `.grid`, or `.expandable`. |
| `toolbarPosition` | `SmartToolbarPosition` | `.above` | Position relative to editor: `.above` or `.below`. |
| `initiallyExpanded` | `bool` | `false` | Starts the expandable toolbar in the open state. |
| `showBorder` | `bool` | `false` | Separation border between editor and toolbar. |
| `showSeparators` | `bool` | `true` | Vertical lines between button groups. |
| `itemHeight` | `double` | `36` | Height of individual buttons and chips. |
| `gridSpacingH` | `double` | `5` | Horizontal gap between buttons in grid layout. |
| `gridSpacingV` | `double` | `5` | Vertical gap between buttons in grid layout. |
| `separatorWidget` | `Widget?` | `null` | Custom widget to use as a separator. |

#### Content

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `defaultButtons` | `List<SmartToolbarGroup>` | `[...]` | List of button groups to display. |
| `customButtons` | `List<Widget>` | `[]` | Custom widgets to insert into the toolbar. |
| `customButtonInsertionIndices` | `List<int>` | `[]` | Position indices for custom buttons. |

#### Container Styling

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `decoration` | `BoxDecoration?` | `null` | Styling for the toolbar background/border. |
| `padding` | `EdgeInsets?` | `null` | Internal padding of the toolbar container. |

#### Button & Text Styling

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `buttonColor` | `Color?` | `null` | Base color for toolbar icons. |
| `buttonSelectedColor` | `Color?` | `null` | Icon color when a style is active. |
| `buttonFillColor` | `Color?` | `null` | Background color of the button. |
| `buttonBorderRadius` | `BorderRadius?` | `null` | Corner rounding for buttons. |
| `buttonIconSize` | `double` | `20.0` | Size of the toolbar icons. |
| `textStyle` | `TextStyle?` | `null` | Style for text labels in the toolbar. |

#### Dropdown Styling

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `dropdownBackgroundColor` | `Color?` | `null` | Background color of popup menus. |
| `dropdownElevation` | `int` | `8` | Shadow depth for popup menus. |
| `dropdownItemHeight` | `double?` | `null` | Height of items inside dropdowns. |
| `dropdownIconSize` | `double` | `24` | Size of the dropdown arrow icon. |

#### Interceptors

| Callback | Signature | Description |
| --- | --- | --- |
| `onButtonPressed` | `(Type, bool, Fn)` | Intercept any button click to add custom logic. |
| `onDropdownChanged` | `(Type, val, Fn)` | Intercept any dropdown selection change. |

---

## 🏃 Migration Guide (v1.0.x ➔ v2.x.x)

Version 2.x.x introduces a **Unified Settings API**. Instead of separate `ScrollSettings`, `KeyboardSettings`, etc., all editor-related properties are now in `SmartEditorSettings`.

**Old:**

```dart
SmartEditor(
  scrollSettings: SmartScrollSettings(autoAdjustHeight: true),
  styleSettings: SmartStyleSettings(editorPadding: EdgeInsets.all(16)),
)
```

**New:**

```dart
SmartEditor(
  editorSettings: SmartEditorSettings(
    autoAdjustHeight: true,
    editorPadding: EdgeInsets.all(16),
  ),
)
```

## 🛠️ Upcoming Features

- [ ] **Markdown Shortcuts**: Auto-format headers and lists during typing.
- [ ] **Find & Replace**: Native search overlay with match highlighting.
- [x] **Image Blocks**: Network/`data:`/pasted images, upload-swap hook, px/% resize menu, and a pluggable AVIF/SVG codec API. _(Freehand drag-resize handles still planned.)_
- [ ] **Code Blocks**: Syntax highlighting for 100+ languages.
- [x] **Hyperlinks**: URL auto-detection, clickable read-only links, and `target="_blank"` output. _(Insertion/management dialogs still planned.)_
- [ ] **Focus Mode**: Zen mode for distraction-free writing.
- [ ] **Live Statistics**: Real-time word, character, and reading time counters.
- [ ] **Auto-Save**: Background persistence and draft recovery.
- [ ] **AI Assistant**: context-aware writing improvements and summaries.
- [ ] **PDF Export**: Generate high-quality PDFs directly from Dart.
- [ ] **Real-time Sync**: Collaborative editing via WebSocket/CRDT.
- [ ] **Slash Commands**: Notion-style `/` menu for quick block insertion.
- [ ] **Mobile Haptics**: Tactile feedback for editing actions.

## ❓ Troubleshooting

### Failed to load 'libsuper_native_extensions.so'

If you encounter errors when using the **Paste** feature:

1. `flutter clean`
2. `flutter pub get`
3. Perform a **cold start** (full rebuild) of the app. This is required to bundle the native clipboard libraries.

## 📄 License

This project is licensed under the MIT License.
