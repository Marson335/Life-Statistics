class PortfolioOverview {
  final double totalNetWorthUsd;
  final double totalPnlUsd;
  final double totalPnlPct;
  final CashRatioInfo cashRatio;
  final int holdingsCount;
  final List<HoldingItem> holdings;

  PortfolioOverview({
    required this.totalNetWorthUsd,
    required this.totalPnlUsd,
    required this.totalPnlPct,
    required this.cashRatio,
    required this.holdingsCount,
    required this.holdings,
  });

  factory PortfolioOverview.empty() {
    return PortfolioOverview(
      totalNetWorthUsd: 0.0,
      totalPnlUsd: 0.0,
      totalPnlPct: 0.0,
      cashRatio: CashRatioInfo(
        totalUsd: 0.0,
        cashUsd: 0.0,
        cryptoUsd: 0.0,
        cashPercentage: 0.0,
        cryptoPercentage: 0.0,
        riskLabel: 'ПОРОЖНІЙ',
        aiAdvice: 'Додайте активи до гаманця для аналізу.',
      ),
      holdingsCount: 0,
      holdings: [],
    );
  }
}

class CashRatioInfo {
  final double totalUsd;
  final double cashUsd;
  final double cryptoUsd;
  final double cashPercentage;
  final double cryptoPercentage;
  final String riskLabel;
  final String aiAdvice;

  CashRatioInfo({
    required this.totalUsd,
    required this.cashUsd,
    required this.cryptoUsd,
    required this.cashPercentage,
    required this.cryptoPercentage,
    required this.riskLabel,
    required this.aiAdvice,
  });
}

class TpSlInfo {
  final double entryPrice;
  final double tp1;
  final int tp1Pct;
  final double distToTp1Pct;
  final String tp1Label;
  final double tp2;
  final int tp2Pct;
  final double distToTp2Pct;
  final String tp2Label;
  final double tp3;
  final int tp3Pct;
  final double distToTp3Pct;
  final String tp3Label;
  final double stopLoss;
  final double distToSlPct;
  final String stopReason;

  // Технічні індикатори (Смуги Боллінджера 1D та Шари підтримки/опору)
  final double bollingerUpper;
  final double bollingerMiddle;
  final double bollingerLower;
  final double swingHigh;
  final double swingLow;
  final double globalPeak100d;
  final double globalBottom100d;
  final String positionInChannel;
  final double accumulatePrice;
  final double distToAccumulatePct;

  // Професійні індикатори (RSI 14, ATR волатильність, Об'єм, R:R та BTC Regime)
  final double rsi;
  final String rsiStatus;
  final String rsiDivergence;
  final double atr;
  final double atrPct;
  final double volumeRatio;
  final String volumeStatus;
  final double riskRewardRatio;
  final String riskRewardGrade; // GOOD, ACCEPTABLE, POOR
  final String riskRewardLabel;
  final String btcMarketRegime;
  final List<DcaOrderLevel> dcaLadder;

  TpSlInfo({
    required this.entryPrice,
    required this.tp1,
    required this.tp1Pct,
    required this.distToTp1Pct,
    this.tp1Label = 'Шар 1 (Верхній Боллінджер)',
    required this.tp2,
    required this.tp2Pct,
    this.distToTp2Pct = 0.0,
    this.tp2Label = 'Шар 2 (Опір структури / Swing High)',
    required this.tp3,
    required this.tp3Pct,
    this.distToTp3Pct = 0.0,
    this.tp3Label = 'Шар 3 (Глобальна вершина / Цикл)',
    required this.stopLoss,
    required this.distToSlPct,
    required this.stopReason,
    this.bollingerUpper = 0.0,
    this.bollingerMiddle = 0.0,
    this.bollingerLower = 0.0,
    this.swingHigh = 0.0,
    this.swingLow = 0.0,
    this.globalPeak100d = 0.0,
    this.globalBottom100d = 0.0,
    this.positionInChannel = 'У межах каналу',
    this.accumulatePrice = 0.0,
    this.distToAccumulatePct = 0.0,
    this.rsi = 50.0,
    this.rsiStatus = 'Нейтральний (RSI 50.0)',
    this.rsiDivergence = 'Відсутня',
    this.atr = 0.0,
    this.atrPct = 0.0,
    this.volumeRatio = 1.0,
    this.volumeStatus = 'Нормальний об\'єм',
    this.riskRewardRatio = 2.0,
    this.riskRewardGrade = 'ACCEPTABLE',
    this.riskRewardLabel = '🟡 Помірний R:R (2.0 : 1)',
    this.btcMarketRegime = '⚪ Нейтральний ринок BTC',
    this.dcaLadder = const [],
  });
}

