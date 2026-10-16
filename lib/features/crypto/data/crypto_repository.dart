import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models/crypto_models.dart';

class DcaAggregatedSummary {
  final String symbol;
  final double totalAmount;
  final double totalCost;
  final double avgEntryPrice;

  DcaAggregatedSummary({
    required this.symbol,
    required this.totalAmount,
    required this.totalCost,
    required this.avgEntryPrice,
  });
}

class CryptoRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userId => _auth.currentUser?.uid;

  CollectionReference? get _dcaCollection {
    final uid = _userId;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('crypto_dca');
  }

  // --- STREAM DCA ТРАНЗАКЦІЙ ---
  Stream<List<DcaTransaction>> watchDcaTransactions() {
    final col = _dcaCollection;
    if (col == null) return Stream.value([]);

    return col
        .orderBy('txDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DcaTransaction.fromMap(
                  doc.id,
                  doc.data() as Map<String, dynamic>,
                ))
            .toList());
  }

  // --- ОТРИМАННЯ ВСІХ ТРАНЗАКЦІЙ ОДНОРАЗОВО ---
  Future<List<DcaTransaction>> getDcaTransactions() async {
    final col = _dcaCollection;
    if (col == null) return [];

    try {
      final snapshot = await col.orderBy('txDate', descending: true).get();
      return snapshot.docs
          .map((doc) => DcaTransaction.fromMap(
                doc.id,
                doc.data() as Map<String, dynamic>,
              ))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // --- ДОДАВАННЯ DCA ПОКУПКИ ---
  Future<void> addDcaTransaction(DcaTransaction tx) async {
    final col = _dcaCollection;
    if (col == null) return;

    if (tx.id.isEmpty) {
      await col.add(tx.toMap());
    } else {
      await col.doc(tx.id).set(tx.toMap());
    }
  }

  // --- ВИДАЛЕННЯ ТРАНЗАКЦІЇ ---
  Future<void> deleteDcaTransaction(String id) async {
    final col = _dcaCollection;
    if (col == null) return;
    await col.doc(id).delete();
  }

  // --- РОЗРАХУНОК СЕРЕДНЬОВЗВАЖЕНОЇ ТОЧКИ ВХОДУ (WEIGHTED DCA) ---
  Future<Map<String, DcaAggregatedSummary>> getAggregatedDcaSummary() async {
    final transactions = await getDcaTransactions();
    final Map<String, double> amountMap = {};
    final Map<String, double> costMap = {};

    for (final tx in transactions) {
      final sym = tx.symbol.toUpperCase();
      final amt = tx.amount;
      final cost = (tx.amount * tx.buyPrice) + tx.fee;

      amountMap[sym] = (amountMap[sym] ?? 0.0) + amt;
      costMap[sym] = (costMap[sym] ?? 0.0) + cost;
    }

    final Map<String, DcaAggregatedSummary> result = {};
    for (final sym in amountMap.keys) {
      final totalAmt = amountMap[sym] ?? 0.0;
      final totalCost = costMap[sym] ?? 0.0;
      final avgEntry = totalAmt > 0 ? totalCost / totalAmt : 0.0;

      result[sym] = DcaAggregatedSummary(
        symbol: sym,
        totalAmount: totalAmt,
        totalCost: totalCost,
        avgEntryPrice: avgEntry,
      );
    }

    return result;
  }

  // --- СИНХРОНІЗАЦІЯ БІНАНС DCA ТРАНШІВ (FIFO) ---
  Future<void> syncBinanceDcaTranches(List<DcaTransaction> newBinanceTranches) async {
    final col = _dcaCollection;
    if (col == null) return;

    try {
      // Знаходимо всі існуючі записи Binance Spot
      final snapshot = await col.where('walletType', isEqualTo: 'Binance Spot').get();
      final newIds = newBinanceTranches.map((t) => t.id).toSet();

      // Карта існуючих документів для збереження початкової ціни першого виявлення
      final Map<String, DcaTransaction> existingMap = {};
      for (final doc in snapshot.docs) {
        existingMap[doc.id] = DcaTransaction.fromMap(doc.id, doc.data() as Map<String, dynamic>);
      }

      final batch = _firestore.batch();

      // Видаляємо ті, що вже повністю продані (відсутні в новому списку FIFO)
      for (final doc in snapshot.docs) {
        if (!newIds.contains(doc.id)) {
          batch.delete(doc.reference);
        }
      }

      // Додаємо або оновлюємо актуальні активні транші
      for (final tx in newBinanceTranches) {
        final existing = existingMap[tx.id];

        // КРИТИЧНО: Якщо транш було створено на основі балансу гаманця (binance_balance_*)
        // або в базі вже зафіксовано початкову ціну входу, ми ЗАЛИШАЄМО початкову ціну та дату!
        // Не перезаписуємо її поточною ринковою ціною при кожному запуску!
        DcaTransaction effectiveTx = tx;
        if (existing != null) {
          final isBalanceFallback = tx.id.startsWith('binance_balance_');
          final shouldKeepOldPrice = (isBalanceFallback && existing.buyPrice > 0) ||
              (tx.buyPrice <= 0 && existing.buyPrice > 0);

          if (shouldKeepOldPrice) {
            effectiveTx = DcaTransaction(
              id: tx.id,
              symbol: tx.symbol,
              walletType: tx.walletType,
              amount: tx.amount, // актуальний залишок монет
              buyPrice: existing.buyPrice, // зберігаємо початкову ціну покупки!
              fee: existing.fee > 0 ? existing.fee : tx.fee,
              txDate: existing.txDate, // зберігаємо первинну дату фіксації!
              notes: existing.notes.isNotEmpty ? existing.notes : tx.notes,
            );
          }
        }

        batch.set(col.doc(effectiveTx.id), effectiveTx.toMap());
      }

      await batch.commit();
    } catch (_) {}
  }
}

