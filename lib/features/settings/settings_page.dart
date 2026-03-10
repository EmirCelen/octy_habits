import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/notifications/local_notifications_service.dart';
import '../../data/repositories/providers.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  Future<void> _savePreference({
    required WidgetRef ref,
    required String uid,
    required String key,
    required bool value,
  }) async {
    await ref.read(firestoreProvider).collection('users').doc(uid).set({
      key: value,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _saveReminderTime({
    required WidgetRef ref,
    required String uid,
    required TimeOfDay time,
  }) async {
    await ref.read(firestoreProvider).collection('users').doc(uid).set({
      'reminderHour': time.hour,
      'reminderMinute': time.minute,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _saveReminderDays({
    required WidgetRef ref,
    required String uid,
    required List<bool> selected,
  }) async {
    await ref.read(firestoreProvider).collection('users').doc(uid).set({
      'reminderDays': selected,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _syncReminders({
    required bool enabled,
    required TimeOfDay time,
    required List<bool> days,
  }) async {
    final service = LocalNotificationsService.instance;
    await service.requestPermissions();
    await service.syncWeeklyReminder(
      enabled: enabled,
      hour: time.hour,
      minute: time.minute,
      days: days,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: authAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (user) {
              if (user == null) {
                return Center(
                  child: ElevatedButton(
                    onPressed: () => context.go('/gate'),
                    child: const Text('Girise Git'),
                  ),
                );
              }

              final profileAsync = ref.watch(userProfileProvider(user.uid));
              return profileAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (profile) {
                  final reminders = profile?['remindersEnabled'] != false;
                  final mondayFirst = profile?['mondayFirst'] == true;
                  final hour = (profile?['reminderHour'] ?? 21) as int;
                  final minute = (profile?['reminderMinute'] ?? 0) as int;
                  final time = TimeOfDay(hour: hour, minute: minute);
                  final dynamic daysRaw = profile?['reminderDays'];
                  final reminderDays = (daysRaw is List && daysRaw.length == 7)
                      ? daysRaw.map((e) => e == true).toList()
                      : List<bool>.filled(7, true);

                  return ListView(
                    children: [
                      _Section(
                        title: 'Tercihler',
                        child: Column(
                          children: [
                            SwitchListTile(
                              value: reminders,
                              title: const Text('Gunluk hatirlatici'),
                              subtitle: const Text('Her gun kisa bir durtme al.'),
                              onChanged: (v) => _savePreference(
                                ref: ref,
                                uid: user.uid,
                                key: 'remindersEnabled',
                                value: v,
                              ).then(
                                (_) => _syncReminders(
                                  enabled: v,
                                  time: time,
                                  days: reminderDays,
                                ),
                              ),
                            ),
                            ListTile(
                              leading: const Icon(Icons.schedule_rounded),
                              title: const Text('Hatirlatici saati'),
                              subtitle: Text(
                                '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                              ),
                              onTap: () async {
                                final picked = await showTimePicker(
                                  context: context,
                                  initialTime: time,
                                );
                                if (picked == null) return;
                                await _saveReminderTime(
                                  ref: ref,
                                  uid: user.uid,
                                  time: picked,
                                );
                                await _syncReminders(
                                  enabled: reminders,
                                  time: picked,
                                  days: reminderDays,
                                );
                              },
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: List.generate(7, (i) {
                                  const labels = [
                                    'Paz',
                                    'Pzt',
                                    'Sal',
                                    'Car',
                                    'Per',
                                    'Cum',
                                    'Cmt',
                                  ];
                                  return FilterChip(
                                    label: Text(labels[i]),
                                    selected: reminderDays[i],
                                    onSelected: (v) async {
                                      final next = [...reminderDays];
                                      next[i] = v;
                                      await _saveReminderDays(
                                        ref: ref,
                                        uid: user.uid,
                                        selected: next,
                                      );
                                      await _syncReminders(
                                        enabled: reminders,
                                        time: time,
                                        days: next,
                                      );
                                    },
                                  );
                                }),
                              ),
                            ),
                            SwitchListTile(
                              value: mondayFirst,
                              title: const Text('Hafta Pazartesi baslar'),
                              subtitle: const Text('Takvim hizalamasini etkiler.'),
                              onChanged: (v) => _savePreference(
                                ref: ref,
                                uid: user.uid,
                                key: 'mondayFirst',
                                value: v,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _Section(
                        title: 'Hesap',
                        child: ListTile(
                          leading: const Icon(Icons.logout),
                          title: const Text('Cikis yap'),
                          onTap: () async {
                            await ref.read(firebaseAuthProvider).signOut();
                            if (context.mounted) context.go('/gate');
                          },
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
