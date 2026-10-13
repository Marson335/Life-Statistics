import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../data/ai_nutrition_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/models.dart';
import '../../../settings/data/settings_repository.dart';
import '../../data/calories_repository.dart';

final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

class CaloriesScreen extends ConsumerWidget {
  Future<void> _takeFoodPhoto(BuildContext context, WidgetRef ref, DateTime date) async {
    final aiService = ref.read(aiNutritionServiceProvider);
    if (aiService == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введіть Gemini API Key в налаштуваннях!')),
      );
      return;
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 70,
    );
    
    if (pickedFile == null) return;
    
    if (!context.mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Аналізуємо їжу...', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );

    NutritionAnalysis? result;
    String? errorMessage;
    try {
      final settings = ref.read(settingsProvider).valueOrNull;
      final macros = ref.read(dailyMacrosProvider(date)).valueOrNull;
      
      if (settings != null && macros != null) {
        result = await aiService.analyzeFoodImage(
          File(pickedFile.path),
          settings.targetCalories,
          settings.targetProtein,
          settings.targetFats,
          settings.targetCarbs,
          macros.calories,
          macros.protein,
          macros.fats,
          macros.carbs,
        );
      }
    } catch (e) {
      errorMessage = e.toString();
    } finally {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // close dialog
      }
    }

