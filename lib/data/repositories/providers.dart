import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/habit.dart';
import 'habit_logs_repository.dart';
import 'habits_repository.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

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

final habitsStreamProvider = StreamProvider<List<Habit>>((ref) {
  return ref.watch(habitsRepositoryProvider).watchHabits();
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
  final keys = List.generate(7, (i) {
    final d = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: i));
    return HabitLogsRepository.dateKey(d);
  });

  return db
      .collection('users')
      .doc(uid)
      .collection('habitLogs')
      .where('dateKey', whereIn: keys) // max 10, biz 7
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

/// ✅ MVP: Son 10 gün toplam completion (whereIn limiti yüzünden 10 gün)
final last30DaysTotalCompletedProvider = StreamProvider<int>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final db = ref.watch(firestoreProvider);

  final uid = auth.currentUser?.uid;
  if (uid == null) return Stream.value(0);

  final now = DateTime.now();
  final keys = List.generate(10, (i) {
    final d = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: i));
    return HabitLogsRepository.dateKey(d);
  });

  return db
      .collection('users')
      .doc(uid)
      .collection('habitLogs')
      .where('dateKey', whereIn: keys)
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
