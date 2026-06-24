/// The unit a dimension on an [ImageSize] is expressed in.
enum ImageSizeUnit {
  /// Absolute pixels (`200px`, or a bare `200` HTML attribute).
  px,

  /// A percentage of the available width/height (`50%`).
  percent,

  /// Intrinsic size (`auto`).
  auto,
}

/// A round-trippable image dimension — px, percent, or `auto`.
///
/// Pure value object: serializes to either an HTML attribute (px only) or a CSS
/// length, and parses back from both. See `ImageNode.width`/`height`.
class ImageSize {
  const ImageSize(this.value, this.unit);
  const ImageSize.px(double v)
      : value = v,
        unit = ImageSizeUnit.px;
  const ImageSize.percent(double v)
      : value = v,
        unit = ImageSizeUnit.percent;
  const ImageSize.auto()
      : value = null,
        unit = ImageSizeUnit.auto;

  /// The numeric magnitude. `null` only for [ImageSizeUnit.auto].
  final double? value;
  final ImageSizeUnit unit;

  /// Renders as a CSS length: `"200px"`, `"50%"`, or `"auto"`.
  String toCss() => switch (unit) {
        ImageSizeUnit.px => '${value!.round()}px',
        ImageSizeUnit.percent => '${value!.round()}%',
        ImageSizeUnit.auto => 'auto',
      };

  /// Parses `"200px"`, `"50%"`, `"auto"`, or a bare numeric `"200"` (treated as
  /// px). Returns `null` for empty or unrecognized input.
  static ImageSize? parse(String? raw) {
    if (raw == null) return null;
    final s = raw.trim().toLowerCase();
    if (s.isEmpty) return null;
    if (s == 'auto') return const ImageSize.auto();
    if (s.endsWith('%')) {
      final n = double.tryParse(s.substring(0, s.length - 1).trim());
      return n == null ? null : ImageSize.percent(n);
    }
    if (s.endsWith('px')) {
      final n = double.tryParse(s.substring(0, s.length - 2).trim());
      return n == null ? null : ImageSize.px(n);
    }
    final n = double.tryParse(s);
    return n == null ? null : ImageSize.px(n);
  }

  @override
  bool operator ==(Object other) =>
      other is ImageSize && other.value == value && other.unit == unit;

  @override
  int get hashCode => Object.hash(value, unit);

  @override
  String toString() => 'ImageSize(${toCss()})';
}
