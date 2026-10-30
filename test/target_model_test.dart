import 'package:flutter_test/flutter_test.dart';
import 'package:life_statistics/shared/models/models.dart';

void main() {
  group('TargetGoal Level, Progress & Completion Logic', () {
    test('calculates currentLevel, currentLevelProgress, and totalProgress accurately', () {
      final target = TargetGoal(
        id: 't1',
        userId: 'u1',
        title: 'Вивчити Англійську C1',
        pointsPerLevel: 500,
        targetLevel: 10,
        currentPoints: 1250,
        createdAt: DateTime(2026, 1, 1),
      );

      expect(target.currentLevel, 3); // 0..499 = LVL 1, 500..999 = LVL 2, 1000..1499 = LVL 3
      expect(target.completedLevelsCount, 2);
      expect(target.pointsInCurrentLevel, 250);
      expect(target.currentLevelProgress, closeTo(0.5, 0.001));
      expect(target.totalTargetPoints, 5000);
      expect(target.remainingPointsToClose, 3750);
      expect(target.totalProgress, closeTo(0.25, 0.001));
      expect(target.isMaxPointsReached, isFalse);
    });

    test('caps currentLevelProgress at 1.0 and currentLevel at targetLevel when max points reached', () {
      final target = TargetGoal(
        id: 't1',
        userId: 'u1',
        title: 'Спорт Форма',
        pointsPerLevel: 500,
        targetLevel: 5,
        currentPoints: 2600,
        createdAt: DateTime(2026, 1, 1),
      );

      expect(target.isMaxPointsReached, isTrue);
      expect(target.currentLevel, 5);
      expect(target.currentLevelProgress, 1.0);
      expect(target.totalProgress, 1.0);
      expect(target.remainingPointsToClose, 0);
    });

    test('supports de-leveling when points drop below level boundary', () {
      final atLevel3 = TargetGoal(
        id: 't1',
        userId: 'u1',
        title: 'Таргет',
        pointsPerLevel: 500,
        targetLevel: 10,
        currentPoints: 1020, // LVL 3 (20 / 500)
        createdAt: DateTime(2026, 1, 1),
      );
      expect(atLevel3.currentLevel, 3);

      // After -50 TP penalty -> 970 TP -> drops to LVL 2 (470 / 500)
      final afterPenalty = atLevel3.copyWith(currentPoints: 970);
      expect(afterPenalty.currentLevel, 2);
      expect(afterPenalty.pointsInCurrentLevel, 470);
    });

    test('calculates streak and anti-streak multiplier (+10% per day, max x3.0)', () {
      expect(TargetGoal.calculateStreakMultiplier(0), 1.0);
      expect(TargetGoal.calculateStreakMultiplier(1), 1.0);
      expect(TargetGoal.calculateStreakMultiplier(2), closeTo(1.1, 0.001));
      expect(TargetGoal.calculateStreakMultiplier(6), closeTo(1.5, 0.001));
      expect(TargetGoal.calculateStreakMultiplier(11), closeTo(2.0, 0.001));
      expect(TargetGoal.calculateStreakMultiplier(21), closeTo(3.0, 0.001));
      expect(TargetGoal.calculateStreakMultiplier(35), 3.0); // Capped at x3.0

      expect(TargetGoal.calculateAwardedPoints(50, 1), 50);
      expect(TargetGoal.calculateAwardedPoints(50, 6), 75); // 50 * 1.5
      expect(TargetGoal.calculateAwardedPoints(50, 25), 150); // 50 * 3.0
    });

    test('unlocks stages by requiredLevel and checks isReadyToComplete', () {
      final stages = [
        const TargetStage(
          id: 's1',
          title: 'Етап 1: База',
          requiredLevel: 2,
          isCompleted: true,
        ),
        const TargetStage(
          id: 's2',
          title: 'Етап 2: Фінальний іспит',
          requiredLevel: 5,
          isCompleted: false,
        ),
      ];

      final targetLvl3 = TargetGoal(
        id: 't1',
        userId: 'u1',
        title: 'Іспит',
        pointsPerLevel: 100,
        targetLevel: 5,
        currentPoints: 250, // LVL 3
        stages: stages,
        createdAt: DateTime(2026, 1, 1),
      );

      expect(targetLvl3.isStageUnlocked(stages[0]), isTrue); // LVL 3 >= 2
      expect(targetLvl3.isStageUnlocked(stages[1]), isFalse); // LVL 3 < 5
      expect(targetLvl3.areAllStagesCompleted, isFalse);
      expect(targetLvl3.isReadyToComplete, isFalse);

      // Reach 500 TP (LVL 5) and complete all stages
      final targetLvl5Done = targetLvl3.copyWith(
        currentPoints: 500,
        stages: [
          stages[0],
          stages[1].copyWith(isCompleted: true),
        ],
      );

      expect(targetLvl5Done.isMaxPointsReached, isTrue);
      expect(targetLvl5Done.areAllStagesCompleted, isTrue);
      expect(targetLvl5Done.isReadyToComplete, isTrue);
    });

    test('serializes and deserializes Task target bindings properly', () {
      final task = Task(
        id: 'task_1',
        userId: 'u1',
        title: '50 слів Anki',
        type: TaskType.green,
        date: DateTime(2026, 10, 25),
        createdAt: DateTime(2026, 10, 25),
        targetPoints: const {'target_eng': 30, 'target_memory': 15},
        appliedTargetPoints: const {'target_eng': 45, 'target_memory': 23},
        targetPenaltyProcessed: false,
      );

      final map = task.toMap();
      final restored = Task.fromMap(map, task.id);

      expect(restored.targetPoints, {'target_eng': 30, 'target_memory': 15});
      expect(restored.appliedTargetPoints, {'target_eng': 45, 'target_memory': 23});
      expect(restored.targetPenaltyProcessed, isFalse);
    });
  });
}
