import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../core/theme/app_theme.dart';

import '../../features/tasks/data/notification_expense_service.dart';
import '../../../core/services/notification_service.dart';
import '../../features/tasks/data/task_repository.dart';
import '../../features/tasks/presentation/screens/today_screen.dart' as tasks_today;
import '../../features/calories/presentation/screens/calories_screen.dart' as calories_screen;

class MainScaffold extends ConsumerStatefulWidget {
  final Widget child;
  const MainScaffold({super.key, required this.child});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Ensure date begins on today upon fresh initialization
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      ref.read(tasks_today.selectedDateProvider.notifier).state = today;
      ref.read(calories_screen.selectedDateProvider.notifier).state = today;

      NotificationExpenseService().startListening();
      final taskRepo = TaskRepository();
      NotificationService().rescheduleAllTaskReminders(taskRepo);
      taskRepo.processMissedTaskPenalties();
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
      NotificationExpenseService().scanActiveNotifications();
      TaskRepository().processMissedTaskPenalties();
      
      // Auto rollover to the new day if midnight elapsed while backgrounded
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final currentTasksDate = ref.read(tasks_today.selectedDateProvider);
      if (currentTasksDate.isBefore(today)) {
        ref.read(tasks_today.selectedDateProvider.notifier).state = today;
      }
      final currentCaloriesDate = ref.read(calories_screen.selectedDateProvider);
      if (currentCaloriesDate.isBefore(today)) {
        ref.read(calories_screen.selectedDateProvider.notifier).state = today;
      }
    }
  }

  bool get _isDesktop => !kIsWeb && Platform.isWindows;

  @override
  Widget build(BuildContext context) {
    if (_isDesktop) {
      return _DesktopScaffold(child: widget.child);
    }
    return _MobileScaffold(child: widget.child);
  }
}

// ---- MOBILE: Bottom Navigation ----
class _MobileScaffold extends ConsumerWidget {
  final Widget child;
  const _MobileScaffold({required this.child});

  int _getSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location == '/') return 0;
    if (location == '/targets') return 1;
    if (location == '/statistics') return 2;
    if (location == '/calories') return 3;
    if (location == '/crypto') return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = _getSelectedIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border, width: 1.5)),
        ),
        child: BottomNavigationBar(
          backgroundColor: AppColors.surface,
          selectedItemColor: AppColors.accent,
          unselectedItemColor: const Color(0xFF7E8594),
          selectedLabelStyle: GoogleFonts.chakraPetch(
            fontWeight: FontWeight.w800,
            fontSize: 10,
            letterSpacing: 0.2,
          ),
          unselectedLabelStyle: GoogleFonts.chakraPetch(
            fontWeight: FontWeight.w600,
            fontSize: 9.5,
            letterSpacing: 0.1,
          ),
          type: BottomNavigationBarType.fixed,
          currentIndex: selectedIndex,
          onTap: (index) {
            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            switch (index) {
              case 0:
                ref.read(tasks_today.selectedDateProvider.notifier).state = today;
                context.go('/');
                break;
              case 1:
                context.go('/targets');
                break;
              case 2:
                context.go('/statistics');
                break;
              case 3:
                ref.read(calories_screen.selectedDateProvider.notifier).state = today;
                context.go('/calories');
                break;
              case 4:
                context.go('/crypto');
                break;
            }
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.today_rounded), label: 'СЬОГОДНІ'),
            BottomNavigationBarItem(icon: Icon(Icons.track_changes_rounded), label: 'ТАРГЕТ'),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'СТАТИСТИКА'),
            BottomNavigationBarItem(icon: Icon(Icons.local_fire_department_rounded), label: 'КАЛОРІЇ'),
            BottomNavigationBarItem(icon: Icon(Icons.currency_bitcoin_rounded), label: 'КРИПТА'),
          ],
        ),
      ),
    );
  }
}

// ---- DESKTOP: Left Navigation Rail ----
class _DesktopScaffold extends ConsumerWidget {
  final Widget child;
  const _DesktopScaffold({required this.child});

  int _getSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location == '/') return 0;
    if (location == '/targets') return 1;
    if (location == '/statistics') return 2;
    if (location == '/calories') return 3;
    if (location == '/crypto') return 4;
    if (location == '/settings') return 5;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = _getSelectedIndex(context);

    return Scaffold(
      body: Row(
        children: [
          Container(
            decoration: const BoxDecoration(
              border: Border(right: BorderSide(color: AppColors.border)),
            ),
            child: NavigationRail(
              extended: true,
              minExtendedWidth: 200,
              backgroundColor: AppColors.surface,
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) {
                final now = DateTime.now();
                final today = DateTime(now.year, now.month, now.day);
                switch (index) {
                  case 0:
                    ref.read(tasks_today.selectedDateProvider.notifier).state = today;
                    context.go('/');
                    break;
                  case 1:
                    context.go('/targets');
                    break;
                  case 2:
                    context.go('/statistics');
                    break;
                  case 3:
                    ref.read(calories_screen.selectedDateProvider.notifier).state = today;
                    context.go('/calories');
                    break;
                  case 4:
                    context.go('/crypto');
                    break;
                  case 5:
                    context.go('/settings');
                    break;
                }
              },
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/app_logo.png',
                      width: 44,
                      height: 44,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'LifeStatistic',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.today_rounded), label: Text('Сьогодні')),
                NavigationRailDestination(icon: Icon(Icons.track_changes_rounded), label: Text('Таргет')),
                NavigationRailDestination(icon: Icon(Icons.bar_chart_rounded), label: Text('Статистика')),
                NavigationRailDestination(icon: Icon(Icons.local_fire_department_rounded), label: Text('Калорії')),
                NavigationRailDestination(icon: Icon(Icons.currency_bitcoin_rounded), label: Text('Крипта')),
                NavigationRailDestination(icon: Icon(Icons.settings_rounded), label: Text('Налаштування')),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}


