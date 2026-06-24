import 'package:flutter/painting.dart';
import '../document/document.dart';
import '../../models/enums.dart';
import '../../models/image_size.dart';

/// Converts a [Document] tree into an HTML string.
///
/// Produces clean, minimal HTML by merging inline formatting tags
/// and only outputting attributes when they differ from defaults.
class SmartHtmlSerializer {
  SmartHtmlSerializer({this.onTagSerialize, this.linkTargetBlank = true});

  /// When true, serialized `<a>` tags get `target="_blank"` and
  /// `rel="noopener noreferrer"` so links open in a new tab in a browser.
  bool linkTargetBlank;

  /// Custom tag serialization callback.
  String? Function(
      SmartTagType type,
      String tag,
      Map<String, String> attributes,
      Map<String, String> styles,
      String content)? onTagSerialize;

  /// Serializes a [Document] into an HTML string.
  String serialize(Document document) {
    final buffer = StringBuffer();
    final blocks = document.blocks;
    int i = 0;

    while (i < blocks.length) {
      final block = blocks[i];

      if (block is HorizontalRuleNode) {
        buffer.write(_serializeHr(block));
        i++;
        continue;
      }

      if (block is ImageNode) {
        buffer.write(_serializeImage(block));
        i++;
        continue;
      }

      if (block is TableNode) {
        buffer.write(_serializeTable(block));
        i++;
        continue;
      }

      if (block is ListItemNode) {
        // Collect the entire contiguous list group
        int end = i;
        while (end < blocks.length - 1 && blocks[end + 1] is ListItemNode) { end++; }
        final group = blocks.sublist(i, end + 1).cast<ListItemNode>();
        buffer.write(_serializeListGroup(group));
        i = end + 1;
        continue;
      }

      _serializeBlock(block, buffer);
      i++;
    }
    final html = buffer.toString();
    // Strip any ZWSP characters used by the mobile backspace bridge
    return html.replaceAll('\u200B', '');
  }

  /// Serializes a [TableNode] into `<table>` HTML.
  String _serializeTable(TableNode table) {
    final buf = StringBuffer();

    // Table opening with optional onTagSerialize callback
    final customTable = onTagSerialize?.call(
        SmartTagType.table, 'table', {}, {}, '');
    if (customTable != null) return customTable;

    buf.write('<table>');

    for (int r = 0; r < table.rows.length; r++) {
      final isHeader = table.hasHeaderRow && r == 0;

      // Row opening
      final customRow = onTagSerialize?.call(
          SmartTagType.tableRow, 'tr', {}, {}, '');
      if (customRow == null) buf.write('<tr>');

      for (final cell in table.rows[r]) {
        final cellTag = isHeader ? 'th' : 'td';
        final cellType = isHeader ? SmartTagType.tableHeaderCell : SmartTagType.tableCell;

        // Build cell content
        final contentBuf = StringBuffer();
        if (cell.block is ListItemNode) {
          contentBuf.write(_serializeListGroup([cell.block as ListItemNode]));
        } else if (cell.block is ParagraphNode) {
          for (final span in cell.spans) {
            _serializeSpan(span, contentBuf);
          }
        } else {
          _serializeBlock(cell.block, contentBuf);
        }

        // Build cell styles
        final cellStyles = <String, String>{};
        if (cell.alignment != SmartTextAlign.left) {
          cellStyles['text-align'] = _alignToCSS(cell.alignment);
        }
        if (cell.backgroundColor != null) {
          cellStyles['background-color'] = '#${_colorToHex(cell.backgroundColor!)}';
        }

        final cellContent = contentBuf.toString();
        final customCell = onTagSerialize?.call(
            cellType, cellTag, {}, cellStyles, cellContent);
        if (customCell != null) {
          buf.write(customCell);
        } else {
          if (cellStyles.isNotEmpty) {
            final styleStr = cellStyles.entries
                .map((e) => '${e.key}: ${e.value}')
                .join('; ');
            buf.write('<$cellTag style="$styleStr">$cellContent</$cellTag>');
          } else {
            buf.write('<$cellTag>$cellContent</$cellTag>');
          }
        }
      }

      if (customRow == null) buf.write('</tr>');
    }

    buf.write('</table>');
    return buf.toString();
  }

