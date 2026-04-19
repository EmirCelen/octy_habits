import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

final octyAiServiceProvider = Provider<OctyAiService>((ref) {
  return const OctyAiService();
});

class OctyAiContext {
  final int totalHabits;
  final int doneToday;
  final int weeklyDoneTotal;
  final int currentStreak;
  final List<String> pendingHabitTitles;

  const OctyAiContext({
    required this.totalHabits,
    required this.doneToday,
    required this.weeklyDoneTotal,
    required this.currentStreak,
    required this.pendingHabitTitles,
  });

  Map<String, dynamic> toJson() {
    return {
      'totalHabits': totalHabits,
      'doneToday': doneToday,
      'weeklyDoneTotal': weeklyDoneTotal,
      'currentStreak': currentStreak,
      'pendingHabitTitles': pendingHabitTitles,
    };
  }
}

class OctyAiService {
  const OctyAiService();

  static const String _endpoint = String.fromEnvironment('OCTY_AI_ENDPOINT');
  static const String _apiKey = String.fromEnvironment('OCTY_AI_KEY');
  static const String _systemPrompt =
      'You are Octy, a concise Turkish habit coach. Keep tone warm and practical. '
      'Use 2-4 short sentences. Give one concrete next action. Never provide medical or legal advice.';

  Future<String> generateReply({
    required String userMessage,
    required OctyAiContext context,
  }) async {
    if (_endpoint.trim().isEmpty) {
      return _fallbackReply(userMessage: userMessage, context: context);
    }

    try {
      final client = HttpClient();
      final uri = Uri.parse(_endpoint);
      final req = await client.postUrl(uri).timeout(const Duration(seconds: 12));
      req.headers.contentType = ContentType.json;
      if (_apiKey.trim().isNotEmpty) {
        req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_apiKey');
      }

      final body = jsonEncode({
        'message': userMessage,
        'context': context.toJson(),
        'system': _systemPrompt,
      });
      req.write(body);

      final res = await req.close().timeout(const Duration(seconds: 20));
      final raw = await utf8.decodeStream(res);
      client.close();

      if (res.statusCode < 200 || res.statusCode >= 300) {
        return _fallbackReply(userMessage: userMessage, context: context);
      }

      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final direct = decoded['reply'];
        if (direct is String && direct.trim().isNotEmpty) {
          return direct.trim();
        }

        final outputText = decoded['output_text'];
        if (outputText is String && outputText.trim().isNotEmpty) {
          return outputText.trim();
        }

        final choices = decoded['choices'];
        if (choices is List && choices.isNotEmpty) {
          final first = choices.first;
          if (first is Map<String, dynamic>) {
            final message = first['message'];
            if (message is Map<String, dynamic>) {
              final content = message['content'];
              if (content is String && content.trim().isNotEmpty) {
                return content.trim();
              }
            }
          }
        }
      }

      return _fallbackReply(userMessage: userMessage, context: context);
    } catch (_) {
      return _fallbackReply(userMessage: userMessage, context: context);
    }
  }

  String _fallbackReply({
    required String userMessage,
    required OctyAiContext context,
  }) {
    final lower = userMessage.toLowerCase();
    final remaining = context.totalHabits - context.doneToday;
    final pending = context.pendingHabitTitles.take(2).toList();
    final firstPending = pending.isNotEmpty ? pending.first : null;

    if (context.totalHabits == 0) {
      return 'Henüz alışkanlık yok. Bugün sadece 1 tane ekle: küçük ve net bir hedef seç, sonra birlikte planlayalım.';
    }

    if (lower.contains('plan') || lower.contains('ne yap')) {
      if (firstPending != null) {
        return 'Bugün odak: "$firstPending". Şimdi 5 dakikalık mini bir tur başlat. Bitirince ikinci adım olarak kalanlardan birini seç.';
      }
      return 'Bugün harika gidiyorsun. Bir mini tekrar turu yap ve yarın için tek bir net saat belirle.';
    }

    if (lower.contains('motiv') || lower.contains('zor') || lower.contains('usengec')) {
      if (remaining <= 0) {
        return 'Bugün tamamsın, güzel iş. Zinciri korumak için yarın en kolay alışkanlıkla başla.';
      }
      return 'Şu an mükemmel olman gerekmiyor. Sadece 1 alışkanlığı tamamla ve ivmeyi aç; gerisi daha kolay gelecek.';
    }

    if (remaining <= 0) {
      return 'Bugün tüm hedefleri tamamladın. Bu ritmi korumak için yarın ilk alışkanlığa saat koyup sabitle.';
    }

    return 'Bugün ${context.doneToday}/${context.totalHabits} durumundasın. Şimdi tek bir alışkanlık seç ve 5 dakika uygula. Sonra bana "bitti" yaz, bir sonraki adımı vereyim.';
  }
}
