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

  static const Set<String> _stablecoins = {
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

  static const Set<String> _coreAssets = {'BTC', 'ETH', 'WBTC', 'WETH'};

  Future<GroqAuditReport> auditPortfolio({
    required List<HoldingItem> holdings,
    required CashRatioInfo cashRatio,
    List<DcaGroupedCoin> dcaCoins = const [],
    double futuresMargin = 0.0,
    double futuresPnl = 0.0,
    List<BinancePositionItem> futuresPositions = const [],
  }) async {
    // 1. Об'єднуємо спотові активи з точними цінами закупки із DCA (FIFO + Ручні)
    final Map<String, DcaGroupedCoin> dcaMap = {
      for (final c in dcaCoins) c.symbol.toUpperCase(): c,
    };

    final List<HoldingItem> unifiedHoldings = [];
    final Set<String> processedSymbols = {};

    for (final h in holdings) {
      final sym = h.symbol.toUpperCase();
      processedSymbols.add(sym);
      final dca = dcaMap[sym];

      double avgEntry = h.avgEntryPrice;
      if (dca != null && dca.avgEntryPrice > 0) {
        avgEntry = dca.avgEntryPrice;
      }

      final costUsd = h.amount * avgEntry;
      final pnlUsd = _stablecoins.contains(sym) ? 0.0 : (h.totalUsd - costUsd);
      final pnlPct = (!_stablecoins.contains(sym) && costUsd > 0)
          ? ((pnlUsd / costUsd) * 100.0)
          : 0.0;

      unifiedHoldings.add(HoldingItem(
        symbol: sym,
        amount: h.amount,
        currentPrice: h.currentPrice,
        totalUsd: h.totalUsd,
        avgEntryPrice: avgEntry,
        pnlUsd: double.parse(pnlUsd.toStringAsFixed(2)),
        pnlPct: double.parse(pnlPct.toStringAsFixed(2)),
        chg24h: h.chg24h,
        chg7d: h.chg7d,
        chg30d: h.chg30d,
        chg1y: h.chg1y,
        sharePct: h.sharePct,
        sources: h.sources,
        tpSl: h.tpSl,
      ));
    }

    // Якщо користувач додав ручні DCA монети, яких немає в біржовому списку holdings
    for (final dca in dcaCoins) {
      final sym = dca.symbol.toUpperCase();
      if (!processedSymbols.contains(sym) && dca.totalValueUsd >= 0.5) {
        final curPrice = dca.currentPrice > 0 ? dca.currentPrice : dca.avgEntryPrice;
        final tp1 = double.parse((curPrice * 1.25).toStringAsFixed(4));
        final tp2 = double.parse((curPrice * 1.55).toStringAsFixed(4));
        final tp3 = double.parse((curPrice * 2.10).toStringAsFixed(4));
        final sl = double.parse((curPrice * 0.88).toStringAsFixed(4));
        final acc = double.parse((curPrice * 0.92).toStringAsFixed(4));

        unifiedHoldings.add(HoldingItem(
          symbol: sym,
          amount: dca.totalAmount,
          currentPrice: curPrice,
          totalUsd: dca.totalValueUsd,
          avgEntryPrice: dca.avgEntryPrice,
          pnlUsd: double.parse(dca.pnlUsd.toStringAsFixed(2)),
          pnlPct: double.parse(dca.pnlPct.toStringAsFixed(2)),
          chg24h: 0.0,
          chg7d: 0.0,
          chg30d: 0.0,
          chg1y: 0.0,
          sharePct: 0.0,
          sources: const ['DCA'],
          tpSl: TpSlInfo(
            entryPrice: dca.avgEntryPrice,
            tp1: tp1,
            tp1Pct: 30,
            distToTp1Pct: 25.0,
            tp2: tp2,
            tp2Pct: 35,
            distToTp2Pct: 55.0,
            tp3: tp3,
            tp3Pct: 35,
            distToTp3Pct: 110.0,
            stopLoss: sl,
            distToSlPct: 12.0,
            stopReason: 'Захисний стоп (-12%)',
            accumulatePrice: acc,
            distToAccumulatePct: 8.0,
            rsi: 48.0,
            atrPct: 4.5,
            riskRewardRatio: 2.3,
          ),
        ));
      }
    }

    // Відсікаємо мікроскопічний пил (< $0.50), якщо є нормальні позиції
    final activeHoldings = unifiedHoldings.where((h) => h.totalUsd >= 0.50).toList();
    final targetHoldings = activeHoldings.isNotEmpty ? activeHoldings : unifiedHoldings;

    if (targetHoldings.isEmpty && futuresMargin <= 0) {
      return GroqAuditReport(
        overallHealthScore: 50,
        diversificationStatus: 'ПОРОЖНІЙ',
        cashReserveComment: 'Активи не виявлені на споті або в DCA.',
        assetRecommendations: [],
        strategicSummary: 'Додайте активи до гаманця, синхронізуйте Binance Spot або внесіть угоду в DCA для запуску професійного аудиту.',
      );
    }

    // 2. Будуємо точний математичний квант-аудит як базовий фундамент
    final baseReport = _generateDeterministicAudit(
      targetHoldings,
      cashRatio,
      futuresMargin: futuresMargin,
      futuresPnl: futuresPnl,
      futuresPositions: futuresPositions,
    );

    // 3. Якщо налаштовано Groq API — збагачуємо аналітику через Llama 3.3 70B зі збереженням точних чисел
    if (isConfigured && baseReport.assetRecommendations.isNotEmpty) {
      try {
        final summaryAssets = baseReport.assetRecommendations.take(15).map((item) => {
          'symbol': item.symbol,
          'total_usd': item.totalUsd,
          'share_pct': item.sharePct,
          'avg_entry_price': item.avgEntryPrice,
          'current_price': item.currentPrice,
          'pnl_usd': item.pnlUsd,
          'pnl_pct': item.pnlPct,
          'rsi_14d': item.rsi,
          'rsi_divergence': item.rsiDivergence,
          'channel_position': item.channelPosition,
          'atr_volatility_pct': item.atrPct,
          'volume_status': item.volumeStatus,
          'risk_reward_ratio': item.riskRewardRatio,
          'tp1_price_30pct': item.tp1Price,
          'tp2_price_35pct': item.tp2Price,
          'tp3_price_35pct': item.tp3Price,
          'dca_buy_dip_price': item.dcaBuyPrice,
          'structural_stop_loss': item.stopLossPrice,
          'quant_suggested_action': item.action,
        }).toList();

        const systemPrompt = '''
Ти — Головний Квант-Трейдер та Ризик-Менеджер Інституційного Криптофонду.
Твоє завдання — провести глибокий, конкретний та зрозумілий аудит криптопортфеля клієнта на основі реальних позицій, їхньої ціни закупки (Avg Entry), поточного PnL та технічних індикаторів 1D свічок.

ВАЖЛИВІ ПРАВИЛА:
1. Використовуй ТОЧНІ ціни та відсотки із вхідних даних (`avg_entry_price`, `current_price`, `pnl_pct`, `share_pct`, `tp1_price_30pct`, `tp2_price_35pct`, `dca_buy_dip_price`, `structural_stop_loss`). Не вигадуй випадкових цифр.
2. По кожній монеті з `summaryAssets` надай:
   - `action`: одне зі значень `TAKE_PROFIT`, `ACCUMULATE`, `HOLD`, `REDUCE`, `STOP_WATCH`.
   - `action_label_uk`: короткий наказ українською (наприклад: `ФІКСУВАТИ ЧАСТИНУ`, `ДОБИРАТИ НА СПАДІ`, `УТРИМУВАТИ`, `СКОРОТИТИ КОНЦЕНТРАЦІЮ`, `КОНТРОЛЬ СТОПУ`).
   - `risk_level`: `LOW`, `MEDIUM` або `HIGH`.
   - `reason`: детальне пояснення стану позиції (порівняння ціни закупки з ринком, поточний PnL, RSI, положення в каналі Боллінджера, R:R та вага монети в портфелі).
   - `execution_plan`: чіткий покроковий план дій з конкретними цінами: де фіксувати TP1 (30%) та TP2 (35%), за якою ціною стоїть ліміт на добір (`dca_buy_dip_price`) і де проходить захисний стоп (`structural_stop_loss`).
3. Сформуй `priority_actions` — список із 3–4 конкретних першочергових кроків для трейдера прямо зараз.
4. Надай відповідь ВИКЛЮЧНО у валідному JSON без markdown-обгорток:
{
  "overall_health_score": 82,
  "diversification_status": "ДОБРА",
  "cash_reserve_comment": "Детальний аналіз кеш-подушки в стейблкоїнах та суми на відкуп просадок...",
  "risk_summary": "Аналіз концентрації активів, кореляції з BTC, волатильності та ф'ючерсного плеча...",
  "strategic_summary": "Комплексний висновок керуючого портфелем...",
  "priority_actions": [
    "1. Зафіксувати 30% прибутку по ...",
    "2. Виставити лімітний ордер на добір ... по \$..."
  ],
  "asset_recommendations": [
    {
      "symbol": "SOL",
      "action": "ACCUMULATE",
      "action_label_uk": "ДОБИРАТИ НА СПАДІ",
      "risk_level": "MEDIUM",
      "reason": "Розбір позиції...",
      "execution_plan": "Торговий план із точними цінами..."
    }
  ]
}
''';

        final userPrompt = json.encode({
          'portfolio_metrics': {
            'total_value_usd': baseReport.totalValueUsd,
            'total_invested_usd': baseReport.totalInvestedUsd,
            'total_pnl_usd': baseReport.totalPnlUsd,
            'total_pnl_pct': baseReport.totalPnlPct,
            'cash_stablecoins_pct': baseReport.cashPct,
            'cash_stablecoins_usd': baseReport.cashUsd,
            'core_btc_eth_pct': baseReport.corePct,
            'altcoins_pct': baseReport.altPct,
            'top_asset': '${baseReport.topAssetSymbol} (${baseReport.topAssetSharePct}%)',
            'futures_margin_usd': baseReport.futuresMarginUsd,
            'futures_unrealized_pnl_usd': baseReport.futuresPnlUsd,
            'btc_market_regime': baseReport.marketRegime,
          },
          'assets': summaryAssets,
        });

        final response = await http.post(
          Uri.parse(_groqUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${apiKey!.trim()}',
          },
          body: json.encode({
            'model': _model,
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': userPrompt},
            ],
            'temperature': 0.15,
            'response_format': {'type': 'json_object'},
          }),
        ).timeout(const Duration(seconds: 16));

        if (response.statusCode == 200) {
          final data = json.decode(utf8.decode(response.bodyBytes));
          final content = data['choices']?[0]?['message']?['content']?.toString() ?? '{}';
          final parsed = json.decode(content) as Map<String, dynamic>;

          final aiRecsRaw = parsed['asset_recommendations'] as List<dynamic>? ?? [];
          final Map<String, Map<String, dynamic>> aiRecMap = {};
          for (final r in aiRecsRaw) {
            if (r is Map<String, dynamic>) {
              final s = r['symbol']?.toString().toUpperCase() ?? '';
              if (s.isNotEmpty) aiRecMap[s] = r;
            }
          }

          final List<GroqAuditItem> mergedRecs = baseReport.assetRecommendations.map((baseItem) {
            final aiItem = aiRecMap[baseItem.symbol];
            if (aiItem == null) return baseItem;

            final aiAction = aiItem['action']?.toString().toUpperCase();
            final validAction = (aiAction != null &&
                    ['TAKE_PROFIT', 'ACCUMULATE', 'HOLD', 'REDUCE', 'STOP_WATCH'].contains(aiAction))
                ? aiAction
                : baseItem.action;

            final aiReason = aiItem['reason']?.toString().trim() ?? '';
            final aiPlan = aiItem['execution_plan']?.toString().trim() ?? '';
            final aiLabel = aiItem['action_label_uk']?.toString().trim() ?? '';

            return GroqAuditItem(
              symbol: baseItem.symbol,
              action: validAction,
              actionLabelUk: aiLabel.isNotEmpty ? aiLabel : _defaultActionLabelUk(validAction),
              riskLevel: aiItem['risk_level']?.toString().toUpperCase() ?? baseItem.riskLevel,
              reason: aiReason.isNotEmpty ? aiReason : baseItem.reason,
              executionPlan: aiPlan.isNotEmpty ? aiPlan : baseItem.executionPlan,
              amount: baseItem.amount,
              currentPrice: baseItem.currentPrice,
              avgEntryPrice: baseItem.avgEntryPrice,
              totalUsd: baseItem.totalUsd,
              sharePct: baseItem.sharePct,
              pnlUsd: baseItem.pnlUsd,
              pnlPct: baseItem.pnlPct,
              rsi: baseItem.rsi,
              rsiDivergence: baseItem.rsiDivergence,
              channelPosition: baseItem.channelPosition,
              atrPct: baseItem.atrPct,
              volumeStatus: baseItem.volumeStatus,
              riskRewardRatio: baseItem.riskRewardRatio,
              tp1Price: baseItem.tp1Price,
              tp2Price: baseItem.tp2Price,
              tp3Price: baseItem.tp3Price,
              dcaBuyPrice: baseItem.dcaBuyPrice,
              stopLossPrice: baseItem.stopLossPrice,
            );
          }).toList();

          final aiPriority = (parsed['priority_actions'] as List<dynamic>?)
                  ?.map((e) => e.toString().trim())
                  .where((e) => e.isNotEmpty)
                  .toList() ??
              [];

          final aiScore = (parsed['overall_health_score'] as num?)?.toInt();

          return GroqAuditReport(
            overallHealthScore: aiScore != null
                ? ((aiScore + baseReport.overallHealthScore) ~/ 2).clamp(20, 99)
                : baseReport.overallHealthScore,
            diversificationStatus: parsed['diversification_status']?.toString() ?? baseReport.diversificationStatus,
            marketRegime: baseReport.marketRegime,
            totalValueUsd: baseReport.totalValueUsd,
            totalInvestedUsd: baseReport.totalInvestedUsd,
            totalPnlUsd: baseReport.totalPnlUsd,
            totalPnlPct: baseReport.totalPnlPct,
            cashPct: baseReport.cashPct,
            cashUsd: baseReport.cashUsd,
            corePct: baseReport.corePct,
            coreUsd: baseReport.coreUsd,
            altPct: baseReport.altPct,
            altUsd: baseReport.altUsd,
            futuresMarginUsd: baseReport.futuresMarginUsd,
            futuresPnlUsd: baseReport.futuresPnlUsd,
            topAssetSymbol: baseReport.topAssetSymbol,
            topAssetSharePct: baseReport.topAssetSharePct,
            cashReserveComment: (parsed['cash_reserve_comment']?.toString().trim().isNotEmpty ?? false)
                ? parsed['cash_reserve_comment'].toString()
                : baseReport.cashReserveComment,
            riskSummary: (parsed['risk_summary']?.toString().trim().isNotEmpty ?? false)
                ? parsed['risk_summary'].toString()
                : baseReport.riskSummary,
            strategicSummary: (parsed['strategic_summary']?.toString().trim().isNotEmpty ?? false)
                ? parsed['strategic_summary'].toString()
                : baseReport.strategicSummary,
            priorityActions: aiPriority.isNotEmpty ? aiPriority : baseReport.priorityActions,
            assetRecommendations: mergedRecs,
            auditedAt: DateTime.now(),
          );
        }
      } catch (_) {
        // У разі тайм-ауту чи офлайну повертаємо повний математичний квант-аудит
      }
    }

    return baseReport;
  }

  GroqAuditReport _generateDeterministicAudit(
    List<HoldingItem> holdings,
    CashRatioInfo cashRatio, {
    double futuresMargin = 0.0,
    double futuresPnl = 0.0,
    List<BinancePositionItem> futuresPositions = const [],
  }) {
    // 1. Розрахунок структури капіталу
    double cashUsd = 0.0;
    double coreUsd = 0.0;
    double altUsd = 0.0;
    double spotInvestedUsd = 0.0;
    double spotPnlUsd = 0.0;

    for (final h in holdings) {
      final sym = h.symbol.toUpperCase();
      if (_stablecoins.contains(sym)) {
        cashUsd += h.totalUsd;
        spotInvestedUsd += h.totalUsd;
      } else if (_coreAssets.contains(sym)) {
        coreUsd += h.totalUsd;
        spotInvestedUsd += (h.amount * h.avgEntryPrice);
        spotPnlUsd += h.pnlUsd;
      } else {
        altUsd += h.totalUsd;
        spotInvestedUsd += (h.amount * h.avgEntryPrice);
        spotPnlUsd += h.pnlUsd;
      }
    }

    final double totalSpotUsd = cashUsd + coreUsd + altUsd;
    final double totalPortfolioUsd = totalSpotUsd + futuresMargin;
    final double totalInvestedUsd = spotInvestedUsd + (futuresMargin - futuresPnl);
    final double totalPnlUsd = spotPnlUsd + futuresPnl;
    final double totalPnlPct = totalInvestedUsd > 0 ? ((totalPnlUsd / totalInvestedUsd) * 100.0) : 0.0;

    final double denom = totalPortfolioUsd > 0 ? totalPortfolioUsd : 1.0;
    final double cashPct = double.parse(((cashUsd / denom) * 100.0).toStringAsFixed(1));
    final double corePct = double.parse(((coreUsd / denom) * 100.0).toStringAsFixed(1));
    final double altPct = double.parse(((altUsd / denom) * 100.0).toStringAsFixed(1));

    // Нормалізуємо частки монет відносно загального капіталу
    final List<HoldingItem> normalized = holdings.map((h) {
      final share = double.parse(((h.totalUsd / denom) * 100.0).toStringAsFixed(1));
      return HoldingItem(
        symbol: h.symbol,
        amount: h.amount,
        currentPrice: h.currentPrice,
        totalUsd: h.totalUsd,
        avgEntryPrice: h.avgEntryPrice,
        pnlUsd: h.pnlUsd,
        pnlPct: h.pnlPct,
        chg24h: h.chg24h,
        chg7d: h.chg7d,
        chg30d: h.chg30d,
        chg1y: h.chg1y,
        sharePct: share,
        sources: h.sources,
        tpSl: h.tpSl,
      );
    }).toList()
      ..sort((a, b) => b.totalUsd.compareTo(a.totalUsd));

    final cryptoOnly = normalized.where((h) => !_stablecoins.contains(h.symbol.toUpperCase())).toList();
    final targetAssets = cryptoOnly.isNotEmpty ? cryptoOnly : normalized;

    String topAssetSymbol = '—';
    double topAssetSharePct = 0.0;
    if (targetAssets.isNotEmpty) {
      topAssetSymbol = targetAssets.first.symbol;
      topAssetSharePct = targetAssets.first.sharePct;
    }

    String marketRegime = '⚪ Нейтральний ринок BTC';
    for (final h in normalized) {
      if (h.tpSl.btcMarketRegime.isNotEmpty && !h.tpSl.btcMarketRegime.contains('аналізується')) {
        marketRegime = h.tpSl.btcMarketRegime;
        break;
      }
    }

    // 2. 4-факторна оцінка здоров'я портфеля (0-100)
    // Фактор А: Ліквідність / Кеш-подушка (25 балів)
    int liquidityScore = 22;
    if (cashPct >= 15 && cashPct <= 40) {
      liquidityScore = 25;
    } else if (cashPct >= 8 && cashPct < 15) {
      liquidityScore = 19;
    } else if (cashPct < 8) {
      liquidityScore = 11;
    } else if (cashPct > 65) {
      liquidityScore = 16;
    }

    // Фактор Б: Диверсифікація та Концентрація (25 балів)
    int divScore = 22;
    bool highAltConcentration = false;
    double maxAltShare = 0.0;
    String maxAltSym = '';
    for (final h in cryptoOnly) {
      if (!_coreAssets.contains(h.symbol.toUpperCase()) && h.sharePct > maxAltShare) {
        maxAltShare = h.sharePct;
        maxAltSym = h.symbol;
      }
    }
    if (maxAltShare > 40.0) {
      highAltConcentration = true;
      divScore = 10;
    } else if (maxAltShare > 28.0) {
      highAltConcentration = true;
      divScore = 15;
    } else if (cryptoOnly.length >= 3 && corePct >= 20.0) {
      divScore = 25;
    } else if (cryptoOnly.length == 1 && cryptoOnly.first.totalUsd > 20) {
      divScore = 15;
    }

    final String divStatus = maxAltShare > 40.0
        ? 'ПЕРЕКІС ($maxAltSym ${maxAltShare.toStringAsFixed(0)}%)'
        : (highAltConcentration
            ? 'КОНЦЕНТРАЦІЯ'
            : (cryptoOnly.length >= 4 ? 'ВІДМІННА' : (cryptoOnly.length >= 2 ? 'ДОБРА' : 'БАЗОВА')));

    // Фактор В: Технічна якість позицій та R:R (25 балів)
    int techScore = 20;
    if (cryptoOnly.isNotEmpty) {
      double avgRr = 0.0;
      int overboughtUnfixed = 0;
      for (final h in cryptoOnly) {
        avgRr += h.tpSl.riskRewardRatio;
        if (h.tpSl.rsi >= 72 && h.pnlPct > 15) overboughtUnfixed++;
      }
      avgRr /= cryptoOnly.length;
      if (avgRr >= 2.2) {
        techScore = 24;
      } else if (avgRr < 1.4) {
        techScore = 15;
      }
      if (overboughtUnfixed > 0) techScore -= 3;
    }

    // Фактор Г: Стійкість PnL та Ф'ючерсний ризик (25 балів)
    int pnlScore = 20;
    if (totalPnlPct >= 10) {
      pnlScore = 24;
    } else if (totalPnlPct <= -25) {
      pnlScore = 13;
    } else if (totalPnlPct < -10) {
      pnlScore = 16;
    }
    for (final fp in futuresPositions) {
      if (fp.leverage >= 15) {
        pnlScore -= 5;
        break;
      }
    }

    final int healthScore = (liquidityScore + divScore + techScore + pnlScore).clamp(25, 98);

    // 3. Поглиблений аудит кожної позиції
    final List<GroqAuditItem> recs = [];
    final List<String> takeProfitSymbols = [];
    final List<String> accumulateSymbols = [];
    final List<String> reduceSymbols = [];

    for (final h in targetAssets.take(15)) {
      final sym = h.symbol.toUpperCase();
      final isStable = _stablecoins.contains(sym);

      if (isStable) {
        recs.add(GroqAuditItem(
          symbol: sym,
          action: 'HOLD',
          actionLabelUk: 'КЕШ-РЕЗЕРВ (DRY POWDER)',
          riskLevel: 'LOW',
          reason:
              'Стейблкоїн-резерв на суму \$${h.totalUsd.toStringAsFixed(2)} (${h.sharePct}% портфеля). Забезпечує захист від просадок ринку та ліквідність для лімітних ордерів DCA.',
          executionPlan:
              'Утримувати як резерв ліквідності. Використовувати траншами по 25–30% для відкупу активів у зонах перепроданості (RSI < 38) або за сигналами вкладки AI-Радар.',
          amount: h.amount,
          currentPrice: 1.0,
          avgEntryPrice: 1.0,
          totalUsd: h.totalUsd,
          sharePct: h.sharePct,
          pnlUsd: 0.0,
          pnlPct: 0.0,
          rsi: 50.0,
          rsiDivergence: 'Стабільний пег \$1.00',
          channelPosition: 'Стейблкоїн-резерв',
          atrPct: 0.2,
          volumeStatus: 'Висока ліквідність',
          riskRewardRatio: 5.0,
          tp1Price: 1.0,
          tp2Price: 1.0,
          tp3Price: 1.0,
          dcaBuyPrice: 1.0,
          stopLossPrice: 0.98,
        ));
        continue;
      }

      final rsi = h.tpSl.rsi;
      final rr = h.tpSl.riskRewardRatio;
      final isOverbought = rsi >= 68 || (h.tpSl.bollingerUpper > 0 && h.currentPrice >= (h.tpSl.bollingerUpper * 0.98));
      final isOversold = rsi <= 40 || (h.tpSl.bollingerLower > 0 && h.currentPrice <= (h.tpSl.bollingerLower * 1.02));
      final hasBullDiv = h.tpSl.rsiDivergence.contains('Бичача');
      final hasBearDiv = h.tpSl.rsiDivergence.contains('Ведмежа');
      final isOverweightAlt = !_coreAssets.contains(sym) && h.sharePct > 35.0;

      // Розрахунок нової середньої при доборі +35% обсягу на рівні DCA
      final dcaPrice = h.tpSl.accumulatePrice > 0 ? h.tpSl.accumulatePrice : (h.currentPrice * 0.92);
      final newAvgAfterDca = h.avgEntryPrice > 0
          ? (((h.amount * h.avgEntryPrice) + (h.amount * 0.35 * dcaPrice)) / (h.amount * 1.35))
          : dcaPrice;

      final tp1PctGain = h.currentPrice > 0 ? (((h.tpSl.tp1 - h.currentPrice) / h.currentPrice) * 100.0) : 20.0;
      final tp2PctGain = h.currentPrice > 0 ? (((h.tpSl.tp2 - h.currentPrice) / h.currentPrice) * 100.0) : 45.0;
      final slPctRisk = h.currentPrice > 0 ? (((h.currentPrice - h.tpSl.stopLoss) / h.currentPrice) * 100.0) : 10.0;

      String action = 'HOLD';
      String actionLabelUk = 'УТРИМУВАТИ В СТРУКТУРІ';
      String risk = 'LOW';
      String reason = '';
      String executionPlan = '';

      if (isOverweightAlt) {
        action = 'REDUCE';
        actionLabelUk = 'СКОРОТИТИ КОНЦЕНТРАЦІЮ';
        risk = 'HIGH';
        reduceSymbols.add('$sym (${h.sharePct}%)');
        final targetTrimUsd = ((h.sharePct - 22.0).clamp(5.0, 50.0) / 100.0) * totalPortfolioUsd;
        reason =
            'Позиція займає ${h.sharePct.toStringAsFixed(1)}% портфеля (\$${h.totalUsd.toStringAsFixed(2)}), що створює надмірний ризик на один альткоїн. '
            'Середня ціна закупки: \$${_fmtPrice(h.avgEntryPrice)}, поточний результат: ${h.pnlPct >= 0 ? '+' : ''}${h.pnlPct.toStringAsFixed(2)}% (${h.pnlUsd >= 0 ? '+' : '-'}\$${h.pnlUsd.abs().toStringAsFixed(2)}). '
            'RSI(14D): ${rsi.toStringAsFixed(1)}, положення: ${h.tpSl.positionInChannel}.';
        executionPlan =
            'Розвантажити приблизно \$${targetTrimUsd.toStringAsFixed(0)} на поточному рівні або лімітним ордером біля TP1 \$${_fmtPrice(h.tpSl.tp1)} (+${tp1PctGain.toStringAsFixed(1)}%), перевівши вивільнений капітал у USDT або BTC/ETH. '
            'Захисний Stop-Loss для залишку тримати на \$${_fmtPrice(h.tpSl.stopLoss)} (-${slPctRisk.toStringAsFixed(1)}%).';
      } else if (isOverbought || hasBearDiv || h.pnlPct >= 40.0) {
        action = 'TAKE_PROFIT';
        actionLabelUk = 'ФІКСУВАТИ ЧАСТИНУ TP';
        risk = 'MEDIUM';
        takeProfitSymbols.add(sym);
        final fix30Usd = h.totalUsd * 0.30;
        reason =
            'Актив у плюсі на +${h.pnlPct.toStringAsFixed(2)}% (+\$${h.pnlUsd.abs().toStringAsFixed(2)}) від ціни входу \$${_fmtPrice(h.avgEntryPrice)}. '
            'Індикатори сигналізують локальний перегрів: RSI ${rsi.toStringAsFixed(1)}${hasBearDiv ? ', наявна ведмежа дивергенція' : ''}, ціна біля верхньої межі каналу. '
            'Співвідношення R:R для нових покупок зараз знижене ($rr:1).';
        executionPlan =
            '1) Зафіксувати 30% позиції (~\$${fix30Usd.toStringAsFixed(0)}) на рівні Шар 1: \$${_fmtPrice(h.tpSl.tp1)} (+${tp1PctGain.toStringAsFixed(1)}%). '
            '2) Перенести Stop-Loss у зону беззбитку (\$${_fmtPrice(h.avgEntryPrice)}). '
            '3) Наступні 35% виставити лімітом на Шар 2: \$${_fmtPrice(h.tpSl.tp2)} (+${tp2PctGain.toStringAsFixed(1)}%).';
      } else if (isOversold || hasBullDiv || (h.pnlPct <= -8.0 && rr >= 1.8)) {
        action = 'ACCUMULATE';
        actionLabelUk = 'ДОБИРАТИ НА СПАДІ (DCA)';
        risk = rr >= 1.8 ? 'LOW' : 'MEDIUM';
        accumulateSymbols.add('$sym (\$${_fmtPrice(dcaPrice)})');
        reason =
            '${hasBullDiv ? 'Виявлено бичачу дивергенцію RSI! ' : ''}Монета знаходиться у зоні дисконту (RSI ${rsi.toStringAsFixed(1)}, ${h.tpSl.positionInChannel}). '
            'Ваша ціна закупки: \$${_fmtPrice(h.avgEntryPrice)}, поточне відхилення: ${h.pnlPct >= 0 ? '+' : ''}${h.pnlPct.toStringAsFixed(2)}%. '
            'Математичне співвідношення Прибуток/Ризик вигідне ($rr:1), волатильність ATR становить ${h.tpSl.atrPct}%.';
        executionPlan =
            '1) Виставити лімітний ордер на добір у зоні підтримки \$${_fmtPrice(dcaPrice)} — це покращить вашу середню ціну входу з \$${_fmtPrice(h.avgEntryPrice)} до ~\$${_fmtPrice(newAvgAfterDca)}. '
            '2) Ціль розвантаження №1 (30% обсягу): \$${_fmtPrice(h.tpSl.tp1)} (+${tp1PctGain.toStringAsFixed(1)}%). '
            '3) Ціль №2 (35% обсягу): \$${_fmtPrice(h.tpSl.tp2)} (+${tp2PctGain.toStringAsFixed(1)}%). Захисний стоп за структурою: \$${_fmtPrice(h.tpSl.stopLoss)}.';
      } else if (h.pnlPct <= -16.0 && rr < 1.4) {
        action = 'STOP_WATCH';
        actionLabelUk = 'КОНТРОЛЬ СТОПУ / БЕЗ ДОБОРУ';
        risk = 'HIGH';
        reason =
            'Позиція у просадці ${h.pnlPct.toStringAsFixed(2)}% (вхід \$${_fmtPrice(h.avgEntryPrice)} проти ринку \$${_fmtPrice(h.currentPrice)}), при цьому поточний R:R слабкий ($rr:1). '
            'Усереднювати по поточній ціні передчасно — треба дочекатися підтвердження покупця.';
        executionPlan =
            'Тимчасово утриматися від ринкових докупок. Дозволений лише глибокий лімітний відкуп на рівні \$${_fmtPrice(dcaPrice)} при появі зеленої свічки викупу. '
            'Критичний рівень інвалідації структури (Stop-Loss): \$${_fmtPrice(h.tpSl.stopLoss)} (-${slPctRisk.toStringAsFixed(1)}%). На відскоку до \$${_fmtPrice(h.tpSl.tp1)} скоротити 30% позиції.';
      } else {
        action = 'HOLD';
        actionLabelUk = 'УТРИМУВАТИ ДО TP1/TP2';
        risk = rr >= 1.6 ? 'LOW' : 'MEDIUM';
        reason =
            'Здорова технічна структура: ${h.tpSl.positionInChannel}, RSI ${rsi.toStringAsFixed(1)}, ${h.tpSl.volumeStatus}. '
            'Ціна входу \$${_fmtPrice(h.avgEntryPrice)}, поточний PnL: ${h.pnlPct >= 0 ? '+' : ''}${h.pnlPct.toStringAsFixed(2)}% (${h.pnlUsd >= 0 ? '+' : '-'}\$${h.pnlUsd.abs().toStringAsFixed(2)}). '
            'Потенціал руху до опору дає робочий R:R ($rr:1).';
        executionPlan =
            'Утримувати позицію в рамках тренду. Виставити лімітний Take-Profit №1 (30% обсягу) на \$${_fmtPrice(h.tpSl.tp1)} (+${tp1PctGain.toStringAsFixed(1)}%) та Take-Profit №2 (35%) на \$${_fmtPrice(h.tpSl.tp2)} (+${tp2PctGain.toStringAsFixed(1)}%). '
            'Рівень добору на випадок проливу: \$${_fmtPrice(dcaPrice)}. Структурний стоп: \$${_fmtPrice(h.tpSl.stopLoss)} (-${slPctRisk.toStringAsFixed(1)}%).';
      }

      recs.add(GroqAuditItem(
        symbol: sym,
        action: action,
        actionLabelUk: actionLabelUk,
        riskLevel: risk,
        reason: reason,
        executionPlan: executionPlan,
        amount: h.amount,
        currentPrice: h.currentPrice,
        avgEntryPrice: h.avgEntryPrice,
        totalUsd: h.totalUsd,
        sharePct: h.sharePct,
        pnlUsd: h.pnlUsd,
        pnlPct: h.pnlPct,
        rsi: rsi,
        rsiDivergence: h.tpSl.rsiDivergence,
        channelPosition: h.tpSl.positionInChannel,
        atrPct: h.tpSl.atrPct,
        volumeStatus: h.tpSl.volumeStatus,
        riskRewardRatio: rr,
        tp1Price: h.tpSl.tp1,
        tp2Price: h.tpSl.tp2,
        tp3Price: h.tpSl.tp3,
        dcaBuyPrice: dcaPrice,
        stopLossPrice: h.tpSl.stopLoss,
      ));
    }

    // 4. Формуємо чіткий чек-лист першочергових дій трейдера
    final List<String> priorityActions = [];
    if (reduceSymbols.isNotEmpty) {
      priorityActions.add(
        'Ребалансування концентрації: знизити надмірну вагу в ${reduceSymbols.join(', ')} на найближчому імпульсі до TP1, перевівши частину в USDT або BTC.',
      );
    }
    if (takeProfitSymbols.isNotEmpty) {
      priorityActions.add(
        'Фіксація прибутку: виставити лімітні ордери на продаж 30% позиції по ${takeProfitSymbols.join(', ')} на рівнях Шар 1 (TP1) та перевести стопи в беззбиток.',
      );
    }
    if (accumulateSymbols.isNotEmpty) {
      priorityActions.add(
        'Розумний DCA-добір: розмістити лімітні ордери на відкуп дна по ${accumulateSymbols.take(3).join(', ')} для зниження середньої ціни закупки.',
      );
    }
    if (cashPct < 12.0) {
      priorityActions.add(
        'Поповнення кеш-подушки: частка стейблкоїнів становить лише $cashPct% (\$${cashUsd.toStringAsFixed(2)}). Спрямовуйте всі фіксації TP1 у USDT до досягнення резерву 20–25%.',
      );
    } else if (cashPct > 55.0) {
      priorityActions.add(
        'Робота з вільним кешем: у стейблкоїнах зосереджено $cashPct% (\$${cashUsd.toStringAsFixed(2)}). Використайте вкладку AI-Радар для поетапного набору недооцінених активів із R:R >= 1:3.',
      );
    }
    if (priorityActions.isEmpty) {
      priorityActions.add(
        'Утримувати поточну структуру портфеля: виставити каскадні Take-Profit ордери (TP1 30% / TP2 35%) та контролювати захисні стоп-рівні за денними свічками.',
      );
    }

    // 5. Коментар по кеш-подушці та аналіз ризиків
    final String cashComment = cashPct < 10.0
        ? 'Критично низький запас кешу: $cashPct% (\$${cashUsd.toStringAsFixed(2)}). У разі проливу ринку на 15–20% вам бракуватиме вільної ліквідності для вигідного усереднення. Пріоритет — фіксація TP1 у стейблкоїни.'
        : (cashPct <= 35.0
            ? 'Оптимальна інституційна кеш-подушка: $cashPct% (\$${cashUsd.toStringAsFixed(2)}). У вас достатньо «сухого пороху» для викупу локальних просадок за сіткою DCA без перевантаження ризиком.'
            : 'Високий захисний резерв у кеші: $cashPct% (\$${cashUsd.toStringAsFixed(2)}). Портфель максимально захищений від дампів і готовий до набору спотових сетапів із вкладки AI-Радар.');

    String riskSummary =
        'Розподіл капіталу: Фундамент (BTC/ETH) — $corePct% (\$${coreUsd.toStringAsFixed(2)}), Альткоїни — $altPct% (\$${altUsd.toStringAsFixed(2)}), Стейблкоїни — $cashPct% (\$${cashUsd.toStringAsFixed(2)}). ';
    if (highAltConcentration) {
      riskSummary +=
          'Виявлено підвищений ризик концентрації в $maxAltSym (${maxAltShare.toStringAsFixed(1)}% портфеля) — рекомендовано поступову диверсифікацію. ';
    } else {
      riskSummary += 'Вага окремих альткоїнів збалансована і не створює критичної загрози для капіталу. ';
    }
    if (futuresMargin > 0) {
      riskSummary +=
          'Відкрита ф\'ючерсна маржа: \$${futuresMargin.toStringAsFixed(2)} (поточний PnL: ${futuresPnl >= 0 ? '+' : ''}\$${futuresPnl.toStringAsFixed(2)}, активних позицій: ${futuresPositions.length}).';
    }

    final String strategicSummary =
        'Загальний баланс портфеля становить \$${totalPortfolioUsd.toStringAsFixed(2)} при вкладеному капіталі \$${totalInvestedUsd.toStringAsFixed(2)} '
        '(сумарний результат: ${totalPnlUsd >= 0 ? '+' : '-'}\$${totalPnlUsd.abs().toStringAsFixed(2)} або ${totalPnlPct >= 0 ? '+' : ''}${totalPnlPct.toStringAsFixed(2)}%). '
        '${highAltConcentration ? 'Головний фокус зараз — зменшити перекіс в окремих альткоїнах через часткову фіксацію на рівнях опору Боллінджера.' : 'Структура портфеля дозволяє комбінувати утримання сильних трендових позицій до TP1/TP2 з лімітним добором недооцінених монет на рівнях підтримки.'}';

    return GroqAuditReport(
      overallHealthScore: healthScore,
      diversificationStatus: divStatus,
      marketRegime: marketRegime,
      totalValueUsd: double.parse(totalPortfolioUsd.toStringAsFixed(2)),
      totalInvestedUsd: double.parse(totalInvestedUsd.toStringAsFixed(2)),
      totalPnlUsd: double.parse(totalPnlUsd.toStringAsFixed(2)),
      totalPnlPct: double.parse(totalPnlPct.toStringAsFixed(2)),
      cashPct: cashPct,
      cashUsd: double.parse(cashUsd.toStringAsFixed(2)),
      corePct: corePct,
      coreUsd: double.parse(coreUsd.toStringAsFixed(2)),
      altPct: altPct,
      altUsd: double.parse(altUsd.toStringAsFixed(2)),
      futuresMarginUsd: double.parse(futuresMargin.toStringAsFixed(2)),
      futuresPnlUsd: double.parse(futuresPnl.toStringAsFixed(2)),
      topAssetSymbol: topAssetSymbol,
      topAssetSharePct: topAssetSharePct,
      cashReserveComment: cashComment,
      riskSummary: riskSummary,
      strategicSummary: strategicSummary,
      priorityActions: priorityActions,
      assetRecommendations: recs,
      auditedAt: DateTime.now(),
    );
  }

  String _defaultActionLabelUk(String action) {
    switch (action.toUpperCase()) {
      case 'TAKE_PROFIT':
        return 'ФІКСУВАТИ ЧАСТИНУ TP';
      case 'ACCUMULATE':
        return 'ДОБИРАТИ НА СПАДІ (DCA)';
      case 'REDUCE':
        return 'СКОРОТИТИ КОНЦЕНТРАЦІЮ';
      case 'STOP_WATCH':
        return 'КОНТРОЛЬ СТОПУ';
      default:
        return 'УТРИМУВАТИ ДО TP1/TP2';
    }
  }

  String _fmtPrice(double val) {
    if (val >= 1000) return val.toStringAsFixed(2);
    if (val >= 1) return val.toStringAsFixed(2);
    if (val >= 0.01) return val.toStringAsFixed(4);
    if (val > 0) return val.toStringAsFixed(6);
    return '0.00';
  }

  /// Мультиагентний AI-аналіз кандидатів для формування звіту «AI-Радар»
  Future<AiMarketRadarReport> analyzeMarketOpportunities({
    required List<Map<String, dynamic>> candidates,
    required int totalCoinsScanned,
    String btcTrendContext = 'Консолідація',
  }) async {
    if (candidates.isEmpty) {
      return AiMarketRadarReport(
        scannedAt: DateTime.now(),
        marketRegime: 'Нейтральний ринок',
        btcTrend: btcTrendContext,
        macroSummary: 'Квантовий скринер не виявив сетапів із підтвердженим викупом Smart Money та співвідношенням R:R >= 1:2.6.',
        totalCoinsScanned: totalCoinsScanned,
        opportunities: const [],
      );
    }

    if (isConfigured) {
      try {
        const systemPrompt = '''
Ти — Інституційний Мультиагентний Комітет Алготрейдерів (Квантовий Аналітик, Аналітик Order Flow & Smart Money та Ризик-Архітектор).
Тобі передані кандидати з Binance Spot, які вже пройшли 5-факторний математичний відбір (Order Flow Taker Buy Ratio, бичача дивергенція, ATR волатильність, рівні Фібоначчі 0.382/0.618, структурний Support та Stop-Loss за рівнем підтримки мінус 1.2×ATR).

Твоє завдання — проаналізувати ці монети та сформувати професійний інвестиційний звіт українською мовою.
ВАЖЛИВО:
1. Використовуй вже розраховані математичні рівні з вхідних даних (`entryZoneMin`, `entryZoneMax`, `targetPrice1`, `targetPrice2`, `stopLoss`, `riskRewardRatio`), не вигадуй випадкові ціни.
2. Для кожної монети детально поясни:
   - `technical_reason`: структура графіка, поведінка RSI, відбій від підтримки, EMA/Bollinger Squeeze.
   - `smart_money_catalyst`: аналіз потоку ордерів (`takerBuyRatioPct` — частка агресивних покупок по ринку), OBV, відносна сила проти BTC (`rs7dVsBtc`).
   - `dca_strategy`: як саме розбити вхід ордерами між `entryZoneMax` та `entryZoneMin`.
   - `tp_trigger_rule`: чіткий алгоритм фіксації прибутку на TP1 (скільки % закрити + перенесення стопа в Беззбиток), на TP2 та за яким індикатором виходити достроково (наприклад, RSI > 74 або кульмінація обсягів).
   - `sl_trigger_rule`: чітка умова виходу в мінус на рівні `stopLoss` (закриття тіла свічки 4H/1D нижче рівня підтримки з буфером 1.2×ATR, щоб уникнути хибного вибивання шпилькою маркет-мейкера).

ВІДПОВІДЬ НАДАЙ ВИКЛЮЧНО В ЧИСТОМУ JSON БЕЗ МАРКДАУНУ (RAW JSON):
{
  "market_regime": "ACCUMULATION",
  "btc_trend": "Консолідація вище підтримки",
  "macro_summary": "Розгорнутий професійний огляд ринку та логіки відбору...",
  "opportunities": [
    {
      "symbol": "NEAR",
      "name": "NEAR Protocol",
      "sector": "AI & Layer 1",
      "setup_type": "Поглинання китів (Order Flow)",
      "risk_level": "Низький",
      "confidence_score": 89,
      "technical_reason": " Детальний технічний розбір...",
      "smart_money_catalyst": "Детальний розбір Taker Buy Volume та OBV...",
      "dca_strategy": "План набору позиції...",
      "tp_trigger_rule": "Коли і як фіксувати TP1 та TP2...",
      "sl_trigger_rule": "Коли і як виконувати Stop-Loss..."
    }
  ]
}
''';

        final userPrompt = json.encode({
          'total_scanned_pairs': totalCoinsScanned,
          'btc_trend_context': btcTrendContext,
          'quant_candidates': candidates,
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
            final candidateMatch = candidates.firstWhere(
              (c) => c['symbol'] == sym,
              orElse: () => <String, dynamic>{},
            );
            if (candidateMatch.isEmpty) continue;

            final currPrice = (candidateMatch['currentPrice'] as num?)?.toDouble() ?? 1.0;
            final supportLvl = (candidateMatch['supportLevel'] as num?)?.toDouble() ?? currPrice * 0.92;
            final entryMin = (candidateMatch['entryZoneMin'] as num?)?.toDouble() ?? currPrice * 0.94;
            final entryMax = (candidateMatch['entryZoneMax'] as num?)?.toDouble() ?? currPrice * 1.005;
            final tp1 = (candidateMatch['targetPrice1'] as num?)?.toDouble() ?? currPrice * 1.25;
            final tp2 = (candidateMatch['targetPrice2'] as num?)?.toDouble() ?? currPrice * 1.55;
            final sl = (candidateMatch['stopLoss'] as num?)?.toDouble() ?? currPrice * 0.88;
            final rr = (candidateMatch['riskRewardRatio'] as num?)?.toDouble() ?? 3.5;
            final tp2Pct = (candidateMatch['tp2Pct'] as num?)?.toDouble() ?? (((tp2 - currPrice) / currPrice) * 100.0);

            opps.add(AiMarketOpportunity(
              symbol: sym,
              name: o['name']?.toString() ?? sym,
              sector: o['sector']?.toString() ?? 'Altcoin',
              setupType: o['setup_type']?.toString() ?? candidateMatch['setupType']?.toString() ?? 'Накопичення Smart Money',
              currentPrice: currPrice,
              supportLevel: supportLvl,
              entryZoneMin: entryMin,
              entryZoneMax: entryMax,
              targetPrice1: tp1,
              targetPrice2: tp2,
              stopLoss: sl,
              potentialPct: tp2Pct,
              riskRewardRatio: rr,
              riskLevel: o['risk_level']?.toString() ?? 'Помірний',
              confidenceScore: (o['confidence_score'] as num?)?.toInt() ?? (candidateMatch['alphaScore'] as num?)?.toInt() ?? 82,
              technicalReason: o['technical_reason']?.toString() ?? 'Підтверджений розворот від структурної підтримки.',
              smartMoneyCatalyst: o['smart_money_catalyst']?.toString() ?? 'Активне поглинання пропозиції покупцями по ринку.',
              dcaStrategy: o['dca_strategy']?.toString() ?? 'Вхід 2-3 траншами в діапазоні підтримки.',
              tpTriggerRule: o['tp_trigger_rule']?.toString() ?? candidateMatch['tpTriggerRule']?.toString() ?? '',
              slTriggerRule: o['sl_trigger_rule']?.toString() ?? candidateMatch['slTriggerRule']?.toString() ?? '',
              rsi: (candidateMatch['rsi'] as num?)?.toDouble() ?? 40.0,
              dropFromPeakPct: (candidateMatch['dropFromPeakPct'] as num?)?.toDouble() ?? 35.0,
              volume24hUsd: (candidateMatch['quoteVolume'] as num?)?.toDouble() ?? 5000000.0,
              takerBuyRatioPct: (candidateMatch['takerBuyRatioPct'] as num?)?.toDouble() ?? 52.0,
              atrPct: (candidateMatch['atrPct'] as num?)?.toDouble() ?? 4.5,
              scannedAt: DateTime.now(),
            ));
          }

          if (opps.isNotEmpty) {
            return AiMarketRadarReport(
              scannedAt: DateTime.now(),
              marketRegime: parsed['market_regime']?.toString() ?? 'ACCUMULATION',
              btcTrend: parsed['btc_trend']?.toString() ?? btcTrendContext,
              macroSummary: parsed['macro_summary']?.toString() ?? 'Відібрані активи демонструють накопичення Smart Money та високе співвідношення R:R.',
              totalCoinsScanned: totalCoinsScanned,
              opportunities: opps,
            );
          }
        }
      } catch (_) {}
    }

    // Резервний алгоритмічний звіт на базі чистої квантової математики
    return _generateFallbackRadarReport(candidates, totalCoinsScanned, btcTrendContext);
  }

  AiMarketRadarReport _generateFallbackRadarReport(
    List<Map<String, dynamic>> candidates,
    int totalCoinsScanned,
    String btcTrendContext,
  ) {
    final List<AiMarketOpportunity> opps = [];

    for (final c in candidates.take(6)) {
      final sym = c['symbol']?.toString().toUpperCase() ?? '';
      final setupType = c['setupType']?.toString() ?? 'Накопичення Smart Money';
      final price = (c['currentPrice'] as num?)?.toDouble() ?? 1.0;
      final supportLvl = (c['supportLevel'] as num?)?.toDouble() ?? price * 0.92;
      final entryMin = (c['entryZoneMin'] as num?)?.toDouble() ?? price * 0.94;
      final entryMax = (c['entryZoneMax'] as num?)?.toDouble() ?? price * 1.005;
      final tp1 = (c['targetPrice1'] as num?)?.toDouble() ?? price * 1.25;
      final tp2 = (c['targetPrice2'] as num?)?.toDouble() ?? price * 1.55;
      final sl = (c['stopLoss'] as num?)?.toDouble() ?? price * 0.88;
      final tp2Pct = (c['tp2Pct'] as num?)?.toDouble() ?? (((tp2 - price) / price) * 100.0);
      final rr = (c['riskRewardRatio'] as num?)?.toDouble() ?? 3.5;
      final rsi = (c['rsi'] as num?)?.toDouble() ?? 40.0;
      final rsiDelta = (c['rsiDelta'] as num?)?.toDouble() ?? 0.0;
      final drop = (c['dropFromPeakPct'] as num?)?.toDouble() ?? 35.0;
      final vol = (c['quoteVolume'] as num?)?.toDouble() ?? 5000000.0;
      final takerBuy = (c['takerBuyRatioPct'] as num?)?.toDouble() ?? 52.0;
      final atrPct = (c['atrPct'] as num?)?.toDouble() ?? 4.5;
      final rs7d = (c['rs7dVsBtc'] as num?)?.toDouble() ?? 0.0;
      final alphaScore = (c['alphaScore'] as num?)?.toInt() ?? 82;

      opps.add(AiMarketOpportunity(
        symbol: sym,
        name: sym,
        sector: 'Spot Alpha',
        setupType: setupType,
        currentPrice: price,
        supportLevel: supportLvl,
        entryZoneMin: entryMin,
        entryZoneMax: entryMax,
        targetPrice1: tp1,
        targetPrice2: tp2,
        stopLoss: sl,
        potentialPct: tp2Pct,
        riskRewardRatio: rr,
        riskLevel: (takerBuy >= 52.0 && rsi < 45) ? 'Низький' : 'Помірний',
        confidenceScore: alphaScore.clamp(65, 96),
        technicalReason:
            'Дисконт від 90D максимуму становить -$drop%. Денний RSI ($rsi, імпульс ${rsiDelta >= 0 ? '+' : ''}$rsiDelta) виходить із зони перепроданості з опорою на структурну підтримку (ATR волатильність $atrPct%).',
        smartMoneyCatalyst:
            'Аналіз Order Flow фіксує $takerBuy% агресивних ринкових покупок (Taker Buy Volume) при добовому обороті \$${(vol / 1000000).toStringAsFixed(1)}M. Відносна сила до BTC за 7 днів: ${rs7d >= 0 ? '+' : ''}$rs7d%.',
        dcaStrategy:
            'Каскадний набір у 3 ордери: 40% по поточній ціні, 35% лімітним ордером посередині зони входу та 25% біля рівня структурної підтримки.',
        tpTriggerRule: c['tpTriggerRule']?.toString() ?? '',
        slTriggerRule: c['slTriggerRule']?.toString() ?? '',
        rsi: rsi,
        dropFromPeakPct: drop,
        volume24hUsd: vol,
        takerBuyRatioPct: takerBuy,
        atrPct: atrPct,
        scannedAt: DateTime.now(),
      ));
    }

    return AiMarketRadarReport(
      scannedAt: DateTime.now(),
      marketRegime: 'ACCUMULATION',
      btcTrend: btcTrendContext,
      macroSummary:
          '5-факторний алгоритм проаналізував Order Flow (Taker Buy), структуру підтримки, ATR-волатильність та рівні Фібоначчі по $totalCoinsScanned спотових парах. Відібрані активи мають підтверджений викуп дна та R:R не менше 1:2.6.',
      totalCoinsScanned: totalCoinsScanned,
      opportunities: opps,
    );
  }

  static const Map<String, ({String name, String sector})> _knownTokenMeta = {
    'BTC': (name: 'Bitcoin', sector: 'Store of Value'),
    'ETH': (name: 'Ethereum', sector: 'Layer 1 / Smart Contracts'),
    'BNB': (name: 'BNB Chain', sector: 'Exchange & Layer 1'),
    'SOL': (name: 'Solana', sector: 'High-Perf Layer 1'),
    'XRP': (name: 'XRP Ledger', sector: 'Payments'),
    'ADA': (name: 'Cardano', sector: 'Layer 1'),
    'AVAX': (name: 'Avalanche', sector: 'Layer 1 / Subnets'),
    'DOT': (name: 'Polkadot', sector: 'Layer 0 / Interop'),
    'LINK': (name: 'Chainlink', sector: 'Oracle & CCIP'),
    'TON': (name: 'Toncoin', sector: 'Layer 1 / Web3'),
    'SUI': (name: 'Sui Network', sector: 'Move Layer 1'),
    'APT': (name: 'Aptos', sector: 'Move Layer 1'),
    'SEI': (name: 'Sei Network', sector: 'Parallel EVM L1'),
    'NEAR': (name: 'NEAR Protocol', sector: 'AI & Sharded L1'),
    'ICP': (name: 'Internet Computer', sector: 'Decentralized Cloud'),
    'INJ': (name: 'Injective', sector: 'DeFi Layer 1'),
    'TIA': (name: 'Celestia', sector: 'Modular DA'),
    'ATOM': (name: 'Cosmos Hub', sector: 'Interchain L0'),
    'FTM': (name: 'Fantom / Sonic', sector: 'Layer 1'),
    'S': (name: 'Sonic', sector: 'High-Speed L1'),
    'ALGO': (name: 'Algorand', sector: 'Layer 1'),
    'HBAR': (name: 'Hedera', sector: 'Enterprise DLT'),
    'EGLD': (name: 'MultiversX', sector: 'Layer 1'),
    'VET': (name: 'VeChain', sector: 'Supply Chain L1'),
    'ARB': (name: 'Arbitrum', sector: 'Ethereum Layer 2'),
    'OP': (name: 'Optimism', sector: 'Ethereum Layer 2'),
    'POL': (name: 'Polygon', sector: 'Layer 2 / ZK'),
    'MATIC': (name: 'Polygon', sector: 'Layer 2 / ZK'),
    'STRK': (name: 'Starknet', sector: 'ZK-Rollup L2'),
    'ZK': (name: 'ZKsync', sector: 'ZK-Rollup L2'),
    'IMX': (name: 'Immutable', sector: 'Gaming Layer 2'),
    'STX': (name: 'Stacks', sector: 'Bitcoin Layer 2'),
    'MNT': (name: 'Mantle', sector: 'Modular Layer 2'),
    'METIS': (name: 'Metis', sector: 'Ethereum Layer 2'),
    'UNI': (name: 'Uniswap', sector: 'DeFi DEX'),
    'AAVE': (name: 'Aave', sector: 'DeFi Lending'),
    'MKR': (name: 'Maker / Sky', sector: 'DeFi & Stablecoin'),
    'LDO': (name: 'Lido DAO', sector: 'Liquid Staking'),
    'PENDLE': (name: 'Pendle', sector: 'Yield DeFi'),
    'ENA': (name: 'Ethena', sector: 'Synthetic Yield'),
    'RUNE': (name: 'THORChain', sector: 'Cross-Chain DEX'),
    'JUP': (name: 'Jupiter', sector: 'Solana DEX Aggregator'),
    'RAY': (name: 'Raydium', sector: 'Solana AMM'),
    'CRV': (name: 'Curve DAO', sector: 'DeFi AMM'),
    'DYDX': (name: 'dYdX', sector: 'Perp DEX'),
    'GMX': (name: 'GMX', sector: 'Perp DEX'),
    'SNX': (name: 'Synthetix', sector: 'Derivatives DeFi'),
    'COMP': (name: 'Compound', sector: 'DeFi Lending'),
    'CAKE': (name: 'PancakeSwap', sector: 'DEX'),
    '1INCH': (name: '1inch Network', sector: 'DEX Aggregator'),
    'EIGEN': (name: 'EigenLayer', sector: 'Restaking'),
    'ETHFI': (name: 'ether.fi', sector: 'Liquid Restaking'),
    'ONDO': (name: 'Ondo Finance', sector: 'RWA Tokenization'),
    'FET': (name: 'Artificial Superintelligence', sector: 'AI Agents'),
    'RENDER': (name: 'Render Network', sector: 'AI & GPU DePIN'),
    'RNDR': (name: 'Render Network', sector: 'AI & GPU DePIN'),
    'TAO': (name: 'Bittensor', sector: 'Decentralized AI'),
    'WLD': (name: 'Worldcoin', sector: 'AI & Identity'),
    'ARKM': (name: 'Arkham', sector: 'AI On-Chain Intel'),
    'AKT': (name: 'Akash Network', sector: 'AI Cloud DePIN'),
    'IO': (name: 'io.net', sector: 'GPU DePIN'),
    'FIL': (name: 'Filecoin', sector: 'Storage DePIN'),
    'AR': (name: 'Arweave', sector: 'Permanent Storage'),
    'GRT': (name: 'The Graph', sector: 'Web3 Indexing'),
    'PYTH': (name: 'Pyth Network', sector: 'High-Freq Oracle'),
    'API3': (name: 'API3', sector: 'Oracle'),
    'TRB': (name: 'Tellor', sector: 'Oracle'),
    'ZRO': (name: 'LayerZero', sector: 'Omnichain Interop'),
    'W': (name: 'Wormhole', sector: 'Cross-Chain Bridge'),
    'AXL': (name: 'Axelar', sector: 'Cross-Chain Interop'),
    'ENS': (name: 'Ethereum Name Service', sector: 'Web3 Identity'),
    'DOGE': (name: 'Dogecoin', sector: 'Large-Cap Meme'),
    'SHIB': (name: 'Shiba Inu', sector: 'Meme Ecosystem'),
    'PEPE': (name: 'Pepe', sector: 'High-Liq Meme'),
    'WIF': (name: 'dogwifhat', sector: 'Solana Meme'),
    'BONK': (name: 'Bonk', sector: 'Solana Meme'),
    'FLOKI': (name: 'Floki', sector: 'Meme & Utility'),
    'ORDI': (name: 'ORDI', sector: 'BRC-20 / Bitcoin'),
  };

  Future<AiMarketRadarReport> enrichRadarReport(AiMarketRadarReport report) async {
    // 1. Спочатку підставляємо відомі назви та сектори монет (навіть якщо AI офлайн)
    List<AiMarketOpportunity> enrichedOpps = report.opportunities.map((opp) {
      final meta = _knownTokenMeta[opp.symbol.toUpperCase()];
      final resolvedName = (opp.name.isEmpty || opp.name == opp.symbol)
          ? (meta?.name ?? opp.symbol)
          : opp.name;
      final resolvedSector = opp.sector.isEmpty
          ? (meta?.sector ?? 'Spot Alpha')
          : opp.sector;
      final defaultAiCommentary =
          'Квантовий профіль ${opp.symbol}: сетап «${opp.setupType}» з оцінкою ${opp.confidenceScore}/100 '
          '(RS 30D: ${opp.rsVsBtc30d >= 0 ? '+' : ''}${opp.rsVsBtc30d.toStringAsFixed(1)}% до BTC, '
          'Order Flow Δ: ${opp.takerDeltaPp >= 0 ? '+' : ''}${opp.takerDeltaPp.toStringAsFixed(1)} п.п., '
          'зважений R:R 1:${opp.blendedRR.toStringAsFixed(2)}).';
      return opp.withAi(
        name: resolvedName,
        sector: resolvedSector,
        aiCommentary: opp.aiCommentary.isNotEmpty ? opp.aiCommentary : defaultAiCommentary,
      );
    }).toList();

    final baseWithMeta = report.copyWith(opportunities: enrichedOpps);
    if (!isConfigured || enrichedOpps.isEmpty) return baseWithMeta;

    try {
      const systemPrompt = '''
Ти — Головний Квантовий Трейдер та Інституційний Портфельний Менеджер.
Тобі передано результати математичного скринінгу Binance Spot (v3 Engine: 230 закритих денних свічок, EMA50/200, крос-секційні перцентилі RS vs BTC 30D/90D, дельта Taker Buy відносно власної 60D норми, стиснення VCP, перевірка опору за Pivot Highs та бектест hit-rate TP1 за 200 днів).
Усі ціни, стопи, тейки та оцінки вже розраховані детерміновано — НЕ змінюй і НЕ вигадуй цифри.

Твоє завдання — надати лаконічний професійний синтез українською мовою у форматі JSON:
1. `macro_insight`: 2–3 речення професійного погляду на поточний режим ринку, ширину ринку та тактику розподілу капіталу.
2. `coins`: масив об'єктів для кожної монети:
   - `symbol`: символ монети (як у вхідних даних)
   - `name`: повна назва проекту (напр. "Solana", "Chainlink", "Pendle")
   - `sector`: сектор (напр. "Layer 1", "DeFi Yield", "AI & DePIN", "RWA", "Layer 2")
   - `ai_commentary`: 2–3 чіткі речення українською: чому саме ця монета виділяється серед ринку за сукупністю факторів (RS, Order Flow, структура бази/тренду) і на що звернути увагу при виконанні угоди.

Відповідь ВИКЛЮЧНО у валідному JSON:
{
  "macro_insight": "...",
  "coins": [
    {
      "symbol": "SOL",
      "name": "Solana",
      "sector": "Layer 1",
      "ai_commentary": "..."
    }
  ]
}
''';

      final userPayload = jsonEncode({
        'market_regime': report.marketRegime,
        'btc_trend': report.btcTrend,
        'breadth_pct': report.breadthPct,
        'risk_per_trade_pct': report.riskPerTradePct,
        'funnel': report.funnel,
        'picks': enrichedOpps
            .map((o) => {
                  'symbol': o.symbol,
                  'setup': o.setupType,
                  'entry_status': o.entryStatus,
                  'score': o.confidenceScore,
                  'price': o.currentPrice,
                  'trigger_price': o.triggerPrice,
                  'tp1': o.targetPrice1,
                  'tp2': o.targetPrice2,
                  'sl': o.stopLoss,
                  'blended_rr': o.blendedRR,
                  'rs_30d_vs_btc': o.rsVsBtc30d,
                  'rs_90d_vs_btc': o.rsVsBtc90d,
                  'taker_delta_pp': o.takerDeltaPp,
                  'up_down_vol': o.upDownVolumeRatio,
                  'tp1_hit_rate_pct': o.tp1HitRatePct,
                  'expectancy_pct': o.expectancyPct,
                  'warnings': o.warnings,
                })
            .toList(),
      });

      final response = await http
          .post(
            Uri.parse(_groqUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              'model': _model,
              'messages': [
                {'role': 'system', 'content': systemPrompt},
                {'role': 'user', 'content': userPayload},
              ],
              'temperature': 0.25,
              'max_tokens': 900,
              'response_format': {'type': 'json_object'},
            }),
          )
          .timeout(const Duration(seconds: 14));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final content = data['choices']?[0]?['message']?['content']?.toString().trim();
        if (content != null && content.isNotEmpty) {
          final parsed = jsonDecode(content) as Map<String, dynamic>;
          final macroInsight = parsed['macro_insight']?.toString().trim() ?? '';
          final coinsList = parsed['coins'] as List<dynamic>? ?? const [];

          final bySymbol = <String, Map<String, dynamic>>{};
          for (final item in coinsList) {
            if (item is Map<String, dynamic>) {
              final s = item['symbol']?.toString().toUpperCase() ?? '';
              if (s.isNotEmpty) bySymbol[s] = item;
            }
          }

          final updatedOpps = enrichedOpps.map((opp) {
            final aiItem = bySymbol[opp.symbol.toUpperCase()];
            if (aiItem == null) return opp;
            return opp.withAi(
              name: aiItem['name']?.toString(),
              sector: aiItem['sector']?.toString(),
              aiCommentary: aiItem['ai_commentary']?.toString(),
            );
          }).toList();

          final combinedMacro = macroInsight.isNotEmpty
              ? '${report.macroSummary}\n\n🧠 Висновки AI-Аналітика: $macroInsight'
              : report.macroSummary;

          return baseWithMeta.copyWith(
            macroSummary: combinedMacro,
            opportunities: updatedOpps,
          );
        }
      }
    } catch (_) {}
    return baseWithMeta;
  }
}

