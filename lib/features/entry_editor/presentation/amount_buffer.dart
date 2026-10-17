/// UI-only keypad editing. Parsing and bounds validation use shared Money.
final class AmountBuffer {
  String value = '';

  String? insert(String key) {
    if (key == 'backspace') {
      if (value.isNotEmpty) value = value.substring(0, value.length - 1);
      return null;
    }
    if (key == '.') {
      if (!value.contains('.')) value = value.isEmpty ? '0.' : '$value.';
      return null;
    }
    if (!RegExp(r'^\d$').hasMatch(key)) return null;
    final parts = value.split('.');
    if (parts.length == 2 && parts[1].length == 2) return '金额最多保留两位小数';
    if (parts.length == 1 && parts[0].length == 9) return '金额最多输入九位整数';
    value = value == '0' ? key : '$value$key';
    return null;
  }

  String get parseable => value.endsWith('.') ? '${value}00' : value;
}