  /// Serializes a [HorizontalRuleNode] as `<hr/>`
  String _serializeHr(HorizontalRuleNode block) {
    final custom = onTagSerialize?.call(
        SmartTagType.horizontalRule, 'hr', {}, {}, '');
    return custom ?? '<hr/>';
  }

  /// Serializes an [ImageNode] as a void `<img …/>`, with sizing emitted both as
  /// bare attributes (px only — max compatibility) and CSS `style`, and every
  /// preserved attribute re-emitted. Inline-SVG nodes re-emit their raw markup.
  String _serializeImage(ImageNode b) {
    // Inline <svg> captured verbatim — re-emit as-is (still interceptable).
    if (b.rawSvg != null) {
      final custom =
          onTagSerialize?.call(SmartTagType.image, 'svg', {}, {}, b.rawSvg!);
      return custom ?? b.rawSvg!;
    }

    final attrs = <String, String>{'src': b.src};
    if (b.alt.isNotEmpty) attrs['alt'] = b.alt;
    if (b.title != null) attrs['title'] = b.title!;
    // px sizing also emitted as bare attrs (old renderers ignore CSS).
    if (b.width?.unit == ImageSizeUnit.px) {
      attrs['width'] = b.width!.value!.round().toString();
    }
    if (b.height?.unit == ImageSizeUnit.px) {
      attrs['height'] = b.height!.value!.round().toString();
    }
    // Preserve all round-tripped attributes (loading, srcset, crossorigin, …)
    // without clobbering the typed ones above.
    b.attributes.forEach((k, v) => attrs.putIfAbsent(k, () => v));

    final styles = <String, String>{};
    if (b.width != null) styles['width'] = b.width!.toCss();
    if (b.height != null) styles['height'] = b.height!.toCss();
    // Responsive cap (D-A6): always emitted so neither `%` nor `px` sizes
    // overflow a narrower viewport on web or in-app. Round-trips cleanly —
    // the parser matches the exact `width` key, so `max-width` is ignored.
    styles['max-width'] = '100%';
    if (b.alignment == SmartTextAlign.center) {
      styles['display'] = 'block';
      styles['margin'] = '0 auto';
    } else if (b.alignment == SmartTextAlign.right) {
      styles['float'] = 'right';
    }

    return _wrapImgTag(SmartTagType.image, attrs, styles, b);
  }

  /// Void-element variant of [_wrapTag] for `<img>`: still calls
  /// [onTagSerialize] (identical interceptor contract) but emits `<img …/>`
  /// with no closing tag.
  String _wrapImgTag(
    SmartTagType type,
    Map<String, String> attributes,
    Map<String, String> styles,
    ImageNode block,
  ) {
    final custom = onTagSerialize?.call(type, 'img', attributes, styles, '');
    if (custom != null) return custom;

    if (styles.isNotEmpty) {
      attributes['style'] =
          styles.entries.map((e) => '${e.key}: ${e.value}').join('; ');
    }
    final attrString = attributes.entries
        .map((e) => ' ${e.key}="${_escapeAttr(e.value)}"')
        .join('');
    return '<img$attrString/>';
  }

