import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/habit.dart';
import '../../data/repositories/providers.dart';
import 'logic/octy_ai_service.dart';
import 'logic/octy_insight_engine.dart';

class AiAssistantPage extends ConsumerStatefulWidget {
  const AiAssistantPage({super.key});

  @override
  ConsumerState<AiAssistantPage> createState() => _AiAssistantPageState();
}

class _AiAssistantPageState extends ConsumerState<AiAssistantPage> {
  final TextEditingController _inputCtrl = TextEditingController();
  final List<_ChatMessage> _messages = [
    const _ChatMessage(
      role: _MessageRole.assistant,
      text: 'Ben Octy. Bugun hangi aliskanlikta takildigini yaz, birlikte net bir plan cikaralim.',
    ),
  ];
  bool _sending = false;
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _seeded) return;
      final insight = ref.read(octyInsightProvider);
      setState(() {
        _messages.add(
          _ChatMessage(role: _MessageRole.assistant, text: insight.microNudge),
        );
        _seeded = true;
      });
    });
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  Future<void> _send({
    required List<Habit> habits,
    required Map<String, bool> todayMap,
    required List<int> weeklyDailyTotals,
    required int currentStreak,
  }) async {
    if (_sending) return;
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(role: _MessageRole.user, text: text));
      _sending = true;
      _inputCtrl.clear();
    });

    ref.read(appEventsRepositoryProvider).logEventSafe(
      type: 'assistant_message',
      data: {'length': text.length},
    );

    final pending = habits
        .where((h) => todayMap[h.id] != true)
        .map((h) => h.title)
        .toList(growable: false);

    final context = OctyAiContext(
      totalHabits: habits.length,
      doneToday: todayMap.values.where((v) => v).length,
      weeklyDoneTotal: weeklyDailyTotals.fold(0, (a, b) => a + b),
      currentStreak: currentStreak,
      pendingHabitTitles: pending,
    );

    final reply = await ref
        .read(octyAiServiceProvider)
        .generateReply(userMessage: text, context: context);

    if (!mounted) return;
    setState(() {
      _messages.add(_ChatMessage(role: _MessageRole.assistant, text: reply));
      _sending = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final habits = ref.watch(habitsStreamProvider).valueOrNull ?? const <Habit>[];
    final todayMap = ref.watch(todayCompletionsProvider).valueOrNull ?? const <String, bool>{};
    final weeklyDailyTotals =
        ref.watch(weeklyDailyTotalsProvider).valueOrNull ?? const <int>[0, 0, 0, 0, 0, 0, 0];
    final streak = ref.watch(streakSummaryProvider).current;
    final insight = ref.watch(octyInsightProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Octy Asistan'),
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF121B36), Color(0xFF070B17)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: _ContextBar(
                  doneToday: todayMap.values.where((v) => v).length,
                  totalHabits: habits.length,
                  streak: streak,
                  riskLevel: insight.riskLevel,
                  riskScore: insight.riskScore,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  itemCount: _messages.length + (_sending ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (_sending && i == _messages.length) {
                      return const Align(
                        alignment: Alignment.centerLeft,
                        child: _TypingBubble(),
                      );
                    }
                    final m = _messages[i];
                    final isUser = m.role == _MessageRole.user;
                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        constraints: const BoxConstraints(maxWidth: 310),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: isUser
                              ? const Color(0xFF7B61FF).withValues(alpha: 0.9)
                              : Colors.white.withValues(alpha: 0.09),
                          border: Border.all(
                            color: isUser
                                ? const Color(0xFF9EA9FF).withValues(alpha: 0.7)
                                : Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Text(m.text),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputCtrl,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(
                          habits: habits,
                          todayMap: todayMap,
                          weeklyDailyTotals: weeklyDailyTotals,
                          currentStreak: streak,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Octy\'ye yaz...',
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.08),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.09),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.09),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      onPressed: _sending
                          ? null
                          : () => _send(
                                habits: habits,
                                todayMap: todayMap,
                                weeklyDailyTotals: weeklyDailyTotals,
                                currentStreak: streak,
                              ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(52, 52),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _MessageRole { user, assistant }

class _ChatMessage {
  final _MessageRole role;
  final String text;
  const _ChatMessage({required this.role, required this.text});
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.09),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: const SizedBox(
        height: 18,
        width: 38,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _Dot(),
            _Dot(),
            _Dot(),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white70,
      ),
    );
  }
}

class _ContextBar extends StatelessWidget {
  final int doneToday;
  final int totalHabits;
  final int streak;
  final RiskLevel riskLevel;
  final double riskScore;

  const _ContextBar({
    required this.doneToday,
    required this.totalHabits,
    required this.streak,
    required this.riskLevel,
    required this.riskScore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.07),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        'Bugun: $doneToday/$totalHabits  •  Streak: $streak gun  •  Risk: ${_riskLabel(riskLevel)} ${(riskScore * 100).round()}%',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Colors.white70,
        ),
      ),
    );
  }

  String _riskLabel(RiskLevel level) {
    switch (level) {
      case RiskLevel.low:
        return 'Dusuk';
      case RiskLevel.medium:
        return 'Orta';
      case RiskLevel.high:
        return 'Yuksek';
    }
  }
}
