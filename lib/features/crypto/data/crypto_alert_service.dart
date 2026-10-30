import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/notification_service.dart';
import '../../settings/data/settings_repository.dart';
import '../../../shared/models/user_settings.dart';
import 'models/crypto_models.dart';

class CoinAlertTarget {
  final String symbol;
  final double entryPrice;
  final double tp1;
  final double tp1Pct;
  final double trailingStop;
  final double earlyExit;
  final double stopLoss;
  final double recentPeak;
  final int peakExhaustionScore;
  final int slProbabilityPct;
  final double dca1Price;
  final double rsi;
  final String exitSignalCode;
  final double lastPrice;

  const CoinAlertTarget({
    required this.symbol,
    required this.entryPrice,
    required this.tp1,
    required this.tp1Pct,
    required this.trailingStop,
    required this.earlyExit,
    required this.stopLoss,
    required this.recentPeak,
    required this.peakExhaustionScore,
    required this.slProbabilityPct,
    this.dca1Price = 0.0,
    this.rsi = 50.0,
    this.exitSignalCode = 'HOLD_WAIT_TARGETS',
    this.lastPrice = 0.0,
  });

  Map<String, dynamic> toJson() => {
        'symbol': symbol,
        'entryPrice': entryPrice,
        'tp1': tp1,
        'tp1Pct': tp1Pct,
        'trailingStop': trailingStop,
        'earlyExit': earlyExit,
        'stopLoss': stopLoss,
        'recentPeak': recentPeak,
        'peakExhaustionScore': peakExhaustionScore,
        'slProbabilityPct': slProbabilityPct,
        'dca1Price': dca1Price,
        'rsi': rsi,
        'exitSignalCode': exitSignalCode,
        'lastPrice': lastPrice,
      };

  factory CoinAlertTarget.fromJson(Map<String, dynamic> json) =>
      CoinAlertTarget(
        symbol: json['symbol'] as String,
        entryPrice: (json['entryPrice'] as num?)?.toDouble() ?? 0.0,
        tp1: (json['tp1'] as num?)?.toDouble() ?? 0.0,
        tp1Pct: (json['tp1Pct'] as num?)?.toDouble() ?? 0.0,
        trailingStop: (json['trailingStop'] as num?)?.toDouble() ?? 0.0,
        earlyExit: (json['earlyExit'] as num?)?.toDouble() ?? 0.0,
        stopLoss: (json['stopLoss'] as num?)?.toDouble() ?? 0.0,
        recentPeak: (json['recentPeak'] as num?)?.toDouble() ?? 0.0,
        peakExhaustionScore:
            (json['peakExhaustionScore'] as num?)?.toInt() ?? 0,
        slProbabilityPct: (json['slProbabilityPct'] as num?)?.toInt() ?? 0,
        dca1Price: (json['dca1Price'] as num?)?.toDouble() ?? 0.0,
        rsi: (json['rsi'] as num?)?.toDouble() ?? 50.0,
        exitSignalCode:
            json['exitSignalCode'] as String? ?? 'HOLD_WAIT_TARGETS',
        lastPrice: (json['lastPrice'] as num?)?.toDouble() ?? 0.0,
      );

  CoinAlertTarget copyWith({
    double? lastPrice,
    int? peakExhaustionScore,
    int? slProbabilityPct,
    double? dca1Price,
    double? rsi,
    String? exitSignalCode,
    double? trailingStop,
    double? recentPeak,
  }) {
    return CoinAlertTarget(
      symbol: symbol,
      entryPrice: entryPrice,
      tp1: tp1,
      tp1Pct: tp1Pct,
      trailingStop: trailingStop ?? this.trailingStop,
      earlyExit: earlyExit,
      stopLoss: stopLoss,
      recentPeak: recentPeak ?? this.recentPeak,
      peakExhaustionScore: peakExhaustionScore ?? this.peakExhaustionScore,
      slProbabilityPct: slProbabilityPct ?? this.slProbabilityPct,
      dca1Price: dca1Price ?? this.dca1Price,
      rsi: rsi ?? this.rsi,
      exitSignalCode: exitSignalCode ?? this.exitSignalCode,
      lastPrice: lastPrice ?? this.lastPrice,
    );
  }
}

