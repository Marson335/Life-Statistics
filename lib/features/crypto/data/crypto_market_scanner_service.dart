import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models/crypto_models.dart';
import 'groq_ai_service.dart';

class CryptoMarketScannerService {
  final GroqAiService groqService;
  static const String _baseUrl = 'https://api.binance.com';

  static const Set<String> _excludedTokens = {
    'USDT', 'USDC', 'FDUSD', 'TUSD', 'DAI', 'BUSD', 'EUR', 'GBP', 'UAH',
    'TRY', 'BIDR', 'IDRT', 'AUD', 'CAD', 'BRL', 'JPY', 'RUB', 'PAXG',
    'WBTC', 'WETH', 'WBETH', 'BTCST', 'USDD', 'PYUSD', 'AEUR',
  };

  CryptoMarketScannerService({required this.groqService});

  /// Повний цикл сканування: 350+ монет -> Квантовий відсів -> Технічний аналіз -> AI Мультиагентний синтез
  Future<AiMarketRadarReport> scanMarket({
    void Function(String stage, double progress)? onProgress,
  }) async {
    try {
      onProgress?.call('Завантаження котирувань 350+ спотових пар Binance...', 0.15);

      // 1. Завантажуємо 24-годинні котирування всіх пар Binance в один запит
      final tickerUrl = Uri.parse('$_baseUrl/api/v3/ticker/24hr');
      final tickerResp = await http.get(tickerUrl).timeout(const Duration(seconds: 10));

      if (tickerResp.statusCode != 200) {
        throw Exception('Помилка отримання біржових котирувань Binance (${tickerResp.statusCode})');
      }

      final List<dynamic> allTickers = json.decode(tickerResp.body);
      final totalScanned = allTickers.length;

      onProgress?.call('Квантовий відсів та пошук зон накопичення...', 0.35);

      // 2. Первинний квантовий фільтр
      final List<Map<String, dynamic>> filteredPairs = [];

      for (final t in allTickers) {
        final symbol = t['symbol']?.toString().toUpperCase() ?? '';
        if (!symbol.endsWith('USDT')) continue;

        final baseAsset = symbol.replaceAll('USDT', '');
        if (_excludedTokens.contains(baseAsset)) continue;
        if (baseAsset.contains('UP') || baseAsset.contains('DOWN') || baseAsset.contains('BULL') || baseAsset.contains('BEAR')) continue;

        final quoteVolume = double.tryParse(t['quoteVolume']?.toString() ?? '0') ?? 0.0;
        final lastPrice = double.tryParse(t['lastPrice']?.toString() ?? '0') ?? 0.0;
        final priceChangePct = double.tryParse(t['priceChangePercent']?.toString() ?? '0') ?? 0.0;

        // Ліквідність: мінімум $1,000,000 добового обсягу, щоб уникнути неліквідних шиткоїнів
        if (quoteVolume < 1000000 || lastPrice <= 0) continue;

        // Шукаємо монети в просадці або в стадії консолідації (не перегріті пампами)
        // Пріоритет: просадка від -15% до +3% за 24г з великим торговим інтересом
        double dipScore = 0.0;
        if (priceChangePct < -3.0) dipScore += 25.0;
        if (priceChangePct < -8.0) {
          dipScore += 35.0;
        }
        if (priceChangePct >= -3.0 && priceChangePct <= 2.0) {
          dipScore += 15.0; // консолідація
        }

        // Логарифмічний бонус об'єму (чим вища ліквідність і активність інституціоналів, тим краще)
        if (quoteVolume > 50000000) {
          dipScore += 30.0;
        } else if (quoteVolume > 15000000) {
          dipScore += 20.0;
        } else if (quoteVolume > 5000000) {
          dipScore += 10.0;
        }

        filteredPairs.add({
          'symbol': baseAsset,
          'pair': symbol,
          'lastPrice': lastPrice,
          'quoteVolume': quoteVolume,
          'priceChangePct': priceChangePct,
          'highPrice24h': double.tryParse(t['highPrice']?.toString() ?? '0') ?? lastPrice,
          'lowPrice24h': double.tryParse(t['lowPrice']?.toString() ?? '0') ?? lastPrice,
          'initialScore': dipScore,
        });
      }

      // Сортуємо кандидатів за первинним балом просадки та беремо ТОП-20 для глибокого свічкового аналізу
      filteredPairs.sort((a, b) => (b['initialScore'] as double).compareTo(a['initialScore'] as double));
      final topCandidates = filteredPairs.take(20).toList();

      onProgress?.call('Технічний аналіз індикаторів (RSI, Боллінджер, об\'єми)...', 0.60);

      // 3. Паралельний розрахунок технічних індикаторів для ТОП-20 кандидатів
      final List<Map<String, dynamic>> analyzedCandidates = [];

      await Future.wait(topCandidates.map((c) async {
        try {
          final sym = c['symbol'] as String;
          final pair = c['pair'] as String;
          final klinesUrl = Uri.parse('$_baseUrl/api/v3/klines?symbol=$pair&interval=1d&limit=60');
          final kResp = await http.get(klinesUrl).timeout(const Duration(seconds: 4));

          if (kResp.statusCode == 200) {
            final klines = json.decode(kResp.body) as List<dynamic>;
            if (klines.length >= 25) {
              final closes = klines.map((k) => double.tryParse(k[4].toString()) ?? 0.0).toList();
              final highs = klines.map((k) => double.tryParse(k[2].toString()) ?? 0.0).toList();
              final volumes = klines.map((k) => double.tryParse(k[5].toString()) ?? 0.0).toList();

              final currentPrice = closes.last;
              final maxPeak60d = highs.reduce((a, b) => a > b ? a : b);
              final dropFromPeakPct = maxPeak60d > 0 ? ((maxPeak60d - currentPrice) / maxPeak60d) * 100 : 0.0;

              // Розрахунок RSI (14)
              final rsi = _calculateRsi(closes, period: 14);

              // Смуги Боллінджера (SMA 20)
              final bb = _calculateBollingerBands(closes, period: 20);

              // Співвідношення об'єму (останній день до середнього за 14 днів)
              final avgVol = volumes.reversed.take(14).fold(0.0, (s, v) => s + v) / 14.0;
              final volumeRatio = avgVol > 0 ? volumes.last / avgVol : 1.0;

              // Фінальний квантовий бал привабливості накопичення (0 - 100)
              double alphaScore = 0.0;
              if (rsi < 35) {
                alphaScore += 35.0; // Сильна перепроданість
              } else if (rsi < 45) {
                alphaScore += 20.0;
              } else if (rsi > 68) {
                alphaScore -= 20.0; // Перекуплений - штраф
              }

              if (dropFromPeakPct > 50.0) {
                alphaScore += 30.0; // Глибока знижка
              } else if (dropFromPeakPct > 30.0) {
                alphaScore += 20.0;
              }

              // Відбій від нижньої межі Боллінджера (до 3% від нижньої смуги)
              if (bb.lower > 0 && currentPrice <= bb.lower * 1.04) {
                alphaScore += 20.0;
              }

              // Аномалія розумних грошей (сплеск об'єму на просадці)
              if (volumeRatio > 1.25) {
                alphaScore += 15.0;
              }

              analyzedCandidates.add({
                'symbol': sym,
                'currentPrice': currentPrice,
                'quoteVolume': c['quoteVolume'],
                'priceChange24h': c['priceChangePct'],
                'rsi': double.parse(rsi.toStringAsFixed(1)),
                'dropFromPeakPct': double.parse(dropFromPeakPct.toStringAsFixed(1)),
                'bollingerLower': bb.lower,
                'bollingerUpper': bb.upper,
                'volumeRatio': double.parse(volumeRatio.toStringAsFixed(2)),
                'alphaScore': alphaScore,
              });
            }
          }
        } catch (_) {}
      }));

      // Сортуємо кандидатів за підсумковим балом та беремо ТОП 8 найперспективніших монет
      analyzedCandidates.sort((a, b) => (b['alphaScore'] as double).compareTo(a['alphaScore'] as double));
      final topPicksForAi = analyzedCandidates.take(8).toList();

      onProgress?.call('Синтез рішень мультиагентним AI-комітетом...', 0.85);

      // 4. Запит до AI-комітету аналітиків через Groq (Llama 3.3 70B)
      final radarReport = await groqService.analyzeMarketOpportunities(
        candidates: topPicksForAi,
        totalCoinsScanned: totalScanned,
      );

      onProgress?.call('Аналіз завершено!', 1.0);
      return radarReport;
    } catch (e) {
      // Повертаємо резервний звіт у разі непередбачуваної помилки мережі
      return AiMarketRadarReport(
        scannedAt: DateTime.now(),
        marketRegime: 'Помилка сканування',
        btcTrend: '—',
        macroSummary: 'Не вдалося завершити сканування: $e. Перевірте з\'єднання з інтернетом та повторіть спробу.',
        totalCoinsScanned: 0,
        opportunities: const [],
      );
    }
  }

