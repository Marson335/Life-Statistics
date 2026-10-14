import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'models/crypto_models.dart';

class BinanceService {
  final String? apiKey;
  final String? apiSecret;
  static const String _baseUrl = 'https://api.binance.com';
  static const String _fapiBaseUrl = 'https://fapi.binance.com';

  BinanceService({this.apiKey, this.apiSecret});

  bool get isConfigured =>
      apiKey != null &&
      apiSecret != null &&
      apiKey!.trim().isNotEmpty &&
      apiSecret!.trim().isNotEmpty &&
      !apiKey!.contains('your_binance');

  String _sign(Map<String, dynamic> params) {
    params['timestamp'] = DateTime.now().millisecondsSinceEpoch.toString();
    final queryString = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}')
        .join('&');

    final key = utf8.encode(apiSecret!);
    final bytes = utf8.encode(queryString);
    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(bytes);

    return '$queryString&signature=$digest';
  }

  // --- 1. СПОТОВИЙ ГАМАНЕЦЬ ---
  Future<Map<String, double>> getSpotBalances() async {
    if (!isConfigured) return {};

    try {
      final signedQuery = _sign({});
      final url = Uri.parse('$_baseUrl/api/v3/account?$signedQuery');
      final response = await http.get(
        url,
        headers: {'X-MBX-APIKEY': apiKey!},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final balances = data['balances'] as List<dynamic>? ?? [];
        final Map<String, double> result = {};

        for (final b in balances) {
          final free = double.tryParse(b['free']?.toString() ?? '0') ?? 0.0;
          final locked = double.tryParse(b['locked']?.toString() ?? '0') ?? 0.0;
          final total = free + locked;
          if (total > 0.0000001) {
            result[b['asset'].toString().toUpperCase()] = total;
          }
        }
        return result;
      }
    } catch (e) {
      // Помилка мережі або невалідний ключ
    }
    return {};
  }

  // --- 2. Ф'ЮЧЕРСНИЙ ГАМАНЕЦЬ (USDT-M) ---
  Future<Map<String, dynamic>> getFuturesData() async {
    if (!isConfigured) {
      return {'totalMarginUsd': 0.0, 'unrealizedPnlUsd': 0.0, 'positions': <BinancePositionItem>[]};
    }

    double totalMargin = 0.0;
    double unrealizedPnl = 0.0;
    final List<BinancePositionItem> positions = [];

    try {
      // Акаунт
      final signedAccQuery = _sign({});
      final accUrl = Uri.parse('$_fapiBaseUrl/fapi/v2/account?$signedAccQuery');
      final accResp = await http.get(
        accUrl,
        headers: {'X-MBX-APIKEY': apiKey!},
      ).timeout(const Duration(seconds: 10));

      if (accResp.statusCode == 200) {
        final accData = json.decode(accResp.body);
        totalMargin = double.tryParse(accData['totalMarginBalance']?.toString() ?? '0') ?? 0.0;
        unrealizedPnl = double.tryParse(accData['totalUnrealizedProfit']?.toString() ?? '0') ?? 0.0;
      }

      // Позиції
      final signedPosQuery = _sign({});
      final posUrl = Uri.parse('$_fapiBaseUrl/fapi/v2/positionRisk?$signedPosQuery');
      final posResp = await http.get(
        posUrl,
        headers: {'X-MBX-APIKEY': apiKey!},
      ).timeout(const Duration(seconds: 10));

      if (posResp.statusCode == 200) {
        final List<dynamic> posData = json.decode(posResp.body);
        for (final p in posData) {
          final amt = double.tryParse(p['positionAmt']?.toString() ?? '0') ?? 0.0;
          if (amt != 0) {
            positions.add(BinancePositionItem(
              symbol: p['symbol'] ?? '',
              direction: amt > 0 ? 'LONG' : 'SHORT',
              amount: amt.abs(),
              entryPrice: double.tryParse(p['entryPrice']?.toString() ?? '0') ?? 0.0,
              markPrice: double.tryParse(p['markPrice']?.toString() ?? '0') ?? 0.0,
              liquidationPrice: double.tryParse(p['liquidationPrice']?.toString() ?? '0') ?? 0.0,
              unrealizedPnl: double.tryParse(p['unRealizedProfit']?.toString() ?? '0') ?? 0.0,
              leverage: int.tryParse(p['leverage']?.toString() ?? '1') ?? 1,
            ));
          }
        }
      }
    } catch (_) {}

    return {
      'totalMarginUsd': totalMargin,
      'unrealizedPnlUsd': unrealizedPnl,
      'positions': positions,
    };
  }

  // --- 3. BINANCE SIMPLE EARN (СТЕЙКІНГ) ---
  Future<List<BinanceEarnItem>> getSimpleEarnHoldings() => getEarnPositions();

  Future<List<BinanceEarnItem>> getEarnPositions() async {
    if (!isConfigured) return [];
    final List<BinanceEarnItem> earnList = [];

    try {
      // Гнучкий стейкінг
      final signedFlex = _sign({'size': 100});
      final flexUrl = Uri.parse('$_baseUrl/sapi/v1/simple-earn/flexible/position?$signedFlex');
      final flexResp = await http.get(
        flexUrl,
        headers: {'X-MBX-APIKEY': apiKey!},
      ).timeout(const Duration(seconds: 10));

      if (flexResp.statusCode == 200) {
        final flexData = json.decode(flexResp.body);
        final rows = flexData['rows'] as List<dynamic>? ?? [];
        for (final r in rows) {
          final amt = double.tryParse(r['totalAmount']?.toString() ?? '0') ?? 0.0;
          if (amt > 0) {
            final apr = (double.tryParse(r['airdropPercentageRate']?.toString() ?? '0') ?? 0.0) +
                (double.tryParse(r['bonusPercentageRate']?.toString() ?? '0') ?? 0.0);
            earnList.add(BinanceEarnItem(
              symbol: r['asset']?.toString().toUpperCase() ?? '',
              productName: 'Simple Earn Flexible',
              type: 'FLEXIBLE',
              amount: amt,
              apr: apr,
            ));
          }
        }
      }

      // Фіксований стейкінг
      final signedLock = _sign({'size': 100});
      final lockUrl = Uri.parse('$_baseUrl/sapi/v1/simple-earn/locked/position?$signedLock');
      final lockResp = await http.get(
        lockUrl,
        headers: {'X-MBX-APIKEY': apiKey!},
      ).timeout(const Duration(seconds: 10));

      if (lockResp.statusCode == 200) {
        final lockData = json.decode(lockResp.body);
        final rows = lockData['rows'] as List<dynamic>? ?? [];
        for (final r in rows) {
          final amt = double.tryParse(r['amount']?.toString() ?? '0') ?? 0.0;
          if (amt > 0) {
            final apr = (double.tryParse(r['rewardRate']?.toString() ?? '0') ?? 0.0) * 100;
            earnList.add(BinanceEarnItem(
              symbol: r['asset']?.toString().toUpperCase() ?? '',
              productName: 'Locked ${r['duration']} Days',
              type: 'LOCKED',
              amount: amt,
              apr: apr,
            ));
          }
        }
      }
    } catch (_) {}

    return earnList;
  }
}
