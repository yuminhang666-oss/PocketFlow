import 'dart:async';

import '../../../contracts/contracts.dart';
import '../domain/budget_calculator.dart';

/// UI-independent budget streams. Main owns Riverpod/lifecycle wiring.
class BudgetService {
  BudgetService({
    required LedgerRepository repository,
    Clock clock = const SystemClock(),
    BudgetCalculator calculator = const BudgetCalculator(),
  }) : _repository = repository,
       _clock = clock,
       _calculator = calculator;

  final LedgerRepository _repository;
  final Clock _clock;
  final BudgetCalculator _calculator;
  final _refreshes = StreamController<void>.broadcast(sync: true);
  final _watches = <_BudgetWatch>{};
  bool _disposed = false;

  /// Null follows the current month; a fixed month stays selected across midnight.
  /// Each call returns a cold single-subscription stream with its own initial read.
  Stream<BudgetSnapshot> watch({CalendarMonth? month}) {
    if (_disposed) throw StateError('BudgetService is disposed');
    late final _BudgetWatch watch;
    watch = _BudgetWatch(
      repository: _repository,
      clock: _clock,
      calculator: _calculator,
      refreshes: _refreshes.stream,
      selectedMonth: month,
      onClosed: () => _watches.remove(watch),
    );
    _watches.add(watch);
    return watch.stream;
  }

  /// Call on app foregrounding or system clock/timezone change. Midnight is
  /// handled internally; no database write is needed to refresh the denominator.
  void refreshDate() {
    if (!_disposed) _refreshes.add(null);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await Future.wait(_watches.toList().map((watch) => watch.close()));
    await _refreshes.close();
  }
}

class _BudgetWatch {
  _BudgetWatch({
    required this.repository,
    required this.clock,
    required this.calculator,
    required this.refreshes,
    required this.selectedMonth,
    required this.onClosed,
  }) {
    _controller = StreamController<BudgetSnapshot>(
      onListen: _start,
      onCancel: close,
    );
  }

  final LedgerRepository repository;
  final Clock clock;
  final BudgetCalculator calculator;
  final Stream<void> refreshes;
  final CalendarMonth? selectedMonth;
  final void Function() onClosed;
  late final StreamController<BudgetSnapshot> _controller;
  StreamSubscription<LedgerMonthData>? _ledger;
  StreamSubscription<void>? _refresh;
  final _cancellations = <Future<void>>{};
  CalendarMonth? _month;
  LedgerMonthData? _data;
  DateTime? _today;
  Timer? _midnight;
  bool _closed = false;
  int _generation = 0;
  Future<void>? _closing;

  Stream<BudgetSnapshot> get stream => _controller.stream;

  void _start() {
    if (_closed) return;
    _refresh = refreshes.listen((_) => _refreshDate());
    _refreshDate();
  }

  void _refreshDate() {
    if (_closed) return;
    try {
      final now = clock.now();
      final month = selectedMonth ?? CalendarMonth.fromDate(now);
      // Validate the injected clock even while a fixed historical month is open.
      CalendarMonth.fromDate(now);
      _today = now;
      _midnight?.cancel();
      final next = now.isUtc
          ? DateTime.utc(now.year, now.month, now.day + 1)
          : DateTime(now.year, now.month, now.day + 1);
      _midnight = Timer(next.difference(now), _refreshDate);
      if (_month != month || _data == null) {
        _month = month;
        _data = null;
        final generation = ++_generation;
        _retire(_ledger);
        _ledger = repository.watchMonth(month).listen(
          (data) {
            if (!_closed && generation == _generation) {
              if (data.month != month) {
                _data = null;
                _controller.addError(const PocketFlowException(
                  PocketFlowErrorCode.dataCorrupted,
                ));
                return;
              }
              _data = data;
              _emit();
            }
          },
          onError: (Object error, StackTrace stack) {
            if (!_closed && generation == _generation) {
              _data = null;
              _controller.addError(_businessError(error), stack);
            }
          },
          onDone: () {
            if (!_closed && generation == _generation) unawaited(close());
          },
        );
      } else {
        _emit();
      }
    } catch (error, stack) {
      _controller.addError(_businessError(error), stack);
    }
  }

  void _emit() {
    final data = _data;
    final today = _today;
    if (_closed || data == null || today == null) return;
    try {
      _controller.add(calculator.calculate(
        month: data.month,
        today: today,
        budget: data.budget?.amount,
        entries: data.entries,
      ));
    } catch (error, stack) {
      _controller.addError(_businessError(error), stack);
    }
  }

  void _retire(StreamSubscription<LedgerMonthData>? subscription) {
    if (subscription == null) return;
    late final Future<void> cancellation;
    cancellation = subscription.cancel().catchError(
      (Object error, StackTrace stack) {
        if (!_closed) _controller.addError(_businessError(error), stack);
      },
    ).whenComplete(() {
      _cancellations.remove(cancellation);
    });
    _cancellations.add(cancellation);
  }

  Future<void> close() => _closing ??= _close();

  PocketFlowException _businessError(Object error) =>
      error is PocketFlowException ? error : PocketFlowException(
        PocketFlowErrorCode.dataCorrupted, cause: error,
      );

  Future<void> _close() async {
    _closed = true;
    ++_generation;
    _midnight?.cancel();
    onClosed();
    try {
      await Future.wait([
        if (_ledger != null) _ledger!.cancel(),
        if (_refresh != null) _refresh!.cancel(),
        ..._cancellations,
      ]);
    } finally {
      // Do not wait for an absent/paused UI listener to acknowledge stream done.
      unawaited(_controller.close());
    }
  }
}
