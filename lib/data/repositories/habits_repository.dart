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
        .orderBy('createdAt', descending: true)
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
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
