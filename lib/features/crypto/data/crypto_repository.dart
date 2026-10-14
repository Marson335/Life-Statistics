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
}
