import 'dart:async';

/// Runs two loads side by side. When one fails, its own error is thrown rather than Dart's
/// [ParallelWaitError], so a lost connection still reads as "no connection" on screen.
Future<(A, B)> waitBoth<A, B>(Future<A> a, Future<B> b) async {
  try {
    return await (a, b).wait;
  } on ParallelWaitError<(A?, B?), (AsyncError?, AsyncError?)> catch (e) {
    _rethrow((e.errors.$1 ?? e.errors.$2)!);
  }
}

/// [waitBoth] for three loads.
Future<(A, B, C)> waitThree<A, B, C>(Future<A> a, Future<B> b, Future<C> c) async {
  try {
    return await (a, b, c).wait;
  } on ParallelWaitError<(A?, B?, C?), (AsyncError?, AsyncError?, AsyncError?)> catch (e) {
    _rethrow((e.errors.$1 ?? e.errors.$2 ?? e.errors.$3)!);
  }
}

Never _rethrow(AsyncError first) => Error.throwWithStackTrace(first.error, first.stackTrace);
