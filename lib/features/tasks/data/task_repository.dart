import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/notification_service.dart';
import '../../../shared/models/models.dart';

class TaskRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _userId => _auth.currentUser!.uid;

  CollectionReference get _tasksCollection =>
      _firestore.collection('users').doc(_userId).collection('tasks');

  // Get tasks for a specific date
  Stream<List<Task>> getTasksForDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    return _tasksCollection
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .orderBy('date')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Task.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  // Get tasks for a date range (week view)
  Stream<List<Task>> getTasksForDateRange(DateTime start, DateTime end) {
    return _tasksCollection
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .orderBy('date')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Task.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }

  // Add a task
  Future<void> addTask(Task task) async {
    final docRef = _tasksCollection.doc();
    final newTask = task.copyWith(id: docRef.id);
    await docRef.set(newTask.toMap());

    if (newTask.reminderTime != null) {
      await NotificationService().scheduleTaskReminder(newTask);
    }

    // If green recurring task - generate future instances
    if (task.type == TaskType.green && task.recurrence != null) {
      await _generateRecurringTasks(newTask);
    }
  }

  // Generate recurring task instances (next 90 days)
  Future<void> _generateRecurringTasks(Task task) async {
    final rule = task.recurrence!;
    final endDate = rule.endDate ?? rule.startDate.add(const Duration(days: 90));
    final batch = _firestore.batch();
    int batchCount = 0;

    DateTime current = rule.startDate.add(const Duration(days: 1));

    while (current.isBefore(endDate) && batchCount < 400) {
      bool shouldAdd = false;

      switch (rule.frequency) {
        case RecurrenceFrequency.daily:
          shouldAdd = true;
          break;
        case RecurrenceFrequency.weekly:
          shouldAdd = rule.daysOfWeek?.contains(current.weekday) ?? false;
          break;
        case RecurrenceFrequency.custom:
          shouldAdd = rule.daysOfWeek?.contains(current.weekday) ?? false;
          break;
      }

      if (shouldAdd) {
        final docRef = _tasksCollection.doc();
        final instance = task.copyWith(
          id: docRef.id,
          date: DateTime(current.year, current.month, current.day,
              task.date.hour, task.date.minute),
          isCompleted: false,
        );
        batch.set(docRef, instance.toMap());
        batchCount++;
      }

      current = current.add(const Duration(days: 1));
    }

    if (batchCount > 0) await batch.commit();
  }

  // Update task
  Future<void> updateTask(Task task) async {
    await _tasksCollection.doc(task.id).update(task.toMap());
    
    if (task.reminderTime != null) {
      await NotificationService().scheduleTaskReminder(task);
    } else {
      await NotificationService().cancelTaskReminder(task.id);
    }
  }

  // Toggle task completion
  Future<void> toggleTaskCompletion(String taskId, bool isCompleted) async {
    await _tasksCollection.doc(taskId).update({'isCompleted': isCompleted});
  }

  // Delete task
  Future<void> deleteTask(String taskId) async {
    await _tasksCollection.doc(taskId).delete();
    await NotificationService().cancelTaskReminder(taskId);
  }

  // Delete all instances of a green task from a specific date onwards
  Future<void> deleteAllGreenTaskInstances(String groupId, DateTime fromDate) async {
    final normalizedDate = DateTime(fromDate.year, fromDate.month, fromDate.day);
    
    final snapshot = await _tasksCollection
        .where('groupId', isEqualTo: groupId)
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      final taskDate = (doc.data() as Map<String, dynamic>)['date'].toDate();
      if (!taskDate.isBefore(normalizedDate)) {
        batch.delete(doc.reference);
      }
    }
    await batch.commit();
    await NotificationService().cancelTaskReminder(groupId);
  }

  // Update all instances of a green task from a specific date onwards
  Future<void> updateAllGreenTaskInstances(Task updatedTask, DateTime fromDate) async {
    final normalizedDate = DateTime(fromDate.year, fromDate.month, fromDate.day);

    final snapshot = await _tasksCollection
        .where('groupId', isEqualTo: updatedTask.groupId)
        .get();

    final batch = _firestore.batch();
    final updateMap = updatedTask.toMap();
    updateMap.remove('date');
    updateMap.remove('isCompleted');
    
    for (final doc in snapshot.docs) {
      final taskDate = (doc.data() as Map<String, dynamic>)['date'].toDate();
      if (!taskDate.isBefore(normalizedDate)) {
        batch.update(doc.reference, updateMap);
      }
    }
    await batch.commit();

    if (updatedTask.reminderTime != null) {
      await NotificationService().scheduleTaskReminder(updatedTask);
    } else {
      await NotificationService().cancelTaskReminder(updatedTask.groupId ?? updatedTask.id);
    }
  }

  // Get statistics for a date range
  Future<Map<String, dynamic>> getStatisticsForRange(
      DateTime start, DateTime end, {bool isYearly = false}) async {
    final snapshot = await _tasksCollection
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();

    final tasks = snapshot.docs
        .map((doc) => Task.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();

    final checkableTasks =
        tasks.where((t) => t.type == TaskType.green || t.type == TaskType.blue).toList();
    final completedTasks = checkableTasks.where((t) => t.isCompleted).toList();

    // Calculate time only for COMPLETED tasks
    final int completedTimeMinutes = tasks
        .where((t) => t.isCompleted)
        .fold(0, (acc, t) => acc + (t.timeSpentMinutes ?? 0));

    // Green tasks time breakdown (only completed)
    final greenTimeBreakdown = <String, int>{};
    for (final t in tasks) {
      if (t.type == TaskType.green && t.isCompleted && (t.timeSpentMinutes ?? 0) > 0) {
        final title = t.title;
        greenTimeBreakdown[title] = (greenTimeBreakdown[title] ?? 0) + t.timeSpentMinutes!;
      }
    }

    // Money spent by day (or month if yearly)
    final expensesChart = <String, double>{};
    double totalCompletedMoney = 0;
    
    for (final t in tasks) {
      // Red/yellow tasks are auto-confirmed (no checkbox), so always count their money.
      final bool countMoney = t.isCompleted ||
          t.type == TaskType.red ||
          t.type == TaskType.yellow;

      if (countMoney && (t.moneySpent ?? 0) > 0) {
        totalCompletedMoney += t.moneySpent!;
        
        String dateKey;
        if (isYearly) {
          dateKey = "${t.date.year}-${t.date.month.toString().padLeft(2, '0')}";
        } else {
          dateKey = "${t.date.year}-${t.date.month.toString().padLeft(2, '0')}-${t.date.day.toString().padLeft(2, '0')}";
        }
        
        expensesChart[dateKey] = (expensesChart[dateKey] ?? 0) + t.moneySpent!;
      }
    }

    return {
      'total': checkableTasks.length,
      'completed': completedTasks.length,
      'percentage': checkableTasks.isEmpty
          ? 0.0
          : (completedTasks.length / checkableTasks.length * 100),
      'byType': {
        'green': tasks.where((t) => t.type == TaskType.green).length,
        'blue': tasks.where((t) => t.type == TaskType.blue).length,
        'red': tasks.where((t) => t.type == TaskType.red).length,
        'yellow': tasks.where((t) => t.type == TaskType.yellow).length,
      },
      'greenCompleted': tasks.where((t) => t.type == TaskType.green && t.isCompleted).length,
      'blueCompleted': tasks.where((t) => t.type == TaskType.blue && t.isCompleted).length,
      'totalTimeMinutes': completedTimeMinutes,
      'greenTimeBreakdown': greenTimeBreakdown,
      'totalMoney': totalCompletedMoney,
      'expensesChart': expensesChart,
    };
  }

  // Calculate current streak for a green task
  Future<int> calculateTaskStreak(String groupId, DateTime upToDate) async {
    final normalizedDate = DateTime(upToDate.year, upToDate.month, upToDate.day);
    
    final snapshot = await _tasksCollection
        .where('groupId', isEqualTo: groupId)
        .get();

    final tasks = snapshot.docs.map((d) {
      final data = d.data() as Map<String, dynamic>;
      return {
        'date': (data['date'] as Timestamp).toDate(),
        'isCompleted': data['isCompleted'] as bool? ?? false,
      };
    }).toList();

    tasks.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

    int streak = 0;
    bool isFirst = true;

    for (var t in tasks) {
      final taskDate = t['date'] as DateTime;
      final taskDay = DateTime(taskDate.year, taskDate.month, taskDate.day);
      if (taskDay.isAfter(normalizedDate)) continue;

      if (isFirst) {
        isFirst = false;
        if (t['isCompleted'] as bool) streak++;
      } else {
        if (t['isCompleted'] as bool) {
          streak++;
        } else {
          break;
        }
      }
    }
    return streak;
  }

  // Get streaks for all green tasks
  Future<Map<String, Map<String, dynamic>>> getHabitStreaks() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final snapshot = await _tasksCollection
        .where('type', isEqualTo: TaskType.green.name)
        .get();

    final grouped = <String, List<Map<String, dynamic>>>{};
    final titles = <String, String>{};

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final groupId = data['groupId'] as String?;
      if (groupId == null) continue;

      final taskDate = (data['date'] as Timestamp).toDate();
      if (taskDate.isAfter(today)) continue;

      titles[groupId] = data['title'] as String? ?? 'Задача';
      
      grouped.putIfAbsent(groupId, () => []).add({
        'date': taskDate,
        'isCompleted': data['isCompleted'] as bool? ?? false,
      });
    }

    final results = <String, Map<String, dynamic>>{};

    for (final entry in grouped.entries) {
      final groupId = entry.key;
      final tasks = entry.value;
      
      tasks.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

      int currentStreak = 0;
      int maxStreak = 0;
      int tempStreak = 0;
      
      bool isFirst = true;

      for (final t in tasks) {
        final isCompleted = t['isCompleted'] as bool;
        if (isFirst) {
          isFirst = false;
          if (isCompleted) currentStreak++;
        } else {
          if (isCompleted) {
            currentStreak++;
          } else {
            break;
          }
        }
      }

      for (final t in tasks.reversed) {
        if (t['isCompleted'] as bool) {
          tempStreak++;
          if (tempStreak > maxStreak) {
            maxStreak = tempStreak;
          }
        } else {
          tempStreak = 0;
        }
      }
      
      if (currentStreak > maxStreak) maxStreak = currentStreak;

      results[groupId] = {
        'title': titles[groupId],
        'currentStreak': currentStreak,
        'maxStreak': maxStreak,
      };
    }

    return results;
  }

  // Get perfect days for a range
  Future<int> getPerfectDaysForRange(DateTime start, DateTime end) async {
    final snapshot = await _tasksCollection
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();

    final tasks = snapshot.docs
        .map((doc) => Task.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();

    final tasksByDay = <String, List<Task>>{};
    for (final task in tasks) {
      if (task.type == TaskType.green || task.type == TaskType.blue) {
        final dayString = "${task.date.year}-${task.date.month.toString().padLeft(2, '0')}-${task.date.day.toString().padLeft(2, '0')}";
        tasksByDay.putIfAbsent(dayString, () => []).add(task);
      }
    }

    int perfectDaysCount = 0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final entry in tasksByDay.entries) {
      final parts = entry.key.split('-');
      final dayDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      
      if (dayDate.isAfter(today)) continue;

      final dayTasks = entry.value;
      if (dayTasks.isEmpty) continue;

      bool isPerfect = true;
      for (final task in dayTasks) {
        if (!task.isCompleted) {
          isPerfect = false;
          break;
        }
      }
      
      if (isPerfect) {
        perfectDaysCount++;
      }
    }

    return perfectDaysCount;
  }


  // --- STREAM VERSIONS FOR LIVE UPDATES ---

  Stream<Map<String, dynamic>> watchStatisticsForRange(
      DateTime start, DateTime end, {bool isYearly = false}) {
    return _tasksCollection
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .snapshots()
        .map((snapshot) {
      final tasks = snapshot.docs
          .map((doc) => Task.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      final checkableTasks =
          tasks.where((t) => t.type == TaskType.green || t.type == TaskType.blue).toList();
      final completedTasks = checkableTasks.where((t) => t.isCompleted).toList();

      final int completedTimeMinutes = tasks
          .where((t) => t.isCompleted)
          .fold(0, (acc, t) => acc + (t.timeSpentMinutes ?? 0));

      final greenTimeBreakdown = <String, int>{};
      for (final t in tasks) {
        if (t.type == TaskType.green && t.isCompleted && (t.timeSpentMinutes ?? 0) > 0) {
          final title = t.title;
          greenTimeBreakdown[title] = (greenTimeBreakdown[title] ?? 0) + t.timeSpentMinutes!;
        }
      }

      final expensesChart = <String, double>{};
      final incomeChart = <String, double>{};
      final expensesBreakdown = <String, double>{};
      final incomeBreakdown = <String, double>{};
      
      double totalExpense = 0;
      double totalIncome = 0;
      
      for (final t in tasks) {
        // Red/yellow tasks are auto-confirmed (no checkbox), so always count their money.
        // Green/blue tasks need isCompleted to count.
        final bool countMoney = t.isCompleted ||
            t.type == TaskType.red ||
            t.type == TaskType.yellow;

        if (countMoney) {
          String dateKey;
          if (isYearly) {
            dateKey = "${t.date.year}-${t.date.month.toString().padLeft(2, '0')}";
          } else {
            dateKey = "${t.date.year}-${t.date.month.toString().padLeft(2, '0')}-${t.date.day.toString().padLeft(2, '0')}";
          }

          if ((t.moneySpent ?? 0) > 0) {
            totalExpense += t.moneySpent!;
            expensesChart[dateKey] = (expensesChart[dateKey] ?? 0) + t.moneySpent!;
            final title = t.title;
            expensesBreakdown[title] = (expensesBreakdown[title] ?? 0) + t.moneySpent!;
          }
          
          if ((t.moneyEarned ?? 0) > 0) {
            totalIncome += t.moneyEarned!;
            incomeChart[dateKey] = (incomeChart[dateKey] ?? 0) + t.moneyEarned!;
            final title = t.title;
            incomeBreakdown[title] = (incomeBreakdown[title] ?? 0) + t.moneyEarned!;
          }
        }
      }

      return {
        'total': checkableTasks.length,
        'completed': completedTasks.length,
        'percentage': checkableTasks.isEmpty
            ? 0.0
            : (completedTasks.length / checkableTasks.length * 100),
        'byType': {
          'green': tasks.where((t) => t.type == TaskType.green).length,
          'blue': tasks.where((t) => t.type == TaskType.blue).length,
          'red': tasks.where((t) => t.type == TaskType.red).length,
          'yellow': tasks.where((t) => t.type == TaskType.yellow).length,
        },
        'greenCompleted': tasks.where((t) => t.type == TaskType.green && t.isCompleted).length,
        'blueCompleted': tasks.where((t) => t.type == TaskType.blue && t.isCompleted).length,
        'totalTimeMinutes': completedTimeMinutes,
        'greenTimeBreakdown': greenTimeBreakdown,
        'totalExpense': totalExpense,
        'totalIncome': totalIncome,
        'balance': totalIncome - totalExpense,
        'expensesChart': expensesChart,
        'incomeChart': incomeChart,
        'expensesBreakdown': expensesBreakdown,
        'incomeBreakdown': incomeBreakdown,
      };
    });
  }

  Stream<int> watchPerfectDaysForRange(DateTime start, DateTime end) {
    return _tasksCollection
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .snapshots()
        .map((snapshot) {
      final tasks = snapshot.docs
          .map((doc) => Task.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();

      final tasksByDay = <String, List<Task>>{};
      for (final task in tasks) {
        if (task.type == TaskType.green || task.type == TaskType.blue) {
          final dayString = "${task.date.year}-${task.date.month.toString().padLeft(2, '0')}-${task.date.day.toString().padLeft(2, '0')}";
          tasksByDay.putIfAbsent(dayString, () => []).add(task);
        }
      }

      int perfectDaysCount = 0;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      for (final entry in tasksByDay.entries) {
        final parts = entry.key.split('-');
        final dayDate = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        
        if (dayDate.isAfter(today)) continue;

        final dayTasks = entry.value;
        if (dayTasks.isEmpty) continue;

        bool isPerfect = true;
        for (final task in dayTasks) {
          if (!task.isCompleted) {
            isPerfect = false;
            break;
          }
        }
        
        if (isPerfect) {
          perfectDaysCount++;
        }
      }

      return perfectDaysCount;
    });
  }

  Stream<Map<String, Map<String, dynamic>>> watchHabitStreaks() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return _tasksCollection
        .where('type', isEqualTo: TaskType.green.name)
        .snapshots()
        .map((snapshot) {
      final grouped = <String, List<Map<String, dynamic>>>{};
      final titles = <String, String>{};

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final groupId = data['groupId'] as String?;
        if (groupId == null) continue;

        final taskDate = (data['date'] as Timestamp).toDate();
        if (taskDate.isAfter(today)) continue;

        titles[groupId] = data['title'] as String? ?? 'Задача';
        
        grouped.putIfAbsent(groupId, () => []).add({
          'date': taskDate,
          'isCompleted': data['isCompleted'] as bool? ?? false,
        });
      }

      final results = <String, Map<String, dynamic>>{};

      for (final entry in grouped.entries) {
        final groupId = entry.key;
        final tasks = entry.value;
        
        tasks.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

        int currentStreak = 0;
        int maxStreak = 0;
        int tempStreak = 0;
        
        bool isFirst = true;

        for (final t in tasks) {
          final isCompleted = t['isCompleted'] as bool;
          if (isFirst) {
            isFirst = false;
            if (isCompleted) currentStreak++;
          } else {
            if (isCompleted) {
              currentStreak++;
            } else {
              break;
            }
          }
        }

        for (final t in tasks.reversed) {
          if (t['isCompleted'] as bool) {
            tempStreak++;
            if (tempStreak > maxStreak) {
              maxStreak = tempStreak;
            }
          } else {
            tempStreak = 0;
          }
        }
        
        if (currentStreak > maxStreak) maxStreak = currentStreak;

        results[groupId] = {
          'title': titles[groupId],
          'currentStreak': currentStreak,
          'maxStreak': maxStreak,
        };
      }

      return results;
    });
  }
}

