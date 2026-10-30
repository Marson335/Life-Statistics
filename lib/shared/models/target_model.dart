import 'dart:math' as math;

DateTime _parseTargetDateTime(dynamic val, [DateTime? fallback]) {
  if (val == null) return fallback ?? DateTime.now();
  if (val is DateTime) return val;
  try {
    final toDateMethod = (val as dynamic).toDate;
    if (toDateMethod != null) {
      return (val as dynamic).toDate();
    }
  } catch (_) {}
  if (val is String) {
    final parsed = DateTime.tryParse(val);
    if (parsed != null) return parsed;
  }
  if (val is int) {
    return DateTime.fromMillisecondsSinceEpoch(val);
  }
  return fallback ?? DateTime.now();
}

/// Етап (віха) досягнення глобального Таргета.
class TargetStage {
  final String id;
  final int requiredLevel;
  final String title;
  final String actionsDescription;
  final bool isCompleted;
  final DateTime? completedAt;

  const TargetStage({
    required this.id,
    required this.requiredLevel,
    required this.title,
    this.actionsDescription = '',
    this.isCompleted = false,
    this.completedAt,
  });

  factory TargetStage.fromMap(Map<String, dynamic> map) {
    return TargetStage(
      id: map['id']?.toString() ?? '',
      requiredLevel: (map['requiredLevel'] as num?)?.toInt() ?? 1,
      title: map['title']?.toString() ?? '',
      actionsDescription: map['actionsDescription']?.toString() ?? '',
      isCompleted: map['isCompleted'] as bool? ?? false,
      completedAt: map['completedAt'] != null
          ? _parseTargetDateTime(map['completedAt'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'requiredLevel': requiredLevel,
      'title': title,
      'actionsDescription': actionsDescription,
      'isCompleted': isCompleted,
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  TargetStage copyWith({
    String? id,
    int? requiredLevel,
    String? title,
    String? actionsDescription,
    bool? isCompleted,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return TargetStage(
      id: id ?? this.id,
      requiredLevel: requiredLevel ?? this.requiredLevel,
      title: title ?? this.title,
      actionsDescription: actionsDescription ?? this.actionsDescription,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }
}

/// Запис у журналі нарахувань і штрафів Таргета.
class TargetHistoryEntry {
  final String id;
  final DateTime date;
  final String taskTitle;
  final String? taskId;
  final int basePoints;
  final int deltaPoints;
  final double multiplier;
  final int streakCount;
  final bool isPenalty;

  const TargetHistoryEntry({
    required this.id,
    required this.date,
    required this.taskTitle,
    this.taskId,
    required this.basePoints,
    required this.deltaPoints,
    this.multiplier = 1.0,
    this.streakCount = 1,
    this.isPenalty = false,
  });

  factory TargetHistoryEntry.fromMap(Map<String, dynamic> map) {
    return TargetHistoryEntry(
      id: map['id']?.toString() ?? '',
      date: _parseTargetDateTime(map['date']),
      taskTitle: map['taskTitle']?.toString() ?? '',
      taskId: map['taskId']?.toString(),
      basePoints: (map['basePoints'] as num?)?.toInt() ?? 0,
      deltaPoints: (map['deltaPoints'] as num?)?.toInt() ?? 0,
      multiplier: (map['multiplier'] as num?)?.toDouble() ?? 1.0,
      streakCount: (map['streakCount'] as num?)?.toInt() ?? 1,
      isPenalty: map['isPenalty'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'taskTitle': taskTitle,
      'taskId': taskId,
      'basePoints': basePoints,
      'deltaPoints': deltaPoints,
      'multiplier': multiplier,
      'streakCount': streakCount,
      'isPenalty': isPenalty,
    };
  }
}

/// Глобальна ціль (Таргет) з рівнями, етапами та прогрес-баром.
class TargetGoal {
  final String id;
  final String userId;
  final String title;
  final String description;
  final String completionCriteria;
  final int iconKey; // Індекс іконки зі стандартного набору
  final int colorValue;
  final int pointsPerLevel;
  final int targetLevel;
  final int currentPoints;
  final List<TargetStage> stages;
  final List<TargetHistoryEntry> history;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime createdAt;

  const TargetGoal({
    required this.id,
    required this.userId,
    required this.title,
    this.description = '',
    this.completionCriteria = '',
    this.iconKey = 0,
    this.colorValue = 0xFFD4FF00,
    this.pointsPerLevel = 500,
    this.targetLevel = 10,
    this.currentPoints = 0,
    this.stages = const [],
    this.history = const [],
    this.isCompleted = false,
    this.completedAt,
    required this.createdAt,
  });

  /// Загальна кількість очок для повного закриття всіх рівнів Таргета.
  int get totalTargetPoints =>
      math.max(1, pointsPerLevel) * math.max(1, targetLevel);

  /// Поточний рівень (від 1 до targetLevel).
  int get currentLevel {
    final ppl = math.max(1, pointsPerLevel);
    final maxLvl = math.max(1, targetLevel);
    if (currentPoints <= 0) return 1;
    final lvl = (currentPoints ~/ ppl) + 1;
    return lvl.clamp(1, maxLvl);
  }

  /// Скільки повних рівнів уже закрито (від 0 до targetLevel).
  int get completedLevelsCount {
    final ppl = math.max(1, pointsPerLevel);
    final maxLvl = math.max(1, targetLevel);
    return (currentPoints ~/ ppl).clamp(0, maxLvl);
  }

  /// Чи набрано 100% очок для фінального рівня закриття.
  bool get isMaxPointsReached => currentPoints >= totalTargetPoints;

  /// Очки всередині поточного рівня (від 0 до pointsPerLevel).
  int get pointsInCurrentLevel {
    final ppl = math.max(1, pointsPerLevel);
    if (isMaxPointsReached) return ppl;
    return (currentPoints % ppl).clamp(0, ppl);
  }

  /// Прогрес поточного рівня (0.0 .. 1.0).
  double get currentLevelProgress {
    final ppl = math.max(1, pointsPerLevel);
    if (isMaxPointsReached) return 1.0;
    return (pointsInCurrentLevel / ppl).clamp(0.0, 1.0);
  }

  /// Загальний прогрес усього Таргета (0.0 .. 1.0).
  double get totalProgress {
    return (currentPoints / totalTargetPoints).clamp(0.0, 1.0);
  }

  /// Скільки очок залишилось до повного закриття Таргета.
  int get remainingPointsToClose =>
      math.max(0, totalTargetPoints - currentPoints);

  /// Чи розблокований конкретний етап за поточним рівнем/очками.
  bool isStageUnlocked(TargetStage stage) {
    if (isCompleted) return true;
    if (stage.requiredLevel >= targetLevel) {
      return currentLevel >= targetLevel;
    }
    return currentLevel >= stage.requiredLevel;
  }

  /// Чи всі прописані етапи виконані.
  bool get areAllStagesCompleted {
    if (stages.isEmpty) return true;
    return stages.every((s) => s.isCompleted);
  }

  /// Чи готові всі умови для фінального закриття Таргета.
  bool get isReadyToComplete => isMaxPointsReached && areAllStagesCompleted;

  /// Поточний активний етап (перший невиконаний).
  TargetStage? get activeStage {
    final sorted = List<TargetStage>.from(stages)
      ..sort((a, b) => a.requiredLevel.compareTo(b.requiredLevel));
    for (final s in sorted) {
      if (!s.isCompleted) return s;
    }
    return sorted.isNotEmpty ? sorted.last : null;
  }

  /// Розрахунок множника за стрік або анти-стрік: +10% за день (від x1.0 до x3.0).
  static double calculateStreakMultiplier(int streakDays) {
    if (streakDays <= 1) return 1.0;
    final mult = 1.0 + (streakDays - 1) * 0.10;
    return mult.clamp(1.0, 3.0);
  }

  /// Розрахунок очок із урахуванням стріку.
  static int calculateAwardedPoints(int basePoints, int streakDays) {
    final mult = calculateStreakMultiplier(streakDays);
    return (basePoints * mult).round();
  }

  factory TargetGoal.fromMap(Map<String, dynamic> map, String id) {
    final stagesRaw = map['stages'] as List<dynamic>? ?? [];
    final historyRaw = map['history'] as List<dynamic>? ?? [];

    return TargetGoal(
      id: id,
      userId: map['userId']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      completionCriteria: map['completionCriteria']?.toString() ?? '',
      iconKey: (map['iconKey'] as num?)?.toInt() ?? 0,
      colorValue: (map['colorValue'] as num?)?.toInt() ?? 0xFFD4FF00,
      pointsPerLevel:
          math.max(1, (map['pointsPerLevel'] as num?)?.toInt() ?? 500),
      targetLevel: math.max(1, (map['targetLevel'] as num?)?.toInt() ?? 10),
      currentPoints: math.max(0, (map['currentPoints'] as num?)?.toInt() ?? 0),
      stages: stagesRaw
          .whereType<Map>()
          .map((e) => TargetStage.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      history: historyRaw
          .whereType<Map>()
          .map((e) => TargetHistoryEntry.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
      isCompleted: map['isCompleted'] as bool? ?? false,
      completedAt: map['completedAt'] != null
          ? _parseTargetDateTime(map['completedAt'])
          : null,
      createdAt: _parseTargetDateTime(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'title': title,
      'description': description,
      'completionCriteria': completionCriteria,
      'iconKey': iconKey,
      'colorValue': colorValue,
      'pointsPerLevel': pointsPerLevel,
      'targetLevel': targetLevel,
      'currentPoints': currentPoints,
      'stages': stages.map((s) => s.toMap()).toList(),
      'history': history.map((h) => h.toMap()).toList(),
      'isCompleted': isCompleted,
      'completedAt': completedAt?.toIso8601String(),
      'createdAt': createdAt,
    };
  }

  TargetGoal copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    String? completionCriteria,
    int? iconKey,
    int? colorValue,
    int? pointsPerLevel,
    int? targetLevel,
    int? currentPoints,
    List<TargetStage>? stages,
    List<TargetHistoryEntry>? history,
    bool? isCompleted,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    DateTime? createdAt,
  }) {
    return TargetGoal(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      completionCriteria: completionCriteria ?? this.completionCriteria,
      iconKey: iconKey ?? this.iconKey,
      colorValue: colorValue ?? this.colorValue,
      pointsPerLevel: pointsPerLevel ?? this.pointsPerLevel,
      targetLevel: targetLevel ?? this.targetLevel,
      currentPoints: currentPoints ?? this.currentPoints,
      stages: stages ?? this.stages,
      history: history ?? this.history,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
