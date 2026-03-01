import 'package:go_router/go_router.dart';

import 'app_shell.dart';
import 'features/home/home_page.dart';
import 'features/habits/habits_page.dart';
import 'features/stats/stats_page.dart';
import 'features/profile/profile_page.dart';
import 'features/settings/settings_page.dart';

final appRouter = GoRouter(
  initialLocation: '/home',
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomePage()),
        GoRoute(path: '/habits', builder: (_, __) => const HabitsPage()),
        GoRoute(path: '/stats', builder: (_, __) => const StatsPage()),
        GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
      ],
    ),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
  ],
);
