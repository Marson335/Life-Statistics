import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/models.dart';
import '../../../settings/data/settings_repository.dart';
import '../../data/calories_repository.dart';

final selectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

class CaloriesScreen extends ConsumerWidget {
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

                  ref.read(caloriesRepositoryProvider).updateDailyMacros(
                    date,
                    calories: cal,
                    protein: pro,
                    fats: fat,
                    carbs: carb,
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
        const SizedBox(height: 20),
      ],
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
