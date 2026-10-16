import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models/crypto_models.dart';

class GroqAiService {
  final String? apiKey;
  static const String _groqUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'llama-3.3-70b-versatile';

  GroqAiService({this.apiKey});

  bool get isConfigured =>
      apiKey != null &&
      apiKey!.trim().isNotEmpty &&
      !apiKey!.contains('your_groq');

  Future<GroqAuditReport> auditPortfolio({
    required List<HoldingItem> holdings,
    required CashRatioInfo cashRatio,
  }) async {
    if (holdings.isEmpty) {
      return GroqAuditReport(
        overallHealthScore: 50,
        diversificationStatus: 'ПОРОЖНІЙ',
        cashReserveComment: 'Активи не виявлені.',
        assetRecommendations: [],
        strategicSummary: 'Додайте активи до гаманця або підключіть біржу для запуску AI-аудиту.',
      );
    }

    // Якщо ключ введено, робимо запит до Groq Llama 3.3 70B
    if (isConfigured) {
      try {
        final summaryAssets = holdings.take(15).map((h) => {
          'symbol': h.symbol,
          'total_usd': h.totalUsd,
          'share_pct': h.sharePct,
          'pnl_pct': h.pnlPct,
          'avg_entry': h.avgEntryPrice,
          'current_price': h.currentPrice,
          'bollinger_upper_1d': h.tpSl.bollingerUpper,
          'bollinger_middle_sma20': h.tpSl.bollingerMiddle,
          'bollinger_lower_1d': h.tpSl.bollingerLower,
          'swing_high_resistance': h.tpSl.swingHigh,
          'swing_low_support': h.tpSl.swingLow,
          'global_peak_100d': h.tpSl.globalPeak100d,
          'channel_position': h.tpSl.positionInChannel,
          'tp1_layer_bollinger': h.tpSl.tp1,
          'tp2_layer_resistance': h.tpSl.tp2,
          'tp3_layer_peak': h.tpSl.tp3,
          'accumulate_dip_price': h.tpSl.accumulatePrice,
          'structural_stop_loss': h.tpSl.stopLoss,
          'rsi_14': h.tpSl.rsi,
          'rsi_status': h.tpSl.rsiStatus,
          'rsi_divergence': h.tpSl.rsiDivergence,
          'atr_volatility_pct': h.tpSl.atrPct,
          'volume_status': h.tpSl.volumeStatus,
          'risk_reward_ratio': h.tpSl.riskRewardRatio,
          'risk_reward_label': h.tpSl.riskRewardLabel,
          'btc_market_regime': h.tpSl.btcMarketRegime,
        }).toList();

        const systemPrompt = '''
Ти — Професійний Квант-Трейдер та Керуючий Криптопортфелем.
Твоє завдання — провести глибокий аудит відкритого криптопортфелю клієнта на основі індикаторів 1D свічок.
Для кожного активу тобі надані реальні індикатори:
- Смуги Боллінджера (SMA 20, 2 StdDev): bollinger_upper_1d, bollinger_lower_1d.
- RSI (14 періодів): rsi_14, rsi_status, rsi_divergence (Бичача / Ведмежа дивергенція).
- Волатильність ATR: atr_volatility_pct, адаптивний стоп-лос (structural_stop_loss).
- Об'єм (Volume): volume_status (наявність великих гравців / сплеск об'єму).
- Співвідношення Ризик/Прибуток: risk_reward_ratio, risk_reward_label.
- Стан ринку BTC: btc_market_regime (Бичачий / Ведмежий фон).
- 3 Шари фіксації TP: Шар 1 (30%), Шар 2 (35%), Шар 3 (35%), рівень закупки на дні (accumulate_dip_price).

Ти повинен надати відповідь ВИКЛЮЧНО у валідному форматі JSON без жодного додаткового тексту чи markdown-обгорток.

Формат JSON:
{
  "overall_health_score": 85,
  "diversification_status": "ДОБРА",
  "cash_reserve_comment": "Коментар щодо достатності кешу та стейблкоїнів українською мовою",
  "asset_recommendations": [
    {
      "symbol": "BTC",
      "action": "HOLD",
      "risk_level": "LOW",
      "reason": "Чітке обґрунтування з урахуванням RSI, R:R та шарів фіксації українською мовою"
    }
  ],
  "strategic_summary": "Стратегічний підсумок: кого фіксувати по шарах, кого добирати на дні за RSI/DCA, стан фону BTC і кеш-подушки"
}

Допустимі значення action: HOLD, ACCUMULATE, TAKE_PROFIT, REDUCE
Допустимі значення risk_level: LOW, MEDIUM, HIGH

Торгові правила:
1. Якщо RSI > 70 або ціна біля/вище bollinger_upper_1d: action: TAKE_PROFIT. Рекомендуй скинути 30% на Шар 1 і зафіксувати прибуток у стейбли.
2. Якщо RSI < 35 або виявлено бичачу дивергенцію біля bollinger_lower_1d чи swing_low: action: ACCUMULATE. Вкажи ціну закупки accumulate_dip_price.
3. Якщо risk_reward_ratio < 1.4: попередь, що ризик перевищує прибуток, краще дочекатися глибшого просідання або виходу в беззбиток.
4. Якщо btc_market_regime ведмежий — попередь про додаткову обережність щодо альткоїнів.
5. Якщо частка монети > 35% (крім BTC/ETH) — action: REDUCE.
6. Усі тексти мають бути грамотною, професійною УКРАЇНСЬКОЮ МОВОЮ трейдера.
''';

        final userPrompt = '''
ДАНІ ПОРТФЕЛЮ:
- Загальний капітал: \$${cashRatio.totalUsd.toStringAsFixed(2)}
- Частка кешу (стейблкоїнів): ${cashRatio.cashPercentage}% (\$${cashRatio.cashUsd.toStringAsFixed(2)})
- Частка волатильної крипти: ${cashRatio.cryptoPercentage}% (\$${cashRatio.cryptoUsd.toStringAsFixed(2)})
- Активи з технічними індикаторами 1D:
${json.encode(summaryAssets)}
''';

        final body = json.encode({
          'model': _model,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': userPrompt},
          ],
          'temperature': 0.1,
          'response_format': {'type': 'json_object'},
        });

        final response = await http.post(
          Uri.parse(_groqUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${apiKey!.trim()}',
          },
          body: body,
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = json.decode(utf8.decode(response.bodyBytes));
          final content = data['choices']?[0]?['message']?['content']?.toString() ?? '{}';
          final jsonResult = json.decode(content);
          return GroqAuditReport.fromJson(jsonResult);
        }
      } catch (_) {
        // У разі збою мережі переходимо до детермінованого квант-аналізу
      }
    }

