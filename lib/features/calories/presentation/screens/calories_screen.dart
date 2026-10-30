import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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

class CaloriesScreen extends ConsumerStatefulWidget {
  const CaloriesScreen({super.key});

  @override
  ConsumerState<CaloriesScreen> createState() => _CaloriesScreenState();
}

class _CaloriesScreenState extends ConsumerState<CaloriesScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      ref.read(selectedDateProvider.notifier).state = today;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final currentSelected = ref.read(selectedDateProvider);
      if (currentSelected.isBefore(today)) {
        ref.read(selectedDateProvider.notifier).state = today;
      }
    }
  }

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
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Готово', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

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
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Додати', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
  Widget build(BuildContext context) {
    final date = ref.watch(selectedDateProvider);
    final macrosAsync = ref.watch(dailyMacrosProvider(date));
    final settingsAsync = ref.watch(settingsProvider);

    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    final dateStr = isToday
        ? 'СЬОГОДНІ'
        : "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}";

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NUTRITION FUEL // $dateStr',
              style: GoogleFonts.chakraPetch(
                color: AppColors.accent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
            Text(
              'ХАРЧУВАННЯ & FUEL',
              style: GoogleFonts.chakraPetch(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.textSecondary, size: 22),
            tooltip: 'Налаштування',
            onPressed: () => context.go('/settings'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildDateSelector(ref, date),
            const SizedBox(height: 12),
            Expanded(
              child: macrosAsync.when(
                data: (macros) {
                  return settingsAsync.when(
                    data: (settings) => _buildDashboard(context, ref, macros, settings, date),
                    loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
                    error: (e, _) => Center(child: Text('Помилка налаштувань', style: GoogleFonts.chakraPetch(color: Colors.red))),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
                error: (e, _) => Center(child: Text('Помилка: $e', style: GoogleFonts.chakraPetch(color: Colors.red))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector(WidgetRef ref, DateTime date) {
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;

    String dateText = isToday
        ? 'СЬОГОДНІ'
        : "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}";

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.accent.withAlpha(160), width: 1.5),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded, color: AppColors.accent, size: 24),
              onPressed: () {
                final prev = DateTime(date.year, date.month, date.day - 1);
                ref.read(selectedDateProvider.notifier).state = prev;
              },
            ),
            Expanded(
              child: Text(
                isToday ? '< $dateText // TODAY >' : '< $dateText >',
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: GoogleFonts.chakraPetch(
                  color: AppColors.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded, color: AppColors.accent, size: 24),
              onPressed: isToday
                  ? null
                  : () {
                      final next = DateTime(date.year, date.month, date.day + 1);
                      ref.read(selectedDateProvider.notifier).state = next;
                    },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, WidgetRef ref, DailyMacros macros, UserSettings settings, DateTime date) {
    final int currentKcal = macros.calories;
    final int targetKcal = settings.targetCalories > 0 ? settings.targetCalories : 2400;
    final int remainingKcal = targetKcal - currentKcal;
    final double kcalRatio = (currentKcal / targetKcal).clamp(0.0, 1.0);
    final int diffPercent = (((currentKcal - targetKcal) / targetKcal) * 100).round();
    final String deficitText = diffPercent <= 0
        ? 'ДЕФІЦИТ: $diffPercent% // ЧИСТИЙ РІСТ ТІЛА'
        : 'ПРОФІЦИТ: +$diffPercent% // НАБІР МАСИ';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        // Card 1: Calorie Big Gauge Card (Style 3)
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.accent.withAlpha(180), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(90),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 5, color: AppColors.accent),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ДЕННА ЕНЕРГІЯ // ККАЛ',
                            style: GoogleFonts.chakraPetch(
                              color: AppColors.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              // Circular Gauge
                              SizedBox(
                                width: 90,
                                height: 90,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    CircularProgressIndicator(
                                      value: kcalRatio,
                                      strokeWidth: 9,
                                      backgroundColor: const Color(0xFF20242E),
                                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                                    ),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '$currentKcal',
                                          style: GoogleFonts.chakraPetch(
                                            color: Colors.white,
                                            fontSize: 17,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        Text(
                                          'ККАЛ',
                                          style: GoogleFonts.chakraPetch(
                                            color: AppColors.accent,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.6,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$currentKcal / $targetKcal ККАЛ',
                                      style: GoogleFonts.chakraPetch(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      remainingKcal >= 0
                                          ? 'ЗАЛИШИЛОСЬ: $remainingKcal ККАЛ'
                                          : 'ПЕРЕВИЩЕНО НА: ${remainingKcal.abs()} ККАЛ',
                                      style: GoogleFonts.chakraPetch(
                                        color: AppColors.accent,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      deficitText,
                                      style: GoogleFonts.chakraPetch(
                                        color: const Color(0xFFA0AAB9),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'РЕЖИМ: [ATHLETE NUTRITION]',
                                      style: GoogleFonts.chakraPetch(
                                        color: Colors.white70,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Card 2: Macro Blocks (Style 3)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'РОЗПОДІЛ МАКРОНУТРІЄНТІВ (Б / Ж / В)',
                style: GoogleFonts.chakraPetch(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 16),
              _buildMacroProgressRow(
                'БІЛОК (PROTEIN)',
                macros.protein,
                settings.targetProtein > 0 ? settings.targetProtein : 160,
                AppColors.accent,
              ),
              const SizedBox(height: 14),
              _buildMacroProgressRow(
                'ЖИРИ (FATS)',
                macros.fats,
                settings.targetFats > 0 ? settings.targetFats : 70,
                const Color(0xFFC8CDDC),
              ),
              const SizedBox(height: 14),
              _buildMacroProgressRow(
                'ВУГЛЕВОДИ (CARBS)',
                macros.carbs,
                settings.targetCarbs > 0 ? settings.targetCarbs : 280,
                Colors.white,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Buttons: + ДОДАТИ ПРИЙОМ & AI СКАНЕР ЇЖІ (side-by-side Style 3)
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => _showAddMacrosSheet(context, ref, date),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 4,
                ),
                child: Text(
                  '+ ДОДАТИ ПРИЙОМ',
                  style: GoogleFonts.chakraPetch(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _takeFoodPhoto(context, ref, date),
                icon: const Icon(Icons.camera_alt_rounded, color: AppColors.accent, size: 18),
                label: Text(
                  'AI СКАНЕР ЇЖІ',
                  style: GoogleFonts.chakraPetch(
                    color: AppColors.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: const BorderSide(color: AppColors.accent, width: 1.5),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Meal Logs Section Header
        Text(
          '[ ІСТОРІЯ ПРИЙОМІВ ХАРЧУВАННЯ ]',
          style: GoogleFonts.chakraPetch(
            color: AppColors.accent,
            fontSize: 13,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),

        if (macros.meals.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: Column(
              children: [
                Icon(Icons.no_meals_rounded, size: 36, color: AppColors.textSecondary.withAlpha(120)),
                const SizedBox(height: 8),
                Text(
                  'Ще немає записів про їжу за цей день',
                  style: GoogleFonts.chakraPetch(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Натисніть "+ ДОДАТИ ПРИЙОМ" або "AI СКАНЕР ЇЖІ" вище!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.chakraPetch(color: AppColors.textSecondary, fontSize: 11),
                ),
              ],
            ),
          )
        else
          ...macros.meals.reversed.map((meal) => _buildMealCard(context, ref, date, meal)),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildMacroProgressRow(String title, int current, int target, Color barColor) {
    final double ratio = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                title,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: GoogleFonts.chakraPetch(
                  color: const Color(0xFFDCDEE7),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$current / $target г',
              style: GoogleFonts.chakraPetch(
                color: barColor,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 8,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF0C0D10),
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: ratio,
            child: Container(
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMealCard(BuildContext context, WidgetRef ref, DateTime date, MealItem meal) {
    final timeStr = "${meal.timestamp.hour.toString().padLeft(2, '0')}:${meal.timestamp.minute.toString().padLeft(2, '0')}";
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Stack(
          children: [
            const Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: ColoredBox(color: AppColors.accent),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'ПРИЙОМ ЇЖІ  •  $timeStr',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: GoogleFonts.chakraPetch(
                            color: AppColors.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${meal.calories} ккал',
                            style: GoogleFonts.chakraPetch(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.redTask, size: 18),
                            tooltip: 'Видалити прийом',
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (dCtx) => AlertDialog(
                                  backgroundColor: AppColors.surface,
                                  title: Text('Видалити прийом їжі?', style: GoogleFonts.chakraPetch(color: AppColors.textPrimary)),
                                  content: Text(
                                    'Калорії та макронутрієнти цього прийому будуть відраховані від вашого дня.',
                                    style: GoogleFonts.chakraPetch(color: AppColors.textSecondary),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(dCtx),
                                      child: Text('Скасувати', style: GoogleFonts.chakraPetch(color: AppColors.textSecondary)),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.redTask),
                                      onPressed: () {
                                        ref.read(caloriesRepositoryProvider).deleteMeal(date, meal);
                                        Navigator.pop(dCtx);
                                      },
                                      child: Text('Видалити', style: GoogleFonts.chakraPetch(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    meal.text.trim(),
                    style: GoogleFonts.chakraPetch(
                      color: const Color(0xFFF0F5FF),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Б: ${meal.protein}г  •  Ж: ${meal.fats}г  •  В: ${meal.carbs}г',
                    style: GoogleFonts.chakraPetch(
                      color: const Color(0xFF96A0AF),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
