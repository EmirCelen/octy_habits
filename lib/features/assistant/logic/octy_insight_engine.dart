import '../../../data/models/habit.dart';

enum RiskLevel { low, medium, high }

class HabitRiskInput {
  final Habit habit;
  final int weeklyDone;
  final bool doneToday;

  const HabitRiskInput({
    required this.habit,
    required this.weeklyDone,
    required this.doneToday,
  });
}

class OctyInsight {
  final double riskScore; // 0..1
  final RiskLevel riskLevel;
  final String microNudge;
  final String? focusHabitTitle;
  final bool shouldBoostReminders;

  const OctyInsight({
    required this.riskScore,
    required this.riskLevel,
    required this.microNudge,
    required this.focusHabitTitle,
    required this.shouldBoostReminders,
  });
}

OctyInsight buildOctyInsight({
  required List<HabitRiskInput> habits,
  required int totalHabits,
  required int doneTodayCount,
  double loginRegularity = 0.5,
  double assistantEngagement = 0.0,
  double eveningUsagePattern = 0.5,
}) {
  if (totalHabits <= 0 || habits.isEmpty) {
    return const OctyInsight(
      riskScore: 0.18,
      riskLevel: RiskLevel.low,
      microNudge: 'Ilk aliskanligini ekle, mini bir hedefle baslayalim.',
      focusHabitTitle: null,
      shouldBoostReminders: false,
    );
  }

  double riskSum = 0;
  HabitRiskInput? maxRiskHabit;
  double maxRisk = -1;

  for (final item in habits) {
    final goal = item.habit.goalPerWeek <= 0 ? 1 : item.habit.goalPerWeek;
    final adherence = (item.weeklyDone / goal).clamp(0.0, 1.0);
    final missingRatio = 1 - adherence;

    final streakPenalty = item.habit.currentStreak <= 0
        ? 1.0
        : (item.habit.currentStreak <= 2 ? 0.55 : 0.2);
    final doneTodayPenalty = item.doneToday ? 0.0 : 0.9;

    // Lightweight logistic-style weighted score (MVP).
    final habitRisk = (0.52 * missingRatio) + (0.28 * doneTodayPenalty) + (0.20 * streakPenalty);
    riskSum += habitRisk;

    if (habitRisk > maxRisk) {
      maxRisk = habitRisk;
      maxRiskHabit = item;
    }
  }

  final avgRisk = riskSum / habits.length;
  final loadPenalty = totalHabits > 6 ? ((totalHabits - 6) * 0.03).clamp(0.0, 0.15) : 0.0;
  final dailyPenalty = totalHabits <= 0 ? 0.0 : ((totalHabits - doneTodayCount) / totalHabits) * 0.15;
  final regularityBoost = (1 - loginRegularity).clamp(0.0, 1.0) * 0.12;
  final engagementRelief = assistantEngagement.clamp(0.0, 1.0) * 0.06;
  final timePatternPenalty = (eveningUsagePattern < 0.15 ? 0.03 : 0.0);

  final riskScore =
      (avgRisk + loadPenalty + dailyPenalty + regularityBoost + timePatternPenalty - engagementRelief)
          .clamp(0.0, 1.0);

  final level = riskScore >= 0.62
      ? RiskLevel.high
      : (riskScore >= 0.38 ? RiskLevel.medium : RiskLevel.low);

  final focus = maxRiskHabit?.habit.title;
  final message = _nudgeFor(
    level: level,
    doneTodayCount: doneTodayCount,
    totalHabits: totalHabits,
    focusHabit: focus,
  );

  return OctyInsight(
    riskScore: riskScore,
    riskLevel: level,
    microNudge: message,
    focusHabitTitle: focus,
    shouldBoostReminders: level == RiskLevel.high,
  );
}

String _nudgeFor({
  required RiskLevel level,
  required int doneTodayCount,
  required int totalHabits,
  required String? focusHabit,
}) {
  if (level == RiskLevel.high) {
    if (focusHabit != null && focusHabit.trim().isNotEmpty) {
      return 'Ritim dusuyor. Simdi "$focusHabit" icin 5 dakikalik mini tur yap.';
    }
    return 'Ritim dusuyor. Tek bir aliskanligi simdi tamamlayip ivmeyi geri acalim.';
  }
  if (level == RiskLevel.medium) {
    return 'Iyi gidiyorsun: $doneTodayCount/$totalHabits. Bir adim daha atarsan bugun kilitlenir.';
  }
  if (doneTodayCount >= totalHabits && totalHabits > 0) {
    return 'Harika, bugun tamamsin. Yarinin ilk adimini simdiden belirle.';
  }
  return 'Ritmin iyi. Kucuk ve surekli adimlarla devam et.';
}
