class MealItem {
  final String id;
  final DateTime timestamp;
  final String text; // AI markdown description or meal name
  final int calories;
  final int protein;
  final int fats;
  final int carbs;

  MealItem({
    required this.id,
    required this.timestamp,
    required this.text,
    required this.calories,
    required this.protein,
    required this.fats,
    required this.carbs,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'text': text,
      'calories': calories,
      'protein': protein,
      'fats': fats,
      'carbs': carbs,
    };
  }

  factory MealItem.fromMap(Map<String, dynamic> map) {
    return MealItem(
      id: map['id'] ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp']) ?? DateTime.now()
          : DateTime.now(),
      text: map['text'] ?? '',
      calories: map['calories']?.toInt() ?? 0,
      protein: map['protein']?.toInt() ?? 0,
      fats: map['fats']?.toInt() ?? 0,
      carbs: map['carbs']?.toInt() ?? 0,
    );
  }
}

class DailyMacros {
  final String dateStr; // e.g., "2024-05-18"
  final int calories;
  final int protein;
  final int fats;
  final int carbs;
  final List<MealItem> meals;

  DailyMacros({
    required this.dateStr,
    required this.calories,
    required this.protein,
    required this.fats,
    required this.carbs,
    this.meals = const [],
  });

  factory DailyMacros.empty(String dateStr) {
    return DailyMacros(
      dateStr: dateStr,
      calories: 0,
      protein: 0,
      fats: 0,
      carbs: 0,
      meals: const [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dateStr': dateStr,
      'calories': calories,
      'protein': protein,
      'fats': fats,
      'carbs': carbs,
      'meals': meals.map((m) => m.toMap()).toList(),
    };
  }

  factory DailyMacros.fromMap(Map<String, dynamic> map, String id) {
    return DailyMacros(
      dateStr: id,
      calories: map['calories']?.toInt() ?? 0,
      protein: map['protein']?.toInt() ?? 0,
      fats: map['fats']?.toInt() ?? 0,
      carbs: map['carbs']?.toInt() ?? 0,
      meals: (map['meals'] as List<dynamic>?)
              ?.map((m) => MealItem.fromMap(m as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  DailyMacros copyWith({
    String? dateStr,
    int? calories,
    int? protein,
    int? fats,
    int? carbs,
    List<MealItem>? meals,
  }) {
    return DailyMacros(
      dateStr: dateStr ?? this.dateStr,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      fats: fats ?? this.fats,
      carbs: carbs ?? this.carbs,
      meals: meals ?? this.meals,
    );
  }
}