class DcaOrderLevel {
  final int orderNumber;
  final int sharePct;
  final double targetPrice;
  final double distFromCurrentPct;
  final String rationale;

  const DcaOrderLevel({
    required this.orderNumber,
    required this.sharePct,
    required this.targetPrice,
    required this.distFromCurrentPct,
    required this.rationale,
  });
}

class HoldingItem {
  final String symbol;
  final double amount;
  final double currentPrice;
  final double totalUsd;
  final double avgEntryPrice;
  final double pnlUsd;
  final double pnlPct;
  final double chg24h;
  final double chg7d;
  final double chg30d;
  final double chg1y;
  final double sharePct;
  final List<String> sources;
  final TpSlInfo tpSl;

  HoldingItem({
    required this.symbol,
    required this.amount,
    required this.currentPrice,
    required this.totalUsd,
    required this.avgEntryPrice,
    required this.pnlUsd,
    required this.pnlPct,
    required this.chg24h,
    required this.chg7d,
    required this.chg30d,
    required this.chg1y,
    required this.sharePct,
    required this.sources,
    required this.tpSl,
  });
}

class DcaTransaction {
  final String id;
  final String symbol;
  final String walletType;
  final double amount;
  final double buyPrice;
  final double fee;
  final DateTime txDate;
  final String notes;

  DcaTransaction({
    required this.id,
    required this.symbol,
    required this.walletType,
    required this.amount,
    required this.buyPrice,
    required this.fee,
    required this.txDate,
    required this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'symbol': symbol,
      'walletType': walletType,
      'amount': amount,
      'buyPrice': buyPrice,
      'fee': fee,
      'txDate': txDate.millisecondsSinceEpoch,
      'notes': notes,
    };
  }

  factory DcaTransaction.fromMap(String id, Map<String, dynamic> map) {
    return DcaTransaction(
      id: id,
      symbol: map['symbol'] ?? '',
      walletType: map['walletType'] ?? 'MANUAL',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      buyPrice: (map['buyPrice'] as num?)?.toDouble() ?? 0.0,
      fee: (map['fee'] as num?)?.toDouble() ?? 0.0,
      txDate: DateTime.fromMillisecondsSinceEpoch(map['txDate'] ?? DateTime.now().millisecondsSinceEpoch),
      notes: map['notes'] ?? '',
    );
  }
}

class DcaTrancheItem {
  final String id;
  final String symbol;
  final double amount;
  final double buyPrice;
  final double fee;
  final DateTime date;
  final String walletType;
  final String notes;
  final double currentPrice;
  final double pnlPct;
  final double pnlUsd;

  const DcaTrancheItem({
    required this.id,
    required this.symbol,
    required this.amount,
    required this.buyPrice,
    required this.fee,
    required this.date,
    required this.walletType,
    required this.notes,
    required this.currentPrice,
    required this.pnlPct,
    required this.pnlUsd,
  });
}

class DcaGroupedCoin {
  final String symbol;
  final double totalAmount;
  final double avgEntryPrice;
  final double totalCost;
  final double currentPrice;
  final double totalValueUsd;
  final double pnlUsd;
  final double pnlPct;
  final List<DcaTrancheItem> tranches;

  const DcaGroupedCoin({
    required this.symbol,
    required this.totalAmount,
    required this.avgEntryPrice,
    required this.totalCost,
    required this.currentPrice,
    required this.totalValueUsd,
    required this.pnlUsd,
    required this.pnlPct,
    required this.tranches,
  });
}


