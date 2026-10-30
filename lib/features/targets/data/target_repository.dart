import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../shared/models/models.dart';

class TargetRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _userIdOrNull => _auth.currentUser?.uid;
  String get _userId => _auth.currentUser!.uid;

  CollectionReference get _targetsCollection =>
      _firestore.collection('users').doc(_userId).collection('targets');

  Stream<List<TargetGoal>> watchTargets() {
    if (_userIdOrNull == null) return Stream.value(const []);
    return _targetsCollection.snapshots().map((snapshot) {
      final list = <TargetGoal>[];
      for (final doc in snapshot.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>?;
          if (data != null) {
            list.add(TargetGoal.fromMap(data, doc.id));
          }
        } catch (_) {}
      }
      list.sort((a, b) {
        if (a.isCompleted != b.isCompleted) {
          return a.isCompleted ? 1 : -1;
        }
        return b.createdAt.compareTo(a.createdAt);
      });
      return list;
    });
  }

  Future<List<TargetGoal>> getTargets() async {
    if (_userIdOrNull == null) return const [];
    try {
      final snapshot = await _targetsCollection.get();
      final list = <TargetGoal>[];
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          list.add(TargetGoal.fromMap(data, doc.id));
        }
      }
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (_) {
      return const [];
    }
  }

  Future<TargetGoal?> getTargetById(String targetId) async {
    if (_userIdOrNull == null) return null;
    try {
      final doc = await _targetsCollection.doc(targetId).get();
      if (doc.exists && doc.data() != null) {
        return TargetGoal.fromMap(
          doc.data() as Map<String, dynamic>,
          doc.id,
        );
      }
    } catch (_) {}
    return null;
  }

  Future<String> addTarget(TargetGoal target) async {
    final docRef = _targetsCollection.doc();
    final newTarget = target.copyWith(
      id: docRef.id,
      userId: _userId,
    );
    await docRef.set(newTarget.toMap());
    return docRef.id;
  }

  Future<void> updateTarget(TargetGoal target) async {
    await _targetsCollection.doc(target.id).update(target.toMap());
  }

  Future<void> deleteTarget(String targetId) async {
    await _targetsCollection.doc(targetId).delete();
  }

  /// Відмітити виконання або скасування конкретного етапу Таргета.
  Future<void> toggleStageCompletion(
    String targetId,
    String stageId,
    bool isCompleted,
  ) async {
    final target = await getTargetById(targetId);
    if (target == null || target.isCompleted) return;

    final updatedStages = target.stages.map((s) {
      if (s.id == stageId) {
        return s.copyWith(
          isCompleted: isCompleted,
          completedAt: isCompleted ? DateTime.now() : null,
          clearCompletedAt: !isCompleted,
        );
      }
      return s;
    }).toList();

    final updated = target.copyWith(stages: updatedStages);
    await updateTarget(updated);
  }

  /// Закрити (виконати) глобальний Таргет, коли фінальний рівень та всі етапи досягнуті.
  Future<bool> completeTarget(String targetId) async {
    final target = await getTargetById(targetId);
    if (target == null) return false;
    if (!target.isReadyToComplete) return false;

    final now = DateTime.now();
    final updatedStages = target.stages.map((s) {
      if (!s.isCompleted) {
        return s.copyWith(isCompleted: true, completedAt: now);
      }
      return s;
    }).toList();

    final completedTarget = target.copyWith(
      stages: updatedStages,
      isCompleted: true,
      completedAt: now,
    );
    await updateTarget(completedTarget);
    return true;
  }

  /// Повернути закритий Таргет назад у активні (за потреби).
  Future<void> reopenTarget(String targetId) async {
    final target = await getTargetById(targetId);
    if (target == null) return;
    final reopened = target.copyWith(
      isCompleted: false,
      clearCompletedAt: true,
    );
    await updateTarget(reopened);
  }

  /// Нарахувати або відкотити очки Таргетів при виконанні/знятті галочки задачі.
  /// Повертає оновлену мапу `appliedTargetPoints` для збереження в задачі.
  Future<Map<String, int>> applyTaskCompletionToTargets({
    required Task task,
    required bool isCompleted,
    required int streakDays,
  }) async {
    if (_userIdOrNull == null) return task.appliedTargetPoints;
    if (task.targetPoints.isEmpty && task.appliedTargetPoints.isEmpty) {
      return const {};
    }

    final newApplied = <String, int>{};
    final multiplier = TargetGoal.calculateStreakMultiplier(streakDays);

    // Збираємо всі targetId, які є або в налаштуваннях задачі, або у вже нарахованих
    final allTargetIds = <String>{
      ...task.targetPoints.keys,
      ...task.appliedTargetPoints.keys,
    };

    for (final targetId in allTargetIds) {
      final target = await getTargetById(targetId);
      if (target == null) continue;

      // Якщо Таргет уже закрито в Залі Слави — не чіпаємо його баланс
      if (target.isCompleted) {
        if (task.appliedTargetPoints.containsKey(targetId)) {
          newApplied[targetId] = task.appliedTargetPoints[targetId]!;
        }
        continue;
      }

      final prevApplied = task.appliedTargetPoints[targetId] ?? 0;
      final basePts = task.targetPoints[targetId] ?? 0;

      int desiredApplied = 0;
      if (isCompleted && basePts > 0) {
        desiredApplied = TargetGoal.calculateAwardedPoints(basePts, streakDays);
      }

      final netDelta = desiredApplied - prevApplied;
      final updatedPoints = math.max(0, target.currentPoints + netDelta);

      // Оновлюємо журнал історії (прибираємо попередній запис цієї ж задачі, якщо був)
      final updatedHistory = target.history
          .where((h) => h.taskId != task.id)
          .toList();

      if (isCompleted && desiredApplied > 0) {
        updatedHistory.insert(
          0,
          TargetHistoryEntry(
            id: '${task.id}_${DateTime.now().millisecondsSinceEpoch}',
            date: task.date,
            taskTitle: task.title,
            taskId: task.id,
            basePoints: basePts,
            deltaPoints: desiredApplied,
            multiplier: multiplier,
            streakCount: math.max(1, streakDays),
            isPenalty: false,
          ),
        );
        if (updatedHistory.length > 40) {
          updatedHistory.removeRange(40, updatedHistory.length);
        }
        newApplied[targetId] = desiredApplied;
      }

      final updatedTarget = target.copyWith(
        currentPoints: updatedPoints,
        history: updatedHistory,
      );
      await updateTarget(updatedTarget);
    }

    return newApplied;
  }

  /// Застосувати штраф за пропущену задачу минулого дня (режим NO EXCUSES).
  /// Повертає мапу списаних очок `appliedTargetPoints`.
  Future<Map<String, int>> applyMissedTaskPenalty({
    required Task task,
    required int antiStreakDays,
  }) async {
    if (_userIdOrNull == null || task.targetPoints.isEmpty) return const {};

    final newApplied = <String, int>{};
    final multiplier = TargetGoal.calculateStreakMultiplier(antiStreakDays);
    final taskDay = DateTime(task.date.year, task.date.month, task.date.day);

    for (final entry in task.targetPoints.entries) {
      final targetId = entry.key;
      final basePts = entry.value;
      if (basePts <= 0) continue;

      final target = await getTargetById(targetId);
      if (target == null || target.isCompleted) continue;

      // Не штрафуємо за дні, які були ДО дати створення самого Таргета
      final targetCreatedDay = DateTime(
        target.createdAt.year,
        target.createdAt.month,
        target.createdAt.day,
      );
      if (taskDay.isBefore(targetCreatedDay)) continue;

      final penaltyMagnitude =
          TargetGoal.calculateAwardedPoints(basePts, antiStreakDays);
      final deltaPoints = -penaltyMagnitude;
      final updatedPoints = math.max(0, target.currentPoints + deltaPoints);

      final updatedHistory = target.history
          .where((h) => h.taskId != task.id)
          .toList();

      updatedHistory.insert(
        0,
        TargetHistoryEntry(
          id: 'pen_${task.id}_${DateTime.now().millisecondsSinceEpoch}',
          date: task.date,
          taskTitle: task.title,
          taskId: task.id,
          basePoints: basePts,
          deltaPoints: deltaPoints,
          multiplier: multiplier,
          streakCount: math.max(1, antiStreakDays),
          isPenalty: true,
        ),
      );
      if (updatedHistory.length > 40) {
        updatedHistory.removeRange(40, updatedHistory.length);
      }

      newApplied[targetId] = deltaPoints;

      final updatedTarget = target.copyWith(
        currentPoints: updatedPoints,
        history: updatedHistory,
      );
      await updateTarget(updatedTarget);
    }

    return newApplied;
  }
}
