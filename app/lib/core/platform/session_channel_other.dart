import 'session_channel.dart';

/// Outside the browser there is one window: nothing to tell.
SessionChannel createSessionChannel() => _SingleWindow();

class _SingleWindow implements SessionChannel {
  @override
  void announce() {}

  @override
  Stream<void> get changes => const Stream.empty();
}
