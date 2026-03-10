import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/habit.dart';
import '../../features/assistant/logic/octy_insight_engine.dart';
import 'app_events_repository.dart';
import 'habit_logs_repository.dart';
import 'habits_repository.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

final userProfileProvider =
    StreamProvider.family<Map<String, dynamic>?, String>((ref, uid) {
      return ref
          .watch(firestoreProvider)
          .collection('users')
          .doc(uid)
          .snapshots()
          .map((doc) => doc.data());
    });

final habitLogsRepositoryProvider = Provider<HabitLogsRepository>((ref) {
  return HabitLogsRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseAuthProvider),
  );
});

final habitsRepositoryProvider = Provider<HabitsRepository>((ref) {
  return HabitsRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseAuthProvider),
  );
});

final appEventsRepositoryProvider = Provider<AppEventsRepository>((ref) {
  return AppEventsRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseAuthProvider),
  );
});

final habitsStreamProvider = StreamProvider<List<Habit>>((ref) {
  return ref.watch(habitsRepositoryProvider).watchHabits();
});

final recentAppEventsProvider = StreamProvider<List<AppEventEntry>>((ref) {
  return ref.watch(appEventsRepositoryProvider).watchRecentEvents(days: 7);
});

final todayCompletionsProvider = StreamProvider<Map<String, bool>>((ref) {
  return ref
      .watch(habitLogsRepositoryProvider)
      .watchTodayCompletions(DateTime.now());
});

/// ✅ Son 7 günde her habit kaç kez tamamlandı?  {habitId: count}
final weeklyDoneCountsProvider = StreamProvider<Map<String, int>>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final db = ref.watch(firestoreProvider);

  final uid = auth.currentUser?.uid;
  if (uid == null) return Stream.value(<String, int>{});

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final start = today.subtract(const Duration(days: 6));
  final startKey = HabitLogsRepository.dateKey(start);
  final endKey = HabitLogsRepository.dateKey(today);

  return db
      .collection('users')
      .doc(uid)
      .collection('habitLogs')
      .where('dateKey', isGreaterThanOrEqualTo: startKey)
      .where('dateKey', isLessThanOrEqualTo: endKey)
      .snapshots()
      .map((snap) {
        final counts = <String, int>{};
        for (final doc in snap.docs) {
          final data = doc.data();
          final habitId = (data['habitId'] ?? '') as String;
          final completed = (data['completed'] ?? false) as bool;
          if (habitId.isEmpty || !completed) continue;
          counts[habitId] = (counts[habitId] ?? 0) + 1;
        }
        return counts;
      });
});

/// Son 7 gun icin gunluk toplam tamamlanma adetleri (eskiden bugune).
final weeklyDailyTotalsProvider = StreamProvider<List<int>>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final db = ref.watch(firestoreProvider);

  final uid = auth.currentUser?.uid;
  if (uid == null) return Stream.value(List<int>.filled(7, 0));

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final start = today.subtract(const Duration(days: 6));
  final startKey = HabitLogsRepository.dateKey(start);
  final endKey = HabitLogsRepository.dateKey(today);

  return db
      .collection('users')
      .doc(uid)
      .collection('habitLogs')
      .where('dateKey', isGreaterThanOrEqualTo: startKey)
      .where('dateKey', isLessThanOrEqualTo: endKey)
      .snapshots()
      .map((snap) {
        final byKey = <String, int>{};
        for (final doc in snap.docs) {
          final data = doc.data();
          final completed = (data['completed'] ?? false) as bool;
          if (!completed) continue;
          final key = (data['dateKey'] ?? '') as String;
          if (key.isEmpty) continue;
          byKey[key] = (byKey[key] ?? 0) + 1;
        }

        return List<int>.generate(7, (i) {
          final d = start.add(Duration(days: i));
          return byKey[HabitLogsRepository.dateKey(d)] ?? 0;
        });
      });
});

/// Son 30 gunde toplam completion.
final last30DaysTotalCompletedProvider = StreamProvider<int>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final db = ref.watch(firestoreProvider);

  final uid = auth.currentUser?.uid;
  if (uid == null) return Stream.value(0);

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final start = today.subtract(const Duration(days: 29));
  final startKey = HabitLogsRepository.dateKey(start);
  final endKey = HabitLogsRepository.dateKey(today);

  return db
      .collection('users')
      .doc(uid)
      .collection('habitLogs')
      .where('dateKey', isGreaterThanOrEqualTo: startKey)
      .where('dateKey', isLessThanOrEqualTo: endKey)
      .snapshots()
      .map((snap) {
        int total = 0;
        for (final doc in snap.docs) {
          final data = doc.data();
          final completed = (data['completed'] ?? false) as bool;
          if (completed) total += 1;
        }
        return total;
      });
});

/// ✅ Tek tip streak summary (AsyncValue değil) — çakışma bitti
final streakSummaryProvider = Provider<StreakSummary>((ref) {
  final habitsAsync = ref.watch(habitsStreamProvider);

  return habitsAsync.maybeWhen(
    data: (habits) {
      int current = 0;
      int longest = 0;
      for (final h in habits) {
        if (h.currentStreak > current) current = h.currentStreak;
        if (h.longestStreak > longest) longest = h.longestStreak;
      }
      return StreakSummary(current: current, longest: longest);
    },
    orElse: () => const StreakSummary(current: 0, longest: 0),
  );
});

class StreakSummary {
  final int current;
  final int longest;
  const StreakSummary({required this.current, required this.longest});
}

final octyInsightProvider = Provider<OctyInsight>((ref) {
  final habits = ref.watch(habitsStreamProvider).valueOrNull ?? const <Habit>[];
  final todayMap = ref.watch(todayCompletionsProvider).valueOrNull ?? const <String, bool>{};
  final weeklyCounts = ref.watch(weeklyDoneCountsProvider).valueOrNull ?? const <String, int>{};
  final events = ref.watch(recentAppEventsProvider).valueOrNull ?? const <AppEventEntry>[];

  final inputs = habits
      .map(
        (h) => HabitRiskInput(
          habit: h,
          weeklyDone: weeklyCounts[h.id] ?? 0,
          doneToday: todayMap[h.id] == true,
        ),
      )
      .toList(growable: false);

  final loginDays = events
      .where((e) => e.type == 'app_open')
      .map((e) => e.dateKey)
      .toSet()
      .length;
  final loginRegularity = (loginDays / 7).clamp(0.0, 1.0);

  final assistantMessages = events.where((e) => e.type == 'assistant_message').length;
  final assistantEngagement = (assistantMessages / 7).clamp(0.0, 1.0);

  final eveningEvents = events.where((e) => e.hour >= 18 && e.hour <= 23).length;
  final allEvents = events.isEmpty ? 1 : events.length;
  final eveningPattern = (eveningEvents / allEvents).clamp(0.0, 1.0);

  final doneToday = todayMap.values.where((v) => v).length;
  return buildOctyInsight(
    habits: inputs,
    totalHabits: habits.length,
    doneTodayCount: doneToday,
    loginRegularity: loginRegularity,
    assistantEngagement: assistantEngagement,
    eveningUsagePattern: eveningPattern,
  );
});
