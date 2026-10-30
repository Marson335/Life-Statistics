import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models/crypto_models.dart';
import 'radar_http.dart';
import 'radar_trade_simulator.dart';

/// Агрегована статистика по сигналах журналу радара.
class RadarSetupStat {
  RadarSetupStat();
  int closed = 0;
  int wins = 0;
  double sumR = 0;
  double get avgR => closed > 0 ? sumR / closed : 0.0;
}

class RadarJournalStats {
  RadarJournalStats({
    this.closed = 0,
    this.wins = 0,
    this.tp1Hits = 0,
    this.sumR = 0,
    this.open = 0,
    this.pending = 0,
    this.expired = 0,
    Map<String, RadarSetupStat>? bySetup,
  }) : bySetup = bySetup ?? {};

  final int closed;
  final int wins;
  final int tp1Hits;
  final double sumR;
  final int open;
  final int pending;
  final int expired;
  final Map<String, RadarSetupStat> bySetup;

  double get winRatePct => closed > 0 ? wins / closed * 100.0 : 0.0;
  double get avgR => closed > 0 ? sumR / closed : 0.0;
  double get tp1HitRatePct => closed > 0 ? tp1Hits / closed * 100.0 : 0.0;

  /// Середній R по типу сетапу (лише при >= 10 закритих угодах) — для калібрування скору.
  Map<String, double> get edgeBySetup => {
        for (final e in bySetup.entries)
          if (e.value.closed >= 10) e.key: e.value.avgR,
      };

  String toSummary() {
    if (closed == 0 && open == 0 && pending == 0) {
      return '📒 Журнал радара: сигнали записуються автоматично — статистика з\'явиться після перших закритих угод.';
    }
    final sb = StringBuffer('📒 Журнал радара (реальні сигнали, з комісіями): ');
    if (closed > 0) {
      sb.write('закрито $closed · win-rate ${winRatePct.toStringAsFixed(0)}% · '
          'TP1 досягнуто ${tp1HitRatePct.toStringAsFixed(0)}% · середній результат '
          '${avgR >= 0 ? '+' : ''}${avgR.toStringAsFixed(2)}R. ');
    } else {
      sb.write('поки немає закритих угод. ');
    }
    sb.write('Відкрито: $open, очікують входу: $pending.');
    return sb.toString();
  }
}

