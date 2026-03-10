import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/notifications/local_notifications_service.dart';
import '../../data/repositories/providers.dart';

class IntroPage extends StatefulWidget {
  const IntroPage({super.key});

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _introController;
  late final Animation<double> _circleScale;
  late final Animation<double> _circleOpacity;
  late final Animation<double> _textOpacity;

  static const _poses = <String>[
    'assets/octy/octy_happy.jpg',
    'assets/octy/octy_thinking.jpg',
    'assets/octy/octy_sleepy.jpg',
    'assets/octy/octy_sad.jpg',
  ];

  int _poseIndex = 0;
  Timer? _poseTimer;

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _circleScale = Tween<double>(begin: 1, end: 0.05).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.62, 0.95, curve: Curves.easeInBack),
      ),
    );
    _circleOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.62, 1, curve: Curves.easeOut),
      ),
    );
    _textOpacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.52, 0.86, curve: Curves.easeOut),
      ),
    );

    _poseTimer = Timer.periodic(const Duration(milliseconds: 450), (_) {
      if (!mounted) return;
      setState(() {
        _poseIndex = (_poseIndex + 1) % _poses.length;
      });
    });

    _introController.forward().whenComplete(() {
      if (!mounted) return;
      context.go('/gate');
    });
  }

  @override
  void dispose() {
    _poseTimer?.cancel();
    _introController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF101326), Color(0xFF090B15)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _introController,
                  builder: (context, _) {
                    return Opacity(
                      opacity: _circleOpacity.value,
                      child: Transform.scale(
                        scale: _circleScale.value,
                        child: Container(
                          width: 250,
                          height: 250,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF7C5CFF,
                                ).withValues(alpha: 0.18),
                                blurRadius: 28,
                                spreadRadius: 6,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 260),
                              child: ColorFiltered(
                                key: ValueKey(_poses[_poseIndex]),
                                colorFilter: ColorFilter.mode(
                                  Colors.black.withValues(alpha: 0.12),
                                  BlendMode.darken,
                                ),
                                child: Image.asset(
                                  _poses[_poseIndex],
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                FadeTransition(
                  opacity: _textOpacity,
                  child: Text(
                    'Merhaba, ben Octy.',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StartupGatePage extends ConsumerWidget {
  const StartupGatePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);

    return authAsync.when(
      loading: () => const _FullPageLoader(),
      error: (e, _) => _FullPageError(message: 'Auth error: $e'),
      data: (user) {
        if (user == null) return const _AuthPage();
        _logAppOpenIfNeeded(ref);

        final profileAsync = ref.watch(userProfileProvider(user.uid));
        return profileAsync.when(
          loading: () => const _FullPageLoader(),
          error: (e, _) => _FullPageError(message: 'Profile error: $e'),
          data: (profile) {
            final onboardingDone = profile?['onboardingCompleted'] == true;
            final setupDone = profile?['setupCompleted'] == true;
            _syncReminderFromProfile(profile);

            if (!onboardingDone) return _OnboardingPage(uid: user.uid);
            if (!setupDone) return _SetupPage(uid: user.uid);

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) context.go('/home');
            });
            return const _FullPageLoader();
          },
        );
      },
    );
  }
}

void _syncReminderFromProfile(Map<String, dynamic>? profile) {
  final enabled = profile?['remindersEnabled'] != false;
  final hour = (profile?['reminderHour'] ?? 21) as int;
  final minute = (profile?['reminderMinute'] ?? 0) as int;
  final dynamic daysRaw = profile?['reminderDays'];
  final days = (daysRaw is List && daysRaw.length == 7)
      ? daysRaw.map((e) => e == true).toList()
      : List<bool>.filled(7, true);

  unawaited(
    LocalNotificationsService.instance.syncWeeklyReminder(
      enabled: enabled,
      hour: hour,
      minute: minute,
      days: days,
    ),
  );
}

DateTime? _lastAppOpenLogAt;

void _logAppOpenIfNeeded(WidgetRef ref) {
  final now = DateTime.now();
  if (_lastAppOpenLogAt != null &&
      now.difference(_lastAppOpenLogAt!).inMinutes < 10) {
    return;
  }
  _lastAppOpenLogAt = now;
  unawaited(
    ref.read(appEventsRepositoryProvider).logEventSafe(type: 'app_open'),
  );
}

class _AuthPage extends ConsumerStatefulWidget {
  const _AuthPage();

  @override
  ConsumerState<_AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<_AuthPage> {
  bool _loading = false;

  Future<void> _signInAnonymously() async {
    setState(() => _loading = true);
    try {
      await ref.read(firebaseAuthProvider).signInAnonymously();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Giris yapilamadi: ${e.code}')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF10162A), Color(0xFF080C17)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _GlassPanel(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ClipOval(
                        child: SizedBox(
                          width: 132,
                          height: 132,
                          child: Image.asset(
                            'assets/octy/octy_happy.jpg',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Octy Habits',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Aliskanlik takibini baslatmak icin devam et.',
                        textAlign: TextAlign.center,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton(
                        onPressed: _loading ? null : _signInAnonymously,
                        child: Text(_loading ? 'Baglaniyor...' : 'Devam Et'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OnboardingPage extends ConsumerStatefulWidget {
  final String uid;
  const _OnboardingPage({required this.uid});

  @override
  ConsumerState<_OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<_OnboardingPage> {
  static const _steps = <(String title, String body)>[
    (
      'Hedeflerini sec',
      'Kendine uygun haftalik hedef koy, Octy kalanini takip etsin.',
    ),
    (
      'Her gun tek dokunus',
      'Sadece bugunku kutuyu isaretle. Zincirin bozulmadan buyusun.',
    ),
    (
      'Ilerlemeni gor',
      'Stats ve Calendar ile neyin ise yaradigini net sekilde gor.',
    ),
  ];

  bool _saving = false;
  int _step = 0;

  Future<void> _completeOnboarding() async {
    setState(() => _saving = true);
    try {
      await ref
          .read(firestoreProvider)
          .collection('users')
          .doc(widget.uid)
          .set({
            'onboardingCompleted': true,
            'setupCompleted': false,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _step == _steps.length - 1;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF10162A), Color(0xFF080C17)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _GlassPanel(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Hos geldin!',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 14),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Column(
                          key: ValueKey(_step),
                          children: [
                            Text(
                              _steps[_step].$1,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _steps[_step].$2,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_steps.length, (i) {
                          final selected = i == _step;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: selected ? 18 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: selected
                                  ? const Color(0xFF7C5CFF)
                                  : Colors.white24,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton(
                        onPressed: _saving
                            ? null
                            : () async {
                                if (isLast) {
                                  await _completeOnboarding();
                                  return;
                                }
                                setState(() => _step += 1);
                              },
                        child: Text(
                          _saving
                              ? 'Kaydediliyor...'
                              : (isLast ? 'Basla' : 'Devam'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SetupPage extends ConsumerStatefulWidget {
  final String uid;
  const _SetupPage({required this.uid});

  @override
  ConsumerState<_SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends ConsumerState<_SetupPage> {
  final TextEditingController _titleCtrl = TextEditingController();
  int _goal = 4;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _finishSetup({required bool withSample}) async {
    setState(() => _saving = true);
    final db = ref.read(firestoreProvider);
    try {
      if (withSample) {
        final title = _titleCtrl.text.trim();
        if (title.isNotEmpty) {
          await db
              .collection('users')
              .doc(widget.uid)
              .collection('habits')
              .add({
                'title': title,
                'goalPerWeek': _goal,
                'colorValue': 0xFF7C5CFF,
                'isActive': true,
                'createdAt': FieldValue.serverTimestamp(),
                'currentStreak': 0,
                'longestStreak': 0,
                'lastCompletedDateKey': null,
              });
        }
      }

      await db.collection('users').doc(widget.uid).set({
        'setupCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF10162A), Color(0xFF080C17)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _GlassPanel(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Ilk aliskanligini ekle',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Sadece bir tane ekle. Sonra istedigin kadar buyutursun.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _titleCtrl,
                        decoration: const InputDecoration(labelText: 'Ornek: Su ic'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: _goal,
                        items: [1, 2, 3, 4, 5, 6, 7]
                            .map(
                              (v) => DropdownMenuItem<int>(
                                value: v,
                                child: Text('$v'),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _goal = v ?? 4),
                        decoration: const InputDecoration(labelText: 'Hedef/hafta'),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton(
                        onPressed: _saving
                            ? null
                            : () => _finishSetup(withSample: true),
                        child: Text(_saving ? 'Hazirlaniyor...' : 'Takibe Basla'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => _finishSetup(withSample: false),
                        child: const Text('Simdilik atla'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FullPageLoader extends StatelessWidget {
  const _FullPageLoader();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _FullPageError extends StatelessWidget {
  final String message;
  const _FullPageError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(message)));
  }
}

class _GlassPanel extends StatelessWidget {
  final Widget child;
  const _GlassPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}
