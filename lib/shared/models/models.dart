export 'user_settings.dart';
export 'daily_macros.dart';
// Task type enum
enum TaskType { green, blue, red, yellow }

// Recurrence frequency
enum RecurrenceFrequency { daily, weekly, custom }

// Task model
class Task {
  final String id;
  final String userId;
  final String title;
  final TaskType type;
  bool isCompleted;
  final DateTime date;
  final int? timeSpentMinutes;
  final double? moneySpent;
  final double? moneyEarned;
  final RecurrenceRule? recurrence;
  final DateTime createdAt;
  final String? groupId; // for green tasks versioning
  final String? reminderTime; // Format: "HH:mm"

  Task({
    required this.id,
    required this.userId,
    required this.title,
    required this.type,
    this.isCompleted = false,
    required this.date,
    this.timeSpentMinutes,
    this.moneySpent,
    this.moneyEarned,
    this.recurrence,
    required this.createdAt,
    this.groupId,
    this.reminderTime,
  });

  bool get hasCheckbox => type == TaskType.green || type == TaskType.blue;

  factory Task.fromMap(Map<String, dynamic> map, String id) {
    return Task(
      id: id,
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      type: TaskType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TaskType.blue,
      ),
      isCompleted: map['isCompleted'] ?? false,
      date: (map['date'] as dynamic).toDate(),
      timeSpentMinutes: map['timeSpentMinutes'],
      moneySpent: (map['moneySpent'] as num?)?.toDouble(),
      moneyEarned: (map['moneyEarned'] as num?)?.toDouble(),
      recurrence: map['recurrence'] != null
          ? RecurrenceRule.fromMap(map['recurrence'])
          : null,
      createdAt: (map['createdAt'] as dynamic).toDate(),
      groupId: map['groupId'],
      reminderTime: map['reminderTime'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'type': type.name,
      'isCompleted': isCompleted,
      'date': date,
      'timeSpentMinutes': timeSpentMinutes,
      'moneySpent': moneySpent,
      'moneyEarned': moneyEarned,
      'recurrence': recurrence?.toMap(),
      'createdAt': createdAt,
      'groupId': groupId,
      'reminderTime': reminderTime,
    };
  }

  Task copyWith({
    String? id,
    String? userId,
    String? title,
    TaskType? type,
    bool? isCompleted,
    DateTime? date,
    int? timeSpentMinutes,
    double? moneySpent,
    double? moneyEarned,
    RecurrenceRule? recurrence,
    DateTime? createdAt,
    String? groupId,
    String? reminderTime,
  }) {
    return Task(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      type: type ?? this.type,
      isCompleted: isCompleted ?? this.isCompleted,
      date: date ?? this.date,
      timeSpentMinutes: timeSpentMinutes ?? this.timeSpentMinutes,
      moneySpent: moneySpent ?? this.moneySpent,
      moneyEarned: moneyEarned ?? this.moneyEarned,
      recurrence: recurrence ?? this.recurrence,
      createdAt: createdAt ?? this.createdAt,
      groupId: groupId ?? this.groupId,
      reminderTime: reminderTime ?? this.reminderTime,
    );
  }
}

class RecurrenceRule {
  final RecurrenceFrequency frequency;
  final List<int>? daysOfWeek; // 1=Mon, 7=Sun
  final DateTime startDate;
  final DateTime? endDate;

  RecurrenceRule({
    required this.frequency,
    this.daysOfWeek,
    required this.startDate,
    this.endDate,
  });

  factory RecurrenceRule.fromMap(Map<String, dynamic> map) {
    return RecurrenceRule(
      frequency: RecurrenceFrequency.values.firstWhere(
        (e) => e.name == map['frequency'],
        orElse: () => RecurrenceFrequency.daily,
      ),
      daysOfWeek: (map['daysOfWeek'] as List?)?.cast<int>(),
      startDate: (map['startDate'] as dynamic).toDate(),
      endDate: map['endDate'] != null ? (map['endDate'] as dynamic).toDate() : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'frequency': frequency.name,
      'daysOfWeek': daysOfWeek,
      'startDate': startDate,
      'endDate': endDate,
    };
  }
}

class MindsetEntry {
  final String id; // date string yyyy-MM-dd
  final String userId;
  final DateTime date;
  final int energy;    // 1-5
  final int focus;     // 1-5
  final int motivation; // 1-5
  final int mood;      // 1-5

  MindsetEntry({
    required this.id,
    required this.userId,
    required this.date,
    required this.energy,
    required this.focus,
    required this.motivation,
    required this.mood,
  });

  factory MindsetEntry.fromMap(Map<String, dynamic> map, String id) {
    return MindsetEntry(
      id: id,
      userId: map['userId'] ?? '',
      date: (map['date'] as dynamic).toDate(),
      energy: map['energy'] ?? 3,
      focus: map['focus'] ?? 3,
      motivation: map['motivation'] ?? 3,
      mood: map['mood'] ?? 3,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'date': date,
      'energy': energy,
      'focus': focus,
      'motivation': motivation,
      'mood': mood,
    };
  }
}