/// Журнал сигналів AI-радара: кожен виданий сигнал записується у Firestore,
/// а потім автоматично перевіряється за реальними денними свічками тією самою
/// моделлю виконання, що й бектест ([RadarTradeSimulator]).
class CryptoRadarJournalService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference? get _col {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('radar_signals');
  }

  static String _dayKey(DateTime d) {
    final u = d.toUtc();
    return '${u.year}${u.month.toString().padLeft(2, '0')}${u.day.toString().padLeft(2, '0')}';
  }

  /// Записує сигнали звіту (один сигнал на монету на добу — повторний скан у той самий день не дублює).
  Future<void> recordSignals(AiMarketRadarReport report) async {
    final col = _col;
    if (col == null || report.isError || report.opportunities.isEmpty) return;
    try {
      for (final o in report.opportunities) {
        final id = '${_dayKey(report.scannedAt)}_${o.symbol}';
        final ref = col.doc(id);
        final existing = await ref.get();
        if (existing.exists) continue;
        await ref.set({
          'symbol': o.symbol,
          'setupType': o.setupType,
          'regime': report.marketRegime,
          'score': o.confidenceScore,
          'entryStatus': o.entryStatus,
          'priceAtSignal': o.currentPrice,
          'entryMin': o.entryZoneMin,
          'entryMax': o.entryZoneMax,
          'trigger': o.triggerPrice,
          'stop': o.stopLoss,
          'tp1': o.targetPrice1,
          'tp2': o.targetPrice2,
          'timeStopDays': o.timeStopDays,
          'createdAt': Timestamp.fromDate(report.scannedAt),
          'status': 'pending',
          'outcome': '',
          'rMultiple': null,
          'tp1Hit': false,
        });
      }
    } catch (_) {
      // журнал не повинен ламати сканування
    }
  }

  /// Перевіряє всі сигнали зі статусом pending/open за свічками, які закрилися після дня сигналу.
  Future<void> evaluateOpenSignals() async {
    final col = _col;
    if (col == null) return;
    try {
      final snap = await col.where('status', whereIn: ['pending', 'open']).get();
      final now = DateTime.now().toUtc();
      for (final doc in snap.docs) {
        try {
          final d = doc.data() as Map<String, dynamic>;
          final created = (d['createdAt'] as Timestamp).toDate().toUtc();
          final nextDay = DateTime.utc(created.year, created.month, created.day + 1);
          if (now.isBefore(nextDay.add(const Duration(days: 1)))) continue; // ще немає закритої свічки після сигналу

          final ageDays = now.difference(created).inDays;
          final raw = await RadarHttp.fetchDailyKlines('${d['symbol']}USDT', 120, useCache: false);
          if (raw == null) continue;

          final nowMs = now.millisecondsSinceEpoch;
          final o = <double>[], h = <double>[], l = <double>[], c = <double>[];
          for (final k in raw) {
            final openTime = (k[0] as num).toInt();
            final closeTime = (k[6] as num).toInt();
            if (closeTime > nowMs) continue;
            if (openTime < nextDay.millisecondsSinceEpoch) continue;
            o.add(double.tryParse(k[1].toString()) ?? 0);
            h.add(double.tryParse(k[2].toString()) ?? 0);
            l.add(double.tryParse(k[3].toString()) ?? 0);
            c.add(double.tryParse(k[4].toString()) ?? 0);
          }
          if (c.isEmpty) continue;

          final res = RadarTradeSimulator.simulate(
            entryStatus: d['entryStatus']?.toString() ?? RadarEntryStatus.buyNow,
            entryMax: (d['entryMax'] as num).toDouble(),
            triggerPrice: (d['trigger'] as num?)?.toDouble() ?? 0,
            stop: (d['stop'] as num).toDouble(),
            tp1: (d['tp1'] as num).toDouble(),
            tp2: (d['tp2'] as num).toDouble(),
            timeStopDays: (d['timeStopDays'] as num?)?.toInt() ?? 21,
            o: o,
            h: h,
            l: l,
            c: c,
          );

          String status = res.status;
          // Підстраховка: давно відкриті угоди без результату не висять вічно
          if (status == 'open' && ageDays > 120) status = 'closed';

          await doc.reference.update({
            'status': status,
            'outcome': res.outcome,
            'rMultiple': res.isClosed ? res.rMultiple : null,
            'tp1Hit': res.tp1Hit,
            'fillPrice': res.fillPrice > 0 ? res.fillPrice : null,
            'unrealizedR': status == 'open' ? res.unrealizedR : null,
            'evaluatedAt': Timestamp.now(),
          });
        } catch (_) {
          continue;
        }
      }
    } catch (_) {
      // немає індексу / мережі — просто пропускаємо перевірку
    }
  }

  /// Статистика журналу (усі закриті/відкриті сигнали).
  Future<RadarJournalStats> loadStats() async {
    final col = _col;
    if (col == null) return RadarJournalStats();
    try {
      final snap = await col.limit(600).get();
      int closed = 0, wins = 0, tp1 = 0, open = 0, pending = 0, expired = 0;
      double sumR = 0;
      final by = <String, RadarSetupStat>{};
      for (final doc in snap.docs) {
        final d = doc.data() as Map<String, dynamic>;
        final status = d['status']?.toString() ?? 'pending';
        switch (status) {
          case 'closed':
            final r = (d['rMultiple'] as num?)?.toDouble();
            if (r == null) break;
            closed++;
            sumR += r;
            if (r > 0) wins++;
            if (d['tp1Hit'] == true) tp1++;
            final s = by.putIfAbsent(d['setupType']?.toString() ?? '', RadarSetupStat.new);
            s.closed++;
            s.sumR += r;
            if (r > 0) s.wins++;
            break;
          case 'open':
            open++;
            break;
          case 'pending':
            pending++;
            break;
          case 'expired':
            expired++;
            break;
        }
      }
      return RadarJournalStats(
        closed: closed,
        wins: wins,
        tp1Hits: tp1,
        sumR: sumR,
        open: open,
        pending: pending,
        expired: expired,
        bySetup: by,
      );
    } catch (_) {
      return RadarJournalStats();
    }
  }
}
