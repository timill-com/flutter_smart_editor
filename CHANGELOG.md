# Changelog

## Unreleased

### 🚀 Features

- **URL Auto-Detection**: Bare `http(s)://` / `www.` URLs are converted into links automatically on load, `setText`, `insertHtml`, and **paste** — no `<a>` tag required. Toggle with `autoDetectLinks` (default `true`).
- **Clickable Read-Only Links**: Read-only blocks now render with a non-editable rich-text widget so link spans are tappable. Provide `SmartEditorSettings.onLinkTap` to handle taps. Links are styled blue + underline in both edit and read-only modes; customize via `linkStyle`.
- **`target="_blank"` Output**: Serialized `<a>` tags get `target="_blank" rel="noopener noreferrer"` by default. Toggle with `linkTargetBlank`.

### 🛠️ Bug Fixes

- **Resilient Clipboard Polling**: `canPaste` state updates no longer throw when the native clipboard channel is unavailable (e.g. in widget tests or on platforms without the plugin).

## 2.1.0

### 🚀 Features

- **Intelligent List System**: Full support for Bullet and Numbered lists with multiple levels/depths.
- **Atomic Group Reordering**: Move entire list groups as a single unit via drag-and-drop.
- **Smart Deletion (Backspace)**: Multi-stage backspace logic (Out-dent -> Un-list -> Merge) and instant empty-item deletion.
- **Mobile Optimized Backspace**: Custom ZWSP Bridge to support software keyboards on iOS and Android.
- **Semantic Tables**: Insert and manage fully responsive HTML tables with interactive dynamic row and column insertion and deletion.

### ⚙️ Setting Updates

- **`draggableBlockTypes`**: Granular control over which blocks (Headings, Lists, etc.) display drag handles.
- **Improved Keyboard Adaptation**: Dynamic scroll padding to prevent content occlusion by the mobile accessory bar.

### 🛠️ Bug Fixes

- **Visual Alignment**: Unified 32px vertical baseline for all blocks (fixes "jagged" text edges).
- **Index Drift**: Resolved reordering errors in large, complex documents.
- **Focus Stability**: Smoother cursor and focus preservation after block type transitions and indentation changes.

## 2.0.0

- **Font Customization**: Added Font Family and Font Size pickers.
- **Color Support**: Integrated foreground and background (highlight) color pickers.
- **Paragraph Alignment**: Added support for Left, Center, Right, and Justify alignment.
- **Line Height**: Configurable line height per block.
- **Clear Formatting**: One-click tool to reset text style in a selection.
- **Visual Refinements**: Tightened editor layout with `isDense` mode and optimized vertical spacing.
- **Stability**: Added 25+ unit tests covering all Phase 2 extended formatting features.

## 1.0.1

- Initial release
- Core editing: paragraphs, headings (H1-H6)
- Inline formatting: bold, italic, underline, strikethrough
- Undo/redo support
- HTML parsing and serialization
- Native Flutter toolbar
- 6 granular settings classes
- Dark mode support
