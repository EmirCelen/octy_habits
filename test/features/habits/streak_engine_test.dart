import 'package:flutter_test/flutter_test.dart';
import 'package:octy_habits/features/habits/logic/streak_engine.dart';

void main() {
  group('applyToggleToStreak', () {
    test('starts streak with 1 when completed with no prior state', () {
      final next = applyToggleToStreak(
        completed: true,
        todayKey: '20260301',
        yesterdayKey: '20260228',
        previous: const StreakState(
          currentStreak: 0,
          longestStreak: 0,
          lastCompletedDateKey: null,
        ),
      );

      expect(next.currentStreak, 1);
      expect(next.longestStreak, 1);
      expect(next.lastCompletedDateKey, '20260301');
    });

    test('increments streak when last completion was yesterday', () {
      final next = applyToggleToStreak(
        completed: true,
        todayKey: '20260301',
        yesterdayKey: '20260228',
        previous: const StreakState(
          currentStreak: 3,
          longestStreak: 4,
          lastCompletedDateKey: '20260228',
        ),
      );

      expect(next.currentStreak, 4);
      expect(next.longestStreak, 4);
      expect(next.lastCompletedDateKey, '20260301');
    });

    test('undo for today reduces streak and sets last to yesterday', () {
      final next = applyToggleToStreak(
        completed: false,
        todayKey: '20260301',
        yesterdayKey: '20260228',
        previous: const StreakState(
          currentStreak: 4,
          longestStreak: 6,
          lastCompletedDateKey: '20260301',
        ),
      );

      expect(next.currentStreak, 3);
      expect(next.longestStreak, 6);
      expect(next.lastCompletedDateKey, '20260228');
    });
  });
}
