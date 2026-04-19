import '../../../data/models/habit.dart';
import 'ml_risk_model.dart';

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
  MlRiskModel? mlModel,
}) {
  if (totalHabits <= 0 || habits.isEmpty) {
    return const OctyInsight(
      riskScore: 0.18,
      riskLevel: RiskLevel.low,
      microNudge: 'İlk alışkanlığını ekle, mini bir hedefle başlayalım.',
      focusHabitTitle: null,
      shouldBoostReminders: false,
    );
  }

  double riskSum = 0;
  HabitRiskInput? maxRiskHabit;
  double maxRisk = -1;

  double missingRatioSum = 0;
  double adherenceSum = 0;
  double streakPenaltySum = 0;

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

    missingRatioSum += missingRatio;
    adherenceSum += adherence;
    streakPenaltySum += streakPenalty;

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

  final heuristicScore =
      (avgRisk + loadPenalty + dailyPenalty + regularityBoost + timePatternPenalty - engagementRelief)
          .clamp(0.0, 1.0);

  final doneTodayRatio =
      totalHabits <= 0 ? 0.0 : (doneTodayCount / totalHabits).clamp(0.0, 1.0);
  final n = habits.isEmpty ? 1 : habits.length;
  final mlFeatures = <String, double>{
    'missing_ratio_avg': (missingRatioSum / n).clamp(0.0, 1.0),
    'weekly_adherence_avg': (adherenceSum / n).clamp(0.0, 1.0),
    'streak_penalty_avg': (streakPenaltySum / n).clamp(0.0, 1.0),
    'done_today_ratio': doneTodayRatio,
    'login_regularity': loginRegularity.clamp(0.0, 1.0),
    'assistant_engagement': assistantEngagement.clamp(0.0, 1.0),
    'evening_usage_pattern': eveningUsagePattern.clamp(0.0, 1.0),
    'total_habits': (totalHabits.toDouble().clamp(0.0, 50.0)) / 50.0,
  };

  final riskScore = mlModel != null
      ? mlModel.predictProbability(mlFeatures).clamp(0.0, 1.0)
      : heuristicScore;

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
      return 'Ritim düşüyor. Şimdi "$focusHabit" için 5 dakikalık mini tur yap.';
    }
    return 'Ritim düşüyor. Tek bir alışkanlığı şimdi tamamlayıp ivmeyi geri açalım.';
  }
  if (level == RiskLevel.medium) {
    return 'İyi gidiyorsun: $doneTodayCount/$totalHabits. Bir adım daha atarsan bugün kilitlenir.';
  }
  if (doneTodayCount >= totalHabits && totalHabits > 0) {
    return 'Harika, bugün tamamsın. Yarının ilk adımını şimdiden belirle.';
  }
  return 'Ritmin iyi. Küçük ve sürekli adımlarla devam et.';
}
