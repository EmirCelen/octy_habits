import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/providers.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(habitsStreamProvider);
    final todayAsync = ref.watch(todayCompletionsProvider);
    final weeklyAsync = ref.watch(weeklyDoneCountsProvider);

    return Scaffold(
      body: SafeArea(
        child: habitsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (habits) {
            return todayAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (todayMap) {
                return weeklyAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (weeklyCounts) {
                    return LayoutBuilder(
                      builder: (context, c) {
                        final size = math.min(c.maxWidth, c.maxHeight);

                        // Ortadaki ahtapot boyutu
                        final octoSize = size * 0.50;
                        // Habit çemberinin yarıçapı
                        final radius = size * 0.40;
                        // Her habit düğmesinin boyutu
                        final itemSize = size * 0.20;

                        return Center(
                          child: SizedBox(
                            width: size,
                            height: size,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Arka plan hafif halo
                                Container(
                                  width: octoSize * 1.5,
                                  height: octoSize * 1.5,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        Colors.cyan.withValues(alpha: 0.15),
                                        Colors.transparent,
                                      ],
                                    ),
                                  ),
                                ),

                                // Ortadaki "ahtapot"
                                _OctopusCenter(size: octoSize),

                                // Habit items dairesel dizilim
                                ..._buildHabitRingItems(
                                  context: context,
                                  ref: ref,
                                  habitsCount: habits.length,
                                  habits: habits,
                                  todayMap: todayMap,
                                  weeklyCounts: weeklyCounts,
                                  radius: radius,
                                  itemSize: itemSize,
                                ),
                              ],
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
    );
  }

  List<Widget> _buildHabitRingItems({
    required BuildContext context,
    required WidgetRef ref,
    required int habitsCount,
    required List<dynamic> habits,
    required Map<String, bool> todayMap,
    required Map<String, int> weeklyCounts,
    required double radius,
    required double itemSize,
  }) {
    if (habitsCount == 0) {
      return [
        Positioned(
          bottom: 24,
          left: 24,
          right: 24,
          child: Text(
            'İlk alışkanlığını Habits sekmesinden ekle.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ];
    }

    return List.generate(habitsCount, (i) {
      final h = habits[i];

      final doneToday = todayMap[h.id] == true;

      // ✅ weekly progress = (son 7 gün done) / goalPerWeek
      final weeklyDone = weeklyCounts[h.id] ?? 0;
      final goal = (h.goalPerWeek is int) ? h.goalPerWeek as int : 0;

      final progress = (goal <= 0)
          ? 0.0
          : (weeklyDone / goal).clamp(0.0, 1.0).toDouble();

      // Açıyı -90 dereceden başlat (tepe)
      final angle = (-math.pi / 2) + (2 * math.pi * i / habitsCount);

      final dx = radius * math.cos(angle);
      final dy = radius * math.sin(angle);

      return Transform.translate(
        offset: Offset(dx, dy),
        child: SizedBox(
          width: itemSize,
          height: itemSize,
          child: _HabitRingItem(
            title: h.title,
            doneToday: doneToday,
            progress: progress,
            subtitle: '$weeklyDone/$goal',
            onToggle: () async {
              await ref
                  .read(habitLogsRepositoryProvider)
                  .toggleToday(habitId: h.id, completed: !doneToday);
            },
          ),
        ),
      );
    });
  }
}

class _OctopusCenter extends StatelessWidget {
  final double size;
  const _OctopusCenter({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.06),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
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
    );
  }
}

class _HabitRingItem extends StatelessWidget {
  final String title;
  final bool doneToday;
  final double progress;
  final String subtitle;
  final VoidCallback onToggle;

  const _HabitRingItem({
    required this.title,
    required this.doneToday,
    required this.progress,
    required this.subtitle,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ring (weekly progress)
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: CircularProgressIndicator(value: progress, strokeWidth: 6),
          ),

          // İç kart
          Container(
            width: double.infinity,
            height: double.infinity,
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.18),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Done badge (today)
          if (doneToday)
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.withValues(alpha: 0.9),
                ),
                child: const Icon(Icons.check, size: 14, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
