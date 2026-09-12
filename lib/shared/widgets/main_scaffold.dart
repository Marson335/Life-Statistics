import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../core/theme/app_theme.dart';

class MainScaffold extends StatelessWidget {
  final Widget child;
  const MainScaffold({super.key, required this.child});

  bool get _isDesktop => !kIsWeb && Platform.isWindows;

  @override
  Widget build(BuildContext context) {
    if (_isDesktop) {
      return _DesktopScaffold(child: child);
    }
    return _MobileScaffold(child: child);
  }
}

// ---- MOBILE: Bottom Navigation ----
class _MobileScaffold extends StatelessWidget {
  final Widget child;
  const _MobileScaffold({required this.child});

  int _getSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location == '/') return 0;
    if (location == '/statistics') return 1;
    if (location == '/mindset') return 2;
    if (location == '/settings') return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _getSelectedIndex(context);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: BottomNavigationBar(
          currentIndex: selectedIndex,
          onTap: (index) {
            switch (index) {
              case 0: context.go('/'); break;
              case 1: context.go('/statistics'); break;
              case 2: context.go('/mindset'); break;
              case 3: context.go('/settings'); break;
            }
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.today_rounded), label: 'Сьогодні'),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart_rounded), label: 'Статистика'),
            BottomNavigationBarItem(icon: Icon(Icons.self_improvement_rounded), label: 'Мислення'),
            BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Налаштування'),
          ],
        ),
      ),
    );
  }
}

// ---- DESKTOP: Left Navigation Rail ----
class _DesktopScaffold extends StatelessWidget {
  final Widget child;
  const _DesktopScaffold({required this.child});

  int _getSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location == '/') return 0;
    if (location == '/statistics') return 1;
    if (location == '/mindset') return 2;
    if (location == '/settings') return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
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
                switch (index) {
                  case 0: context.go('/'); break;
                  case 1: context.go('/statistics'); break;
                  case 2: context.go('/mindset'); break;
                  case 3: context.go('/settings'); break;
                }
              },
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.accent, AppColors.blueTask],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.analytics_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Life Statistics',
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
                NavigationRailDestination(icon: Icon(Icons.bar_chart_rounded), label: Text('Статистика')),
                NavigationRailDestination(icon: Icon(Icons.self_improvement_rounded), label: Text('Mindset')),
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

