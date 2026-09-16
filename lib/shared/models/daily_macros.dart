class DailyMacros {
  final String dateStr; // e.g., "2024-05-18"
  final int calories;
  final int protein;
  final int fats;
  final int carbs;

  DailyMacros({
    required this.dateStr,
    required this.calories,
    required this.protein,
    required this.fats,
    required this.carbs,
  });

  factory DailyMacros.empty(String dateStr) {
    return DailyMacros(
      dateStr: dateStr,
      calories: 0,
      protein: 0,
      fats: 0,
      carbs: 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'dateStr': dateStr,
      'calories': calories,
      'protein': protein,
      'fats': fats,
      'carbs': carbs,
    };
  }

  factory DailyMacros.fromMap(Map<String, dynamic> map, String id) {
    return DailyMacros(
      dateStr: id,
      calories: map['calories']?.toInt() ?? 0,
      protein: map['protein']?.toInt() ?? 0,
      fats: map['fats']?.toInt() ?? 0,
      carbs: map['carbs']?.toInt() ?? 0,
    );
  }

  DailyMacros copyWith({
    String? dateStr,
    int? calories,
    int? protein,
    int? fats,
    int? carbs,
  }) {
    return DailyMacros(
      dateStr: dateStr ?? this.dateStr,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      fats: fats ?? this.fats,
      carbs: carbs ?? this.carbs,
    );
  }
}
