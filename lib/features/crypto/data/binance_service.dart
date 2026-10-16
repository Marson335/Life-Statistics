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

  // --- 4. ІСТОРІЯ УГОД SPOT, BINANCE CONVERT ТА FIFO АНАЛІЗ ---

  static const Set<String> _quoteAssets = {
    'USDT', 'USDC', 'BUSD', 'FDUSD', 'DAI', 'TUSD', 'USDD',
    'EUR', 'USD', 'UAH', 'TRY', 'GBP', 'PLN', 'BIDR', 'AUD', 'CAD', 'BRL', 'JPY'
  };

  /// Спотові угоди біржового стакана (Orderbook)
  Future<List<Map<String, dynamic>>> getMyTrades(String symbol, {int limit = 200}) async {
    if (!isConfigured) return [];
    try {
      final pair = symbol.endsWith('USDT') ? symbol : '${symbol}USDT';
      final signedQuery = _sign({'symbol': pair, 'limit': limit});
      final url = Uri.parse('$_baseUrl/api/v3/myTrades?$signedQuery');
      final response = await http.get(
        url,
        headers: {'X-MBX-APIKEY': apiKey!},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List<dynamic>;
        return data.map((e) => e as Map<String, dynamic>).toList();
      }
    } catch (_) {}
    return [];
  }

  /// Історія швидких конвертацій (Binance Convert / Обмін)
  Future<List<Map<String, dynamic>>> getConvertTrades({int maxDays = 360}) async {
    if (!isConfigured) return [];
    final List<Map<String, dynamic>> allTrades = [];
    final now = DateTime.now().millisecondsSinceEpoch;
    const windowMs = 28 * 24 * 60 * 60 * 1000; // 28 днів (ліміт API Binance - 30 днів)

    final int totalWindows = (maxDays / 28).ceil().clamp(1, 13);
    final List<({int start, int end})> windows = [];
    for (int i = 0; i < totalWindows; i++) {
      final end = now - (i * windowMs);
      final start = end - windowMs;
      windows.add((start: start, end: end));
    }

    try {
      final results = await Future.wait(windows.map((w) async {
        try {
          final signedQuery = _sign({
            'startTime': w.start,
            'endTime': w.end,
            'limit': 1000,
          });
          final url = Uri.parse('$_baseUrl/sapi/v1/convert/tradeFlow?$signedQuery');
          final response = await http.get(
            url,
            headers: {'X-MBX-APIKEY': apiKey!},
          ).timeout(const Duration(seconds: 8));

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            if (data is Map<String, dynamic> && data['list'] is List) {
              return (data['list'] as List<dynamic>)
                  .whereType<Map<String, dynamic>>()
                  .toList();
            }
          }
        } catch (_) {}
        return <Map<String, dynamic>>[];
      }));

      for (final list in results) {
        allTrades.addAll(list);
      }
    } catch (_) {}

    return allTrades;
  }

  /// Парсинг операцій швидкого обміну (Binance Convert) у формат єдиних угод
  List<Map<String, dynamic>> parseConvertTrades(List<Map<String, dynamic>> rawConvertList) {
    final List<Map<String, dynamic>> trades = [];

    for (final item in rawConvertList) {
      final status = item['orderStatus']?.toString().toUpperCase();
      if (status != 'SUCCESS') continue;

      final fromAsset = item['fromAsset']?.toString().toUpperCase() ?? '';
      final toAsset = item['toAsset']?.toString().toUpperCase() ?? '';
      final fromAmount = double.tryParse(item['fromAmount']?.toString() ?? '0') ?? 0.0;
      final toAmount = double.tryParse(item['toAmount']?.toString() ?? '0') ?? 0.0;
      final createTime = (item['createTime'] as num?)?.toInt() ?? 0;
      final orderId = item['orderId']?.toString() ?? '${createTime}_${fromAsset}_$toAsset';

      if (fromAmount <= 0 || toAmount <= 0 || createTime == 0) continue;

      if (_quoteAssets.contains(fromAsset)) {
        // Покупка toAsset за стейблкоїн/фіат (наприклад, USDT -> BTC)
        trades.add({
          'id': 'convert_$orderId',
          'orderId': orderId,
          'symbol': toAsset,
          'price': fromAmount / toAmount,
          'qty': toAmount,
          'commission': 0.0,
          'time': createTime,
          'isBuyer': true,
          'isConvert': true,
        });
      } else if (_quoteAssets.contains(toAsset)) {
        // Продаж fromAsset за стейблкоїн/фіат (наприклад, BTC -> USDT)
        trades.add({
          'id': 'convert_$orderId',
          'orderId': orderId,
          'symbol': fromAsset,
          'price': toAmount / fromAmount,
          'qty': fromAmount,
          'commission': 0.0,
          'time': createTime,
          'isBuyer': false,
          'isConvert': true,
        });
      } else {
        // Прямий обмін крипта -> крипта (наприклад, ETH -> BTC)
        trades.add({
          'id': 'convert_${orderId}_sell',
          'orderId': orderId,
          'symbol': fromAsset,
          'price': 0.0,
          'qty': fromAmount,
          'commission': 0.0,
          'time': createTime,
          'isBuyer': false,
          'isConvert': true,
        });
        trades.add({
          'id': 'convert_${orderId}_buy',
          'orderId': orderId,
          'symbol': toAsset,
          'price': 0.0,
          'qty': toAmount,
          'commission': 0.0,
          'time': createTime,
          'isBuyer': true,
          'isConvert': true,
        });
      }
    }

    return trades;
  }

  /// Автоматичний імпорт та розрахунок активних траншів за методом FIFO (Spot + Convert)
  Future<List<DcaTransaction>> getSpotTradeHistoryWithFifo(
    List<String> symbols, {
    Map<String, double>? currentSpotBalances,
    Map<String, double>? currentPrices,
    List<DcaTransaction>? existingTranches,
  }) async {
    if (!isConfigured) return [];

    final List<DcaTransaction> allActiveTranches = [];

    // Базові монети для пошуку
    final targetSymbols = symbols
        .map((s) => s.toUpperCase())
        .where((s) => !_quoteAssets.contains(s))
        .toSet();

    // 1. Отримуємо операції швидкої конвертації (Binance Convert)
    final rawConvert = await getConvertTrades(maxDays: 360);
    final parsedConvertTrades = parseConvertTrades(rawConvert);

    // Додаємо монети з конвертацій
    for (final ct in parsedConvertTrades) {
      final sym = ct['symbol']?.toString().toUpperCase();
      if (sym != null && !_quoteAssets.contains(sym)) {
        targetSymbols.add(sym);
      }
    }

    final Map<String, List<Map<String, dynamic>>> convertBySymbol = {};
    for (final ct in parsedConvertTrades) {
      final sym = ct['symbol']?.toString().toUpperCase() ?? '';
      if (sym.isNotEmpty) {
        convertBySymbol.putIfAbsent(sym, () => []).add(ct);
      }
    }

    // 2. Отримуємо спотові угоди біржового стакана для кожного символу
    final Map<String, List<Map<String, dynamic>>> spotBySymbol = {};
    await Future.wait(targetSymbols.map((sym) async {
      final rawSpot = await getMyTrades(sym);
      if (rawSpot.isNotEmpty) {
        spotBySymbol[sym] = rawSpot;
      }
    }));

    // 3. Об'єднуємо всі операції (Convert + Spot) за часом та застосовуємо FIFO
    for (final sym in targetSymbols) {
      final List<Map<String, dynamic>> combined = <Map<String, dynamic>>[
        ...(convertBySymbol[sym] ?? const <Map<String, dynamic>>[]),
        ...(spotBySymbol[sym] ?? const <Map<String, dynamic>>[]),
      ];

      if (combined.isNotEmpty) {
        final tranches = applyFifoToTrades(sym, combined);
        allActiveTranches.addAll(tranches);
      }
    }

    // 4. Захисний фолбек: якщо монета є на реальному балансі Binance Spot,
    // але для неї не знайдено історії транзакцій (давній депозит або операція > 1 року тому),
    // ми все одно додаємо її залишок, щоб у користувача не було порожнього екрану
    if (currentSpotBalances != null && currentSpotBalances.isNotEmpty) {
      for (final entry in currentSpotBalances.entries) {
        final sym = entry.key.toUpperCase();
        final actualBalance = entry.value;

        if (_quoteAssets.contains(sym) || actualBalance <= 0.00000001) continue;

        final existingMatches = allActiveTranches.where((t) => t.symbol.toUpperCase() == sym).toList();
        if (existingMatches.isEmpty) {
          // Шукаємо, чи була ця монета вже збережена в базі раніше з початковою ціною
          DcaTransaction? previouslySaved;
          if (existingTranches != null) {
            final prevList = existingTranches.where((t) =>
                t.id == 'binance_balance_$sym' ||
                (t.walletType == 'Binance Spot' && t.symbol.toUpperCase() == sym)).toList();
            if (prevList.isNotEmpty) {
              previouslySaved = prevList.first;
            }
          }

          final initialPrice = (previouslySaved != null && previouslySaved.buyPrice > 0)
              ? previouslySaved.buyPrice
              : (currentPrices?[sym] ?? 0.0);
          final initialDate = previouslySaved?.txDate ?? DateTime.now();

          allActiveTranches.add(DcaTransaction(
            id: 'binance_balance_$sym',
            symbol: sym,
            walletType: 'Binance Spot',
            amount: actualBalance,
            buyPrice: initialPrice,
            fee: previouslySaved?.fee ?? 0.0,
            txDate: initialDate,
            notes: (previouslySaved != null && previouslySaved.notes.isNotEmpty)
                ? previouslySaved.notes
                : 'Поточний баланс Binance (імпортовано з гаманця)',
          ));
        }
      }
    }

    // Сортуємо всі транші від найновіших до найстаріших
    allActiveTranches.sort((a, b) => b.txDate.compareTo(a.txDate));
    return allActiveTranches;
  }

  /// Метод FIFO (First In, First Out) для виділення виключно активних залишків монет
  static List<DcaTransaction> applyFifoToTrades(String symbol, List<Map<String, dynamic>> rawTrades) {
    if (rawTrades.isEmpty) return [];

    // Сортуємо угоди від найстарішої до найновішої за часом
    final sorted = List<Map<String, dynamic>>.from(rawTrades)
      ..sort((a, b) => ((a['time'] as num?) ?? 0).compareTo((b['time'] as num?) ?? 0));

    final List<({
      String id,
      double amount,
      double buyPrice,
      double fee,
      DateTime time,
      String orderId,
      bool isConvert,
    })> activeBuys = [];

    for (final t in sorted) {
      final isBuyer = t['isBuyer'] == true;
      final price = double.tryParse(t['price']?.toString() ?? '0') ?? 0.0;
      final qty = double.tryParse(t['qty']?.toString() ?? '0') ?? 0.0;
      final commission = double.tryParse(t['commission']?.toString() ?? '0') ?? 0.0;
      final timeMs = (t['time'] as num?)?.toInt() ?? 0;
      final time = DateTime.fromMillisecondsSinceEpoch(timeMs);
      final id = t['id']?.toString() ?? 'trade_$timeMs';
      final orderId = t['orderId']?.toString() ?? '';
      final isConvert = t['isConvert'] == true;

      if (qty <= 0) continue;

      if (isBuyer) {
        // Покупка: ставимо новий транш у чергу FIFO
        activeBuys.add((
          id: id,
          amount: qty,
          buyPrice: price,
          fee: commission,
          time: time,
          orderId: orderId,
          isConvert: isConvert,
        ));
      } else {
        // Продаж: списуємо з найстаріших покупок у черзі
        double remainingToSell = qty;
        while (remainingToSell > 0.00000001 && activeBuys.isNotEmpty) {
          final oldest = activeBuys.first;
          if (oldest.amount <= remainingToSell) {
            remainingToSell -= oldest.amount;
            activeBuys.removeAt(0); // Ця покупка повністю закрита/продана
          } else {
            // Частково продана: зменшуємо залишок у найстарішому транші
            final remainingInTranche = oldest.amount - remainingToSell;
            remainingToSell = 0.0;
            activeBuys[0] = (
              id: oldest.id,
              amount: remainingInTranche,
              buyPrice: oldest.buyPrice,
              fee: oldest.fee,
              time: oldest.time,
              orderId: oldest.orderId,
              isConvert: oldest.isConvert,
            );
          }
        }
      }
    }

    // Повертаємо тільки активні залишки
    return activeBuys.map((b) => DcaTransaction(
      id: b.id,
      symbol: symbol.toUpperCase(),
      walletType: 'Binance Spot',
      amount: b.amount,
      buyPrice: b.buyPrice,
      fee: b.fee,
      txDate: b.time,
      notes: b.isConvert
          ? 'Binance Convert #${b.orderId}'
          : (b.orderId.isNotEmpty ? 'Ордер #${b.orderId} (FIFO залишок)' : 'FIFO залишок'),
    )).toList();
  }
}

