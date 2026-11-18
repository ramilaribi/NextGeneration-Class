import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/platform/session_channel.dart';
import '../../../domain/model/app_user.dart';
import '../../../domain/repositories/auth_repository.dart';
import 'auth_state.dart';

/// Who is signed in. The router follows this state to open the right role space.
///
/// All tabs of one browser share one saved session: signing in or out here is announced to the other
/// tabs, and this tab follows what another one did ([followSharedSession]).
class AuthCubit extends Cubit<AuthState> {
  AuthCubit(this._repository, {SessionChannel? channel}) : _channel = channel, super(const AuthUnknown()) {
    _subscription = channel?.changes.listen((_) => followSharedSession());
  }

  final AuthRepository _repository;
  final SessionChannel? _channel;
  StreamSubscription<void>? _subscription;

  AppUser? get user => switch (state) {
    AuthSignedIn(:final user) => user,
    _ => null,
  };

  Future<void> restore() async {
    try {
      final user = await _repository.restoreSession();
      emit(user == null ? const AuthSignedOut() : AuthSignedIn(user));
    } on Object {
      emit(const AuthSignedOut());
    }
  }

  void signedIn(AppUser user) {
    emit(AuthSignedIn(user));
    _channel?.announce();
  }

  void passwordChanged() {
    final current = user;
    if (current != null) emit(AuthSignedIn(current.copyWith(mustChangePassword: false)));
  }

  /// The parent accepted the privacy notice: their space opens.
  void privacyAccepted() {
    final current = user;
    if (current != null) emit(AuthSignedIn(current.copyWith(privacyRequired: false)));
  }

  Future<void> logout() async {
    await _repository.logout();
    emit(const AuthSignedOut());
    _channel?.announce();
  }

  /// The server refused the session (account reset or disabled).
  void sessionExpired() {
    if (state is AuthSignedIn) emit(const AuthSignedOut());
  }

  /// A token refresh answered for [userId]: when it is not the account this tab shows, another tab
  /// changed the session and this tab follows.
  void sessionRefreshed(String userId) {
    if (user?.id != userId) followSharedSession();
  }

  /// Another tab signed in or out: open the saved session again, so this tab never shows one account
  /// while acting as another.
  Future<void> followSharedSession() async {
    if (state is AuthUnknown) return;
    AppUser? saved;
    try {
      saved = await _repository.restoreSession();
    } on Object {
      saved = null;
    }
    if (saved == null) {
      if (state is! AuthSignedOut) emit(const AuthSignedOut());
    } else if (saved.id != user?.id) {
      emit(AuthSignedIn(saved));
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
