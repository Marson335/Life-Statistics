import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/models/models.dart';

final caloriesRepositoryProvider = Provider((ref) => CaloriesRepository());

final dailyMacrosProvider = StreamProvider.family<DailyMacros, DateTime>((ref, date) {
  return ref.watch(caloriesRepositoryProvider).watchDailyMacros(date);
});

final macrosRangeProvider = StreamProvider.family<List<DailyMacros>, (DateTime, DateTime)>((ref, range) {
  return ref.watch(caloriesRepositoryProvider).watchMacrosForRange(range.$1, range.$2);
});

class CaloriesRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _userId => _auth.currentUser!.uid;

  CollectionReference get _macrosCollection =>
      _firestore.collection('users').doc(_userId).collection('macros');

  String _formatDate(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  Stream<DailyMacros> watchDailyMacros(DateTime date) {
    final dateStr = _formatDate(date);
    return _macrosCollection.doc(dateStr).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return DailyMacros.empty(dateStr);
      }
      return DailyMacros.fromMap(snapshot.data() as Map<String, dynamic>, snapshot.id);
    });
  }

  Stream<List<DailyMacros>> watchMacrosForRange(DateTime start, DateTime end) {
    return _macrosCollection
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: _formatDate(start))
        .where(FieldPath.documentId, isLessThanOrEqualTo: _formatDate(end))
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return DailyMacros.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
    });
  }

  Future<void> updateDailyMacros(
    DateTime date, {
    int calories = 0,
    int protein = 0,
    int fats = 0,
    int carbs = 0,
    MealItem? meal,
  }) async {
    final dateStr = _formatDate(date);
    final docRef = _macrosCollection.doc(dateStr);
    
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final mealList = meal != null ? [meal.toMap()] : [];
      
      if (!snapshot.exists) {
        transaction.set(docRef, {
          'calories': calories,
          'protein': protein,
          'fats': fats,
          'carbs': carbs,
          'meals': mealList,
        });
      } else {
        final current = snapshot.data() as Map<String, dynamic>;
        final currentMeals = List<dynamic>.from(current['meals'] ?? []);
        if (meal != null) {
          currentMeals.add(meal.toMap());
        }
        transaction.update(docRef, {
          'calories': (current['calories'] ?? 0) + calories,
          'protein': (current['protein'] ?? 0) + protein,
          'fats': (current['fats'] ?? 0) + fats,
          'carbs': (current['carbs'] ?? 0) + carbs,
          'meals': currentMeals,
        });
      }
    });
  }

  Future<void> deleteMeal(DateTime date, MealItem meal) async {
    final dateStr = _formatDate(date);
    final docRef = _macrosCollection.doc(dateStr);
    
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) return;
      
      final current = snapshot.data() as Map<String, dynamic>;
      final currentMeals = List<dynamic>.from(current['meals'] ?? []);
      final updatedMeals = currentMeals.where((m) => m['id'] != meal.id).toList();

      final newCalories = ((current['calories'] ?? 0) - meal.calories).clamp(0, 999999);
      final newProtein = ((current['protein'] ?? 0) - meal.protein).clamp(0, 999999);
      final newFats = ((current['fats'] ?? 0) - meal.fats).clamp(0, 999999);
      final newCarbs = ((current['carbs'] ?? 0) - meal.carbs).clamp(0, 999999);

      transaction.update(docRef, {
        'calories': newCalories,
        'protein': newProtein,
        'fats': newFats,
        'carbs': newCarbs,
        'meals': updatedMeals,
      });
    });
  }
}
