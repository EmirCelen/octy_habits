import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  static String dateKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y$m$day';
  }

  static String logId({required String habitId, required String dateKey}) =>
      '${habitId}_$dateKey';

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

  Future<void> toggleToday({
    required String habitId,
    required bool completed,
    DateTime? today,
  }) async {
    final key = dateKey(today ?? DateTime.now());
    final id = logId(habitId: habitId, dateKey: key);

    final ref = _logsRef().doc(id);

    if (completed) {
      await ref.set({
        'habitId': habitId,
        'dateKey': key,
        'completed': true,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      // “uncheck” için iki yaklaşım var:
      // A) delete (basit)
      // B) completed:false (audit için)
      // MVP: delete
      await ref.delete();
    }
  }
}
