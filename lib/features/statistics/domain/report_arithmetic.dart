import '../../../contracts/contracts.dart';

// Android/native Dart integers must not wrap on large imported datasets.
final _maxNativeInt = BigInt.parse('9223372036854775807');
final _minNativeInt = -_maxNativeInt - BigInt.one;

int checkedReportInt(BigInt value) {
  if (value > _maxNativeInt || value < _minNativeInt) {
    throw const PocketFlowException(PocketFlowErrorCode.dataCorrupted);
  }
  return value.toInt();
}

int sumReportFen(Iterable<int> values) => checkedReportInt(
  values.fold(BigInt.zero, (sum, value) => sum + BigInt.from(value)),
);

/// Display only: rational percentage rounded half up to two decimal places.
/// An absent/zero denominator is unknown, including an explicit zero budget.
String? reportPercent(int numerator, int? denominator) {
  if (denominator == null || denominator <= 0) return null;
  final divisor = BigInt.from(denominator);
  final scaled =
      (BigInt.from(numerator) * BigInt.from(10000) + divisor ~/ BigInt.two) ~/
      divisor;
  return '${scaled ~/ BigInt.from(100)}.'
      '${(scaled % BigInt.from(100)).toString().padLeft(2, '0')}%';
}