    // Детермінований квант-аналіз (фолбек без Groq ключа або в офлайні)
    return _generateDeterministicAudit(holdings, cashRatio);
  }

  GroqAuditReport _generateDeterministicAudit(
    List<HoldingItem> holdings,
    CashRatioInfo cashRatio,
  ) {
    int healthScore = 78;
    if (cashRatio.cashPercentage < 10) healthScore -= 15;
    if (cashRatio.cashPercentage > 50) healthScore -= 5;

    // Перевірка концентрації
    bool highConcentration = false;
    for (final h in holdings) {
      if (h.symbol != 'BTC' && h.symbol != 'ETH' && h.sharePct > 40) {
        highConcentration = true;
        healthScore -= 10;
        break;
      }
    }

    final String divStatus = highConcentration
        ? 'СЛАБКА'
        : (holdings.length >= 4 ? 'ДОБРА' : 'ПОМІРНА');

    final List<GroqAuditItem> recs = [];
    for (final h in holdings.take(12)) {
      String action = 'HOLD';
      String risk = 'MEDIUM';
      String reason = '';

      final isOverbought = h.tpSl.rsi >= 70 || (h.tpSl.bollingerUpper > 0 && h.currentPrice >= (h.tpSl.bollingerUpper * 0.98));
      final isOversold = h.tpSl.rsi <= 35 || (h.tpSl.bollingerLower > 0 && h.currentPrice <= (h.tpSl.bollingerLower * 1.02));
      final hasBullishDiv = h.tpSl.rsiDivergence.contains('Бичача');

      if (h.sharePct > 40 && h.symbol != 'BTC' && h.symbol != 'ETH') {
        action = 'REDUCE';
        risk = 'HIGH';
        reason = 'Частка ${h.sharePct.toStringAsFixed(1)}% перевищує допустимий ліміт. Рекомендовано знизити позицію.';
      } else if (isOverbought || h.pnlPct >= 50) {
        action = 'TAKE_PROFIT';
        risk = 'MEDIUM';
        reason = 'Перегрів (RSI ${h.tpSl.rsi.toStringAsFixed(1)}, біля верхнього Боллінджера). Фіксуйте 30% на Шар 1 (\$${h.tpSl.tp1.toStringAsFixed(2)}).';
      } else if (isOversold || hasBullishDiv) {
        action = 'ACCUMULATE';
        risk = h.tpSl.riskRewardRatio >= 1.5 ? 'MEDIUM' : 'HIGH';
        reason = '${hasBullishDiv ? 'Бичача дивергенція! ' : ''}Зона накопичення (RSI ${h.tpSl.rsi.toStringAsFixed(1)}). Рівень закупки: \$${h.tpSl.accumulatePrice.toStringAsFixed(2)}. ${h.tpSl.riskRewardLabel}.';
      } else {
        action = 'HOLD';
        risk = 'LOW';
        reason = '${h.tpSl.positionInChannel}. RSI: ${h.tpSl.rsi.toStringAsFixed(1)}. ${h.tpSl.riskRewardLabel}. Ціль TP 1: \$${h.tpSl.tp1.toStringAsFixed(2)}.';
      }

      recs.add(GroqAuditItem(
        symbol: h.symbol,
        action: action,
        riskLevel: risk,
        reason: reason,
      ));
    }

    return GroqAuditReport(
      overallHealthScore: healthScore.clamp(20, 100),
      diversificationStatus: divStatus,
      cashReserveComment: cashRatio.aiAdvice,
      assetRecommendations: recs,
      strategicSummary: highConcentration
          ? 'У портфелі присутній ризик концентрації. Використовуйте Смуги Боллінджера для фіксації прибутку по шарах у стейблкоїни.'
          : 'Аналіз 1D свічок: активи знаходяться у розрахункових технічних коридорах. Дотримуйтесь сітки Take-Profit (шари 1-3) та виставляйте ліміти на відкуп у зонах накопичення.',
    );
  }

  /// Мультиагентний AI-аналіз кандидатів для формування звіту «AI-Радар»
  Future<AiMarketRadarReport> analyzeMarketOpportunities({
    required List<Map<String, dynamic>> candidates,
    required int totalCoinsScanned,
  }) async {
    if (candidates.isEmpty) {
      return AiMarketRadarReport(
        scannedAt: DateTime.now(),
        marketRegime: 'Нейтральний ринок',
        btcTrend: 'Консолідація',
        macroSummary: 'Не знайдено сильних сетапів перепроданості з достатньою ліквідністю на даний момент.',
        totalCoinsScanned: totalCoinsScanned,
        opportunities: const [],
      );
    }

    if (isConfigured) {
      try {
        const systemPrompt = '''
Ти — Висококласний Мультиагентний Інвестиційний Комітет з криптовалют.
Твоє завдання — проаналізувати технічні дані відібраних кандидатів у глибоких просадках на Binance Spot і відібрати найкращі 3-6 монет для середньострокового накопичення (DCA на 3-6 місяців).
Для кожної монети обов'язково розрахуй:
- entry_zone_min та entry_zone_max (діапазон безпечної закупки частинами)
- target_price_1 (+25%..+40%) та target_price_2 (+60%..+120%)
- stop_loss (скасування сетапу, -12%..-18%)
- risk_reward_ratio (мінімум 1:3)
- sector (AI & Big Data, Layer 1, RWA, DePIN, DeFi, Gaming тощо)
- technical_reason, smart_money_catalyst, dca_strategy (все українською мовою, конкретно і професійно).

ВІДПОВІДЬ НАДАЙ ВИКЛЮЧНО В ЧИСТОМУ JSON БЕЗ МАРКДАУНУ (RAW JSON):
{
  "market_regime": "Зона вигідного накопичення альткоїнів",
  "btc_trend": "Консолідація над 50 SMA / Накопичення",
  "macro_summary": "Стратегічний коментар для інвестора українською мовою...",
  "opportunities": [
    {
      "symbol": "NEAR",
      "name": "NEAR Protocol",
      "sector": "AI & Layer 1",
      "current_price": 4.25,
      "entry_zone_min": 3.90,
      "entry_zone_max": 4.30,
      "target_price_1": 5.80,
      "target_price_2": 7.50,
      "stop_loss": 3.45,
      "potential_pct": 76.5,
      "risk_reward_ratio": 4.1,
      "risk_level": "Помірний",
      "confidence_score": 88,
      "technical_reason": "RSI 32 біля нижньої смуги Боллінджера з формуванням бичачої дивергенції.",
      "smart_money_catalyst": "Різке збільшення обсягів на просадці, ознаки поглинання ліквідності смарт-мані.",
      "dca_strategy": "Сітка в 3 кроки: 35% за поточною ціною, 35% при тесті підтримки, 30% на підтвердженні розвороту."
    }
  ]
}
''';

        final userPrompt = json.encode({
          'total_scanned_pairs': totalCoinsScanned,
          'filtered_quant_candidates': candidates,
        });

        final response = await http.post(
          Uri.parse(_groqUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: json.encode({
            'model': _model,
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': userPrompt},
            ],
            'temperature': 0.2,
            'response_format': {'type': 'json_object'},
          }),
        ).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final content = data['choices'][0]['message']['content'];
          final parsed = json.decode(content);

          final rawOpps = parsed['opportunities'] as List<dynamic>? ?? [];
          final List<AiMarketOpportunity> opps = [];

          for (final o in rawOpps) {
            final sym = o['symbol']?.toString().toUpperCase() ?? '';
            final currPrice = (o['current_price'] as num?)?.toDouble() ?? 0.0;
            final entryMin = (o['entry_zone_min'] as num?)?.toDouble() ?? currPrice * 0.95;
            final entryMax = (o['entry_zone_max'] as num?)?.toDouble() ?? currPrice * 1.02;
            final tp1 = (o['target_price_1'] as num?)?.toDouble() ?? currPrice * 1.3;
            final tp2 = (o['target_price_2'] as num?)?.toDouble() ?? currPrice * 1.6;
            final sl = (o['stop_loss'] as num?)?.toDouble() ?? currPrice * 0.85;

            final candidateMatch = candidates.firstWhere(
              (c) => c['symbol'] == sym,
              orElse: () => <String, dynamic>{},
            );

            opps.add(AiMarketOpportunity(
              symbol: sym,
              name: o['name']?.toString() ?? sym,
              sector: o['sector']?.toString() ?? 'Altcoin',
              currentPrice: currPrice > 0 ? currPrice : (candidateMatch['currentPrice'] as double? ?? 1.0),
              entryZoneMin: entryMin,
              entryZoneMax: entryMax,
              targetPrice1: tp1,
              targetPrice2: tp2,
              stopLoss: sl,
              potentialPct: (o['potential_pct'] as num?)?.toDouble() ?? (((tp2 - currPrice) / (currPrice > 0 ? currPrice : 1.0)) * 100),
              riskRewardRatio: (o['risk_reward_ratio'] as num?)?.toDouble() ?? 3.5,
              riskLevel: o['risk_level']?.toString() ?? 'Помірний',
              confidenceScore: (o['confidence_score'] as num?)?.toInt() ?? 80,
              technicalReason: o['technical_reason']?.toString() ?? 'Технічна перепроданість та відбій від підтримки.',
              smartMoneyCatalyst: o['smart_money_catalyst']?.toString() ?? 'Підвищений торговий інтерес на консолідації.',
              dcaStrategy: o['dca_strategy']?.toString() ?? 'Вхід частинами в діапазоні підтримки.',
              rsi: (candidateMatch['rsi'] as num?)?.toDouble() ?? 38.0,
              dropFromPeakPct: (candidateMatch['dropFromPeakPct'] as num?)?.toDouble() ?? 45.0,
              volume24hUsd: (candidateMatch['quoteVolume'] as num?)?.toDouble() ?? 5000000.0,
              scannedAt: DateTime.now(),
            ));
          }

          if (opps.isNotEmpty) {
            return AiMarketRadarReport(
              scannedAt: DateTime.now(),
              marketRegime: parsed['market_regime']?.toString() ?? 'Зона накопичення альткоїнів',
              btcTrend: parsed['btc_trend']?.toString() ?? 'Консолідація',
              macroSummary: parsed['macro_summary']?.toString() ?? 'Формуються сприятливі умови для середньострокового DCA.',
              totalCoinsScanned: totalCoinsScanned,
              opportunities: opps,
            );
          }
        }
      } catch (_) {}
    }

    // Резервний алгоритмічний розрахунок
    return _generateFallbackRadarReport(candidates, totalCoinsScanned);
  }

  AiMarketRadarReport _generateFallbackRadarReport(
    List<Map<String, dynamic>> candidates,
    int totalCoinsScanned,
  ) {
    final List<AiMarketOpportunity> opps = [];

    for (final c in candidates.take(5)) {
      final sym = c['symbol']?.toString().toUpperCase() ?? '';
      final price = (c['currentPrice'] as num?)?.toDouble() ?? 1.0;
      final rsi = (c['rsi'] as num?)?.toDouble() ?? 40.0;
      final drop = (c['dropFromPeakPct'] as num?)?.toDouble() ?? 40.0;
      final vol = (c['quoteVolume'] as num?)?.toDouble() ?? 5000000.0;

      final tp1 = price * 1.35;
      final tp2 = price * 1.75;
      final sl = price * 0.85;
      final rr = ((tp2 - price) / (price - sl)).clamp(1.5, 8.0);

      opps.add(AiMarketOpportunity(
        symbol: sym,
        name: sym,
        sector: 'Top Altcoin',
        currentPrice: price,
        entryZoneMin: price * 0.94,
        entryZoneMax: price * 1.01,
        targetPrice1: tp1,
        targetPrice2: tp2,
        stopLoss: sl,
        potentialPct: 75.0,
        riskRewardRatio: double.parse(rr.toStringAsFixed(1)),
        riskLevel: rsi < 35 ? 'Низький' : 'Помірний',
        confidenceScore: (80 + (drop > 50 ? 8 : 0)).clamp(60, 95),
        technicalReason: 'RSI $rsi вказує на сильну перепроданість, дисконт від піку -$drop%.',
        smartMoneyCatalyst: 'Стійкий добовий обсяг (\$${(vol / 1000000).toStringAsFixed(1)}M) сигналізує про викуп просадки.',
        dcaStrategy: 'Рекомендовано DCA у 3 ордери: 40% зараз, 30% на -5%, 30% на -10%.',
        rsi: rsi,
        dropFromPeakPct: drop,
        volume24hUsd: vol,
        scannedAt: DateTime.now(),
      ));
    }

    return AiMarketRadarReport(
      scannedAt: DateTime.now(),
      marketRegime: 'Зона стратегічного накопичення',
      btcTrend: 'Ринковий баланс',
      macroSummary: 'Квантовий скринер виявив монети з глибоким дисконтом від локальних максимумів та перепроданим RSI.',
      totalCoinsScanned: totalCoinsScanned,
      opportunities: opps,
    );
  }
}

