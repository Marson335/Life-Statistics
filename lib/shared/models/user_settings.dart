class UserSettings {
  final int age;
  final double weight;
  final double height;
  final String gender; // 'male' or 'female'
  final String goal; // 'lose', 'maintain', 'gain'
  
  // Target macros
  final int targetCalories;
  final int targetProtein;
  final int targetFats;
  final int targetCarbs;

  final List<String> expenseTags;
  final List<String> incomeTags;
  final String? geminiApiKey;

  UserSettings({
    required this.age,
    required this.weight,
    required this.height,
    required this.gender,
    required this.goal,
    required this.targetCalories,
    required this.targetProtein,
    required this.targetFats,
    required this.targetCarbs,
    required this.expenseTags,
    required this.incomeTags,
    this.geminiApiKey,
  });

  factory UserSettings.defaultSettings() {
    return UserSettings(
      age: 25,
      weight: 70,
      height: 175,
      gender: 'male',
      goal: 'maintain',
      targetCalories: 2500,
      targetProtein: 125,
      targetFats: 83,
      targetCarbs: 312,
      expenseTags: ['Їжа', 'Транспорт', 'Розваги', 'Житло', 'Інше'],
      incomeTags: ['Зарплата', 'Подарунок', 'Кешбек', 'Інше'],
      geminiApiKey: null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'age': age,
      'weight': weight,
      'height': height,
      'gender': gender,
      'goal': goal,
      'targetCalories': targetCalories,
      'targetProtein': targetProtein,
      'targetFats': targetFats,
      'targetCarbs': targetCarbs,
      'expenseTags': expenseTags,
      'incomeTags': incomeTags,
      'geminiApiKey': geminiApiKey,
    };
  }

  factory UserSettings.fromMap(Map<String, dynamic> map) {
    return UserSettings(
      age: map['age']?.toInt() ?? 25,
      weight: map['weight']?.toDouble() ?? 70.0,
      height: map['height']?.toDouble() ?? 175.0,
      gender: map['gender'] ?? 'male',
      goal: map['goal'] ?? 'maintain',
      targetCalories: map['targetCalories']?.toInt() ?? 2500,
      targetProtein: map['targetProtein']?.toInt() ?? 125,
      targetFats: map['targetFats']?.toInt() ?? 83,
      targetCarbs: map['targetCarbs']?.toInt() ?? 312,
      expenseTags: (map['expenseTags'] as List?)?.cast<String>() ?? ['Їжа', 'Транспорт', 'Розваги', 'Житло', 'Інше'],
      incomeTags: (map['incomeTags'] as List?)?.cast<String>() ?? ['Зарплата', 'Подарунок', 'Кешбек', 'Інше'],
      geminiApiKey: map['geminiApiKey'] as String?,
    );
  }

  UserSettings copyWith({
    int? age,
    double? weight,
    double? height,
    String? gender,
    String? goal,
    int? targetCalories,
    int? targetProtein,
    int? targetFats,
    int? targetCarbs,
    List<String>? expenseTags,
    List<String>? incomeTags,
    String? geminiApiKey,
  }) {
    return UserSettings(
      age: age ?? this.age,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      gender: gender ?? this.gender,
      goal: goal ?? this.goal,
      targetCalories: targetCalories ?? this.targetCalories,
      targetProtein: targetProtein ?? this.targetProtein,
      targetFats: targetFats ?? this.targetFats,
      targetCarbs: targetCarbs ?? this.targetCarbs,
      expenseTags: expenseTags ?? this.expenseTags,
      incomeTags: incomeTags ?? this.incomeTags,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
    );
  }
}