  // --- МАТЕМАТИЧНІ РОЗРАХУНКИ ТЕХНІЧНИХ ІНДИКАТОРІВ ---

  static double _calculateRsi(List<double> prices, {int period = 14}) {
    if (prices.length <= period) return 50.0;

    double gains = 0.0;
    double losses = 0.0;

    for (int i = 1; i <= period; i++) {
      final diff = prices[i] - prices[i - 1];
      if (diff >= 0) {
        gains += diff;
      } else {
        losses -= diff;
      }
    }

    double avgGain = gains / period;
    double avgLoss = losses / period;

    for (int i = period + 1; i < prices.length; i++) {
      final diff = prices[i] - prices[i - 1];
      final currentGain = diff >= 0 ? diff : 0.0;
      final currentLoss = diff < 0 ? -diff : 0.0;

      avgGain = ((avgGain * (period - 1)) + currentGain) / period;
      avgLoss = ((avgLoss * (period - 1)) + currentLoss) / period;
    }

    if (avgLoss == 0) return 100.0;
    final rs = avgGain / avgLoss;
    return 100.0 - (100.0 / (1.0 + rs));
  }

  static ({double upper, double middle, double lower}) _calculateBollingerBands(
    List<double> prices, {
    int period = 20,
    double stdDevMultiplier = 2.0,
  }) {
    if (prices.length < period) return (upper: 0.0, middle: 0.0, lower: 0.0);

    final sublist = prices.sublist(prices.length - period);
    final sma = sublist.reduce((a, b) => a + b) / period;

    double varianceSum = 0.0;
    for (final p in sublist) {
      varianceSum += (p - sma) * (p - sma);
    }
    final stdDev = (varianceSum / period > 0) ? (varianceSum / period).clamp(0.0, double.infinity) : 0.0;
    final std = stdDev > 0 ? (stdDev > 0 ? _sqrt(stdDev) : 0.0) : 0.0;

    return (
      upper: sma + (stdDevMultiplier * std),
      middle: sma,
      lower: (sma - (stdDevMultiplier * std)).clamp(0.0, double.infinity),
    );
  }

  static double _sqrt(double val) {
    if (val <= 0) return 0.0;
    double x = val;
    double y = 1.0;
    const e = 0.000001;
    while (x - y > e) {
      x = (x + y) / 2;
      y = val / x;
    }
    return x;
  }
}