class CryptoAlertService {
  static final CryptoAlertService _instance = CryptoAlertService._internal();
  factory CryptoAlertService() => _instance;
  CryptoAlertService._internal();

  static const String prefKeyEnabled = 'crypto_alerts_enabled';
  static const String prefKeyCoins = 'crypto_alert_coins_list';
  static const String prefKeyOnTp = 'crypto_alert_on_tp';
  static const String prefKeyOnTrailing = 'crypto_alert_on_trailing';
  static const String prefKeyOnPreStop = 'crypto_alert_on_pre_stop';
  static const String prefKeyOnHardStop = 'crypto_alert_on_hard_stop';
  static const String prefKeyOnPeak = 'crypto_alert_on_peak';
  static const String prefKeyOnDcaBuy = 'crypto_alert_on_dca_buy';
  static const String prefKeyTargets = 'crypto_alert_targets_v1';
  static const String prefKeyFiredEvents = 'crypto_alert_fired_events_v2';

  bool _isInitialized = false;
  bool alertsEnabled = true;
  Set<String> enabledCoins = {'BTC', 'ETH', 'SOL'};
  bool onTp = true;
  bool onTrailing = true;
  bool onPreStop = true;
  bool onHardStop = true;
  bool onPeak = true;
  bool onDcaBuy = true;

  final Map<String, CoinAlertTarget> _targets = {};
  final Set<String> _firedAlertKeys = {};
  Timer? _bgPollTimer;
  bool _isPolling = false;

  Map<String, CoinAlertTarget> get targets => Map.unmodifiable(_targets);

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      alertsEnabled = prefs.getBool(prefKeyEnabled) ?? true;
      final savedCoins = prefs.getStringList(prefKeyCoins);
      if (savedCoins != null) {
        enabledCoins = savedCoins.map((s) => s.toUpperCase()).toSet();
      }
      onTp = prefs.getBool(prefKeyOnTp) ?? true;
      onTrailing = prefs.getBool(prefKeyOnTrailing) ?? true;
      onPreStop = prefs.getBool(prefKeyOnPreStop) ?? true;
      onHardStop = prefs.getBool(prefKeyOnHardStop) ?? true;
      onPeak = prefs.getBool(prefKeyOnPeak) ?? true;
      onDcaBuy = prefs.getBool(prefKeyOnDcaBuy) ?? true;

      final targetsJson = prefs.getString(prefKeyTargets);
      if (targetsJson != null) {
        final Map<String, dynamic> raw = jsonDecode(targetsJson);
        raw.forEach((k, v) {
          _targets[k.toUpperCase()] =
              CoinAlertTarget.fromJson(v as Map<String, dynamic>);
        });
      }

      final firedList = prefs.getStringList(prefKeyFiredEvents);
      if (firedList != null) {
        _firedAlertKeys.addAll(firedList);
      }

      // Скасовуємо старі/завислі сповіщення в системній шторці при запуску
      await NotificationService().cancelAllCryptoNotifications();

