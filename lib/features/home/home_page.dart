import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/models/habit.dart';
import '../../data/repositories/providers.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(habitsStreamProvider);
    final todayAsync = ref.watch(todayCompletionsProvider);
    final weeklyAsync = ref.watch(weeklyDoneCountsProvider);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF121B36), Color(0xFF070B17)],
          ),
        ),
        child: SafeArea(
          child: habitsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Hata: $e')),
            data: (habits) {
              return todayAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Hata: $e')),
                data: (todayMap) {
                  return weeklyAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Hata: $e')),
                    data: (weeklyCounts) {
                      final prioritizedHabits = _prioritizedHabits(
                        habits: habits,
                        todayMap: todayMap,
                      );
                      final authUser = ref.watch(authStateProvider).valueOrNull;
                      final reminderText = authUser == null
                          ? null
                          : ref
                                .watch(userProfileProvider(authUser.uid))
                                .maybeWhen(
                                  data: (p) {
                                    if (p == null || p['remindersEnabled'] == false) {
                                      return null;
                                    }
                                    final h = (p['reminderHour'] ?? 21) as int;
                                    final m = (p['reminderMinute'] ?? 0) as int;
                                    return 'Hatırlatıcı ${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
                                  },
                                  orElse: () => null,
                                );
                      final hiddenCount = math.max(0, habits.length - 8);
                      final doneCount = todayMap.values.where((v) => v).length;
                      final insight = ref.watch(octyInsightProvider);
                      return LayoutBuilder(
                        builder: (context, c) {
                          final contentWidth = math.min(c.maxWidth - 24, 460.0);
                          final isCompact = c.maxHeight < 820;
                          final compactScale = (c.maxHeight / 820).clamp(0.84, 1.0);
                          final topSpacing = (isCompact ? 6.0 : 10.0) * compactScale;
                          final sectionSpacing = (isCompact ? 8.0 : 12.0) * compactScale;
                          final showReminder = reminderText != null && c.maxHeight > 700;
                          final showHiddenCta = hiddenCount > 0 && c.maxHeight > 860;
                          final boardSize = math
                              .max(
                                200.0,
                                math.min(
                                  contentWidth * 0.93,
                                  c.maxHeight * (isCompact ? 0.40 : 0.45),
                                ),
                              )
                              .toDouble();
                          return Center(
                            child: SizedBox(
                              width: contentWidth,
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(12, 8, 12, 12 * compactScale),
                                child: Column(
                                  children: [
                                    Column(
                                      children: [
                                        _HomeTopGreeting(compact: isCompact),
                                        SizedBox(height: topSpacing),
                                        _WeekLineCalendar(compact: isCompact),
                                        if (showReminder) ...[
                                          SizedBox(height: topSpacing),
                                          Text(
                                            reminderText,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall?.copyWith(
                                              color: Colors.white54,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    SizedBox(height: sectionSpacing),
                                    Expanded(
                                      child: Center(
                                        child: SizedBox(
                                          width: boardSize,
                                          height: boardSize,
                                          child: _HomeRingBoard(
                                            habits: prioritizedHabits,
                                            todayMap: todayMap,
                                            weeklyCounts: weeklyCounts,
                                            onToggle: (habitId, doneToday) async {
                                              await ref
                                                  .read(habitLogsRepositoryProvider)
                                                  .toggleToday(
                                                    habitId: habitId,
                                                    completed: !doneToday,
                                                  );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                    _ChatBubble(
                                      text: insight.microNudge,
                                    ),
                                    SizedBox(height: sectionSpacing),
                                    _TodayProgressBar(
                                      doneCount: doneCount,
                                      total: habits.length,
                                    ),
                                    if (showHiddenCta) ...[
                                      SizedBox(height: sectionSpacing),
                                      FilledButton.tonal(
                                        onPressed: () => context.go('/habits'),
                                        style: FilledButton.styleFrom(
                                          shape: const StadiumBorder(),
                                        ),
                                            child: const Text('Tüm alışkanlıkları gör'),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '+$hiddenCount tane daha',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall?.copyWith(
                                              color: Colors.white54,
                                            ),
                                          ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  List<Habit> _prioritizedHabits({
    required List<Habit> habits,
    required Map<String, bool> todayMap,
  }) {
    final list = [...habits];
    list.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;

      final aDone = todayMap[a.id] == true;
      final bDone = todayMap[b.id] == true;
      if (aDone != bDone) return aDone ? 1 : -1;

      if (a.sortOrder != b.sortOrder) {
        return a.sortOrder.compareTo(b.sortOrder);
      }

      final aCreated = a.createdAt;
      final bCreated = b.createdAt;
      if (aCreated != null && bCreated != null) {
        return bCreated.compareTo(aCreated);
      }
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return list;
  }
}

class _HomeRingBoard extends StatelessWidget {
  final List<Habit> habits;
  final Map<String, bool> todayMap;
  final Map<String, int> weeklyCounts;
  final Future<void> Function(String habitId, bool doneToday) onToggle;

  const _HomeRingBoard({
    required this.habits,
    required this.todayMap,
    required this.weeklyCounts,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final compactShownHabits = habits.take(8).toList();
    final itemCount = compactShownHabits.length;

    return LayoutBuilder(
      builder: (context, c) {
        final effectiveSize =
            math.min(c.maxWidth, c.maxHeight).clamp(230.0, 460.0).toDouble();
        final desiredCenterSize = effectiveSize *
            (itemCount <= 3
                ? 0.58
                : (itemCount <= 5 ? 0.55 : 0.51));
        final itemSize = effectiveSize *
            (itemCount <= 3 ? 0.34 : (itemCount <= 5 ? 0.325 : 0.29));

        // Push habit rings further out, but guarantee they do not overlap the center octopus.
        // Strategy:
        // 1) pick a radius that fits inside the board bounds
        // 2) if that radius would overlap the center, shrink the center to fit
        const gap = 12.0;
        final targetRadius = effectiveSize *
            (itemCount <= 3 ? 0.40 : (itemCount <= 5 ? 0.44 : 0.47));
        final maxRadius = ((effectiveSize - itemSize) / 2) - gap;
        final radius = math.max(0.0, math.min(targetRadius, maxRadius));
        final maxCenterSize =
            math.max(0.0, 2 * (radius - (itemSize / 2) - gap));
        final centerSize = math.max(
          effectiveSize * 0.36, // don't collapse the center too much
          math.min(desiredCenterSize, maxCenterSize),
        );

        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: centerSize * 1.7,
              height: centerSize * 1.7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF62D7FF).withValues(alpha: 0.24),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            _OctopusCenter(size: centerSize),
            if (itemCount == 0)
              Positioned(
                bottom: 16,
                child: Text(
                  'İlk alışkanlığını Alışkanlıklar sekmesinden ekle.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ),
            ...List.generate(itemCount, (i) {
              final angle = (-math.pi / 2) + (2 * math.pi * i / itemCount);
              final dx = radius * math.cos(angle);
              final dy = radius * math.sin(angle);

              return Transform.translate(
                offset: Offset(dx, dy),
                child: SizedBox(
                  width: itemSize,
                  height: itemSize,
                  child: _HabitRingItem(
                    habit: compactShownHabits[i],
                    doneToday: todayMap[compactShownHabits[i].id] == true,
                    weeklyDone: weeklyCounts[compactShownHabits[i].id] ?? 0,
                    onToggle: () => onToggle(
                      compactShownHabits[i].id,
                      todayMap[compactShownHabits[i].id] == true,
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _OctopusCenter extends StatefulWidget {
  final double size;
  const _OctopusCenter({required this.size});

  @override
  State<_OctopusCenter> createState() => _OctopusCenterState();
}

class _OctopusCenterState extends State<_OctopusCenter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 0.985, end: 1.015).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return AnimatedBuilder(
      animation: _scale,
      builder: (context, _) {
        return Transform.scale(
          scale: _scale.value,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.045),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF62D7FF).withValues(alpha: 0.22),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.24),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipOval(
              child: Padding(
                padding: EdgeInsets.all(size * 0.08),
                child: Image.asset(
                  'assets/anim/octy_anim.webp',
                  fit: BoxFit.contain,
                  gaplessPlayback: true,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HabitRingItem extends StatelessWidget {
  final Habit habit;
  final bool doneToday;
  final int weeklyDone;
  final VoidCallback onToggle;

  const _HabitRingItem({
    required this.habit,
    required this.doneToday,
    required this.weeklyDone,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    const ringPrimary = Color(0xFF90A5FF);
    const ringAccent = Color(0xFF7B61FF);
    final goal = habit.goalPerWeek <= 0 ? 1 : habit.goalPerWeek;
    final progress = (weeklyDone / goal).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: onToggle,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [ringPrimary, ringAccent],
              ),
            ),
            child: const SizedBox.expand(),
          ),
          Padding(
            padding: const EdgeInsets.all(2),
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 5,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              color: ringAccent,
            ),
          ),
          Container(
            margin: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.2),
            ),
            child: LayoutBuilder(
              builder: (context, c) {
                final tiny = c.maxWidth < 74;
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: tiny ? 5 : 7),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          habit.title,
                          maxLines: tiny ? 2 : 3,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: (tiny
                                  ? Theme.of(context).textTheme.labelSmall
                                  : Theme.of(context).textTheme.labelMedium)
                              ?.copyWith(height: 1.05),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$weeklyDone/$goal',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white70,
                          fontSize: tiny ? 9.5 : 10.5,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (doneToday)
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                width: 21,
                height: 21,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.withValues(alpha: 0.9),
                ),
                child: const Icon(Icons.check, size: 13, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}

class _TodayProgressBar extends StatelessWidget {
  final int doneCount;
  final int total;
  const _TodayProgressBar({required this.doneCount, required this.total});

  @override
  Widget build(BuildContext context) {
    final progress = total <= 0 ? 0.0 : (doneCount / total).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bugünkü İlerleme',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            color: const Color(0xFF7A8BFF),
          ),
        ),
      ],
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String text;
  const _ChatBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withValues(alpha: 0.07),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Text(text, textAlign: TextAlign.center),
          ),
        ),
        Container(
          width: 10,
          height: 10,
          transform: Matrix4.rotationZ(0.785),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
        ),
      ],
    );
  }
}

class _WeekLineCalendar extends StatelessWidget {
  final bool compact;
  const _WeekLineCalendar({this.compact = false});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday % 7));
    final days = List<DateTime>.generate(
      7,
      (i) => weekStart.add(Duration(days: i)),
    );

    return Row(
      children: List.generate(days.length, (i) {
        final d = days[i];
        final label = DateFormat.E('tr_TR').format(d);
        final isToday =
            d.year == today.year && d.month == today.month && d.day == today.day;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: compact ? 5 : 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: isToday
                    ? const Color(0xFF3F6FD2)
                    : Colors.white.withValues(alpha: 0.09),
                border: Border.all(
                  color: isToday
                      ? const Color(0xFF79BCFF)
                      : Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    label,
                    style: (compact
                            ? Theme.of(context).textTheme.labelMedium
                            : Theme.of(context).textTheme.labelLarge)
                        ?.copyWith(
                      color: isToday ? Colors.white : Colors.white70,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: compact ? 2 : 4),
                  Container(
                    width: compact ? 30 : 34,
                    height: compact ? 30 : 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isToday
                          ? Colors.white.withValues(alpha: 0.16)
                          : Colors.black.withValues(alpha: 0.16),
                    ),
                    child: Text(
                      '${d.day}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: isToday ? Colors.white : Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _HomeTopGreeting extends ConsumerWidget {
  final bool compact;
  const _HomeTopGreeting({this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final hour = now.hour;
    final salutation = hour < 12
        ? 'Günaydın'
        : (hour < 18 ? 'İyi günler' : 'İyi akşamlar');

    final authUser = ref.watch(authStateProvider).valueOrNull;
    final profile = authUser == null
        ? null
        : ref.watch(userProfileProvider(authUser.uid)).valueOrNull;
    final String displayName = (profile?['displayName'] as String?)?.trim().isNotEmpty ==
            true
        ? (profile!['displayName'] as String)
        : 'Dostum';

    final formattedDate = DateFormat.yMMMMEEEEd('tr_TR').format(now);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$salutation, $displayName',
                style: (compact
                        ? Theme.of(context).textTheme.headlineSmall
                        : Theme.of(context).textTheme.headlineMedium)
                    ?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                formattedDate,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(
                  color: Colors.white70,
                  fontSize: compact ? 13.5 : null,
                ),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => context.push('/assistant'),
          child: Container(
            width: compact ? 48 : 56,
            height: compact ? 48 : 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/octy/octy_happy.jpg',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
