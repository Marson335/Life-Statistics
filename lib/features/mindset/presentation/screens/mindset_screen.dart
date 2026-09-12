import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../statistics/presentation/screens/statistics_screen.dart';

class MindsetScreen extends ConsumerWidget {
  const MindsetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(statPeriodProvider);
    final statsAsync = ref.watch(statisticsProvider(period));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Мислення',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildPeriodSelector(ref, period),
            const SizedBox(height: 16),
            Expanded(
              child: statsAsync.when(
                data: (stats) => _buildStatsContent(stats),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Помилка: $e', style: const TextStyle(color: Colors.red))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodSelector(WidgetRef ref, StatPeriod currentPeriod) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _buildPeriodTab(ref, 'Сьогодні', StatPeriod.day, currentPeriod),
            _buildPeriodTab(ref, 'Тиждень', StatPeriod.week, currentPeriod),
            _buildPeriodTab(ref, 'Місяць', StatPeriod.month, currentPeriod),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodTab(WidgetRef ref, String label, StatPeriod period, StatPeriod currentPeriod) {
    final isSelected = currentPeriod == period;
    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(statPeriodProvider.notifier).state = period,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsContent(Map<String, dynamic> stats) {
    final int yellow = stats['byType']['yellow'] ?? 0;
    final int red = stats['byType']['red'] ?? 0;

    if (yellow == 0 && red == 0) {
      return const Center(
        child: Text(
          'Немає даних (Жовтих/Червоних задач) за цей період',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: [
        _buildSuccessBalanceCard(yellow, red),
      ],
    );
  }

  Widget _buildSuccessBalanceCard(int yellow, int red) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Баланс успіху',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: AppColors.yellowTask, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '$yellow Успіхів',
                    style: const TextStyle(color: AppColors.yellowTask, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    '$red Невдач',
                    style: const TextStyle(color: AppColors.redTask, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.warning_amber_rounded, color: AppColors.redTask, size: 20),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  Expanded(
                    flex: yellow == 0 && red == 0 ? 1 : yellow,
                    child: Container(color: yellow == 0 && red == 0 ? AppColors.surfaceVariant : AppColors.yellowTask),
                  ),
                  Expanded(
                    flex: yellow == 0 && red == 0 ? 1 : red,
                    child: Container(color: yellow == 0 && red == 0 ? AppColors.surfaceVariant : AppColors.redTask),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              yellow > red ? 'Чудовий настрій! Продовжуй так само 🚀' : 
              yellow < red ? 'Не засмучуйся, завтра буде краще 🫂' : 
              'Абсолютний баланс ⚖️',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
