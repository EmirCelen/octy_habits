import 'package:cloud_firestore/cloud_firestore.dart';

class Habit {
  final String id;
  final String title;
  final int goalPerWeek;
  final int colorValue;
  final bool isActive;
  final DateTime? createdAt;

  // ✅ Aggregate fields (MVP)
  final int currentStreak;
  final int longestStreak;
  final String? lastCompletedDateKey;

  Habit({
    required this.id,
    required this.title,
    required this.goalPerWeek,
    required this.colorValue,
    required this.isActive,
    required this.createdAt,
    required this.currentStreak,
    required this.longestStreak,
    required this.lastCompletedDateKey,
  });

  factory Habit.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Habit(
      id: doc.id,
      title: (data['title'] ?? '') as String,
      goalPerWeek: (data['goalPerWeek'] ?? 3) as int,
      colorValue: (data['colorValue'] ?? 0xFF7C5CFF) as int,
      isActive: (data['isActive'] ?? true) as bool,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),

      // ✅ defaults (backward compatible)
      currentStreak: (data['currentStreak'] ?? 0) as int,
      longestStreak: (data['longestStreak'] ?? 0) as int,
      lastCompletedDateKey: data['lastCompletedDateKey'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'goalPerWeek': goalPerWeek,
    'colorValue': colorValue,
    'isActive': isActive,
    'createdAt': FieldValue.serverTimestamp(),

    // ✅ defaults
    'currentStreak': currentStreak,
    'longestStreak': longestStreak,
    'lastCompletedDateKey': lastCompletedDateKey,
  };
}
