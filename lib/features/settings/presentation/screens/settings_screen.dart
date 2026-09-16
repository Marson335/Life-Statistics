import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/models.dart';
import '../../data/settings_repository.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _isCaloriesExpanded = true;
  
  // Controllers
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  
  String _gender = 'male';
  String _goal = 'maintain';

  @override
  void dispose() {
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _calculateAndSave(UserSettings current) {
    final age = int.tryParse(_ageController.text) ?? current.age;
    final weight = double.tryParse(_weightController.text) ?? current.weight;
    final height = double.tryParse(_heightController.text) ?? current.height;

    // Mifflin-St Jeor Equation
    double bmr = (10 * weight) + (6.25 * height) - (5 * age);
    bmr += (_gender == 'male') ? 5 : -161;
    
    // TDEE (Moderate activity assumed)
    double tdee = bmr * 1.55;

    // Goal adjustment
    if (_goal == 'lose') tdee -= 500;
    if (_goal == 'gain') tdee += 500;

    int targetCalories = tdee.round();
    
    // Macros
    int targetProtein = (weight * 2).round(); // 2g per kg
    int targetFats = weight.round(); // 1g per kg
    
    int proteinKcal = targetProtein * 4;
    int fatsKcal = targetFats * 9;
    
    int carbsKcal = targetCalories - proteinKcal - fatsKcal;
    int targetCarbs = (carbsKcal / 4).round();
    if (targetCarbs < 0) targetCarbs = 0;

    final updated = current.copyWith(
      age: age,
      weight: weight,
      height: height,
      gender: _gender,
      goal: _goal,
      targetCalories: targetCalories,
      targetProtein: targetProtein,
      targetFats: targetFats,
      targetCarbs: targetCarbs,
    );

    ref.read(settingsRepositoryProvider).updateSettings(updated);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Дані оновлено!'), backgroundColor: AppColors.greenTask),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Налаштування',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: settingsAsync.when(
        data: (settings) {
          // Initialize controllers if empty
          if (_ageController.text.isEmpty) {
            _ageController.text = settings.age.toString();
            _weightController.text = settings.weight.toString();
            _heightController.text = settings.height.toString();
            _gender = settings.gender;
            _goal = settings.goal;
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildCaloriesSection(settings),
              // More settings can be added here in the future
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Помилка: $e', style: const TextStyle(color: Colors.red))),
      ),
    );
  }

  Widget _buildCaloriesSection(UserSettings settings) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          ListTile(
            title: const Text('Калькулятор калорій', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
            leading: const Icon(Icons.local_fire_department_rounded, color: AppColors.accent),
            trailing: Icon(_isCaloriesExpanded ? Icons.expand_less : Icons.expand_more, color: AppColors.textSecondary),
            onTap: () {
              setState(() => _isCaloriesExpanded = !_isCaloriesExpanded);
            },
          ),
          if (_isCaloriesExpanded)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildTextField('Вік (роки)', _ageController, TextInputType.number)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTextField('Вага (кг)', _weightController, const TextInputType.numberWithOptions(decimal: true))),
                      const SizedBox(width: 16),
                      Expanded(child: _buildTextField('Зріст (см)', _heightController, const TextInputType.numberWithOptions(decimal: true))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Стать', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('Чол', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                          value: 'male',
                          groupValue: _gender,
                          activeColor: AppColors.accent,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (v) => setState(() => _gender = v!),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('Жін', style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                          value: 'female',
                          groupValue: _gender,
                          activeColor: AppColors.accent,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (v) => setState(() => _gender = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text('Мета', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  DropdownButtonFormField<String>(
                    value: _goal,
                    dropdownColor: AppColors.surface,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accent)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'lose', child: Text('Схуднення')),
                      DropdownMenuItem(value: 'maintain', child: Text('Підтримка')),
                      DropdownMenuItem(value: 'gain', child: Text('Набір маси')),
                    ],
                    onChanged: (v) => setState(() => _goal = v!),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _calculateAndSave(settings),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Розрахувати та Зберегти', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 16),
                  const Text('Твоя щоденна норма:', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildMacroRow('Калорії', '${settings.targetCalories} ккал', AppColors.accent),
                  _buildMacroRow('Білки', '${settings.targetProtein} г', AppColors.blueTask),
                  _buildMacroRow('Жири', '${settings.targetFats} г', AppColors.yellowTask),
                  _buildMacroRow('Вуглеводи', '${settings.targetCarbs} г', AppColors.greenTask),
                ],
              ),
            )
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, TextInputType type) {
    return TextField(
      controller: controller,
      keyboardType: type,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accent)),
      ),
    );
  }

  Widget _buildMacroRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: AppColors.textSecondary)),
            ],
          ),
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
