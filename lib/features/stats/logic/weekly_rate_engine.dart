double weeklyCompletionRate({
  required int totalDone,
  required int totalTarget,
}) {
  if (totalTarget <= 0) return 0.0;
  final raw = totalDone / totalTarget;
  if (raw < 0) return 0.0;
  if (raw > 1) return 1.0;
  return raw;
}