  /// Serializes a contiguous group of [ListItemNode]s into nested <ul>/<ol> HTML.
  String _serializeListGroup(List<ListItemNode> items) {
    final buffer = StringBuffer();
    // Stack tracks (listType, depth) of open wrappers
    final openStack = <({SmartListType listType, int depth})>[];

    // Helper to get CSS list-style-type for a bullet style
    String? bulletCss(SmartBulletStyle? style) {
      if (style == null) return null;
      switch (style) {
        case SmartBulletStyle.filledCircle: return 'disc';
        case SmartBulletStyle.hollowCircle: return 'circle';
        case SmartBulletStyle.filledSquare: return 'square';
        case SmartBulletStyle.hollowSquare: return "'\u25a1'";
        case SmartBulletStyle.diamond: return "'\u25c6'";
        case SmartBulletStyle.hollowDiamond: return "'\u25c7'";
        case SmartBulletStyle.arrow: return "'\u2192'";
        case SmartBulletStyle.doubleArrow: return "'\u00bb'";
        case SmartBulletStyle.dash: return "'\u2013'";
        case SmartBulletStyle.star: return "'\u2605'";
        case SmartBulletStyle.hollowStar: return "'\u2606'";
        case SmartBulletStyle.checkmark: return "'\u2713'";
        case SmartBulletStyle.triangle: return "'\u25b6'";
      }
    }

    // Compute ordered counters per (depth, contiguous group)
    // counter[depth] resets each time we go up to a shallower or different type
    final counters = <int, int>{};
    final lastDepthType = <int, SmartListType>{};

    for (int idx = 0; idx < items.length; idx++) {
      final item = items[idx];
      final depth = item.depth;
      final currentDepth = openStack.isEmpty ? -1 : openStack.last.depth;

      if (depth > currentDepth) {
        // Open new wrapper(s) for each depth increment
        while (openStack.isEmpty || openStack.last.depth < depth) {
          final newDepth = openStack.isEmpty ? 0 : openStack.last.depth + 1;
          final newType = (newDepth == depth) ? item.listType : item.listType;
          final wrapTag = newType == SmartListType.bullet ? 'ul' : 'ol';
          final styleAttr = (newType == SmartListType.bullet && item.bulletStyle != null)
              ? ' style="list-style-type: ${bulletCss(item.bulletStyle)}"'
              : '';
          final custom = onTagSerialize?.call(
              newType == SmartListType.bullet
                  ? SmartTagType.unorderedList
                  : SmartTagType.orderedList,
              wrapTag, {}, {}, '');
          if (custom == null) buffer.write('<$wrapTag$styleAttr>');
          openStack.add((listType: newType, depth: newDepth));
          counters[newDepth] = 0;
          lastDepthType[newDepth] = newType;
        }
      } else if (depth < currentDepth) {
        // Close wrapper(s) for each depth decrease
        while (openStack.isNotEmpty && openStack.last.depth > depth) {
          final closed = openStack.removeLast();
          final closeTag = closed.listType == SmartListType.bullet ? 'ul' : 'ol';
          buffer.write('</$closeTag>');
        }
        // If type changed at same depth, close old and open new
        if (openStack.isNotEmpty && openStack.last.listType != item.listType) {
          final closed = openStack.removeLast();
          final closeTag = closed.listType == SmartListType.bullet ? 'ul' : 'ol';
          buffer.write('</$closeTag>');
          final wrapTag = item.listType == SmartListType.bullet ? 'ul' : 'ol';
          buffer.write('<$wrapTag>');
          openStack.add((listType: item.listType, depth: depth));
          counters[depth] = 0;
        }
      } else {
        // Same depth — check type changed
        if (openStack.isNotEmpty && openStack.last.listType != item.listType) {
          final closed = openStack.removeLast();
          buffer.write('</${closed.listType == SmartListType.bullet ? 'ul' : 'ol'}>');
          final wrapTag = item.listType == SmartListType.bullet ? 'ul' : 'ol';
          buffer.write('<$wrapTag>');
          openStack.add((listType: item.listType, depth: depth));
          counters[depth] = 0;
        }
      }

      // Compute counter for ordered list
      if (item.listType == SmartListType.ordered) {
        counters[depth] = (counters[depth] ?? 0) + 1;
      }

      // Serialize <li> content
      final contentBuffer = StringBuffer();
      for (final span in item.spans) {
        _serializeSpan(span, contentBuffer);
      }
      final liContent = contentBuffer.toString();
      final custom = onTagSerialize?.call(
          SmartTagType.listItem, 'li', {}, {}, liContent);
      buffer.write(custom ?? '<li>$liContent</li>');
    }

    // Close all remaining open wrappers
    while (openStack.isNotEmpty) {
      final closed = openStack.removeLast();
      final closeTag = closed.listType == SmartListType.bullet ? 'ul' : 'ol';
      buffer.write('</$closeTag>');
    }

    return buffer.toString();
  }

