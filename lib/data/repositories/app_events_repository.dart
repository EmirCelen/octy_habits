import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppEventEntry {
  final String type;
  final String dateKey;
  final int hour;
  final Map<String, dynamic> data;

  const AppEventEntry({
    required this.type,
    required this.dateKey,
    required this.hour,
    required this.data,
  });
}

class AppEventsRepository {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  AppEventsRepository(this._db, this._auth);

  String? get _uidOrNull => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? _eventsRefOrNull() {
    final uid = _uidOrNull;
    if (uid == null) return null;
    return _db.collection('users').doc(uid).collection('events');
  }

  static String dateKey(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y$m$day';
  }

  Future<void> logEvent({
    required String type,
    Map<String, dynamic>? data,
    DateTime? at,
  }) async {
    final ref = _eventsRefOrNull();
    if (ref == null) return;
    final now = at ?? DateTime.now();
    await ref.add({
      'type': type,
      'dateKey': dateKey(now),
      'hour': now.hour,
      'data': data ?? const <String, dynamic>{},
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> logEventSafe({
    required String type,
    Map<String, dynamic>? data,
    DateTime? at,
  }) async {
    try {
      await logEvent(type: type, data: data, at: at);
    } catch (_) {
      // Best-effort telemetry only; never crash UX.
    }
  }

  Stream<List<AppEventEntry>> watchRecentEvents({int days = 7}) {
    final ref = _eventsRefOrNull();
    if (ref == null) return Stream.value(const <AppEventEntry>[]);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(Duration(days: days - 1));
    final startKey = dateKey(start);
    final endKey = dateKey(today);

    return ref
        .where('dateKey', isGreaterThanOrEqualTo: startKey)
        .where('dateKey', isLessThanOrEqualTo: endKey)
        .snapshots()
        .map((snap) {
          return snap.docs.map((d) {
            final m = d.data();
            return AppEventEntry(
              type: (m['type'] ?? '') as String,
              dateKey: (m['dateKey'] ?? '') as String,
              hour: (m['hour'] ?? 0) as int,
              data: Map<String, dynamic>.from(
                (m['data'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
              ),
            );
          }).toList();
        });
  }
}