class GroqAuditItem {
  final String symbol;
  final String action; // HOLD, ACCUMULATE, TAKE_PROFIT, REDUCE, STOP_WATCH
  final String actionLabelUk;
  final String riskLevel; // LOW, MEDIUM, HIGH
  final String reason;
  final String executionPlan;

  // Кількісні показники позиції та індикатори
  final double amount;
  final double currentPrice;
  final double avgEntryPrice;
  final double totalUsd;
  final double sharePct;
  final double pnlUsd;
  final double pnlPct;
  final double rsi;
  final String rsiDivergence;
  final String channelPosition;
  final double atrPct;
  final String volumeStatus;
  final double riskRewardRatio;
  final double tp1Price;
  final double tp2Price;
  final double tp3Price;
  final double dcaBuyPrice;
  final double stopLossPrice;

  GroqAuditItem({
    required this.symbol,
    required this.action,
    this.actionLabelUk = '',
    required this.riskLevel,
    required this.reason,
    this.executionPlan = '',
    this.amount = 0.0,
    this.currentPrice = 0.0,
    this.avgEntryPrice = 0.0,
    this.totalUsd = 0.0,
    this.sharePct = 0.0,
    this.pnlUsd = 0.0,
    this.pnlPct = 0.0,
    this.rsi = 50.0,
    this.rsiDivergence = 'Відсутня',
    this.channelPosition = 'У межах каналу',
    this.atrPct = 4.0,
    this.volumeStatus = 'Нормальний об\'єм',
    this.riskRewardRatio = 2.0,
    this.tp1Price = 0.0,
    this.tp2Price = 0.0,
    this.tp3Price = 0.0,
    this.dcaBuyPrice = 0.0,
    this.stopLossPrice = 0.0,
  });

  factory GroqAuditItem.fromJson(Map<String, dynamic> json) {
    return GroqAuditItem(
      symbol: json['symbol']?.toString().toUpperCase() ?? '',
      action: json['action']?.toString().toUpperCase() ?? 'HOLD',
      actionLabelUk: json['action_label_uk']?.toString() ?? '',
      riskLevel: json['risk_level']?.toString().toUpperCase() ?? 'MEDIUM',
      reason: json['reason']?.toString() ?? '',
      executionPlan: json['execution_plan']?.toString() ?? '',
    );
  }
}

class GroqAuditReport {
  final int overallHealthScore;
  final String diversificationStatus;
  final String marketRegime;
  final double totalValueUsd;
  final double totalInvestedUsd;
  final double totalPnlUsd;
  final double totalPnlPct;
  final double cashPct;
  final double cashUsd;
  final double corePct;
  final double coreUsd;
  final double altPct;
  final double altUsd;
  final double futuresMarginUsd;
  final double futuresPnlUsd;
  final String topAssetSymbol;
  final double topAssetSharePct;
  final String cashReserveComment;
  final String riskSummary;
  final String strategicSummary;
  final List<String> priorityActions;
  final List<GroqAuditItem> assetRecommendations;
  final DateTime auditedAt;

  GroqAuditReport({
    required this.overallHealthScore,
    required this.diversificationStatus,
    this.marketRegime = '⚪ Нейтральний ринок BTC',
    this.totalValueUsd = 0.0,
    this.totalInvestedUsd = 0.0,
    this.totalPnlUsd = 0.0,
    this.totalPnlPct = 0.0,
    this.cashPct = 0.0,
    this.cashUsd = 0.0,
    this.corePct = 0.0,
    this.coreUsd = 0.0,
    this.altPct = 0.0,
    this.altUsd = 0.0,
    this.futuresMarginUsd = 0.0,
    this.futuresPnlUsd = 0.0,
    this.topAssetSymbol = '—',
    this.topAssetSharePct = 0.0,
    required this.cashReserveComment,
    this.riskSummary = '',
    required this.strategicSummary,
    this.priorityActions = const [],
    required this.assetRecommendations,
    DateTime? auditedAt,
  }) : auditedAt = auditedAt ?? DateTime.now();

