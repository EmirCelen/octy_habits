import 'dart:convert';
import 'dart:math' as math;

class MlRiskModel {
  final double intercept;
  final Map<String, double> weights;

  const MlRiskModel({
    required this.intercept,
    required this.weights,
  });

  factory MlRiskModel.fromJson(Map<String, dynamic> json) {
    final w = <String, double>{};
    final raw = json['weights'];
    if (raw is Map<String, dynamic>) {
      for (final e in raw.entries) {
        final v = e.value;
        if (v is num) w[e.key] = v.toDouble();
      }
    }
    return MlRiskModel(
      intercept: (json['intercept'] is num) ? (json['intercept'] as num).toDouble() : 0.0,
      weights: w,
    );
  }

  static MlRiskModel? tryParse(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return MlRiskModel.fromJson(decoded);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  double predictProbability(Map<String, double> features) {
    double z = intercept;
    for (final e in features.entries) {
      final w = weights[e.key];
      if (w == null) continue;
      z += w * e.value;
    }
    return _sigmoid(z);
  }

  double _sigmoid(double x) {
    // Numerically stable sigmoid.
    if (x >= 0) {
      final expNeg = math.exp(-x);
      return 1 / (1 + expNeg);
    } else {
      final expPos = math.exp(x);
      return expPos / (1 + expPos);
    }
  }
}
