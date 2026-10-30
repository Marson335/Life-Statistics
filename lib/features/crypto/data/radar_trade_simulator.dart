import 'models/crypto_models.dart';

/// Результат симуляції однієї угоди за планом радара.
class RadarSimResult {
  const RadarSimResult({
    required this.status,
    this.outcome = '',
    this.rMultiple = 0.0,
    this.tp1Hit = false,
    this.fillPrice = 0.0,
    this.fillIndex = -1,
    this.exitIndex = -1,
    this.unrealizedR = 0.0,
  });

  /// pending — ще не виконано вхід; open — угода відкрита; closed — завершена;
  /// expired — вхід не відбувся за вікно очікування; cancelled — сетап зламано до входу.
  final String status;

  /// sl / tp1_be / tp2 / time / '' (для не закритих)
  final String outcome;

  /// Результат у R із урахуванням комісій та проковзування (лише для closed).
  final double rMultiple;
  final bool tp1Hit;
  final double fillPrice;
  final int fillIndex;
  final int exitIndex;
  final double unrealizedR;

  bool get isClosed => status == 'closed';
}

/// Єдина модель виконання угоди — використовується і для бектесту (walk-forward),
/// і для автоматичної перевірки реальних сигналів у журналі. Так статистика
/// історичних перевірок і журналу порівнювана.
///
/// Свічки [o],[h],[l],[c] — ЗАКРИТІ денні свічки ПІСЛЯ дня сигналу
/// (індекс 0 = перша свічка після сигналу).
class RadarTradeSimulator {
  /// Комісії туди-назад + проковзування для спотового ринку (у % від ціни входу).
  static const double roundTripCostPct = 0.5;

  /// Скільки днів чекаємо на виконання лімітки / пробою.
  static const int entryWaitDays = 10;

  static RadarSimResult simulate({
    required String entryStatus,
    required double entryMax,
    required double triggerPrice,
    required double stop,
    required double tp1,
    required double tp2,
    required int timeStopDays,
    required List<double> o,
    required List<double> h,
    required List<double> l,
    required List<double> c,
    double costPct = roundTripCostPct,
  }) {
    final len = c.length;
    if (len == 0) return const RadarSimResult(status: 'pending');

    // ---------------- ВХІД ----------------
    int fillIdx = -1;
    double fillPrice = 0;

    if (entryStatus == RadarEntryStatus.buyNow) {
      fillIdx = 0;
      fillPrice = o[0];
    } else {
      final waitLimit = len < entryWaitDays ? len : entryWaitDays;
      for (int i = 0; i < waitLimit; i++) {
        if (entryStatus == RadarEntryStatus.waitPullback) {
          if (c[i] < stop) return const RadarSimResult(status: 'cancelled');
          if (l[i] <= entryMax) {
            fillIdx = i;
            fillPrice = o[i] <= entryMax ? o[i] : entryMax;
            break;
          }
        } else {
          // waitBreakout
          if (c[i] < stop) return const RadarSimResult(status: 'cancelled');
          if (h[i] >= triggerPrice) {
            fillIdx = i;
            fillPrice = o[i] >= triggerPrice ? o[i] : triggerPrice;
            break;
          }
        }
      }
      if (fillIdx < 0) {
        return RadarSimResult(status: len >= entryWaitDays ? 'expired' : 'pending');
      }
    }

    final risk = fillPrice - stop;
    if (risk <= 0 || fillPrice <= 0) return const RadarSimResult(status: 'cancelled');
    final costR = costPct / (risk / fillPrice * 100.0);

    // ---------------- ВЕДЕННЯ УГОДИ ----------------
    double remaining = 1.0;
    double realizedR = 0.0;
    double curStop = stop;
    bool tp1Done = false;
    bool tp2Done = false;

    RadarSimResult closed(String outcome, int idx) => RadarSimResult(
          status: 'closed',
          outcome: outcome,
          rMultiple: realizedR - costR,
          tp1Hit: tp1Done,
          fillPrice: fillPrice,
          fillIndex: fillIdx,
          exitIndex: idx,
        );

    for (int i = fillIdx; i < len; i++) {
      // Консервативно: у день входу та в один день з TP спершу перевіряємо стоп.
      if (l[i] <= curStop) {
        double exitPrice = curStop;
        if (i > fillIdx && o[i] < curStop) exitPrice = o[i]; // гепи вниз
        realizedR += remaining * ((exitPrice - fillPrice) / risk);
        return closed(tp1Done ? 'tp1_be' : 'sl', i);
      }
      if (!tp1Done && h[i] >= tp1) {
        realizedR += 0.5 * ((tp1 - fillPrice) / risk);
        remaining -= 0.5;
        curStop = fillPrice; // беззбиток
        tp1Done = true;
      }
      if (tp1Done && !tp2Done && h[i] >= tp2) {
        realizedR += 0.3 * ((tp2 - fillPrice) / risk);
        remaining -= 0.3;
        tp2Done = true;
      }
      if (i - fillIdx >= timeStopDays) {
        realizedR += remaining * ((c[i] - fillPrice) / risk);
        return closed(tp2Done ? 'tp2' : (tp1Done ? 'tp1_be' : 'time'), i);
      }
    }

    final unreal = realizedR + remaining * ((c[len - 1] - fillPrice) / risk) - costR;
    return RadarSimResult(
      status: 'open',
      tp1Hit: tp1Done,
      fillPrice: fillPrice,
      fillIndex: fillIdx,
      unrealizedR: unreal,
    );
  }
}
