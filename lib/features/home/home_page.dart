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
                return LayoutBuilder(
                  builder: (context, c) {
                    final size = math.min(c.maxWidth, c.maxHeight);

                    // Ortadaki ahtapot boyutu
                    final octoSize = size * 0.50; // %32
                    // Habit çemberinin yarıçapı
                    final radius = size * 0.40; // %30
                    // Her habit düğmesinin boyutu
                    final itemSize = size * 0.20; // %17

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
                                    Colors.cyan.withOpacity(0.15),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),

                            // Ortadaki "ahtapot" placeholder
                            _OctopusCenter(size: octoSize),

                            // Habit items dairesel dizilim
                            ..._buildHabitRingItems(
                              context: context,
                              ref: ref,
                              habitsCount: habits.length,
                              habits: habits,
                              todayMap: todayMap,
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
            // Şimdilik günlük progress: done ise 1, değilse 0
            progress: doneToday ? 1.0 : 0.0,
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
        color: Colors.white.withOpacity(0.06),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
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
  final VoidCallback onToggle;

  const _HabitRingItem({
    required this.title,
    required this.doneToday,
    required this.progress,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ring
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
              color: Colors.black.withOpacity(0.18),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            ),
          ),

          // Done badge
          if (doneToday)
            Positioned(
              right: 2,
              top: 2,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green.withOpacity(0.9),
                ),
                child: const Icon(Icons.check, size: 14, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