    if (!context.mounted) return;

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Помилка: ${errorMessage ?? "Невідома помилка"}'),
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    final mealItem = MealItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      text: result.markdownResponse,
      calories: result.calories,
      protein: result.protein,
      fats: result.fats,
      carbs: result.carbs,
    );

    // Update database
    await ref.read(caloriesRepositoryProvider).updateDailyMacros(
      date,
      calories: result.calories,
      protein: result.protein,
      fats: result.fats,
      carbs: result.carbs,
      meal: mealItem,
    );
    
    // Show markdown response in a bottom sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E2C),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    result!.markdownResponse,
                    style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9C27B0),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Готово', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  const CaloriesScreen({super.key});

  void _showAddMacrosSheet(BuildContext context, WidgetRef ref, DateTime date) {
    final caloriesCtrl = TextEditingController();
    final proteinCtrl = TextEditingController();
    final fatsCtrl = TextEditingController();
    final carbsCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Додати прийом', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _buildInput('Калорії', caloriesCtrl)),
                const SizedBox(width: 16),
                Expanded(child: _buildInput('Білки (г)', proteinCtrl)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildInput('Жири (г)', fatsCtrl)),
                const SizedBox(width: 16),
                Expanded(child: _buildInput('Вуглеводи (г)', carbsCtrl)),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final cal = int.tryParse(caloriesCtrl.text) ?? 0;
                  final pro = int.tryParse(proteinCtrl.text) ?? 0;
                  final fat = int.tryParse(fatsCtrl.text) ?? 0;
                  final carb = int.tryParse(carbsCtrl.text) ?? 0;

                  final mealItem = MealItem(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    timestamp: DateTime.now(),
                    text: 'Ручний запис прийому їжі: $cal ккал (Б: $proг, Ж: $fatг, В: $carbг)',
                    calories: cal,
                    protein: pro,
                    fats: fat,
                    carbs: carb,
                  );

                  ref.read(caloriesRepositoryProvider).updateDailyMacros(
                    date,
                    calories: cal,
                    protein: pro,
                    fats: fat,
                    carbs: carb,
                    meal: mealItem,
                  );
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Додати', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: const TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accent)),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(selectedDateProvider);
    final macrosAsync = ref.watch(dailyMacrosProvider(date));
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _takeFoodPhoto(context, ref, date),
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.camera_alt_rounded, color: Colors.white),
      ),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Калорії',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildDateSelector(ref, date),
            const SizedBox(height: 20),
            Expanded(
              child: macrosAsync.when(
                data: (macros) {
                  return settingsAsync.when(
                    data: (settings) => _buildDashboard(context, ref, macros, settings, date),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Помилка налаштувань', style: const TextStyle(color: Colors.red))),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Помилка: $e', style: const TextStyle(color: Colors.red))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector(WidgetRef ref, DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isToday = date.isAtSameMomentAs(today);

    String dateText = isToday
        ? 'Сьогодні'
        : "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, color: AppColors.textPrimary),
            onPressed: () {
              ref.read(selectedDateProvider.notifier).state = date.subtract(const Duration(days: 1));
            },
          ),
          Text(
            dateText,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, color: AppColors.textPrimary),
            onPressed: isToday
                ? null
                : () {
                    ref.read(selectedDateProvider.notifier).state = date.add(const Duration(days: 1));
                  },
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, WidgetRef ref, DailyMacros macros, UserSettings settings, DateTime date) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        _buildMainRing(macros.calories, settings.targetCalories),
        const SizedBox(height: 40),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildSmallRing('Білки', macros.protein, settings.targetProtein, AppColors.blueTask),
            _buildSmallRing('Жири', macros.fats, settings.targetFats, AppColors.yellowTask),
            _buildSmallRing('Вуглеводи', macros.carbs, settings.targetCarbs, AppColors.greenTask),
          ],
        ),
        const SizedBox(height: 40),
        ElevatedButton.icon(
          onPressed: () => _showAddMacrosSheet(context, ref, date),
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text('Додати прийом', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            const Icon(Icons.restaurant_rounded, color: AppColors.accent, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Прийоми їжі за день',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            if (macros.meals.isNotEmpty)
              Text(
                '${macros.meals.length} ${macros.meals.length == 1 ? "прийом" : "прийоми"}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (macros.meals.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Icon(Icons.no_meals_rounded, size: 36, color: AppColors.textSecondary.withAlpha(120)),
                const SizedBox(height: 8),
                const Text(
                  'Ще немає записів про їжу за цей день',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Сфотографуйте їжу на камеру (кнопка внизу) або додайте вручну!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          )
        else
          ...macros.meals.reversed.map((meal) => _buildMealCard(context, ref, date, meal)),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildMealCard(BuildContext context, WidgetRef ref, DateTime date, MealItem meal) {
    final timeStr = "${meal.timestamp.hour.toString().padLeft(2, '0')}:${meal.timestamp.minute.toString().padLeft(2, '0')}";
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withAlpha(15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lunch_dining_rounded, color: AppColors.accent, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Прийом їжі о $timeStr',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '🔥 ${meal.calories} ккал  |  Б: ${meal.protein}г  Ж: ${meal.fats}г  В: ${meal.carbs}г',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.redTask, size: 20),
                  tooltip: 'Видалити прийом',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (dCtx) => AlertDialog(
                        backgroundColor: AppColors.surface,
                        title: const Text('Видалити прийом їжі?', style: TextStyle(color: AppColors.textPrimary)),
                        content: const Text(
                          'Калорії та макронутрієнти цього прийому будуть відраховані від вашого дня.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dCtx),
                            child: const Text('Скасувати', style: TextStyle(color: AppColors.textSecondary)),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.redTask),
                            onPressed: () {
                              ref.read(caloriesRepositoryProvider).deleteMeal(date, meal);
                              Navigator.pop(dCtx);
                            },
                            child: const Text('Видалити', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 12),
            SelectableText(
              meal.text.trim(),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainRing(int current, int target) {
    double progress = target > 0 ? current / target : 0.0;
    if (progress > 1.0) progress = 1.0;

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 200,
            height: 200,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progress),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return CircularProgressIndicator(
                  value: value,
                  strokeWidth: 16,
                  backgroundColor: AppColors.surface,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                  strokeCap: StrokeCap.round,
                );
              },
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Калорії', style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
              const SizedBox(height: 4),
              Text(
                '$current',
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 40, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text('із $target', style: const TextStyle(color: AppColors.textSecondary, fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallRing(String label, int current, int target, Color color) {
    double progress = target > 0 ? current / target : 0.0;
    if (progress > 1.0) progress = 1.0;

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: progress),
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return CircularProgressIndicator(
                    value: value,
                    strokeWidth: 8,
                    backgroundColor: AppColors.surface,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    strokeCap: StrokeCap.round,
                  );
                },
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$current',
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        Text('із $target', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
      ],
    );
  }
}
