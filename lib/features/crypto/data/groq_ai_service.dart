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
        }).toList();

        const systemPrompt = '''
Ти — Професійний Спотовий Трейдер та Квант-Аналітик.
Твоє завдання — провести технічний та портфельний аудит відкритого криптопортфелю клієнта на основі денних свічок (1D).
Для кожного активу тобі надані реальні індикатори:
- Смуги Боллінджера (SMA 20, 2 StdDev): bollinger_upper_1d, bollinger_lower_1d, bollinger_middle_sma20.
- Локальні вершини (Swing High) та дно (Swing Low / Support).
- Сітка 3-х шарів фіксації прибутку: Шар 1 (Верхній Боллінджер), Шар 2 (Опір структури), Шар 3 (Глобальна вершина / ATH).
- Зона накопичення на дні (accumulate_dip_price) та структурний стоп-лос (structural_stop_loss).

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
      "reason": "Чітке обґрунтування з посиланням на Смуги Боллінджера, цілі TP1/TP2 чи рівні закупки на дні українською мовою"
    }
  ],
  "strategic_summary": "Стратегічний підсумок: кого фіксувати по шарах на вершинах, кого добирати на дні, і стан кеш-подушки"
}

Допустимі значення action: HOLD, ACCUMULATE, TAKE_PROFIT, REDUCE
Допустимі значення risk_level: LOW, MEDIUM, HIGH
Правила:
1. Якщо ціна біля або вище bollinger_upper_1d або тестує swing_high:
   - action: TAKE_PROFIT. Вкажи рекомендований шар фіксації (Шар 1 або Шар 2) та ціну.
2. Якщо ціна біля або нижче bollinger_lower_1d чи біля swing_low:
   - action: ACCUMULATE. Поясни, що актив на дні каналу і вкажи ціну підбору (accumulate_dip_price).
3. Якщо частка монети > 35% (крім BTC/ETH) — вкажи action: REDUCE через ризик надмірної концентрації.
4. Якщо частка стейблкоїнів < 15% — попередь, що бракує кешу для викупу дна.
5. Усі тексти мають бути грамотною, професійною УКРАЇНСЬКОЮ МОВОЮ трейдера.
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

      final isNearUpper = h.tpSl.bollingerUpper > 0 && h.currentPrice >= (h.tpSl.bollingerUpper * 0.97);
      final isNearLower = h.tpSl.bollingerLower > 0 && h.currentPrice <= (h.tpSl.bollingerLower * 1.03);

      if (h.sharePct > 40 && h.symbol != 'BTC' && h.symbol != 'ETH') {
        action = 'REDUCE';
        risk = 'HIGH';
        reason = 'Частка ${h.sharePct.toStringAsFixed(1)}% перевищує допустимий ліміт концентрації. Варто частково вийти в кеш.';
      } else if (isNearUpper || h.pnlPct >= 50) {
        action = 'TAKE_PROFIT';
        risk = 'MEDIUM';
        reason = 'Ціна \$${h.currentPrice.toStringAsFixed(2)} у верхній зоні Боллінджера. Рекомендовано зафіксувати 30% на Шар 1 (\$${h.tpSl.tp1.toStringAsFixed(2)}).';
      } else if (isNearLower || h.pnlPct <= -20) {
        action = 'ACCUMULATE';
        risk = 'HIGH';
        reason = 'Монета на дні каналу (зона перепроданості). Оптимальний рівень добору/DCA: \$${h.tpSl.accumulatePrice.toStringAsFixed(2)}. Стоп: \$${h.tpSl.stopLoss.toStringAsFixed(2)}.';
      } else {
        action = 'HOLD';
        risk = 'LOW';
        reason = '${h.tpSl.positionInChannel}. Ціль фіксації Шар 1: \$${h.tpSl.tp1.toStringAsFixed(2)} (+${h.tpSl.distToTp1Pct}%). Стоп: \$${h.tpSl.stopLoss.toStringAsFixed(2)}.';
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
}
