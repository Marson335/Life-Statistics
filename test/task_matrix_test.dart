import 'package:flutter_test/flutter_test.dart';
import 'package:life_statistics/shared/models/models.dart';
import 'package:life_statistics/features/statistics/presentation/widgets/task_execution_matrix_card.dart';

void main() {
  group('Matrix Bar Data & Aggregation Tests', () {
    test('MatrixBarData computes totals and completion rate correctly', () {
      final bar = MatrixBarData(
        label: 'ПН',
        fullLabel: 'Понеділок, 19 жовтня',
        completed: 4,
        uncompleted: 1,
        isCurrent: true,
        date: DateTime(2026, 10, 19),
      );

      expect(bar.total, equals(5));
      expect(bar.completionRate, equals(80.0));
      expect(bar.isCurrent, isTrue);
    });

    test('MatrixBarData handles zero total safely without division by zero', () {
      final bar = MatrixBarData(
        label: 'ВТ',
        fullLabel: 'Вівторок, 20 жовтня',
        completed: 0,
        uncompleted: 0,
        isCurrent: false,
        date: DateTime(2026, 10, 20),
      );

      expect(bar.total, equals(0));
      expect(bar.completionRate, equals(0.0));
    });

    test('Task hasCheckbox is true only for green and blue tasks', () {
      final now = DateTime.now();
      final greenTask = Task(
        id: '1',
        userId: 'u1',
        title: 'Habit',
        type: TaskType.green,
        date: now,
        createdAt: now,
        isCompleted: true,
      );
      final blueTask = Task(
        id: '2',
        userId: 'u1',
        title: 'Todo',
        type: TaskType.blue,
        date: now,
        createdAt: now,
        isCompleted: false,
      );
      final redTask = Task(
        id: '3',
        userId: 'u1',
        title: 'Mindset',
        type: TaskType.red,
        date: now,
        createdAt: now,
      );
      final financeTask = Task(
        id: '4',
        userId: 'u1',
        title: 'Coffee',
        type: TaskType.finance,
        date: now,
        createdAt: now,
      );

      expect(greenTask.hasCheckbox, isTrue);
      expect(blueTask.hasCheckbox, isTrue);
      expect(redTask.hasCheckbox, isFalse);
      expect(financeTask.hasCheckbox, isFalse);
    });
  });
}
