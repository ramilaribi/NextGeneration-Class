import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'session_channel.dart';

SessionChannel createSessionChannel() => _BrowserTabs();

/// A BroadcastChannel reaches every other tab of this site in this browser (never the sender).
class _BrowserTabs implements SessionChannel {
  _BrowserTabs() {
    try {
      _channel = web.BroadcastChannel('ngclass.session')..onmessage = ((web.MessageEvent _) => _changes.add(null)).toJS;
    } on Object {
      // An old browser without BroadcastChannel: each tab finds out at its next token refresh.
      _channel = null;
    }
  }

  web.BroadcastChannel? _channel;
  final _changes = StreamController<void>.broadcast();

  @override
  void announce() => _channel?.postMessage('changed'.toJS);

  @override
  Stream<void> get changes => _changes.stream;
}
