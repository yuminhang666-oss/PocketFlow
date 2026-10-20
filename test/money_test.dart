import 'package:flutter_test/flutter_test.dart';
import 'package:pocketflow/core/domain/money.dart';

void main() {
  test('decimal money preserves every fen including 0.1 + 0.2', () {
    expect((Money.parse('0.1') + Money.parse('0.2')).fen, 30);
    expect(Money.parse('0012.30').decimal, '12.30');
    expect(const Money.fromFen(-1).yuan, '−¥0.01');
    expect(Money.parse('999999999.99').fen, Money.maxInputFen);
  });

  test('rejects malformed, negative and overprecision input', () {
    for (final input in [
      '',
      '-1',
      '1.001',
      'NaN',
      '1e3',
      '1,000',
      '1000000000',
      '.5',
      '1.',
    ]) {
      expect(() => Money.parse(input), throwsFormatException, reason: input);
    }
  });
}
