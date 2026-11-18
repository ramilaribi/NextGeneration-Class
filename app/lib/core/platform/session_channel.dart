import 'session_channel_other.dart' if (dart.library.js_interop) 'session_channel_web.dart' as impl;

/// Tells the other tabs of this browser that the session changed (someone signed in or out).
///
/// All tabs of one browser share one saved session. Without this, a tab still showing the owner's
/// space would carry on with the account signed in later in another tab.
abstract interface class SessionChannel {
  /// This tab signed in or out.
  void announce();

  /// Another tab signed in or out.
  Stream<void> get changes;
}

SessionChannel createSessionChannel() => impl.createSessionChannel();
