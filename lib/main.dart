import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/services/notification_service.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/tasks/presentation/screens/today_screen.dart';
import 'features/statistics/presentation/screens/statistics_screen.dart';
import 'features/calories/presentation/screens/calories_screen.dart';
import 'features/settings/presentation/screens/settings_screen.dart';
import 'features/crypto/presentation/screens/crypto_screen.dart';
import 'shared/widgets/main_scaffold.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService().init();
  runApp(const ProviderScope(child: LifeStatisticsApp()));
}

final _router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final user = FirebaseAuth.instance.currentUser;
    final isLoggedIn = user != null;
    final isOnLogin = state.matchedLocation == '/login';
    if (!isLoggedIn && !isOnLogin) return '/login';
    if (isLoggedIn && isOnLogin) return '/';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (ctx, state) => const LoginScreen()),
    ShellRoute(
      builder: (ctx, state, child) => MainScaffold(child: child),
      routes: [
        GoRoute(path: '/', builder: (ctx, state) => const TodayScreen()),
        GoRoute(
            path: '/statistics',
            builder: (ctx, state) => const StatisticsScreen()),
        GoRoute(
            path: '/calories',
            builder: (ctx, state) => const CaloriesScreen()),
        GoRoute(
            path: '/crypto',
            builder: (ctx, state) => const CryptoScreen()),
        GoRoute(
            path: '/settings',
            builder: (ctx, state) => const SettingsScreen()),
      ],
    ),
  ],
);

class LifeStatisticsApp extends ConsumerWidget {
  const LifeStatisticsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Life Statistics',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: _router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('uk', 'UA'),
        Locale('en', 'US'),
      ],
      locale: const Locale('uk', 'UA'),
    );
  }
}



