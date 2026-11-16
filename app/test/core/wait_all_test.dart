import 'package:flutter_test/flutter_test.dart';
import 'package:ngclass/core/async/wait_all.dart';
import 'package:ngclass/core/network/api_failure.dart';

/// Pre-production audit F6: a failure among loads run side by side keeps its own meaning.
void main() {
  test('both loads succeed', () async {
    final (a, b) = await waitBoth(Future.value(1), Future.value('x'));
    expect((a, b), (1, 'x'));
  });

  test('a lost connection in one of two loads is still "no connection"', () async {
    final failing = Future<String>.error(const ApiFailure(code: ApiFailure.network));
    await expectLater(
      waitBoth(Future.value(1), failing),
      throwsA(isA<ApiFailure>().having((f) => ApiFailure.from(f).isNetwork, 'isNetwork', isTrue)),
    );
  });

  test('three loads: the first failure is the one thrown', () async {
    await expectLater(
      waitThree(Future.value(1), Future<int>.error(const ApiFailure(code: 'forbidden')), Future.value(3)),
      throwsA(isA<ApiFailure>().having((f) => f.code, 'code', 'forbidden')),
    );
  });
}
