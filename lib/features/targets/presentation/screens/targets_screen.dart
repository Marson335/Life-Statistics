import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/models.dart';
import '../../../tasks/presentation/screens/today_screen.dart'
    show taskRepositoryProvider;
import '../../data/target_repository.dart';

final targetRepositoryProvider =
    Provider<TargetRepository>((ref) => TargetRepository());

final targetsStreamProvider = StreamProvider<List<TargetGoal>>((ref) {
  final repo = ref.watch(targetRepositoryProvider);
  return repo.watchTargets();
});

class TargetVisualPreset {
  static const List<IconData> icons = [
    Icons.track_changes_rounded,
    Icons.emoji_events_rounded,
    Icons.rocket_launch_rounded,
    Icons.fitness_center_rounded,
    Icons.code_rounded,
    Icons.psychology_rounded,
    Icons.savings_rounded,
    Icons.military_tech_rounded,
  ];

  static const List<int> colors = [
    0xFFD4FF00, // Neon Lime
    0xFF00C896, // Green
    0xFF4D9FFF, // Blue
    0xFFFFD740, // Gold
    0xFFFF5252, // Red
    0xFFB388FF, // Purple
  ];

  static IconData getIcon(int key) {
    if (key < 0 || key >= icons.length) return icons[0];
    return icons[key];
  }
}

class TargetsScreen extends ConsumerStatefulWidget {
  const TargetsScreen({super.key});

  @override
  ConsumerState<TargetsScreen> createState() => _TargetsScreenState();
}

