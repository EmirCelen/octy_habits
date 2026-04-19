import 'package:flutter_test/flutter_test.dart';
import 'package:octy_habits/data/models/habit.dart';
import 'package:octy_habits/features/assistant/logic/octy_insight_engine.dart';

Habit _habit({
  required String id,
  required int goal,
  required int streak,
}) {
  return Habit(
    id: id,
    title: id,
    goalPerWeek: goal,
    colorValue: 0xFF7C5CFF,
    isActive: true,
    isPinned: false,
    sortOrder: 0,
    createdAt: null,
    currentStreak: streak,
    longestStreak: streak,
    lastCompletedDateKey: null,
  );
}

void main() {
  test('returns low risk for strong adherence', () {
    final insight = buildOctyInsight(
      habits: [
        HabitRiskInput(
          habit: _habit(id: 'read', goal: 4, streak: 6),
          weeklyDone: 4,
          doneToday: true,
        ),
        HabitRiskInput(
          habit: _habit(id: 'water', goal: 7, streak: 8),
          weeklyDone: 7,
          doneToday: true,
        ),
      ],
      totalHabits: 2,
      doneTodayCount: 2,
    );

    expect(insight.riskLevel, RiskLevel.low);
    expect(insight.riskScore, lessThan(0.38));
  });

  test('returns high risk when adherence and streak are weak', () {
    final insight = buildOctyInsight(
      habits: [
        HabitRiskInput(
          habit: _habit(id: 'study', goal: 5, streak: 0),
          weeklyDone: 0,
          doneToday: false,
        ),
        HabitRiskInput(
          habit: _habit(id: 'sleep', goal: 7, streak: 0),
          weeklyDone: 1,
          doneToday: false,
        ),
      ],
      totalHabits: 2,
      doneTodayCount: 0,
    );

    expect(insight.riskLevel, RiskLevel.high);
    expect(insight.riskScore, greaterThanOrEqualTo(0.62));
    expect(insight.shouldBoostReminders, isTrue);
  });

  test('returns onboarding nudge when there are no habits', () {
    final insight = buildOctyInsight(
      habits: const [],
      totalHabits: 0,
      doneTodayCount: 0,
    );

    expect(insight.riskLevel, RiskLevel.low);
    expect(insight.microNudge, contains('İlk alışkanlığını ekle'));
  });
}
