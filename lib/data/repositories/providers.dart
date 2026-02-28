import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'habit_logs_repository.dart';

import '../repositories/habits_repository.dart';
import '../models/habit.dart';

final habitLogsRepositoryProvider = Provider<HabitLogsRepository>((ref) {
  return HabitLogsRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseAuthProvider),
  );
});

final todayCompletionsProvider = StreamProvider<Map<String, bool>>((ref) {
  return ref
      .watch(habitLogsRepositoryProvider)
      .watchTodayCompletions(DateTime.now());
});

final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);
final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

final habitsRepositoryProvider = Provider<HabitsRepository>((ref) {
  return HabitsRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseAuthProvider),
  );
});

final habitsStreamProvider = StreamProvider<List<Habit>>((ref) {
  return ref.watch(habitsRepositoryProvider).watchHabits();
});
