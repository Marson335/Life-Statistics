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

  // Crypto Settings
  final String? groqApiKey;
  final String? binanceApiKey;
  final String? binanceApiSecret;
  final String? solanaAddress;
  final String? evmAddress;
  final String? btcAddress;

  // Crypto Alerts & Notifications
  final bool cryptoAlertsEnabled;
  final List<String> cryptoAlertCoins;
  final bool cryptoAlertOnTp;
  final bool cryptoAlertOnTrailing;
  final bool cryptoAlertOnPreStop;
  final bool cryptoAlertOnHardStop;
  final bool cryptoAlertOnPeak;
  final bool cryptoAlertOnDcaBuy;

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
    this.groqApiKey,
    this.binanceApiKey,
    this.binanceApiSecret,
    this.solanaAddress,
    this.evmAddress,
    this.btcAddress,
    this.cryptoAlertsEnabled = true,
    this.cryptoAlertCoins = const ['BTC', 'ETH', 'SOL'],
    this.cryptoAlertOnTp = true,
    this.cryptoAlertOnTrailing = true,
    this.cryptoAlertOnPreStop = true,
    this.cryptoAlertOnHardStop = true,
    this.cryptoAlertOnPeak = true,
    this.cryptoAlertOnDcaBuy = true,
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
      groqApiKey: null,
      binanceApiKey: null,
      binanceApiSecret: null,
      solanaAddress: null,
      evmAddress: null,
      btcAddress: null,
      cryptoAlertsEnabled: true,
      cryptoAlertCoins: const ['BTC', 'ETH', 'SOL'],
      cryptoAlertOnTp: true,
      cryptoAlertOnTrailing: true,
      cryptoAlertOnPreStop: true,
      cryptoAlertOnHardStop: true,
      cryptoAlertOnPeak: true,
      cryptoAlertOnDcaBuy: true,
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
      'groqApiKey': groqApiKey,
      'binanceApiKey': binanceApiKey,
      'binanceApiSecret': binanceApiSecret,
      'solanaAddress': (solanaAddress != null && solanaAddress!.trim().isNotEmpty) ? solanaAddress!.trim() : null,
      'evmAddress': (evmAddress != null && evmAddress!.trim().isNotEmpty) ? evmAddress!.trim() : null,
      'btcAddress': (btcAddress != null && btcAddress!.trim().isNotEmpty) ? btcAddress!.trim() : null,
      'cryptoAlertsEnabled': cryptoAlertsEnabled,
      'cryptoAlertCoins': cryptoAlertCoins,
      'cryptoAlertOnTp': cryptoAlertOnTp,
      'cryptoAlertOnTrailing': cryptoAlertOnTrailing,
      'cryptoAlertOnPreStop': cryptoAlertOnPreStop,
      'cryptoAlertOnHardStop': cryptoAlertOnHardStop,
      'cryptoAlertOnPeak': cryptoAlertOnPeak,
      'cryptoAlertOnDcaBuy': cryptoAlertOnDcaBuy,
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
      groqApiKey: map['groqApiKey'] as String?,
      binanceApiKey: map['binanceApiKey'] as String?,
      binanceApiSecret: map['binanceApiSecret'] as String?,
      solanaAddress: map['solanaAddress'] as String?,
      evmAddress: map['evmAddress'] as String?,
      btcAddress: map['btcAddress'] as String?,
      cryptoAlertsEnabled: map['cryptoAlertsEnabled'] as bool? ?? true,
      cryptoAlertCoins: (map['cryptoAlertCoins'] as List?)?.cast<String>() ?? const ['BTC', 'ETH', 'SOL'],
      cryptoAlertOnTp: map['cryptoAlertOnTp'] as bool? ?? true,
      cryptoAlertOnTrailing: map['cryptoAlertOnTrailing'] as bool? ?? true,
      cryptoAlertOnPreStop: map['cryptoAlertOnPreStop'] as bool? ?? true,
      cryptoAlertOnHardStop: map['cryptoAlertOnHardStop'] as bool? ?? true,
      cryptoAlertOnPeak: map['cryptoAlertOnPeak'] as bool? ?? true,
      cryptoAlertOnDcaBuy: map['cryptoAlertOnDcaBuy'] as bool? ?? true,
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
    String? groqApiKey,
    String? binanceApiKey,
    String? binanceApiSecret,
    String? solanaAddress,
    String? evmAddress,
    String? btcAddress,
    bool? cryptoAlertsEnabled,
    List<String>? cryptoAlertCoins,
    bool? cryptoAlertOnTp,
    bool? cryptoAlertOnTrailing,
    bool? cryptoAlertOnPreStop,
    bool? cryptoAlertOnHardStop,
    bool? cryptoAlertOnPeak,
    bool? cryptoAlertOnDcaBuy,
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
      groqApiKey: groqApiKey ?? this.groqApiKey,
      binanceApiKey: binanceApiKey ?? this.binanceApiKey,
      binanceApiSecret: binanceApiSecret ?? this.binanceApiSecret,
      solanaAddress: solanaAddress != null
          ? (solanaAddress.trim().isEmpty ? null : solanaAddress.trim())
          : this.solanaAddress,
      evmAddress: evmAddress != null
          ? (evmAddress.trim().isEmpty ? null : evmAddress.trim())
          : this.evmAddress,
      btcAddress: btcAddress != null
          ? (btcAddress.trim().isEmpty ? null : btcAddress.trim())
          : this.btcAddress,
      cryptoAlertsEnabled: cryptoAlertsEnabled ?? this.cryptoAlertsEnabled,
      cryptoAlertCoins: cryptoAlertCoins ?? this.cryptoAlertCoins,
      cryptoAlertOnTp: cryptoAlertOnTp ?? this.cryptoAlertOnTp,
      cryptoAlertOnTrailing: cryptoAlertOnTrailing ?? this.cryptoAlertOnTrailing,
      cryptoAlertOnPreStop: cryptoAlertOnPreStop ?? this.cryptoAlertOnPreStop,
      cryptoAlertOnHardStop: cryptoAlertOnHardStop ?? this.cryptoAlertOnHardStop,
      cryptoAlertOnPeak: cryptoAlertOnPeak ?? this.cryptoAlertOnPeak,
      cryptoAlertOnDcaBuy: cryptoAlertOnDcaBuy ?? this.cryptoAlertOnDcaBuy,
    );
  }
}
