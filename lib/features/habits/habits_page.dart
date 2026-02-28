import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/providers.dart';

class HabitsPage extends ConsumerWidget {
  const HabitsPage({super.key});

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    final titleCtrl = TextEditingController();
    int goal = 4;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Add Habit'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Title (e.g. Read)',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Goal/week:'),
                  const SizedBox(width: 12),
                  DropdownButton<int>(
                    value: goal,
                    items: [1, 2, 3, 4, 5, 6, 7]
                        .map(
                          (v) => DropdownMenuItem(value: v, child: Text('$v')),
                        )
                        .toList(),
                    onChanged: (v) => goal = v ?? 4,
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      final title = titleCtrl.text.trim();
      if (title.isEmpty) return;

      await ref
          .read(habitsRepositoryProvider)
          .addHabit(title: title, goalPerWeek: goal, colorValue: 0xFF7C5CFF);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(habitsStreamProvider);
    final todayAsync = ref.watch(todayCompletionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Habits')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: habitsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (habits) {
          if (habits.isEmpty) {
            return const Center(
              child: Text('No habits yet. Tap + to add one.'),
            );
          }

          // Bugünün completion map'ini bekliyoruz
          return todayAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (todayMap) {
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: habits.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) {
                  final h = habits[i];
                  final doneToday = todayMap[h.id] == true;

                  return Card(
                    child: ListTile(
                      title: Text(h.title),
                      subtitle: Text('Goal: ${h.goalPerWeek}/week'),
                      trailing: Checkbox(
                        value: doneToday,
                        onChanged: (v) async {
                          final completed = v ?? false;
                          await ref
                              .read(habitLogsRepositoryProvider)
                              .toggleToday(habitId: h.id, completed: completed);
                        },
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
