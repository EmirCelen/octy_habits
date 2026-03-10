import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/repositories/habit_logs_repository.dart';
import '../../data/repositories/providers.dart';

class HabitCalendarPage extends ConsumerStatefulWidget {
  final String habitId;
  final String title;

  const HabitCalendarPage({super.key, required this.habitId, required this.title});

  @override
  ConsumerState<HabitCalendarPage> createState() => _HabitCalendarPageState();
}

class _HabitCalendarPageState extends ConsumerState<HabitCalendarPage> {
  bool _monthly = true;
  late DateTime _focusDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _focusDate = DateTime(now.year, now.month, now.day);
  }

  DateTime get _monthStart => DateTime(_focusDate.year, _focusDate.month, 1);
  DateTime get _monthEnd => DateTime(_focusDate.year, _focusDate.month + 1, 0);

  DateTime _weekStart(DateTime d, {required bool mondayFirst}) {
    final dayOnly = DateTime(d.year, d.month, d.day);
    final offset = mondayFirst ? (dayOnly.weekday - 1) : (dayOnly.weekday % 7);
    return dayOnly.subtract(Duration(days: offset));
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider).valueOrNull;
    final mondayFirst = auth == null
        ? false
        : ref
              .watch(userProfileProvider(auth.uid))
              .maybeWhen(
                data: (p) => p?['mondayFirst'] == true,
                orElse: () => false,
              );
    final repo = ref.read(habitLogsRepositoryProvider);
    final rangeStart = _monthly
        ? _monthStart
        : _weekStart(_focusDate, mondayFirst: mondayFirst);
    final rangeEnd = _monthly
        ? _monthEnd
        : _weekStart(_focusDate, mondayFirst: mondayFirst).add(
            const Duration(days: 6),
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Habit Calendar'),
      ),
      body: StreamBuilder<Set<String>>(
        stream: repo.watchHabitCompletedDateKeysInRange(
          habitId: widget.habitId,
          start: rangeStart,
          end: rangeEnd,
        ),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final doneKeys = snap.data ?? <String>{};
          return DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF13192A), Color(0xFF0A0E1A)],
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.86),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.white.withValues(alpha: 0.06),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Column(
                      children: [
                        _ModeToggle(
                          monthly: _monthly,
                          onModeChanged: (monthly) {
                            setState(() => _monthly = monthly);
                          },
                        ),
                        const SizedBox(height: 12),
                        _HeaderRow(
                          label: DateFormat('MMMM y').format(_focusDate),
                          onPrev: () {
                            setState(() {
                              if (_monthly) {
                                _focusDate = DateTime(
                                  _focusDate.year,
                                  _focusDate.month - 1,
                                  1,
                                );
                              } else {
                                _focusDate = _focusDate.subtract(
                                  const Duration(days: 7),
                                );
                              }
                            });
                          },
                          onNext: () {
                            setState(() {
                              if (_monthly) {
                                _focusDate = DateTime(
                                  _focusDate.year,
                                  _focusDate.month + 1,
                                  1,
                                );
                              } else {
                                _focusDate = _focusDate.add(
                                  const Duration(days: 7),
                                );
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        _WeekLabels(mondayFirst: mondayFirst),
                        const SizedBox(height: 10),
                        if (_monthly)
                          _MonthGrid(
                            month: _focusDate,
                            doneKeys: doneKeys,
                            mondayFirst: mondayFirst,
                          )
                        else
                          _WeekGrid(
                            weekStart: _weekStart(
                              _focusDate,
                              mondayFirst: mondayFirst,
                            ),
                            doneKeys: doneKeys,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _Legend(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  final bool monthly;
  final ValueChanged<bool> onModeChanged;

  const _ModeToggle({required this.monthly, required this.onModeChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleButton(
              selected: !monthly,
              title: 'Weekly',
              onTap: () => onModeChanged(false),
            ),
          ),
          Expanded(
            child: _ToggleButton(
              selected: monthly,
              title: 'Monthly',
              onTap: () => onModeChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final bool selected;
  final String title;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.selected,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withValues(alpha: 0.14) : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _HeaderRow({
    required this.label,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left),
          color: Colors.white70,
        ),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right),
          color: Colors.white70,
        ),
      ],
    );
  }
}

class _WeekLabels extends StatelessWidget {
  final bool mondayFirst;
  const _WeekLabels({required this.mondayFirst});

  @override
  Widget build(BuildContext context) {
    final days = mondayFirst
        ? const ['M', 'T', 'W', 'T', 'F', 'S', 'S']
        : const ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return Row(
      children: days
          .map(
            (d) => Expanded(
              child: Text(
                d,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final Set<String> doneKeys;
  final bool mondayFirst;

  const _MonthGrid({
    required this.month,
    required this.doneKeys,
    required this.mondayFirst,
  });

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month, 1);
    final leading = mondayFirst ? (firstDay.weekday - 1) : (firstDay.weekday % 7);
    final gridStart = firstDay.subtract(Duration(days: leading));
    final cellCount = 42;

    return GridView.builder(
      itemCount: cellCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        final d = gridStart.add(Duration(days: index));
        return _DayCell(
          date: d,
          doneKeys: doneKeys,
          inCurrentPeriod: d.month == month.month,
        );
      },
    );
  }
}

class _WeekGrid extends StatelessWidget {
  final DateTime weekStart;
  final Set<String> doneKeys;

  const _WeekGrid({required this.weekStart, required this.doneKeys});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(7, (i) {
        final d = weekStart.add(Duration(days: i));
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: AspectRatio(
              aspectRatio: 1,
              child: _DayCell(date: d, doneKeys: doneKeys, inCurrentPeriod: true),
            ),
          ),
        );
      }),
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime date;
  final Set<String> doneKeys;
  final bool inCurrentPeriod;

  const _DayCell({
    required this.date,
    required this.doneKeys,
    required this.inCurrentPeriod,
  });

  @override
  Widget build(BuildContext context) {
    final key = HabitLogsRepository.dateKey(date);
    final isDone = doneKeys.contains(key);
    final now = DateTime.now();
    final isToday = now.year == date.year &&
        now.month == date.month &&
        now.day == date.day;

    final color = isDone
        ? const Color(0xFF9BCB4A).withValues(alpha: inCurrentPeriod ? 0.9 : 0.5)
        : Colors.white.withValues(alpha: inCurrentPeriod ? 0.07 : 0.03);

    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isToday ? const Color(0xFF7C5CFF) : Colors.white.withValues(alpha: 0.03),
          width: 1.4,
        ),
      ),
      child: Text(
        '${date.day}',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: inCurrentPeriod ? Colors.white : Colors.white38,
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final swatches = [
      Colors.white.withValues(alpha: 0.07),
      const Color(0xFF6EA43A),
      const Color(0xFF8ABA45),
      const Color(0xFFA6CF57),
      const Color(0xFFC2DD6B),
    ];

    return Row(
      children: [
        Text(
          'Habit Completion',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.white70),
        ),
        const SizedBox(width: 14),
        ...swatches.map((c) {
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: _LegendDot(color: c),
          );
        }),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  const _LegendDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
