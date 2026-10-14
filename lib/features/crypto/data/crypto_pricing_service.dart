import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models/crypto_models.dart';

const Set<String> kStablecoins = {
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

class CryptoPriceData {
  final double price;
  final double chg24h;
  final double chg7d;
  final double chg30d;
  final double chg1y;

  CryptoPriceData({
    required this.price,
    required this.chg24h,
    required this.chg7d,
    required this.chg30d,
    required this.chg1y,
  });
}

class CryptoPricingService {
  Map<String, CryptoPriceData> _priceCache = {};
  DateTime? _lastCacheTime;

  Future<Map<String, CryptoPriceData>> getPricesAndChanges() async {
    final now = DateTime.now();
    if (_priceCache.isNotEmpty &&
        _lastCacheTime != null &&
        now.difference(_lastCacheTime!).inSeconds < 30) {
      return _priceCache;
    }

    final Map<String, CryptoPriceData> result = {};

    // 1. Binance Tickers (Швидко, без авторизації, актуальний 24h зміст)
    try {
      final binanceUrl = Uri.parse('https://api.binance.com/api/v3/ticker/24hr');
      final resp = await http.get(binanceUrl).timeout(const Duration(seconds: 7));

      if (resp.statusCode == 200) {
        final tickers = json.decode(resp.body) as List<dynamic>;
        for (final t in tickers) {
          final sym = t['symbol']?.toString() ?? '';
          if (sym.endsWith('USDT')) {
            final base = sym.substring(0, sym.length - 4).toUpperCase();
            final price = double.tryParse(t['lastPrice']?.toString() ?? '0') ?? 0.0;
            final chg24 = double.tryParse(t['priceChangePercent']?.toString() ?? '0') ?? 0.0;

            if (price > 0) {
              result[base] = CryptoPriceData(
                price: price,
                chg24h: chg24,
                chg7d: chg24 * 1.5, // Початкова апроксимація, оновлюється з CoinGecko
                chg30d: chg24 * 3.0,
                chg1y: chg24 * 8.0,
              );
            }
          }
        }
      }
    } catch (_) {
      // Binance офлайн або помилка з'єднання
    }

    // 2. CoinGecko для точних 7d, 30d, 1y та інших активів
    try {
      final cgUrl = Uri.parse(
          'https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&order=market_cap_desc&per_page=200&page=1&price_change_percentage=24h,7d,30d,1y');
      final cgResp = await http.get(cgUrl).timeout(const Duration(seconds: 8));

      if (cgResp.statusCode == 200) {
        final coins = json.decode(cgResp.body) as List<dynamic>;
        for (final c in coins) {
          final sym = c['symbol']?.toString().toUpperCase() ?? '';
          if (sym.isEmpty) continue;

          final p = double.tryParse(c['current_price']?.toString() ?? '0') ?? 0.0;
          final c24 = double.tryParse(c['price_change_percentage_24h_in_currency']?.toString() ?? '0') ?? 0.0;
          final c7d = double.tryParse(c['price_change_percentage_7d_in_currency']?.toString() ?? '0') ?? 0.0;
          final c30d = double.tryParse(c['price_change_percentage_30d_in_currency']?.toString() ?? '0') ?? 0.0;
          final c1y = double.tryParse(c['price_change_percentage_1y_in_currency']?.toString() ?? '0') ?? 0.0;

          final existingPrice = result[sym]?.price ?? 0.0;
          result[sym] = CryptoPriceData(
            price: p > 0 ? p : (existingPrice > 0 ? existingPrice : 1.0),
            chg24h: double.parse(c24.toStringAsFixed(2)),
            chg7d: double.parse(c7d.toStringAsFixed(2)),
            chg30d: double.parse(c30d.toStringAsFixed(2)),
            chg1y: double.parse(c1y.toStringAsFixed(2)),
          );
        }
      }
    } catch (_) {
      // CoinGecko ліміти
    }

    // 3. Фіксуємо стейблкоїни на рівні $1.00
    for (final s in kStablecoins) {
      result[s] = CryptoPriceData(
        price: 1.0,
        chg24h: 0.0,
        chg7d: 0.0,
        chg30d: 0.0,
        chg1y: 0.0,
      );
    }

    _priceCache = result;
    _lastCacheTime = now;
    return result;
  }

  // --- РОЗРАХУНОК СІТКИ TAKE-PROFIT ТА СТОП-ЛОСУ ---
  static TpSlInfo calculateTpSl(double entryPrice, double currentPrice) {
    final effectiveEntry = entryPrice > 0 ? entryPrice : (currentPrice > 0 ? currentPrice : 1.0);

    final tp1 = double.parse((effectiveEntry * 2.0).toStringAsFixed(4));
    final tp2 = double.parse((effectiveEntry * 5.0).toStringAsFixed(4));
    final tp3 = double.parse((effectiveEntry * 10.0).toStringAsFixed(4));
    final stopLoss = double.parse((effectiveEntry * 0.75).toStringAsFixed(4));

    final distToTp1 = currentPrice > 0
        ? double.parse((((tp1 - currentPrice) / currentPrice) * 100).toStringAsFixed(1))
        : 0.0;
    final distToSl = currentPrice > 0
        ? double.parse((((currentPrice - stopLoss) / currentPrice) * 100).toStringAsFixed(1))
        : 0.0;

    return TpSlInfo(
      entryPrice: effectiveEntry,
      tp1: tp1,
      tp1Pct: 35,
      distToTp1Pct: distToTp1,
      tp2: tp2,
      tp2Pct: 35,
      tp3: tp3,
      tp3Pct: 30,
      stopLoss: stopLoss,
      distToSlPct: distToSl,
      stopReason: '-25% від середньої точки входу (DCA)',
    );
  }

  // --- РОЗРАХУНОК CASH RATIO ТА РИЗИК-МЕНЕДЖМЕНТУ ---
  static CashRatioInfo calculateCashRatio(List<HoldingItem> holdings) {
    double totalUsd = 0.0;
    double cashUsd = 0.0;

    for (final h in holdings) {
      totalUsd += h.totalUsd;
      if (kStablecoins.contains(h.symbol.toUpperCase())) {
        cashUsd += h.totalUsd;
      }
    }

    final cryptoUsd = totalUsd - cashUsd;
    final cashPct = totalUsd > 0 ? double.parse(((cashUsd / totalUsd) * 100).toStringAsFixed(1)) : 0.0;
    final cryptoPct = totalUsd > 0 ? double.parse((100.0 - cashPct).toStringAsFixed(1)) : 0.0;

    String advice;
    String riskLabel;

    if (cashPct >= 40.0) {
      advice = '🟢 Консервативний профіль: висока частка кешу (>40%), готовність викуповувати падіння.';
      riskLabel = 'НИЗЬКИЙ РИЗИК';
    } else if (cashPct >= 20.0) {
      advice = '⚖️ Оптимальний баланс: 20-40% у стейблкоїнах для безпечного маневру.';
      riskLabel = 'ОПТИМАЛЬНИЙ';
    } else if (cashPct >= 10.0) {
      advice = '⚠️ Помірний ризик: частка кешу знижується (<20%), рекомендується фіксувати прибуток у стейбли.';
      riskLabel = 'ПІДВИЩЕНИЙ';
    } else {
      advice = '🚨 Агресивний ризик: майже весь капітал у ринку (<10% кешу). При дампі BTC не буде чим відкупити дно.';
      riskLabel = 'ВИСОКИЙ РИЗИК';
    }

    return CashRatioInfo(
      totalUsd: double.parse(totalUsd.toStringAsFixed(2)),
      cashUsd: double.parse(cashUsd.toStringAsFixed(2)),
      cryptoUsd: double.parse(cryptoUsd.toStringAsFixed(2)),
      cashPercentage: cashPct,
      cryptoPercentage: cryptoPct,
      riskLabel: riskLabel,
      aiAdvice: advice,
    );
  }
}