      _startBackgroundPolling();
      _isInitialized = true;
      debugPrint(
          '[CryptoAlertService] Initialized with ${enabledCoins.length} coins, ${_targets.length} targets, ${_firedAlertKeys.length} fired states.');
    } catch (e) {
      debugPrint('[CryptoAlertService] Error initializing: $e');
    }
  }

  void _startBackgroundPolling() {
    _bgPollTimer?.cancel();
    // Poll every 60 seconds
    _bgPollTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      checkBackgroundPrices();
    });
  }

  void stop() {
    _bgPollTimer?.cancel();
    _bgPollTimer = null;
  }

  bool isCoinMonitored(String symbol) {
    return enabledCoins.contains(symbol.toUpperCase());
  }

  Future<void> toggleCoinMonitoring(
    String symbol,
    bool enable, {
    UserSettings? currentSettings,
    SettingsRepository? settingsRepo,
  }) async {
    final sym = symbol.toUpperCase();
    if (enable) {
      enabledCoins.add(sym);
    } else {
      enabledCoins.remove(sym);
      // Скидаємо збережені спрацювання для цієї монети
      _firedAlertKeys.removeWhere((k) => k.startsWith('${sym}_'));
      _saveFiredKeys();
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(prefKeyCoins, enabledCoins.toList());

    if (currentSettings != null && settingsRepo != null) {
      final updated = currentSettings.copyWith(
        cryptoAlertCoins: enabledCoins.toList(),
      );
      await settingsRepo.updateSettings(updated);
    }
  }

  Future<void> updateSettings({
    required bool enabled,
    required Set<String> coins,
    required bool notifyTp,
    required bool notifyTrailing,
    required bool notifyPreStop,
    required bool notifyHardStop,
    required bool notifyPeak,
    bool notifyDcaBuy = true,
    UserSettings? currentSettings,
    SettingsRepository? settingsRepo,
  }) async {
    alertsEnabled = enabled;
    enabledCoins = coins.map((s) => s.toUpperCase()).toSet();
    onTp = notifyTp;
    onTrailing = notifyTrailing;
    onPreStop = notifyPreStop;
    onHardStop = notifyHardStop;
    onPeak = notifyPeak;
    onDcaBuy = notifyDcaBuy;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(prefKeyEnabled, alertsEnabled);
    await prefs.setStringList(prefKeyCoins, enabledCoins.toList());
    await prefs.setBool(prefKeyOnTp, onTp);
    await prefs.setBool(prefKeyOnTrailing, onTrailing);
    await prefs.setBool(prefKeyOnPreStop, onPreStop);
    await prefs.setBool(prefKeyOnHardStop, onHardStop);
    await prefs.setBool(prefKeyOnPeak, onPeak);
    await prefs.setBool(prefKeyOnDcaBuy, onDcaBuy);

    if (currentSettings != null && settingsRepo != null) {
      final updated = currentSettings.copyWith(
        cryptoAlertsEnabled: alertsEnabled,
        cryptoAlertCoins: enabledCoins.toList(),
        cryptoAlertOnTp: onTp,
        cryptoAlertOnTrailing: onTrailing,
        cryptoAlertOnPreStop: onPreStop,
        cryptoAlertOnHardStop: onHardStop,
        cryptoAlertOnPeak: onPeak,
        cryptoAlertOnDcaBuy: onDcaBuy,
      );
      await settingsRepo.updateSettings(updated);
    }
  }

  Future<void> syncHoldingTargets(List<HoldingItem> holdings) async {
    for (final h in holdings) {
      final sym = h.symbol.toUpperCase();
      final tpSl = h.tpSl;
      if (tpSl.stopLoss <= 0 && tpSl.tp1 <= 0) continue;

      final double effectiveEntry =
          h.avgEntryPrice > 0 ? h.avgEntryPrice : tpSl.entryPrice;

      // Перший лімітний ордер DCA або рівень накопичення
      final double dca1 = tpSl.dcaLadder.isNotEmpty
          ? tpSl.dcaLadder.first.targetPrice
          : tpSl.accumulatePrice;

      // Якщо середня ціна змінилася (наприклад, здійснено новий добір),
      // скидаємо попередні стани спрацьованих алертів для цієї монети
      final existing = _targets[sym];
      if (existing != null && (existing.entryPrice - effectiveEntry).abs() > 0.0001) {
        _firedAlertKeys.removeWhere((k) => k.startsWith('${sym}_'));
      }

      _targets[sym] = CoinAlertTarget(
        symbol: sym,
        entryPrice: effectiveEntry,
        tp1: tpSl.tp1,
        tp1Pct: tpSl.tp1Pct.toDouble(),
        trailingStop: tpSl.trailingStopPrice,
        earlyExit: tpSl.earlyExitPrice,
        stopLoss: tpSl.stopLoss,
        recentPeak: tpSl.recentPeak20d,
        peakExhaustionScore: tpSl.peakExhaustionScore,
        slProbabilityPct: tpSl.slProbabilityPct,
        dca1Price: dca1,
        rsi: tpSl.rsi,
        exitSignalCode: tpSl.exitSignalCode,
        lastPrice: h.currentPrice,
      );
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(
        _targets.map((k, v) => MapEntry(k, v.toJson())),
      );
      await prefs.setString(prefKeyTargets, encoded);
      await _saveFiredKeys();
    } catch (e) {
      debugPrint('[CryptoAlertService] Error saving targets: $e');
    }
  }

  void checkLivePrice(String symbol, double price) {
    if (!alertsEnabled) return;
    final sym = symbol.toUpperCase();
    if (!enabledCoins.contains(sym)) return;

    final target = _targets[sym];
    if (target == null) return;

    _evaluatePrice(target, price);
  }

  Future<void> checkBackgroundPrices() async {
    if (!alertsEnabled || enabledCoins.isEmpty || _isPolling) return;
    _isPolling = true;

    try {
      // Виключаємо стейблкоїни
      final activeSymbols = enabledCoins
          .where((s) => !const {'USDT', 'USDC', 'FDUSD', 'DAI'}.contains(s))
          .toList();
      if (activeSymbols.isEmpty) return;

      final url = Uri.parse('https://api.binance.com/api/v3/ticker/price');
      final resp = await http.get(url).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) {
        final List<dynamic> list = jsonDecode(resp.body);
        final Map<String, double> prices = {};
        for (final item in list) {
          final pair = item['symbol'] as String;
          if (pair.endsWith('USDT')) {
            final base = pair.substring(0, pair.length - 4);
            if (activeSymbols.contains(base)) {
              prices[base] = double.tryParse(item['price'].toString()) ?? 0.0;
            }
          }
        }

        for (final sym in activeSymbols) {
          final p = prices[sym];
          final target = _targets[sym];
          if (p != null && p > 0 && target != null) {
            _evaluatePrice(target, p);
          }
        }
      }
    } catch (e) {
      debugPrint('[CryptoAlertService] Poll error: $e');
    } finally {
      _isPolling = false;
    }
  }

  /// Подієве (Edge-triggered) ядро оцінки:
  /// - Жодних періодичних спам-дублікатів кожні 2 години! Сповіщення надсилається ТІЛЬКИ ОДИН РАЗ при переході порогу.
  /// - Трейлінг-стоп активується ТІЛЬКИ якщо позиція має РЕАЛЬНИЙ зароблений профіт (PnL >= +1.5%) і трейлінг вище входу.
  /// - Застарілі піки кількатижневої давнини НЕ викликають панічного продажу, якщо актив куплено біля поточної ціни.
  /// - Додано сповіщення DCA_BUY для вчасного добору активу на дні/просіданні.
  void _evaluatePrice(CoinAlertTarget target, double price) {
    final sym = target.symbol;
    final effectiveEntry =
        target.entryPrice > 0 ? target.entryPrice : price;
    final double pnlPct = effectiveEntry > 0
        ? ((price - effectiveEntry) / effectiveEntry) * 100.0
        : 0.0;

    // -------------------------------------------------------------
    // 1. TAKE PROFIT (TP1)
    // -------------------------------------------------------------
    final tpKey = '${sym}_TP1';
    if (onTp &&
        target.tp1 > 0 &&
        price >= target.tp1 &&
        effectiveEntry > 0 &&
        pnlPct >= 3.0) {
      if (!_firedAlertKeys.contains(tpKey)) {
        _firedAlertKeys.add(tpKey);
        _saveFiredKeys();
        _sendAlert(
          id: (sym.hashCode ^ 1001) & 0x7FFFFFFF,
          title: '🎯 [$sym] ДОСЯГНУТО TAKE-PROFIT 1 (\$${_formatPrice(target.tp1)})!',
          body:
              'Ціна досягла \$${_formatPrice(price)} (+${pnlPct.toStringAsFixed(1)}%). Рекомендовано зафіксувати 30% прибутку за планом!',
        );
      }
    } else if (_firedAlertKeys.contains(tpKey) &&
        price < target.tp1 * 0.965) {
      // Hysteresis: переозброюємо алерт TP1, якщо ціна охолола нижче TP1 на 3.5%
      _firedAlertKeys.remove(tpKey);
      _saveFiredKeys();
    }

    // -------------------------------------------------------------
    // 2. CHANDELIER TRAILING STOP (Захист накопиченого профіту)
    // Трейлінг існує ВИКЛЮЧНО для захисту позиції, що побувала в плюсі (PnL >= 1.5% та trailingStop > entry).
    // Якщо PnL <= 0, спрацювання СУВОРО ЗАБОРОНЕНО, щоб не продавати актив за застарілим піком!
    // -------------------------------------------------------------
    final trailingKey = '${sym}_TRAILING';
    final bool canTriggerTrailing = onTrailing &&
        target.trailingStop > 0 &&
        target.trailingStop > effectiveEntry * 1.01 &&
        pnlPct >= 1.5 &&
        price <= target.trailingStop &&
        target.recentPeak >= effectiveEntry * 1.04;

    if (canTriggerTrailing) {
      if (!_firedAlertKeys.contains(trailingKey)) {
        _firedAlertKeys.add(trailingKey);
        _saveFiredKeys();
        _sendAlert(
          id: (sym.hashCode ^ 2002) & 0x7FFFFFFF,
          title: '🔒 [$sym] ТРЕЙЛІНГ-СТОП ПРОБИТО (\$${_formatPrice(target.trailingStop)})!',
          body:
              'Ціна відкотилася від піку \$${_formatPrice(target.recentPeak)} до \$${_formatPrice(price)}. Зафіксуйте накопичений прибуток (+${pnlPct.toStringAsFixed(1)}%)!',
        );
      }
    } else if (_firedAlertKeys.contains(trailingKey) &&
        price >= target.trailingStop * 1.05 &&
        price > effectiveEntry * 1.08) {
      // Переозброюємо, лише якщо актив утворив новий сильний висхідний імпульс
      _firedAlertKeys.remove(trailingKey);
      _saveFiredKeys();
    }

    // -------------------------------------------------------------
    // 3. PEAK EXHAUSTION (SELL_PEAK_NOW)
    // Фіксація на локальній вершині: актив має бути в суттєвому плюсі (+7%+) та біля піку САМЕ ЗАРАЗ
    // -------------------------------------------------------------
    final peakKey = '${sym}_PEAK';
    final bool isNearPeakNow = target.recentPeak > 0 &&
        price >= target.recentPeak * 0.975;
    if (onPeak &&
        pnlPct >= 7.0 &&
        isNearPeakNow &&
        target.peakExhaustionScore >= 75) {
      if (!_firedAlertKeys.contains(peakKey)) {
        _firedAlertKeys.add(peakKey);
        _saveFiredKeys();
        _sendAlert(
          id: (sym.hashCode ^ 3003) & 0x7FFFFFFF,
          title: '🔥 [$sym] ПІКОВЕ ВИСНАЖЕННЯ ТРЕНДУ (${target.peakExhaustionScore}%)!',
          body:
              'RSI > 75 та опір на піку \$${_formatPrice(price)} (+${pnlPct.toStringAsFixed(1)}%). Рекомендовано зафіксувати 30–50% на локальній вершині!',
        );
      }
    } else if (_firedAlertKeys.contains(peakKey) &&
        price < (target.recentPeak > 0 ? target.recentPeak : price) * 0.92) {
      _firedAlertKeys.remove(peakKey);
      _saveFiredKeys();
    }

    // -------------------------------------------------------------
    // 4. PRE-STOP DANGER (Рання евакуація при загрозі стопу)
    // Спрацьовує ТІЛЬКИ при реальному мінусі (PnL <= -3.0%), пробитті earlyExit та RSI >= 28
    // -------------------------------------------------------------
    final preStopKey = '${sym}_PRESTOP';
    if (onPreStop &&
        pnlPct <= -3.0 &&
        target.slProbabilityPct >= 65 &&
        target.earlyExit > 0 &&
        price <= target.earlyExit &&
        target.rsi >= 28) {
      if (!_firedAlertKeys.contains(preStopKey)) {
        _firedAlertKeys.add(preStopKey);
        _saveFiredKeys();
        _sendAlert(
          id: (sym.hashCode ^ 4004) & 0x7FFFFFFF,
          title: '🚨 [$sym] ЗАГРОЗА СТОП-ЛОСУ (${target.slProbabilityPct}%) — ПРЕ-СТОП!',
          body:
              'Ціна пробила лінію раннього виходу \$${_formatPrice(target.earlyExit)} (PnL: ${pnlPct.toStringAsFixed(1)}%). Рекомендовано скоротити 50% позиції!',
        );
      }
    } else if (_firedAlertKeys.contains(preStopKey) &&
        price > target.earlyExit * 1.025) {
      _firedAlertKeys.remove(preStopKey);
      _saveFiredKeys();
    }

    // -------------------------------------------------------------
    // 5. HARD STOP-LOSS HIT
    // -------------------------------------------------------------
    final hardStopKey = '${sym}_HARDSTOP';
    if (onHardStop &&
        target.stopLoss > 0 &&
        price <= target.stopLoss &&
        pnlPct <= -4.0) {
      if (!_firedAlertKeys.contains(hardStopKey)) {
        _firedAlertKeys.add(hardStopKey);
        _saveFiredKeys();
        _sendAlert(
          id: (sym.hashCode ^ 5005) & 0x7FFFFFFF,
          title: '🛑 [$sym] ПРОБИТО HARD STOP-LOSS (\$${_formatPrice(target.stopLoss)})!',
          body:
              'Ціна впала до \$${_formatPrice(price)}. Структурну підтримку втрачено, закрийте позицію для збереження капіталу.',
        );
      }
    }

    // -------------------------------------------------------------
    // 6. DCA BUY / ACCUMULATION ZONE (Відкуп дна / перший лімітний добір)
    // Замість панічних помилкових продажів у флеті/просіданні, сповіщаємо про плановий добір
    // -------------------------------------------------------------
    final dcaKey = '${sym}_DCABUY';
    final bool isDcaPriceZone =
        target.dca1Price > 0 && price <= target.dca1Price * 1.008;
    final bool isRsiOversoldDip =
        (target.rsi > 0 && target.rsi <= 32 && pnlPct <= -2.5);
    final bool isAccumulateSignal =
        target.exitSignalCode == 'ACCUMULATE_ZONE' && pnlPct <= -3.0;

    if (onDcaBuy && (isDcaPriceZone || isRsiOversoldDip || isAccumulateSignal)) {
      if (!_firedAlertKeys.contains(dcaKey)) {
        _firedAlertKeys.add(dcaKey);
        _saveFiredKeys();
        final level = target.dca1Price > 0 ? target.dca1Price : price;
        _sendAlert(
          id: (sym.hashCode ^ 6006) & 0x7FFFFFFF,
          title: '💎 [$sym] ЗОНА ДОБОРУ ЗА DCA (\$${_formatPrice(price)})!',
          body:
              'Ціна увійшла у вигідну зону накопичення біля першого DCA ордера (\$${_formatPrice(level)}). Чудовий момент для планового відкупу дна!',
        );
      }
    } else if (_firedAlertKeys.contains(dcaKey)) {
      final baseLevel = target.dca1Price > 0 ? target.dca1Price : price;
      if (price >= baseLevel * 1.035) {
        _firedAlertKeys.remove(dcaKey);
        _saveFiredKeys();
      }
    }
  }

  void _sendAlert({
    required int id,
    required String title,
    required String body,
  }) {
    NotificationService().showCryptoNotification(
      id: id,
      title: title,
      body: body,
    );
    debugPrint('[CryptoAlertService] 🔔 ALERT TRIGGERED ONCE: $title -> $body');
  }

  Future<void> _saveFiredKeys() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(prefKeyFiredEvents, _firedAlertKeys.toList());
    } catch (_) {}
  }

  String _formatPrice(double val) {
    if (val == 0) return '0.0000';
    final abs = val.abs();
    final sign = val < 0 ? '-' : '';
    if (abs >= 1000) {
      return '$sign${NumberFormat('#,##0.0000', 'en_US').format(abs)}';
    } else if (abs >= 0.0001) {
      return '$sign${abs.toStringAsFixed(4)}';
    } else {
      return '$sign${abs.toStringAsFixed(6)}';
    }
  }
}
