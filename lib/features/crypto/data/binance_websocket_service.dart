import 'dart:async';
import 'dart:convert';
import 'dart:io';

typedef PriceTickCallback = void Function(String symbol, double price, double chg24h);
typedef ConnectionStatusCallback = void Function(bool isConnected);

class BinanceWebSocketService {
  WebSocket? _socket;
  StreamSubscription? _socketSub;
  Timer? _reconnectTimer;

  bool _isDisposed = false;
  bool _isConnected = false;
  int _requestId = 1;

  final Set<String> _subscribedStreams = {};
  PriceTickCallback? _onTick;
  ConnectionStatusCallback? _onStatusChanged;

  bool get isConnected => _isConnected;

  static const Set<String> _ignoreSymbols = {
    'USDT',
    'USDC',
    'FDUSD',
    'DAI',
    'TUSD',
    'USDE',
    'BUSD',
    'PYUSD',
    'USDD',
    'GUSD',
  };

  void connect({
    required List<String> symbols,
    required PriceTickCallback onTick,
    ConnectionStatusCallback? onStatusChanged,
  }) {
    _isDisposed = false;
    _onTick = onTick;
    _onStatusChanged = onStatusChanged;

    _updateStreamsList(symbols);
    _connectInternal();
  }

  void updateSymbols(List<String> symbols) {
    if (_isDisposed) return;

    final oldStreams = Set<String>.from(_subscribedStreams);
    _updateStreamsList(symbols);

    if (_isConnected && _socket != null) {
      final toUnsubscribe = oldStreams.difference(_subscribedStreams).toList();
      final toSubscribe = _subscribedStreams.difference(oldStreams).toList();

      if (toUnsubscribe.isNotEmpty) {
        _send({
          'method': 'UNSUBSCRIBE',
          'params': toUnsubscribe,
          'id': _requestId++,
        });
      }

      if (toSubscribe.isNotEmpty) {
        _send({
          'method': 'SUBSCRIBE',
          'params': toSubscribe,
          'id': _requestId++,
        });
      }
    }
  }

  void _updateStreamsList(List<String> symbols) {
    _subscribedStreams.clear();
    for (final s in symbols) {
      final upper = s.trim().toUpperCase();
      if (upper.isEmpty || _ignoreSymbols.contains(upper)) continue;
      _subscribedStreams.add('${upper.toLowerCase()}usdt@ticker');
    }
  }

  Future<void> _connectInternal() async {
    if (_isDisposed) return;

    _cleanupSocket();

    try {
      final ws = await WebSocket.connect(
        'wss://stream.binance.com:9443/ws',
      ).timeout(const Duration(seconds: 8));

      _socket = ws;
      _isConnected = true;
      _onStatusChanged?.call(true);

      if (_subscribedStreams.isNotEmpty) {
        _send({
          'method': 'SUBSCRIBE',
          'params': _subscribedStreams.toList(),
          'id': _requestId++,
        });
      }

      _socketSub = ws.listen(
        _handleMessage,
        onError: (err) {
          _handleDisconnect();
        },
        onDone: () {
          _handleDisconnect();
        },
        cancelOnError: true,
      );
    } catch (_) {
      _handleDisconnect();
    }
  }

  void _send(Map<String, dynamic> data) {
    if (_socket != null && _isConnected) {
      try {
        _socket!.add(jsonEncode(data));
      } catch (_) {}
    }
  }

  void _handleMessage(dynamic raw) {
    if (_isDisposed || raw is! String) return;

    try {
      final data = jsonDecode(raw);
      if (data is! Map) return;

      // Очікуваний формат від @ticker:
      // "s": "BTCUSDT", "c": "81640.01", "P": "-1.98"
      final streamSymbol = data['s']?.toString() ?? '';
      if (streamSymbol.isEmpty || !streamSymbol.endsWith('USDT')) return;

      final baseSymbol = streamSymbol.substring(0, streamSymbol.length - 4).toUpperCase();
      final priceStr = data['c']?.toString();
      final chgStr = data['P']?.toString();

      if (priceStr == null || chgStr == null) return;

      final price = double.tryParse(priceStr);
      final chg24h = double.tryParse(chgStr);

      if (price != null && chg24h != null && price > 0) {
        _onTick?.call(baseSymbol, price, chg24h);
      }
    } catch (_) {}
  }

  void _handleDisconnect() {
    _isConnected = false;
    _onStatusChanged?.call(false);
    _cleanupSocket();

    if (!_isDisposed) {
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: 3), () {
        _connectInternal();
      });
    }
  }

  void _cleanupSocket() {
    _socketSub?.cancel();
    _socketSub = null;
    try {
      _socket?.close();
    } catch (_) {}
    _socket = null;
  }

  void disconnect() {
    _isDisposed = true;
    _isConnected = false;
    _reconnectTimer?.cancel();
    _cleanupSocket();
    _onStatusChanged?.call(false);
  }
}