  factory GroqAuditReport.fromJson(Map<String, dynamic> json) {
    return GroqAuditReport(
      overallHealthScore: (json['overall_health_score'] as num?)?.toInt() ?? 70,
      diversificationStatus: json['diversification_status']?.toString() ?? 'ПОМІРНА',
      cashReserveComment: json['cash_reserve_comment']?.toString() ?? '',
      riskSummary: json['risk_summary']?.toString() ?? '',
      strategicSummary: json['strategic_summary']?.toString() ?? '',
      priorityActions: (json['priority_actions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      assetRecommendations: (json['asset_recommendations'] as List<dynamic>?)
              ?.map((e) => GroqAuditItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class BinancePositionItem {
  final String symbol;
  final String direction;
  final double amount;
  final double entryPrice;
  final double markPrice;
  final double liquidationPrice;
  final double unrealizedPnl;
  final int leverage;

  BinancePositionItem({
    required this.symbol,
    required this.direction,
    required this.amount,
    required this.entryPrice,
    required this.markPrice,
    required this.liquidationPrice,
    required this.unrealizedPnl,
    required this.leverage,
  });
}

class BinanceEarnItem {
  final String symbol;
  final String productName;
  final String type;
  final double amount;
  final double apr;

  BinanceEarnItem({
    required this.symbol,
    required this.productName,
    required this.type,
    required this.amount,
    required this.apr,
  });
}

class ChartPoint {
  final DateTime timestamp;
  final double balance;
  final double pnl;
  final double pnlPct;

  const ChartPoint({
    required this.timestamp,
    required this.balance,
    required this.pnl,
    required this.pnlPct,
  });
}

class PortfolioHistoricalDataset {
  final List<ChartPoint> spotPoints;
  final List<ChartPoint> futuresPoints;
  final List<ChartPoint> totalPoints;

  final double spotBalance;
  final double spotPnlUsd;
  final double spotPnlPct;

  final double futuresMargin;
  final double futuresPnlUsd;
  final double futuresPnlPct;

  final double totalBalance;
  final double totalPnlUsd;
  final double totalPnlPct;

  const PortfolioHistoricalDataset({
    required this.spotPoints,
    required this.futuresPoints,
    required this.totalPoints,
    required this.spotBalance,
    required this.spotPnlUsd,
    required this.spotPnlPct,
    required this.futuresMargin,
    required this.futuresPnlUsd,
    required this.futuresPnlPct,
    required this.totalBalance,
    required this.totalPnlUsd,
    required this.totalPnlPct,
  });

  factory PortfolioHistoricalDataset.empty() {
    return const PortfolioHistoricalDataset(
      spotPoints: [],
      futuresPoints: [],
      totalPoints: [],
      spotBalance: 0.0,
      spotPnlUsd: 0.0,
      spotPnlPct: 0.0,
      futuresMargin: 0.0,
      futuresPnlUsd: 0.0,
      futuresPnlPct: 0.0,
      totalBalance: 0.0,
      totalPnlUsd: 0.0,
      totalPnlPct: 0.0,
    );
  }
}

// ==========================================
// AI-РАДАР МОНЕТ (MARKET SCANNER & ALPHA FINDER) — v3
// ==========================================

/// Статус точки входу для сигналу радара.
/// BUY_NOW — ціна вже в зоні входу; WAIT_PULLBACK — ціна вище зони (лімітка нижче);
/// WAIT_BREAKOUT — сетап пробою, купівля лише після пробою [triggerPrice].
class RadarEntryStatus {
  static const String buyNow = 'BUY_NOW';
  static const String waitPullback = 'WAIT_PULLBACK';
  static const String waitBreakout = 'WAIT_BREAKOUT';
}

class AiMarketOpportunity {
  final String symbol;
  final String name;
  final String sector;
  final String setupType;
  final double currentPrice;
  final double supportLevel;
  final double entryZoneMin;
  final double entryZoneMax;
  final double targetPrice1;
  final double targetPrice2;
  final double stopLoss;
  final double potentialPct;
  final double riskRewardRatio;
  final String riskLevel; // 'Низький', 'Помірний', 'Високий'
  final int confidenceScore; // 1-100 (детермінований квант-скор, AI його не змінює)
  final String technicalReason;
  final String smartMoneyCatalyst;
  final String dcaStrategy;
  final String tpTriggerRule;
  final String slTriggerRule;
  final double rsi;
  final double dropFromPeakPct;
  final double volume24hUsd;
  final double takerBuyRatioPct;
  final double atrPct;
  final DateTime scannedAt;

  // --- v3: точка входу ---
  final String entryStatus;
  final double triggerPrice;
  final double hardStopPrice;
  final int timeStopDays;
  final String tp1Source;
  final String tp2Source;

  // --- v3: квант-метрики ---
  final double rsVsBtc30d;
  final double rsVsBtc90d;
  final double takerDeltaPp;
  final double upDownVolumeRatio;
  final double betaToBtc;
  final double blendedRR;

  // --- v3: історична перевірка рівнів ---
  final double tp1HitRatePct; // -1 = недостатньо історії
  final double expectancyPct;
  final int historicalSamples;

  // --- v3: ризик-менеджмент ---
  final double positionSizePct;
  final double positionSizeUsd;
  final double riskPerTradePct;

  // --- v3: розкладка оцінки по факторах (0-100) ---
  final double scoreMomentum;
  final double scoreTrend;
  final double scoreFlow;
  final double scoreContraction;
  final double scoreEntry;
  final double scoreRiskReward;

  final List<String> warnings;
  final String aiCommentary;

  const AiMarketOpportunity({
    required this.symbol,
    required this.name,
    required this.sector,
    this.setupType = 'Накопичення Smart Money',
    required this.currentPrice,
    this.supportLevel = 0.0,
    required this.entryZoneMin,
    required this.entryZoneMax,
    required this.targetPrice1,
    required this.targetPrice2,
    required this.stopLoss,
    required this.potentialPct,
    required this.riskRewardRatio,
    required this.riskLevel,
    required this.confidenceScore,
    required this.technicalReason,
    required this.smartMoneyCatalyst,
    required this.dcaStrategy,
    this.tpTriggerRule = '',
    this.slTriggerRule = '',
    required this.rsi,
    required this.dropFromPeakPct,
    required this.volume24hUsd,
    this.takerBuyRatioPct = 50.0,
    this.atrPct = 4.5,
    required this.scannedAt,
    this.entryStatus = RadarEntryStatus.buyNow,
    this.triggerPrice = 0.0,
    this.hardStopPrice = 0.0,
    this.timeStopDays = 21,
    this.tp1Source = '',
    this.tp2Source = '',
    this.rsVsBtc30d = 0.0,
    this.rsVsBtc90d = 0.0,
    this.takerDeltaPp = 0.0,
    this.upDownVolumeRatio = 1.0,
    this.betaToBtc = 1.0,
    this.blendedRR = 0.0,
    this.tp1HitRatePct = -1.0,
    this.expectancyPct = 0.0,
    this.historicalSamples = 0,
    this.positionSizePct = 0.0,
    this.positionSizeUsd = 0.0,
    this.riskPerTradePct = 1.0,
    this.scoreMomentum = 0.0,
    this.scoreTrend = 0.0,
    this.scoreFlow = 0.0,
    this.scoreContraction = 0.0,
    this.scoreEntry = 0.0,
    this.scoreRiskReward = 0.0,
    this.warnings = const [],
    this.aiCommentary = '',
  });

  double get tp1Pct => currentPrice > 0 ? ((targetPrice1 - entryReference) / entryReference) * 100.0 : 0.0;
  double get tp2Pct => currentPrice > 0 ? ((targetPrice2 - entryReference) / entryReference) * 100.0 : 0.0;
  double get slPct => currentPrice > 0 ? ((entryReference - stopLoss) / entryReference) * 100.0 : 0.0;

  /// Ціна, від якої рахуються TP/SL: поточна (BUY_NOW) або ціна лімітки / пробою.
  double get entryReference =>
      entryStatus == RadarEntryStatus.buyNow || triggerPrice <= 0 ? currentPrice : triggerPrice;

  /// Копія з AI-описом (числа та рівні AI змінити не може).
  AiMarketOpportunity withAi({String? name, String? sector, String? aiCommentary}) => AiMarketOpportunity(
        symbol: symbol,
        name: (name != null && name.trim().isNotEmpty) ? name.trim() : this.name,
        sector: (sector != null && sector.trim().isNotEmpty) ? sector.trim() : this.sector,
        setupType: setupType,
        currentPrice: currentPrice,
        supportLevel: supportLevel,
        entryZoneMin: entryZoneMin,
        entryZoneMax: entryZoneMax,
        targetPrice1: targetPrice1,
        targetPrice2: targetPrice2,
        stopLoss: stopLoss,
        potentialPct: potentialPct,
        riskRewardRatio: riskRewardRatio,
        riskLevel: riskLevel,
        confidenceScore: confidenceScore,
        technicalReason: technicalReason,
        smartMoneyCatalyst: smartMoneyCatalyst,
        dcaStrategy: dcaStrategy,
        tpTriggerRule: tpTriggerRule,
        slTriggerRule: slTriggerRule,
        rsi: rsi,
        dropFromPeakPct: dropFromPeakPct,
        volume24hUsd: volume24hUsd,
        takerBuyRatioPct: takerBuyRatioPct,
        atrPct: atrPct,
        scannedAt: scannedAt,
        entryStatus: entryStatus,
        triggerPrice: triggerPrice,
        hardStopPrice: hardStopPrice,
        timeStopDays: timeStopDays,
        tp1Source: tp1Source,
        tp2Source: tp2Source,
        rsVsBtc30d: rsVsBtc30d,
        rsVsBtc90d: rsVsBtc90d,
        takerDeltaPp: takerDeltaPp,
        upDownVolumeRatio: upDownVolumeRatio,
        betaToBtc: betaToBtc,
        blendedRR: blendedRR,
        tp1HitRatePct: tp1HitRatePct,
        expectancyPct: expectancyPct,
        historicalSamples: historicalSamples,
        positionSizePct: positionSizePct,
        positionSizeUsd: positionSizeUsd,
        riskPerTradePct: riskPerTradePct,
        scoreMomentum: scoreMomentum,
        scoreTrend: scoreTrend,
        scoreFlow: scoreFlow,
        scoreContraction: scoreContraction,
        scoreEntry: scoreEntry,
        scoreRiskReward: scoreRiskReward,
        warnings: warnings,
        aiCommentary: (aiCommentary != null && aiCommentary.trim().isNotEmpty)
            ? aiCommentary.trim()
            : this.aiCommentary,
      );

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'name': name,
        'sector': sector,
        'setupType': setupType,
        'currentPrice': currentPrice,
        'supportLevel': supportLevel,
        'entryZoneMin': entryZoneMin,
        'entryZoneMax': entryZoneMax,
        'targetPrice1': targetPrice1,
        'targetPrice2': targetPrice2,
        'stopLoss': stopLoss,
        'potentialPct': potentialPct,
        'riskRewardRatio': riskRewardRatio,
        'riskLevel': riskLevel,
        'confidenceScore': confidenceScore,
        'technicalReason': technicalReason,
        'smartMoneyCatalyst': smartMoneyCatalyst,
        'dcaStrategy': dcaStrategy,
        'tpTriggerRule': tpTriggerRule,
        'slTriggerRule': slTriggerRule,
        'rsi': rsi,
        'dropFromPeakPct': dropFromPeakPct,
        'volume24hUsd': volume24hUsd,
        'takerBuyRatioPct': takerBuyRatioPct,
        'atrPct': atrPct,
        'scannedAt': scannedAt.toIso8601String(),
        'entryStatus': entryStatus,
        'triggerPrice': triggerPrice,
        'hardStopPrice': hardStopPrice,
        'timeStopDays': timeStopDays,
        'tp1Source': tp1Source,
        'tp2Source': tp2Source,
        'rsVsBtc30d': rsVsBtc30d,
        'rsVsBtc90d': rsVsBtc90d,
        'takerDeltaPp': takerDeltaPp,
        'upDownVolumeRatio': upDownVolumeRatio,
        'betaToBtc': betaToBtc,
        'blendedRR': blendedRR,
        'tp1HitRatePct': tp1HitRatePct,
        'expectancyPct': expectancyPct,
        'historicalSamples': historicalSamples,
        'positionSizePct': positionSizePct,
        'positionSizeUsd': positionSizeUsd,
        'riskPerTradePct': riskPerTradePct,
        'scoreMomentum': scoreMomentum,
        'scoreTrend': scoreTrend,
        'scoreFlow': scoreFlow,
        'scoreContraction': scoreContraction,
        'scoreEntry': scoreEntry,
        'scoreRiskReward': scoreRiskReward,
        'warnings': warnings,
        'aiCommentary': aiCommentary,
      };

  factory AiMarketOpportunity.fromJson(Map<String, dynamic> json) {
    double d(String k, [double def = 0.0]) => (json[k] as num?)?.toDouble() ?? def;
    return AiMarketOpportunity(
      symbol: json['symbol']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      sector: json['sector']?.toString() ?? '',
      setupType: json['setupType']?.toString() ?? 'Накопичення Smart Money',
      currentPrice: d('currentPrice'),
      supportLevel: d('supportLevel'),
      entryZoneMin: d('entryZoneMin'),
      entryZoneMax: d('entryZoneMax'),
      targetPrice1: d('targetPrice1'),
      targetPrice2: d('targetPrice2'),
      stopLoss: d('stopLoss'),
      potentialPct: d('potentialPct'),
      riskRewardRatio: d('riskRewardRatio'),
      riskLevel: json['riskLevel']?.toString() ?? 'Помірний',
      confidenceScore: (json['confidenceScore'] as num?)?.toInt() ?? 50,
      technicalReason: json['technicalReason']?.toString() ?? '',
      smartMoneyCatalyst: json['smartMoneyCatalyst']?.toString() ?? '',
      dcaStrategy: json['dcaStrategy']?.toString() ?? '',
      tpTriggerRule: json['tpTriggerRule']?.toString() ?? '',
      slTriggerRule: json['slTriggerRule']?.toString() ?? '',
      rsi: d('rsi'),
      dropFromPeakPct: d('dropFromPeakPct'),
      volume24hUsd: d('volume24hUsd'),
      takerBuyRatioPct: d('takerBuyRatioPct', 50.0),
      atrPct: d('atrPct', 4.5),
      scannedAt: json['scannedAt'] != null
          ? DateTime.tryParse(json['scannedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      entryStatus: json['entryStatus']?.toString() ?? RadarEntryStatus.buyNow,
      triggerPrice: d('triggerPrice'),
      hardStopPrice: d('hardStopPrice'),
      timeStopDays: (json['timeStopDays'] as num?)?.toInt() ?? 21,
      tp1Source: json['tp1Source']?.toString() ?? '',
      tp2Source: json['tp2Source']?.toString() ?? '',
      rsVsBtc30d: d('rsVsBtc30d'),
      rsVsBtc90d: d('rsVsBtc90d'),
      takerDeltaPp: d('takerDeltaPp'),
      upDownVolumeRatio: d('upDownVolumeRatio', 1.0),
      betaToBtc: d('betaToBtc', 1.0),
      blendedRR: d('blendedRR'),
      tp1HitRatePct: d('tp1HitRatePct', -1.0),
      expectancyPct: d('expectancyPct'),
      historicalSamples: (json['historicalSamples'] as num?)?.toInt() ?? 0,
      positionSizePct: d('positionSizePct'),
      positionSizeUsd: d('positionSizeUsd'),
      riskPerTradePct: d('riskPerTradePct', 1.0),
      scoreMomentum: d('scoreMomentum'),
      scoreTrend: d('scoreTrend'),
      scoreFlow: d('scoreFlow'),
      scoreContraction: d('scoreContraction'),
      scoreEntry: d('scoreEntry'),
      scoreRiskReward: d('scoreRiskReward'),
      warnings: (json['warnings'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      aiCommentary: json['aiCommentary']?.toString() ?? '',
    );
  }
}

class AiMarketRadarReport {
  final DateTime scannedAt;
  final String marketRegime; // RISK_ON / NEUTRAL / RISK_OFF (або legacy-коди)
  final String btcTrend;
  final String macroSummary;
  final int totalCoinsScanned;
  final List<AiMarketOpportunity> opportunities;

  // --- v3: прозорість відбору ---
  final double breadthPct; // % ліквідних монет вище EMA50
  final double riskPerTradePct;
  final int coinsDeepAnalyzed;
  final int setupsFound;
  final Map<String, int> funnel;

  const AiMarketRadarReport({
    required this.scannedAt,
    required this.marketRegime,
    required this.btcTrend,
    required this.macroSummary,
    required this.totalCoinsScanned,
    required this.opportunities,
    this.breadthPct = -1.0,
    this.riskPerTradePct = 1.0,
    this.coinsDeepAnalyzed = 0,
    this.setupsFound = 0,
    this.funnel = const {},
  });

  AiMarketRadarReport copyWith({
    String? macroSummary,
    List<AiMarketOpportunity>? opportunities,
  }) =>
      AiMarketRadarReport(
        scannedAt: scannedAt,
        marketRegime: marketRegime,
        btcTrend: btcTrend,
        macroSummary: macroSummary ?? this.macroSummary,
        totalCoinsScanned: totalCoinsScanned,
        opportunities: opportunities ?? this.opportunities,
        breadthPct: breadthPct,
        riskPerTradePct: riskPerTradePct,
        coinsDeepAnalyzed: coinsDeepAnalyzed,
        setupsFound: setupsFound,
        funnel: funnel,
      );

  Map<String, dynamic> toJson() => {
        'scannedAt': scannedAt.toIso8601String(),
        'marketRegime': marketRegime,
        'btcTrend': btcTrend,
        'macroSummary': macroSummary,
        'totalCoinsScanned': totalCoinsScanned,
        'opportunities': opportunities.map((o) => o.toJson()).toList(),
        'breadthPct': breadthPct,
        'riskPerTradePct': riskPerTradePct,
        'coinsDeepAnalyzed': coinsDeepAnalyzed,
        'setupsFound': setupsFound,
        'funnel': funnel,
      };

  factory AiMarketRadarReport.fromJson(Map<String, dynamic> json) => AiMarketRadarReport(
        scannedAt: json['scannedAt'] != null
            ? DateTime.tryParse(json['scannedAt'].toString()) ?? DateTime.now()
            : DateTime.now(),
        marketRegime: json['marketRegime']?.toString() ?? 'NEUTRAL',
        btcTrend: json['btcTrend']?.toString() ?? '—',
        macroSummary: json['macroSummary']?.toString() ?? '',
        totalCoinsScanned: (json['totalCoinsScanned'] as num?)?.toInt() ?? 0,
        opportunities: (json['opportunities'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(AiMarketOpportunity.fromJson)
            .toList(),
        breadthPct: (json['breadthPct'] as num?)?.toDouble() ?? -1.0,
        riskPerTradePct: (json['riskPerTradePct'] as num?)?.toDouble() ?? 1.0,
        coinsDeepAnalyzed: (json['coinsDeepAnalyzed'] as num?)?.toInt() ?? 0,
        setupsFound: (json['setupsFound'] as num?)?.toInt() ?? 0,
        funnel: (json['funnel'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, (v as num?)?.toInt() ?? 0)),
      );

  factory AiMarketRadarReport.empty() => AiMarketRadarReport(
        scannedAt: DateTime.now(),
        marketRegime: 'Сканер очікує запуску',
        btcTrend: '—',
        macroSummary:
            'Натисніть "Сканувати ринок", щоб алгоритм проаналізував 350+ монет та підібрав найкращі точки входу.',
        totalCoinsScanned: 0,
        opportunities: const [],
      );
}
