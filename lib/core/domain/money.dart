/// All financial arithmetic uses integer fen. Parsing never passes through double.
final class Money {
  const Money.fromFen(this.fen);

  static const maxInputFen = 99999999999;
  final int fen;

  factory Money.parse(String input) {
    final value = input.trim();
    if (!RegExp(r'^\d{1,9}(?:\.\d{1,2})?$').hasMatch(value)) {
      throw const FormatException('请输入金额，最多保留两位小数');
    }
    final parts = value.split('.');
    final whole = int.parse(parts[0]);
    final fraction = parts.length == 2 ? parts[1].padRight(2, '0') : '00';
    final fen = whole * 100 + int.parse(fraction);
    if (fen > maxInputFen) {
      throw const FormatException('金额超过允许范围');
    }
    return Money.fromFen(fen);
  }

  String get decimal {
    final absolute = fen.abs();
    return '${fen < 0 ? '-' : ''}${absolute ~/ 100}.'
        '${(absolute % 100).toString().padLeft(2, '0')}';
  }

  String get yuan => fen < 0 ? '−¥${decimal.substring(1)}' : '¥$decimal';

  Money operator +(Money other) => Money.fromFen(fen + other.fen);
  Money operator -(Money other) => Money.fromFen(fen - other.fen);

  @override
  bool operator ==(Object other) => other is Money && other.fen == fen;

  @override
  int get hashCode => fen.hashCode;
}
