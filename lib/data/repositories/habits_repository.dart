import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/habit.dart';

class HabitsRepository {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  HabitsRepository(this._db, this._auth);

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('User not signed in');
    return uid;
  }

  CollectionReference<Map<String, dynamic>> _habitsRef() =>
      _db.collection('users').doc(_uid).collection('habits');

  Stream<List<Habit>> watchHabits() {
    return _habitsRef()
        .snapshots()
        .map((snap) => snap.docs.map((d) => Habit.fromDoc(d)).toList());
  }

  Future<void> addHabit({
    required String title,
    required int goalPerWeek,
    required int colorValue,
  }) async {
    await _habitsRef().add({
      'title': title.trim(),
      'goalPerWeek': goalPerWeek,
      'colorValue': colorValue,
      'isActive': true,
      'isPinned': false,
      'sortOrder': DateTime.now().millisecondsSinceEpoch,
      'createdAt': FieldValue.serverTimestamp(),

      // ✅ aggregate defaults
      'currentStreak': 0,
      'longestStreak': 0,
      'lastCompletedDateKey': null,
    });
  }

  Future<void> setPinned({
    required String habitId,
    required bool pinned,
  }) async {
    await _habitsRef().doc(habitId).set({
      'isPinned': pinned,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateHabitOrder(List<String> habitIds) async {
    final batch = _db.batch();
    for (int i = 0; i < habitIds.length; i++) {
      final ref = _habitsRef().doc(habitIds[i]);
      batch.set(ref, {
        'sortOrder': i,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> updateHabit({
    required String habitId,
    required String title,
    required int goalPerWeek,
  }) async {
    await _habitsRef().doc(habitId).set({
      'title': title.trim(),
      'goalPerWeek': goalPerWeek,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteHabit(String habitId) async {
    await deleteHabitWithSnapshot(habitId);
  }

  Future<DeletedHabitSnapshot> deleteHabitWithSnapshot(String habitId) async {
    final habitRef = _habitsRef().doc(habitId);
    final habitSnap = await habitRef.get();
    final habitData = habitSnap.data();
    if (habitData == null) {
      throw StateError('Habit not found');
    }

    final logsQuery = await _db
        .collection('users')
        .doc(_uid)
        .collection('habitLogs')
        .where('habitId', isEqualTo: habitId)
        .get();

    final logs = <DeletedHabitLog>[];
    for (final doc in logsQuery.docs) {
      logs.add(DeletedHabitLog(id: doc.id, data: Map<String, dynamic>.from(doc.data())));
    }

    final batch = _db.batch();
    batch.delete(habitRef);
    for (final log in logs) {
      final ref = _db
          .collection('users')
          .doc(_uid)
          .collection('habitLogs')
          .doc(log.id);
      batch.delete(ref);
    }
    await batch.commit();

    return DeletedHabitSnapshot(
      habitId: habitId,
      habitData: Map<String, dynamic>.from(habitData),
      logs: logs,
    );
  }

  Future<void> restoreDeletedHabit(DeletedHabitSnapshot snapshot) async {
    final habitRef = _habitsRef().doc(snapshot.habitId);
    final batch = _db.batch();
    batch.set(habitRef, snapshot.habitData);

    for (final log in snapshot.logs) {
      final logRef = _db
          .collection('users')
          .doc(_uid)
          .collection('habitLogs')
          .doc(log.id);
      batch.set(logRef, log.data);
    }

    await batch.commit();
  }
}

class DeletedHabitSnapshot {
  final String habitId;
  final Map<String, dynamic> habitData;
  final List<DeletedHabitLog> logs;

  const DeletedHabitSnapshot({
    required this.habitId,
    required this.habitData,
    required this.logs,
  });
}

class DeletedHabitLog {
  final String id;
  final Map<String, dynamic> data;

  const DeletedHabitLog({required this.id, required this.data});
}
