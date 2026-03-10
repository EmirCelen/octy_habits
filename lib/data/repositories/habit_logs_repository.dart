import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../features/habits/logic/streak_engine.dart';

class HabitLogsRepository {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  HabitLogsRepository(this._db, this._auth);

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('User not signed in');
    return uid;
  }

  CollectionReference<Map<String, dynamic>> _logsRef() =>
      _db.collection('users').doc(_uid).collection('habitLogs');

  DocumentReference<Map<String, dynamic>> _habitRef(String habitId) =>
      _db.collection('users').doc(_uid).collection('habits').doc(habitId);

  static String dateKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y$m$day';
  }

  static String logId({required String habitId, required String dateKey}) =>
      '${habitId}_$dateKey';

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Stream<Map<String, bool>> watchTodayCompletions(DateTime today) {
    final key = dateKey(today);
    return _logsRef().where('dateKey', isEqualTo: key).snapshots().map((snap) {
      final map = <String, bool>{};
      for (final d in snap.docs) {
        final data = d.data();
        final habitId = (data['habitId'] ?? '') as String;
        final completed = (data['completed'] ?? false) as bool;
        if (habitId.isNotEmpty) map[habitId] = completed;
      }
      return map;
    });
  }

  Stream<Set<String>> watchHabitCompletedDateKeysInRange({
    required String habitId,
    required DateTime start,
    required DateTime end,
  }) {
    final startKey = dateKey(_dayOnly(start));
    final endKey = dateKey(_dayOnly(end));
    return _logsRef().snapshots().map((snap) {
      final keys = <String>{};
      for (final d in snap.docs) {
        final data = d.data();
        final itemHabitId = (data['habitId'] ?? '') as String;
        if (itemHabitId != habitId) continue;

        final completed = (data['completed'] ?? false) as bool;
        if (!completed) continue;

        final key = (data['dateKey'] ?? '') as String;
        if (key.isEmpty) continue;
        if (key.compareTo(startKey) < 0 || key.compareTo(endKey) > 0) continue;
        keys.add(key);
      }
      return keys;
    });
  }

  Future<void> toggleToday({
    required String habitId,
    required bool completed,
    DateTime? today,
  }) async {
    final now = _dayOnly(today ?? DateTime.now());
    final todayKey = dateKey(now);
    final yesterdayKey = dateKey(now.subtract(const Duration(days: 1)));

    final id = logId(habitId: habitId, dateKey: todayKey);
    final logRef = _logsRef().doc(id);
    final habitRef = _habitRef(habitId);

    await _db.runTransaction((tx) async {
      // ✅ 1️⃣ ÖNCE READ
      final habitSnap = await tx.get(habitRef);
      final habitData = habitSnap.data() ?? <String, dynamic>{};

      final nextState = applyToggleToStreak(
        completed: completed,
        todayKey: todayKey,
        yesterdayKey: yesterdayKey,
        previous: StreakState(
          lastCompletedDateKey: habitData['lastCompletedDateKey'] as String?,
          currentStreak: (habitData['currentStreak'] ?? 0) as int,
          longestStreak: (habitData['longestStreak'] ?? 0) as int,
        ),
      );

      // ✅ 2️⃣ SONRA WRITE
      if (completed) {
        tx.set(logRef, {
          'habitId': habitId,
          'dateKey': todayKey,
          'completed': true,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } else {
        tx.delete(logRef);
      }

      tx.set(habitRef, {
        'currentStreak': nextState.currentStreak,
        'longestStreak': nextState.longestStreak,
        'lastCompletedDateKey': nextState.lastCompletedDateKey,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }
}
