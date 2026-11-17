import '../../domain/models/financial_profile.dart';

/// Data transfer model for local SharedPreferences serialization.
class FinancialProfileModel {
  static FinancialProfile fromJson(Map<String, dynamic> json) {
    return FinancialProfile(
      monthlyIncome: ((json['monthlyIncome'] as num?) ?? 0.0).toDouble(),
      essentialExpenses:
          ((json['essentialExpenses'] as num?) ?? 0.0).toDouble(),
      discretionaryExpenses:
          ((json['discretionaryExpenses'] as num?) ?? 0.0).toDouble(),
      monthlyEmi: ((json['monthlyEmi'] as num?) ?? 0.0).toDouble(),
      declaredSavings:
          ((json['declaredSavings'] as num?) ?? 0.0).toDouble(),
      emergencySavings:
          ((json['emergencySavings'] as num?) ?? 0.0).toDouble(),
      emergencyTargetMonths:
          (json['emergencyTargetMonths'] as num?)?.toInt() ?? 6,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  static Map<String, dynamic> toJson(FinancialProfile profile) {
    return {
      'monthlyIncome': profile.monthlyIncome,
      'essentialExpenses': profile.essentialExpenses,
      'discretionaryExpenses': profile.discretionaryExpenses,
      'monthlyEmi': profile.monthlyEmi,
      'declaredSavings': profile.declaredSavings,
      'emergencySavings': profile.emergencySavings,
      'emergencyTargetMonths': profile.emergencyTargetMonths,
      'updatedAt': profile.updatedAt?.toIso8601String() ??
          DateTime.now().toIso8601String(),
    };
  }
}
