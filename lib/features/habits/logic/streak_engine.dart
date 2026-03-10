class StreakState {
  final int currentStreak;
  final int longestStreak;
  final String? lastCompletedDateKey;

  const StreakState({
    required this.currentStreak,
    required this.longestStreak,
    required this.lastCompletedDateKey,
  });
}

StreakState applyToggleToStreak({
  required bool completed,
  required String todayKey,
  required String yesterdayKey,
  required StreakState previous,
}) {
  final lastKey = previous.lastCompletedDateKey;
  int newCurrent = previous.currentStreak;
  int newLongest = previous.longestStreak;
  String? newLastKey = lastKey;

  if (completed) {
    if (lastKey == todayKey) {
      newCurrent = previous.currentStreak;
    } else if (lastKey == yesterdayKey) {
      newCurrent = previous.currentStreak + 1;
    } else {
      newCurrent = 1;
    }
    newLastKey = todayKey;
    newLongest = newCurrent > previous.longestStreak
        ? newCurrent
        : previous.longestStreak;
  } else if (lastKey == todayKey) {
    newCurrent = previous.currentStreak - 1;
    if (newCurrent <= 0) {
      newCurrent = 0;
      newLastKey = null;
    } else {
      newLastKey = yesterdayKey;
    }
  }

  return StreakState(
    currentStreak: newCurrent,
    longestStreak: newLongest,
    lastCompletedDateKey: newLastKey,
  );
}
