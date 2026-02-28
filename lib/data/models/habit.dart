import 'package:cloud_firestore/cloud_firestore.dart';

class Habit {
  final String id;
  final String title;
  final int goalPerWeek;
  final int colorValue;
  final bool isActive;
  final DateTime? createdAt;

  Habit({
    required this.id,
    required this.title,
    required this.goalPerWeek,
    required this.colorValue,
    required this.isActive,
    required this.createdAt,
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
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'goalPerWeek': goalPerWeek,
    'colorValue': colorValue,
    'isActive': isActive,
    'createdAt': FieldValue.serverTimestamp(),
  };
}
