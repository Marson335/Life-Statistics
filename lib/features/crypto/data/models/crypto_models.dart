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
  final String action; // HOLD, ACCUMULATE, TAKE_PROFIT, REDUCE
  final String riskLevel; // LOW, MEDIUM, HIGH
  final String reason;

  GroqAuditItem({
    required this.symbol,
    required this.action,
    required this.riskLevel,
    required this.reason,
  });

  factory GroqAuditItem.fromJson(Map<String, dynamic> json) {
    return GroqAuditItem(
      symbol: json['symbol'] ?? '',
      action: json['action'] ?? 'HOLD',
      riskLevel: json['risk_level'] ?? 'MEDIUM',
      reason: json['reason'] ?? '',
    );
  }
}

class GroqAuditReport {
  final int overallHealthScore;
  final String diversificationStatus;
  final String cashReserveComment;
  final List<GroqAuditItem> assetRecommendations;
  final String strategicSummary;

  GroqAuditReport({
    required this.overallHealthScore,
    required this.diversificationStatus,
    required this.cashReserveComment,
    required this.assetRecommendations,
    required this.strategicSummary,
  });

  factory GroqAuditReport.fromJson(Map<String, dynamic> json) {
    return GroqAuditReport(
      overallHealthScore: (json['overall_health_score'] as num?)?.toInt() ?? 70,
      diversificationStatus: json['diversification_status'] ?? 'ПОМІРНА',
      cashReserveComment: json['cash_reserve_comment'] ?? '',
      assetRecommendations: (json['asset_recommendations'] as List<dynamic>?)
              ?.map((e) => GroqAuditItem.fromJson(e))
              .toList() ??
          [],
      strategicSummary: json['strategic_summary'] ?? '',
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
// AI-РАДАР МОНЕТ (MARKET SCANNER & ALPHA FINDER)
// ==========================================

class AiMarketOpportunity {
  final String symbol;
  final String name;
  final String sector;
  final double currentPrice;
  final double entryZoneMin;
  final double entryZoneMax;
  final double targetPrice1;
  final double targetPrice2;
  final double stopLoss;
  final double potentialPct;
  final double riskRewardRatio;
  final String riskLevel; // 'Низький', 'Помірний', 'Високий'
  final int confidenceScore; // 1-100
  final String technicalReason;
  final String smartMoneyCatalyst;
  final String dcaStrategy;
  final double rsi;
  final double dropFromPeakPct;
  final double volume24hUsd;
  final DateTime scannedAt;

  const AiMarketOpportunity({
    required this.symbol,
    required this.name,
    required this.sector,
    required this.currentPrice,
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
    required this.rsi,
    required this.dropFromPeakPct,
    required this.volume24hUsd,
    required this.scannedAt,
  });

  Map<String, dynamic> toJson() => {
    'symbol': symbol,
    'name': name,
    'sector': sector,
    'currentPrice': currentPrice,
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
    'rsi': rsi,
    'dropFromPeakPct': dropFromPeakPct,
    'volume24hUsd': volume24hUsd,
    'scannedAt': scannedAt.toIso8601String(),
  };

  factory AiMarketOpportunity.fromJson(Map<String, dynamic> json) => AiMarketOpportunity(
    symbol: json['symbol']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    sector: json['sector']?.toString() ?? 'Altcoin',
    currentPrice: (json['currentPrice'] as num?)?.toDouble() ?? 0.0,
    entryZoneMin: (json['entryZoneMin'] as num?)?.toDouble() ?? 0.0,
    entryZoneMax: (json['entryZoneMax'] as num?)?.toDouble() ?? 0.0,
    targetPrice1: (json['targetPrice1'] as num?)?.toDouble() ?? 0.0,
    targetPrice2: (json['targetPrice2'] as num?)?.toDouble() ?? 0.0,
    stopLoss: (json['stopLoss'] as num?)?.toDouble() ?? 0.0,
    potentialPct: (json['potentialPct'] as num?)?.toDouble() ?? 0.0,
    riskRewardRatio: (json['riskRewardRatio'] as num?)?.toDouble() ?? 0.0,
    riskLevel: json['riskLevel']?.toString() ?? 'Помірний',
    confidenceScore: (json['confidenceScore'] as num?)?.toInt() ?? 75,
    technicalReason: json['technicalReason']?.toString() ?? '',
    smartMoneyCatalyst: json['smartMoneyCatalyst']?.toString() ?? '',
    dcaStrategy: json['dcaStrategy']?.toString() ?? '',
    rsi: (json['rsi'] as num?)?.toDouble() ?? 0.0,
    dropFromPeakPct: (json['dropFromPeakPct'] as num?)?.toDouble() ?? 0.0,
    volume24hUsd: (json['volume24hUsd'] as num?)?.toDouble() ?? 0.0,
    scannedAt: json['scannedAt'] != null
        ? DateTime.tryParse(json['scannedAt'].toString()) ?? DateTime.now()
        : DateTime.now(),
  );
}

class AiMarketRadarReport {
  final DateTime scannedAt;
  final String marketRegime;
  final String btcTrend;
  final String macroSummary;
  final int totalCoinsScanned;
  final List<AiMarketOpportunity> opportunities;

  const AiMarketRadarReport({
    required this.scannedAt,
    required this.marketRegime,
    required this.btcTrend,
    required this.macroSummary,
    required this.totalCoinsScanned,
    required this.opportunities,
  });

  Map<String, dynamic> toJson() => {
    'scannedAt': scannedAt.toIso8601String(),
    'marketRegime': marketRegime,
    'btcTrend': btcTrend,
    'macroSummary': macroSummary,
    'totalCoinsScanned': totalCoinsScanned,
    'opportunities': opportunities.map((o) => o.toJson()).toList(),
  };

  factory AiMarketRadarReport.fromJson(Map<String, dynamic> json) => AiMarketRadarReport(
    scannedAt: json['scannedAt'] != null
        ? DateTime.tryParse(json['scannedAt'].toString()) ?? DateTime.now()
        : DateTime.now(),
    marketRegime: json['marketRegime']?.toString() ?? 'Аналіз ринку...',
    btcTrend: json['btcTrend']?.toString() ?? 'Нейтральний',
    macroSummary: json['macroSummary']?.toString() ?? '',
    totalCoinsScanned: (json['totalCoinsScanned'] as num?)?.toInt() ?? 0,
    opportunities: (json['opportunities'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(AiMarketOpportunity.fromJson)
        .toList(),
  );

  factory AiMarketRadarReport.empty() => AiMarketRadarReport(
    scannedAt: DateTime.now(),
    marketRegime: 'Сканер очікує запуску',
    btcTrend: '—',
    macroSummary: 'Натисніть "Сканувати ринок", щоб AI-аналітики проаналізували 350+ монет та підібрали найкращі точки входу.',
    totalCoinsScanned: 0,
    opportunities: const [],
  );
}

