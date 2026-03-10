import 'package:flutter_test/flutter_test.dart';
import 'package:octy_habits/features/stats/logic/weekly_rate_engine.dart';

void main() {
  group('weeklyCompletionRate', () {
    test('returns 0 when target is zero', () {
      expect(weeklyCompletionRate(totalDone: 4, totalTarget: 0), 0.0);
    });

    test('returns proper ratio in normal range', () {
      expect(weeklyCompletionRate(totalDone: 3, totalTarget: 4), 0.75);
    });

    test('clamps ratio above 1 to 1', () {
      expect(weeklyCompletionRate(totalDone: 9, totalTarget: 7), 1.0);
    });
  });
}