class _TargetsScreenState extends ConsumerState<TargetsScreen> {
  int _selectedFilter = 0; // 0 = Активні, 1 = Виконані 🏆

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(taskRepositoryProvider).processMissedTaskPenalties();
    });
  }

  @override
  Widget build(BuildContext context) {
    final targetsAsync = ref.watch(targetsStreamProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GLOBAL MISSIONS // PROGRESS & LEVELS',
              style: GoogleFonts.chakraPetch(
                color: AppColors.accent,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
            Text(
              'ТАРГЕТИ & ЦІЛІ',
              style: GoogleFonts.chakraPetch(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => context.go('/settings'),
            tooltip: 'Налаштування',
            icon: const Icon(Icons.settings_rounded, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: targetsAsync.when(
          data: (targets) => _buildBody(context, targets),
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          ),
          error: (e, _) => Center(
            child: Text(
              'Помилка завантаження таргетів: $e',
              style: const TextStyle(color: AppColors.redTask),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditTargetSheet(context),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        icon: const Icon(Icons.add_rounded, color: Colors.black),
        label: Text(
          'НОВИЙ ТАРГЕТ',
          style: GoogleFonts.chakraPetch(
            fontWeight: FontWeight.w900,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<TargetGoal> allTargets) {
    final activeTargets = allTargets.where((t) => !t.isCompleted).toList();
    final completedTargets = allTargets.where((t) => t.isCompleted).toList();
    final displayed =
        _selectedFilter == 0 ? activeTargets : completedTargets;

    final totalPoints =
        allTargets.fold<int>(0, (acc, t) => acc + t.currentPoints);

    return Column(
      children: [
        _buildSummaryHeader(
          activeCount: activeTargets.length,
          completedCount: completedTargets.length,
          totalPoints: totalPoints,
        ),
        _buildFilterTabs(
          activeCount: activeTargets.length,
          completedCount: completedTargets.length,
        ),
        Expanded(
          child: displayed.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  itemCount: displayed.length,
                  itemBuilder: (ctx, i) => _TargetCard(
                    target: displayed[i],
                    onEdit: () =>
                        _showAddEditTargetSheet(context, targetToEdit: displayed[i]),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSummaryHeader({
    required int activeCount,
    required int completedCount,
    required int totalPoints,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Row(
        children: [
          _buildKpiItem('АКТИВНІ', '$activeCount', AppColors.accent),
          Container(width: 1, height: 28, color: AppColors.border),
          _buildKpiItem('ЗАКРИТО 🏆', '$completedCount', AppColors.greenTask),
          Container(width: 1, height: 28, color: AppColors.border),
          _buildKpiItem('СУМАРНО TP', '$totalPoints', AppColors.blueTask),
        ],
      ),
    );
  }

  Widget _buildKpiItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: GoogleFonts.chakraPetch(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: GoogleFonts.chakraPetch(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs({
    required int activeCount,
    required int completedCount,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: _FilterTabButton(
              label: 'АКТИВНІ ($activeCount)',
              icon: Icons.bolt_rounded,
              isSelected: _selectedFilter == 0,
              onTap: () => setState(() => _selectedFilter = 0),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _FilterTabButton(
              label: 'ВИКОНАНІ 🏆 ($completedCount)',
              icon: Icons.emoji_events_rounded,
              isSelected: _selectedFilter == 1,
              onTap: () => setState(() => _selectedFilter = 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final isCompletedTab = _selectedFilter == 1;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isCompletedTab
                  ? Icons.emoji_events_outlined
                  : Icons.track_changes_rounded,
              size: 64,
              color: AppColors.textDisabled,
            ),
            const SizedBox(height: 16),
            Text(
              isCompletedTab
                  ? 'Поки немає закритих таргетів'
                  : 'Немає активних глобальних таргетів',
              style: GoogleFonts.chakraPetch(
                color: AppColors.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isCompletedTab
                  ? 'Досягніть фінального рівня та виконайте всі етапи цілі, щоб перенести її в Зал Слави!'
                  : 'Створіть глобальний Таргет, пропишіть рівні та етапи, і прив’яжіть до нього щоденні задачі у вкладці «Сьогодні».',
              style: const TextStyle(
                color: AppColors.textDisabled,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showAddEditTargetSheet(BuildContext context, {TargetGoal? targetToEdit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => AddEditTargetSheet(targetToEdit: targetToEdit),
    );
  }
}

class _FilterTabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterTabButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accent.withAlpha(30)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.accent : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.chakraPetch(
                  color:
                      isSelected ? AppColors.accent : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// TARGET CARD WIDGET
// ============================================================================
class _TargetCard extends ConsumerStatefulWidget {
  final TargetGoal target;
  final VoidCallback onEdit;

  const _TargetCard({
    required this.target,
    required this.onEdit,
  });

  @override
  ConsumerState<_TargetCard> createState() => _TargetCardState();
}

class _TargetCardState extends ConsumerState<_TargetCard> {
  bool _showHistory = false;
  bool _showStages = true;

  @override
  Widget build(BuildContext context) {
    final t = widget.target;
    final repo = ref.read(targetRepositoryProvider);
    final accentColor = Color(t.colorValue);
    final iconData = TargetVisualPreset.getIcon(t.iconKey);

    final lvlPercent = (t.currentLevelProgress * 100).round();
    final totalPercent = (t.totalProgress * 100).toStringAsFixed(1);
    final sortedStages = List<TargetStage>.from(t.stages)
      ..sort((a, b) => a.requiredLevel.compareTo(b.requiredLevel));

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: t.isCompleted
              ? AppColors.greenTask.withAlpha(200)
              : (t.isReadyToComplete
                  ? AppColors.accent
                  : AppColors.border),
          width: t.isCompleted || t.isReadyToComplete ? 2.0 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(80),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. HEADER ROW
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accentColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accentColor.withAlpha(160), width: 1.5),
                  ),
                  child: Icon(iconData, color: accentColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              t.title,
                              style: GoogleFonts.chakraPetch(
                                color: AppColors.textPrimary,
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: accentColor.withAlpha(35),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: accentColor.withAlpha(140)),
                            ),
                            child: Text(
                              t.isMaxPointsReached
                                  ? 'LVL ${t.targetLevel} / ${t.targetLevel} (MAX)'
                                  : 'LVL ${t.currentLevel} / ${t.targetLevel}',
                              style: GoogleFonts.chakraPetch(
                                color: accentColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Text(
                              '${t.currentPoints} / ${t.totalTargetPoints} TP',
                              style: GoogleFonts.chakraPetch(
                                color: AppColors.textPrimary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (t.isCompleted)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.greenTask.withAlpha(40),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.greenTask),
                              ),
                              child: Text(
                                '🏆 ТАРГЕТ ЗАКРИТО',
                                style: GoogleFonts.chakraPetch(
                                  color: AppColors.greenTask,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded,
                      color: AppColors.textSecondary, size: 20),
                  color: AppColors.surfaceVariant,
                  onSelected: (val) async {
                    if (val == 'edit') {
                      widget.onEdit();
                    } else if (val == 'reopen') {
                      await repo.reopenTarget(t.id);
                    } else if (val == 'delete') {
                      final confirm = await _confirmDelete(context, t.title);
                      if (confirm == true) {
                        await repo.deleteTarget(t.id);
                      }
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_rounded, size: 18, color: AppColors.textPrimary),
                          SizedBox(width: 8),
                          Text('Редагувати', style: TextStyle(color: AppColors.textPrimary)),
                        ],
                      ),
                    ),
                    if (t.isCompleted)
                      const PopupMenuItem(
                        value: 'reopen',
                        child: Row(
                          children: [
                            Icon(Icons.refresh_rounded, size: 18, color: AppColors.accent),
                            SizedBox(width: 8),
                            Text('Повернути в активні', style: TextStyle(color: AppColors.accent)),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.redTask),
                          SizedBox(width: 8),
                          Text('Видалити', style: TextStyle(color: AppColors.redTask)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // 2. DESCRIPTION & COMPLETION CRITERIA
            if (t.description.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                t.description,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.flag_circle_rounded, size: 15, color: accentColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'УМОВА ЗАКРИТТЯ: Досягти LVL ${t.targetLevel} (${t.totalTargetPoints} TP)${t.stages.isNotEmpty ? " + виконати всі етапи (${t.stages.where((s) => s.isCompleted).length}/${t.stages.length})" : ""}',
                          style: GoogleFonts.chakraPetch(
                            color: AppColors.textPrimary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (t.completionCriteria.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Фінальна дія: ${t.completionCriteria}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (t.isCompleted && t.completedAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Виконано: ${DateFormat('dd.MM.yyyy HH:mm').format(t.completedAt!)}',
                      style: const TextStyle(
                        color: AppColors.greenTask,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 14),

            // 3. CURRENT LEVEL PROGRESS BAR
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    t.isMaxPointsReached
                        ? 'РІВЕНЬ ${t.targetLevel} ЗАПОВНЕНО НА 100%'
                        : 'ПРОГРЕС РІВНЯ ${t.currentLevel}  (${t.pointsInCurrentLevel} / ${t.pointsPerLevel} TP)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.chakraPetch(
                      color: accentColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$lvlPercent%',
                  style: GoogleFonts.chakraPetch(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: LinearProgressIndicator(
                value: t.currentLevelProgress.clamp(0.0, 1.0),
                minHeight: 11,
                backgroundColor: const Color(0xFF0C0D10),
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              ),
            ),

            const SizedBox(height: 10),

            // 4. TOTAL TARGET PROGRESS BAR
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'ЗАГАЛЬНИЙ ПРОГРЕС (LVL ${t.targetLevel})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.chakraPetch(
                      color: AppColors.textSecondary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      t.remainingPointsToClose > 0
                          ? '$totalPercent% • ще ${t.remainingPointsToClose} TP'
                          : '100% MAX 🔥',
                      style: GoogleFonts.chakraPetch(
                        color: AppColors.textSecondary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: t.totalProgress.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: const Color(0xFF0C0D10),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.blueTask),
              ),
            ),

            // 5. STAGES (MILESTONES) SECTION
            if (sortedStages.isNotEmpty) ...[
              const SizedBox(height: 14),
              InkWell(
                onTap: () => setState(() => _showStages = !_showStages),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.account_tree_rounded,
                          size: 16, color: AppColors.accent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'ЕТАПИ ТА ДІЇ (${sortedStages.where((s) => s.isCompleted).length}/${sortedStages.length})',
                          style: GoogleFonts.chakraPetch(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Icon(
                        _showStages
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              if (_showStages) ...[
                const SizedBox(height: 6),
                ...sortedStages.map((stage) {
                  final unlocked = t.isStageUnlocked(stage);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: stage.isCompleted
                          ? AppColors.greenTask.withAlpha(20)
                          : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: stage.isCompleted
                            ? AppColors.greenTask.withAlpha(120)
                            : (unlocked
                                ? accentColor.withAlpha(120)
                                : AppColors.border),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: (!t.isCompleted && unlocked)
                              ? () => repo.toggleStageCompletion(
                                    t.id,
                                    stage.id,
                                    !stage.isCompleted,
                                  )
                              : null,
                          child: Container(
                            margin: const EdgeInsets.only(top: 2),
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: stage.isCompleted
                                  ? AppColors.greenTask
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: stage.isCompleted
                                    ? AppColors.greenTask
                                    : (unlocked
                                        ? accentColor
                                        : AppColors.textDisabled),
                                width: 1.6,
                              ),
                            ),
                            child: stage.isCompleted
                                ? const Icon(Icons.check_rounded,
                                    size: 15, color: Colors.black)
                                : (!unlocked
                                    ? const Icon(Icons.lock_outline_rounded,
                                        size: 13, color: AppColors.textDisabled)
                                    : null),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: unlocked
                                          ? accentColor.withAlpha(35)
                                          : AppColors.background,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'LVL ${stage.requiredLevel}',
                                      style: GoogleFonts.chakraPetch(
                                        color: unlocked
                                            ? accentColor
                                            : AppColors.textDisabled,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      stage.title,
                                      style: TextStyle(
                                        color: stage.isCompleted
                                            ? AppColors.textSecondary
                                            : AppColors.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        decoration: stage.isCompleted
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (stage.actionsDescription.trim().isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  stage.actionsDescription,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                              if (!unlocked) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Відкриється при досягненні LVL ${stage.requiredLevel}',
                                  style: const TextStyle(
                                    color: AppColors.textDisabled,
                                    fontSize: 10.5,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],

            // 6. COMPLETE TARGET BUTTON (when ready)
            if (!t.isCompleted && t.isReadyToComplete) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final ok = await repo.completeTarget(t.id);
                    if (ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.greenTask,
                          content: Text(
                            '🏆 Таргет «${t.title}» успішно закрито та перенесено у Виконані!',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.emoji_events_rounded, color: Colors.black),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '🏆 ЗАКРИТИ ТАРГЕТ (УСІ УМОВИ ВИКОНАНО!)',
                      style: GoogleFonts.chakraPetch(
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ],

            // 7. JOURNAL / HISTORY SECTION
            const SizedBox(height: 10),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 6),
            InkWell(
              onTap: () => setState(() => _showHistory = !_showHistory),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.history_rounded,
                        size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'ЖУРНАЛ НАРАХУВАНЬ І ШТРАФІВ (${t.history.length})',
                        style: GoogleFonts.chakraPetch(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Icon(
                      _showHistory
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
            if (_showHistory) ...[
              const SizedBox(height: 6),
              if (t.history.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    'Ще немає записів. Виконуйте прив’язані задачі у вкладці «Сьогодні»!',
                    style: TextStyle(color: AppColors.textDisabled, fontSize: 12),
                  ),
                )
              else
                ...t.history.take(15).map((h) {
                  final isPos = h.deltaPoints >= 0 && !h.isPenalty;
                  final sign = h.deltaPoints > 0 ? '+' : '';
                  final dateStr = DateFormat('dd.MM').format(h.date);
                  final multStr = h.multiplier > 1.0
                      ? ' • ${h.isPenalty ? "Анти-стрік" : "Стрік"} ${h.streakCount}д (x${h.multiplier.toStringAsFixed(1)})'
                      : '';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (isPos
                                    ? AppColors.greenTask
                                    : AppColors.redTask)
                                .withAlpha(30),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$sign${h.deltaPoints} TP',
                            style: GoogleFonts.chakraPetch(
                              color: isPos
                                  ? AppColors.greenTask
                                  : AppColors.redTask,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${h.isPenalty ? "Пропуск: " : ""}${h.taskTitle}$multStr',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          dateStr,
                          style: const TextStyle(
                            color: AppColors.textDisabled,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context, String title) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Видалити Таргет?',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Text(
          'Ви впевнені, що хочете видалити глобальну ціль «$title»?',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Скасувати',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Видалити',
                style: TextStyle(color: AppColors.redTask)),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ADD / EDIT TARGET BOTTOM SHEET
// ============================================================================
class AddEditTargetSheet extends ConsumerStatefulWidget {
  final TargetGoal? targetToEdit;

  const AddEditTargetSheet({super.key, this.targetToEdit});

  @override
  ConsumerState<AddEditTargetSheet> createState() => _AddEditTargetSheetState();
}

class _AddEditTargetSheetState extends ConsumerState<AddEditTargetSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _criteriaController = TextEditingController();
  final _pointsPerLevelController = TextEditingController(text: '500');
  final _targetLevelController = TextEditingController(text: '10');

  int _selectedIconKey = 0;
  int _selectedColorValue = TargetVisualPreset.colors[0];
  List<TargetStage> _stages = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.targetToEdit;
    if (t != null) {
      _titleController.text = t.title;
      _descController.text = t.description;
      _criteriaController.text = t.completionCriteria;
      _pointsPerLevelController.text = t.pointsPerLevel.toString();
      _targetLevelController.text = t.targetLevel.toString();
      _selectedIconKey = t.iconKey;
      _selectedColorValue = t.colorValue;
      _stages = List<TargetStage>.from(t.stages);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _criteriaController.dispose();
    _pointsPerLevelController.dispose();
    _targetLevelController.dispose();
    super.dispose();
  }

  int get _parsedPointsPerLevel =>
      (int.tryParse(_pointsPerLevelController.text) ?? 500).clamp(10, 1000000);

  int get _parsedTargetLevel =>
      (int.tryParse(_targetLevelController.text) ?? 10).clamp(1, 1000);

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final totalPts = _parsedPointsPerLevel * _parsedTargetLevel;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.targetToEdit != null
                  ? 'Редагувати Таргет'
                  : 'Новий глобальний Таргет',
              style: GoogleFonts.chakraPetch(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),

            // 1. Назва
            TextField(
              controller: _titleController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Назва цілі (Таргета)',
                hintText: 'Напр.: Розробка власної гри / Ідеальна форма',
                prefixIcon:
                    Icon(Icons.track_changes_rounded, color: AppColors.accent),
              ),
            ),
            const SizedBox(height: 12),

            // 2. Детальний опис
            TextField(
              controller: _descController,
              maxLines: 3,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Детальний опис цілі (Маніфест)',
                hintText: 'Опиши детально, чого саме ти хочеш досягти...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),

            // 3. Фінальна умова закриття
            TextField(
              controller: _criteriaController,
              maxLines: 2,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                labelText: 'Фінальна дія для закриття Таргета',
                hintText:
                    'Напр.: Викласти готовий реліз у магазин / Пробігти 10 км',
                prefixIcon:
                    Icon(Icons.emoji_events_outlined, color: AppColors.accent),
              ),
            ),
            const SizedBox(height: 16),

            // 4. Налаштування рівнів та очок
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _pointsPerLevelController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Очок на 1 рівень (TP)',
                      prefixIcon: Icon(Icons.bolt_rounded,
                          color: AppColors.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _targetLevelController,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: const InputDecoration(
                      labelText: 'Рівень закриття (LVL)',
                      prefixIcon: Icon(Icons.military_tech_rounded,
                          color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                '🎯 Щоб закрити Таргет: досягти LVL $_parsedTargetLevel (усього $totalPts TP по $_parsedPointsPerLevel TP за рівень)',
                style: GoogleFonts.chakraPetch(
                  color: AppColors.accent,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // 5. Іконка та Колір
            const Text(
              'Іконка та колір акценту',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(TargetVisualPreset.icons.length, (i) {
                final selected = _selectedIconKey == i;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIconKey = i),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: selected
                          ? Color(_selectedColorValue).withAlpha(40)
                          : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected
                            ? Color(_selectedColorValue)
                            : AppColors.border,
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      TargetVisualPreset.icons[i],
                      color: selected
                          ? Color(_selectedColorValue)
                          : AppColors.textSecondary,
                      size: 20,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 10),
            Row(
              children: TargetVisualPreset.colors.map((c) {
                final selected = _selectedColorValue == c;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColorValue = c),
                  child: Container(
                    margin: const EdgeInsets.only(right: 10),
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: Color(c),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? Colors.white : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 18),

            // 6. Етапи (Віхи) по рівнях
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ЕТАПИ ДОСЯГНЕННЯ (${_stages.length})',
                  style: GoogleFonts.chakraPetch(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextButton.icon(
                  onPressed: _showAddStageDialog,
                  icon: const Icon(Icons.add_circle_outline_rounded,
                      size: 18, color: AppColors.accent),
                  label: const Text(
                    'Додати етап',
                    style: TextStyle(color: AppColors.accent, fontSize: 13),
                  ),
                ),
              ],
            ),
            if (_stages.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Додайте проміжні та фінальні етапи (на якому рівні та після яких дій етап вважається пройденим).',
                  style: TextStyle(color: AppColors.textDisabled, fontSize: 12),
                ),
              )
            else
              ..._stages.map((s) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withAlpha(30),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'LVL ${s.requiredLevel}',
                          style: GoogleFonts.chakraPetch(
                            color: AppColors.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.title,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (s.actionsDescription.isNotEmpty)
                              Text(
                                s.actionsDescription,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            size: 18, color: AppColors.redTask),
                        onPressed: () {
                          setState(() {
                            _stages.removeWhere((item) => item.id == s.id);
                          });
                        },
                      ),
                    ],
                  ),
                );
              }),

            const SizedBox(height: 20),

            // 7. Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveTarget,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.black, strokeWidth: 2),
                      )
                    : Text(
                        widget.targetToEdit != null
                            ? 'ЗБЕРЕГТИ ЗМІНИ'
                            : 'СТВОРИТИ ТАРГЕТ',
                        style: GoogleFonts.chakraPetch(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddStageDialog() {
    final stageTitleCtrl = TextEditingController();
    final stageActionsCtrl = TextEditingController();
    final stageLevelCtrl =
        TextEditingController(text: _parsedTargetLevel.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Новий етап Таргета',
          style: GoogleFonts.chakraPetch(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: stageLevelCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'На якому рівні (1 .. $_parsedTargetLevel)',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: stageTitleCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Назва етапу',
                  hintText: 'Напр.: Альфа-версія / Перші 5 кг',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: stageActionsCtrl,
                maxLines: 2,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Які дії потрібно виконати',
                  hintText: 'Опиши конкретні дії для закриття цього етапу...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Скасувати',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              if (stageTitleCtrl.text.trim().isEmpty) return;
              final reqLvl = (int.tryParse(stageLevelCtrl.text) ?? 1)
                  .clamp(1, _parsedTargetLevel);
              setState(() {
                _stages.add(
                  TargetStage(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    requiredLevel: reqLvl,
                    title: stageTitleCtrl.text.trim(),
                    actionsDescription: stageActionsCtrl.text.trim(),
                  ),
                );
                _stages.sort(
                    (a, b) => a.requiredLevel.compareTo(b.requiredLevel));
              });
              Navigator.pop(ctx);
            },
            child: const Text('Додати'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveTarget() async {
    if (_isSaving) return;
    if (_titleController.text.trim().isEmpty) return;

    setState(() => _isSaving = true);
    final repo = ref.read(targetRepositoryProvider);
    final existing = widget.targetToEdit;

    final target = TargetGoal(
      id: existing?.id ?? '',
      userId: existing?.userId ?? '',
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      completionCriteria: _criteriaController.text.trim(),
      iconKey: _selectedIconKey,
      colorValue: _selectedColorValue,
      pointsPerLevel: _parsedPointsPerLevel,
      targetLevel: _parsedTargetLevel,
      currentPoints: existing?.currentPoints ?? 0,
      stages: _stages,
      history: existing?.history ?? const [],
      isCompleted: existing?.isCompleted ?? false,
      completedAt: existing?.completedAt,
      createdAt: existing?.createdAt ?? DateTime.now(),
    );

    if (existing != null) {
      await repo.updateTarget(target);
    } else {
      await repo.addTarget(target);
    }

    if (mounted) Navigator.pop(context);
  }
}
