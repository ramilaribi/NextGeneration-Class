import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ngclass/core/platform/session_channel.dart';
import 'package:ngclass/domain/model/app_user.dart';
import 'package:ngclass/domain/repositories/auth_repository.dart';
import 'package:ngclass/view/stateManager/auth/auth_cubit.dart';
import 'package:ngclass/view/stateManager/auth/auth_state.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

/// The other tabs of the browser, seen from this one.
class _Tabs implements SessionChannel {
  final otherTab = StreamController<void>.broadcast();
  int announced = 0;

  @override
  void announce() => announced++;

  @override
  Stream<void> get changes => otherTab.stream;
}

const _owner = AppUser(
  id: 'o',
  role: UserRole.admin,
  username: 'proprietaire',
  firstName: 'Rami',
  lastName: 'Laribi',
  mustChangePassword: false,
);
const _teacher = AppUser(
  id: 't',
  role: UserRole.teacher,
  username: 'ens.demo',
  firstName: 'Salma',
  lastName: 'Ben Ali',
  mustChangePassword: false,
);

const _student = AppUser(
  id: '1',
  role: UserRole.student,
  username: 'eleve.demo',
  firstName: 'Adam',
  lastName: 'Gharbi',
  mustChangePassword: true,
);

void main() {
  late _MockAuthRepository repository;

  setUp(() => repository = _MockAuthRepository());

  blocTest<AuthCubit, AuthState>(
    'a saved session reopens signed in',
    build: () {
      when(() => repository.restoreSession()).thenAnswer((_) async => _student);
      return AuthCubit(repository);
    },
    act: (cubit) => cubit.restore(),
    expect: () => [const AuthSignedIn(_student)],
  );

  blocTest<AuthCubit, AuthState>(
    'no session, or a failure while restoring, means signed out',
    build: () {
      when(() => repository.restoreSession()).thenThrow(StateError('boom'));
      return AuthCubit(repository);
    },
    act: (cubit) => cubit.restore(),
    expect: () => [const AuthSignedOut()],
  );

  blocTest<AuthCubit, AuthState>(
    'choosing a password lifts the temporary-password gate',
    build: () => AuthCubit(repository),
    seed: () => const AuthSignedIn(_student),
    act: (cubit) => cubit.passwordChanged(),
    expect: () => [AuthSignedIn(_student.copyWith(mustChangePassword: false))],
  );

  blocTest<AuthCubit, AuthState>(
    'a session refused by the server signs out',
    build: () => AuthCubit(repository),
    seed: () => const AuthSignedIn(_student),
    act: (cubit) => cubit.sessionExpired(),
    expect: () => [const AuthSignedOut()],
  );

  group('one session shared by the tabs of a browser', () {
    late _Tabs tabs;

    setUp(() => tabs = _Tabs());

    test('signing in or out here tells the other tabs', () async {
      when(() => repository.logout()).thenAnswer((_) async {});
      final cubit = AuthCubit(repository, channel: tabs)..signedIn(_owner);
      await cubit.logout();
      expect(tabs.announced, 2);
      await cubit.close();
    });

    blocTest<AuthCubit, AuthState>(
      'the owner tab follows a teacher signed in another tab',
      build: () {
        when(() => repository.restoreSession()).thenAnswer((_) async => _teacher);
        return AuthCubit(repository, channel: tabs);
      },
      seed: () => const AuthSignedIn(_owner),
      act: (_) => tabs.otherTab.add(null),
      wait: Duration.zero,
      expect: () => [const AuthSignedIn(_teacher)],
      verify: (_) => expect(tabs.announced, 0),
    );

    blocTest<AuthCubit, AuthState>(
      'signing out in another tab signs this tab out',
      build: () {
        when(() => repository.restoreSession()).thenAnswer((_) async => null);
        return AuthCubit(repository, channel: tabs);
      },
      seed: () => const AuthSignedIn(_owner),
      act: (_) => tabs.otherTab.add(null),
      wait: Duration.zero,
      expect: () => [const AuthSignedOut()],
    );

    blocTest<AuthCubit, AuthState>(
      'the same account in both tabs changes nothing',
      build: () {
        when(() => repository.restoreSession()).thenAnswer((_) async => _owner);
        return AuthCubit(repository, channel: tabs);
      },
      seed: () => const AuthSignedIn(_owner),
      act: (_) => tabs.otherTab.add(null),
      wait: Duration.zero,
      expect: () => <AuthState>[],
    );

    blocTest<AuthCubit, AuthState>(
      'a token refresh answered for another account switches this tab to it',
      build: () {
        when(() => repository.restoreSession()).thenAnswer((_) async => _teacher);
        return AuthCubit(repository);
      },
      seed: () => const AuthSignedIn(_owner),
      act: (cubit) => cubit.sessionRefreshed('t'),
      wait: Duration.zero,
      expect: () => [const AuthSignedIn(_teacher)],
    );

    blocTest<AuthCubit, AuthState>(
      'a token refresh for the account shown asks nothing more',
      build: () => AuthCubit(repository),
      seed: () => const AuthSignedIn(_owner),
      act: (cubit) => cubit.sessionRefreshed('o'),
      expect: () => <AuthState>[],
      verify: (_) => verifyNever(() => repository.restoreSession()),
    );
  });
}
