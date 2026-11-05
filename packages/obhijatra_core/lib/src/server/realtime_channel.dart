import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// One message received on a [RealtimeChannel] (one server-sent event).
final class RealtimeEvent {
  /// Creates the event.
  const RealtimeEvent({
    required this.name,
    required this.id,
    required this.data,
  });

  /// The event name, for example `PB_CONNECT` or `@oauth2`.
  final String name;

  /// The event id; PocketBase sends the client id.
  final String id;

  /// The event data (JSON for PocketBase).
  final String data;
}

/// A [RealtimeChannel] could not connect, or ended before the event that
/// was waited for arrived.
final class RealtimeChannelException implements Exception {
  /// Creates the exception; see [statusCode], [cause] and [closedHere].
  const RealtimeChannelException({
    this.statusCode,
    this.cause,
    this.closedHere = false,
  });

  /// The HTTP status when the server refused the connection.
  final int? statusCode;

  /// What broke the connection (a transport error, or a
  /// [TimeoutException] after [RealtimeChannel.idleLimit]); `null` when
  /// the server ended it.
  final Object? cause;

  /// Whether [RealtimeChannel.close] ended it.
  final bool closedHere;

  @override
  String toString() =>
      'RealtimeChannelException(status: $statusCode, cause: $cause, '
      'closedHere: $closedHere)';
}

/// One connection to the server's realtime route (`GET /api/realtime`,
/// server-sent events), held only while a Google sign-in waits for the
/// browser to hand back its code.
///
/// Unlike the PocketBase SDK's `RealtimeService`, it never reconnects (a new
/// connection gets a new client id, which no longer matches the sign-in's
/// `state`, so waiting on would be pointless) and [close] ends it at once,
/// in every state. It owns the HTTP client it is given and closes it, so
/// the socket is released too. Only the time to the response headers is
/// limited by the client; the stream itself may stay open for minutes, and
/// ends after [idleLimit] without a message.
final class RealtimeChannel {
  RealtimeChannel._(this._client);

  /// How long the connection may stay silent: just past the 5 minutes after
  /// which the server ends a realtime connection that had no message (the
  /// PocketBase SDK uses the same limit). A connection that silently died
  /// cannot keep anyone waiting longer.
  static const Duration idleLimit = Duration(seconds: 315);

  final http.Client _client;
  final Map<String, Completer<RealtimeEvent>> _waiting = {};
  StreamSubscription<String>? _lines;
  RealtimeChannelException? _ended;

  // The event being read.
  String _eventName = '';
  String _eventId = '';
  final List<String> _data = [];

  /// The id the server gave this connection (PocketBase's realtime client
  /// id), known once [connect] returns.
  String get clientId => _clientId;
  String _clientId = '';

  /// Whether the connection has ended, by [close] or otherwise.
  bool get isClosed => _ended != null;

  /// Connects to [url] with [client], which the channel owns from now on,
  /// and waits for the server's `PB_CONNECT` event.
  ///
  /// Throws what [client] throws when no answer comes, and a
  /// [RealtimeChannelException] when the server refuses the connection or
  /// ends it first.
  static Future<RealtimeChannel> connect(http.Client client, Uri url) async {
    final channel = RealtimeChannel._(client);
    try {
      final connected = channel.next('PB_CONNECT');
      final request = http.Request('GET', url)
        ..headers['accept'] = 'text/event-stream'
        ..headers['cache-control'] = 'no-store';
      final response = await client.send(request);
      if (response.statusCode != 200) {
        await response.stream.listen(null).cancel();
        throw RealtimeChannelException(statusCode: response.statusCode);
      }
      channel._listen(response.stream);
      final event = await connected;
      final id = _clientIdOf(event);
      if (id.isEmpty) {
        throw const RealtimeChannelException(
          cause: FormatException('PB_CONNECT without a client id'),
        );
      }
      channel._clientId = id;
      return channel;
    } on Object {
      channel.close();
      rethrow;
    }
  }

  /// The next event named [name]; fails with a [RealtimeChannelException]
  /// if the connection ends first. Ask before the event can arrive: events
  /// nobody waits for are dropped.
  Future<RealtimeEvent> next(String name) {
    final ended = _ended;
    if (ended != null) return Future<RealtimeEvent>.error(ended);
    final completer = _waiting.putIfAbsent(name, Completer<RealtimeEvent>.new);
    // Closing fails every wait; a wait nobody listens to any more is not an
    // uncaught error. Those who do listen still get the failure.
    completer.future.ignore();
    return completer.future;
  }

  /// Ends the connection now and releases the socket. Waits still open fail
  /// with a [RealtimeChannelException] whose [RealtimeChannelException.
  /// closedHere] is true. Calling it again does nothing.
  void close() => _end(const RealtimeChannelException(closedHere: true));

  void _listen(Stream<List<int>> body) {
    _lines = body
        .timeout(idleLimit)
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          _line,
          onError: (Object error) =>
              _end(RealtimeChannelException(cause: error)),
          onDone: () => _end(const RealtimeChannelException()),
          cancelOnError: true,
        );
  }

  /// Reads one line of the event stream (the WHATWG server-sent events
  /// format: `field:value` lines, a blank line ends an event).
  void _line(String line) {
    if (line.isEmpty) {
      _dispatch();
      return;
    }
    if (line.startsWith(':')) return; // a comment (keep-alive)
    final colon = line.indexOf(':');
    final field = colon < 0 ? line : line.substring(0, colon);
    var value = colon < 0 ? '' : line.substring(colon + 1);
    if (value.startsWith(' ')) value = value.substring(1);
    switch (field) {
      case 'event':
        _eventName = value;
      case 'data':
        _data.add(value);
      case 'id':
        _eventId = value;
    }
  }

  void _dispatch() {
    if (_eventName.isEmpty && _data.isEmpty) return;
    final event = RealtimeEvent(
      name: _eventName.isEmpty ? 'message' : _eventName,
      id: _eventId,
      data: _data.join('\n'),
    );
    _eventName = '';
    _data.clear();
    _waiting.remove(event.name)?.complete(event);
  }

  void _end(RealtimeChannelException reason) {
    if (_ended != null) return;
    _ended = reason;
    unawaited(_lines?.cancel());
    _client.close();
    final waiting = _waiting.values.toList();
    _waiting.clear();
    for (final completer in waiting) {
      completer.completeError(reason);
    }
  }

  static String _clientIdOf(RealtimeEvent event) {
    try {
      final json = jsonDecode(event.data);
      if (json is Map<String, Object?>) {
        final id = json['clientId'];
        if (id is String && id.isNotEmpty) return id;
      }
    } on FormatException {
      // Fall back to the event id below.
    }
    return event.id;
  }
}