  /// Serializes a single block node into the buffer
  void _serializeBlock(BlockNode block, StringBuffer buffer) {
    final tag = block.tag;
    final attributes = <String, String>{};
    final styles = _buildBlockStyle(block);

    // Serialize inline spans first to get the content
    final contentBuffer = StringBuffer();
    for (final span in block.spans) {
      _serializeSpan(span, contentBuffer);
    }

    // Wrap the block tag
    buffer.write(_wrapTag(
      SmartTagType.block,
      tag,
      attributes,
      styles,
      contentBuffer.toString(),
    ));
  }

  /// Helper to wrap content in a tag, allowing for external interception.
  String _wrapTag(
    SmartTagType type,
    String tag,
    Map<String, String> attributes,
    Map<String, String> styles,
    String content,
  ) {
    // Check for custom interceptor
    final custom = onTagSerialize?.call(type, tag, attributes, styles, content);
    if (custom != null) return custom;

    // Default serialization: Merge styles into attributes if not handled by callback
    if (styles.isNotEmpty) {
      final styleString = styles.entries.map((e) => '${e.key}: ${e.value}').join('; ');
      attributes['style'] = styleString;
    }

    final attrString = attributes.entries
        .map((e) => ' ${e.key}="${_escapeAttr(e.value)}"')
        .join('');
    return '<$tag$attrString>$content</$tag>';
  }

  /// Builds the CSS style map for a block
  Map<String, String> _buildBlockStyle(BlockNode block) {
    final styles = <String, String>{};
    if (block.alignment != SmartTextAlign.left) {
      styles['text-align'] = _alignToCSS(block.alignment);
    }
    return styles;
  }

  /// Converts a [SmartTextAlign] to a CSS value
  String _alignToCSS(SmartTextAlign align) {
    switch (align) {
      case SmartTextAlign.left:
        return 'left';
      case SmartTextAlign.center:
        return 'center';
      case SmartTextAlign.right:
        return 'right';
      case SmartTextAlign.justify:
        return 'justify';
    }
  }

  /// Serializes a single inline span, wrapping text in formatting tags
  void _serializeSpan(TextFormatSpan span, StringBuffer buffer) {
    if (span.text.isEmpty) return;

    String content = _escapeHtml(span.text);

    // 1. Generic Span (Colors, Fonts) - Innermost
    final inlineStyles = <String, String>{};
    if (span.foregroundColor != null) {
      inlineStyles['color'] = '#${_colorToHex(span.foregroundColor!)}';
    }
    if (span.backgroundColor != null) {
      inlineStyles['background-color'] = '#${_colorToHex(span.backgroundColor!)}';
    }
    if (span.fontSize != null) {
      inlineStyles['font-size'] = '${span.fontSize}px';
    }
    if (span.fontFamily != null) {
      inlineStyles['font-family'] = span.fontFamily!;
    }

    if (inlineStyles.isNotEmpty) {
      content = _wrapTag(
        SmartTagType.span,
        'span',
        {},
        inlineStyles,
        content,
      );
    }

    // 2. Strikethrough
    if (span.isStrikethrough) {
      content = _wrapTag(SmartTagType.strikethrough, 's', {}, {}, content);
    }

    // 3. Underline
    if (span.isUnderline) {
      content = _wrapTag(SmartTagType.underline, 'u', {}, {}, content);
    }

    // 4. Italic
    if (span.isItalic) {
      content = _wrapTag(SmartTagType.italic, 'i', {}, {}, content);
    }

    // 5. Bold
    if (span.isBold) {
      content = _wrapTag(SmartTagType.bold, 'b', {}, {}, content);
    }

    // 6. Link wrapping (outermost)
    if (span.linkUrl != null && span.linkUrl!.isNotEmpty) {
      final attrs = <String, String>{'href': span.linkUrl!};
      if (linkTargetBlank) {
        attrs['target'] = '_blank';
        attrs['rel'] = 'noopener noreferrer';
      }
      content = _wrapTag(
        SmartTagType.link,
        'a',
        attrs,
        {},
        content,
      );
    }

    buffer.write(content);
  }

  /// Converts a Color to a hex string (RRGGBB)
  String _colorToHex(Color color) {
    // ignore: deprecated_member_use
    return color.value.toRadixString(16).padLeft(8, '0').substring(2);
  }

  /// Escapes special HTML characters in text
  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }

  /// Escapes special characters in attribute values
  String _escapeAttr(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('"', '&quot;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
  }
}
