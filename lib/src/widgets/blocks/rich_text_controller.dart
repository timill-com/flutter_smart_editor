import 'package:flutter/material.dart';
import '../../core/document/document.dart';

/// Default colour for link spans when no override is provided (Google blue).
const Color kDefaultLinkColor = Color(0xFF1A73E8);

/// Builds the [TextStyle] for a single [TextFormatSpan].
///
/// Shared by the editable [SmartTextEditingController] and the read-only
/// renderer so styling stays identical across modes. Spans carrying a
/// `linkUrl` render blue + underlined by default; [linkStyle] is merged over
/// that for customization.
TextStyle buildSpanTextStyle(
  TextFormatSpan span, {
  required double baseFontSize,
  required FontWeight baseFontWeight,
  required Color defaultColor,
  TextStyle? linkStyle,
}) {
  final isLink = span.linkUrl != null && span.linkUrl!.isNotEmpty;

  final decorations = <TextDecoration>[];
  if (span.isUnderline) decorations.add(TextDecoration.underline);
  if (span.isStrikethrough) decorations.add(TextDecoration.lineThrough);
  if (isLink) decorations.add(TextDecoration.underline);

  final style = TextStyle(
    fontWeight: span.isBold || baseFontWeight == FontWeight.bold
        ? FontWeight.bold
        : FontWeight.normal,
    fontStyle: span.isItalic ? FontStyle.italic : FontStyle.normal,
    decoration: decorations.isEmpty
        ? TextDecoration.none
        : TextDecoration.combine(decorations),
    fontSize: span.fontSize ?? baseFontSize,
    color: span.foregroundColor ?? (isLink ? kDefaultLinkColor : defaultColor),
    backgroundColor: span.backgroundColor,
    fontFamily: span.fontFamily,
  );

  return (isLink && linkStyle != null) ? style.merge(linkStyle) : style;
}

/// A custom [TextEditingController] that renders [TextFormatSpan]s as Flutter [TextSpan]s.
///
/// This controller translates the internal document formatting model into
/// the visual representation used by a standard [TextField].
class SmartTextEditingController extends TextEditingController {
  SmartTextEditingController({super.text});

  void refresh() => notifyListeners();

  List<TextFormatSpan> formatSpans = [];
  double baseFontSize = 16.0;
  FontWeight baseFontWeight = FontWeight.normal;
  Color defaultColor = Colors.black;

  /// Optional style override for link spans (merged over the default).
  TextStyle? linkStyle;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (formatSpans.isEmpty || text.isEmpty) {
      return TextSpan(
        text: text,
        style: style?.copyWith(
          fontSize: baseFontSize,
          fontWeight: baseFontWeight,
          color: defaultColor,
        ),
      );
    }

    final children = <TextSpan>[];
    var textOffset = 0;

    for (final span in formatSpans) {
      if (textOffset >= text.length) break;

      final spanLength = span.text.length.clamp(0, text.length - textOffset);
      if (spanLength <= 0) continue;

      final spanText = text.substring(textOffset, textOffset + spanLength);

      children.add(TextSpan(
        text: spanText,
        style: _buildSpanStyle(span),
      ));

      textOffset += spanLength;
    }

    if (textOffset < text.length) {
      final lastSpan =
          formatSpans.isNotEmpty ? formatSpans.last : TextFormatSpan.plain('');

      children.add(TextSpan(
        text: text.substring(textOffset),
        style: _buildSpanStyle(lastSpan),
      ));
    }

    return TextSpan(
      style: style,
      children: children,
    );
  }

  TextStyle _buildSpanStyle(TextFormatSpan span) {
    return buildSpanTextStyle(
      span,
      baseFontSize: baseFontSize,
      baseFontWeight: baseFontWeight,
      defaultColor: defaultColor,
      linkStyle: linkStyle,
    );
  }
}
