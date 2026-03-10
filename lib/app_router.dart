import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'app_shell.dart';
import 'features/home/home_page.dart';
import 'features/habits/habit_calendar_page.dart';
import 'features/habits/habits_page.dart';
import 'features/stats/stats_page.dart';
import 'features/profile/profile_page.dart';
import 'features/settings/settings_page.dart';
import 'features/assistant/ai_assistant_page.dart';
import 'features/startup/startup_flow_page.dart';

final appRouter = GoRouter(
  initialLocation: '/intro',
  routes: [
    GoRoute(path: '/intro', builder: (_, __) => const IntroPage()),
    GoRoute(
      path: '/gate',
      pageBuilder: (context, state) => CustomTransitionPage<void>(
        key: state.pageKey,
        child: const StartupGatePage(),
        transitionDuration: const Duration(milliseconds: 420),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    ),
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomePage()),
        GoRoute(path: '/habits', builder: (_, __) => const HabitsPage()),
        GoRoute(
          path: '/habit/:habitId/calendar',
          builder: (_, state) => HabitCalendarPage(
            habitId: state.pathParameters['habitId']!,
            title: state.extra is String ? state.extra! as String : 'Calendar',
          ),
        ),
        GoRoute(path: '/stats', builder: (_, __) => const StatsPage()),
        GoRoute(path: '/profile', builder: (_, __) => const ProfilePage()),
      ],
    ),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
    GoRoute(path: '/assistant', builder: (_, __) => const AiAssistantPage()),
  ],
);
