import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum GoalCategory {
  emergencyFund('Emergency Fund', Icons.health_and_safety, Color(0xFFEF4444)),
  homePurchase('Home Purchase', Icons.home, Color(0xFF3B82F6)),
  vehiclePurchase('Vehicle Purchase', Icons.directions_car, Color(0xFFF59E0B)),
  education('Education', Icons.school, Color(0xFF10B981)),
  marriage('Marriage', Icons.favorite, Color(0xFFEC4899)),
  retirement('Retirement', Icons.beach_access, Color(0xFF8B5CF6)),
  travel('Travel', Icons.flight_takeoff, Color(0xFF06B6D4)),
  custom('Custom Goal', Icons.flag, Color(0xFFC9A96E));

  const GoalCategory(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;

  static GoalCategory fromString(String? val) {
    if (val == null) return GoalCategory.custom;
    for (final cat in GoalCategory.values) {
      if (cat.name.toLowerCase() == val.toLowerCase() ||
          cat.label.toLowerCase() == val.toLowerCase()) {
        return cat;
      }
    }
    return GoalCategory.custom;
  }
}

enum GoalStatus {
  active('Active', Color(0xFF10B981)),
  paused('Paused', Color(0xFFF59E0B)),
  completed('Completed', Color(0xFF00E5FF));

  const GoalStatus(this.label, this.color);

  final String label;
  final Color color;

  static GoalStatus fromString(String? val) {
    if (val == null) return GoalStatus.active;
    for (final status in GoalStatus.values) {
      if (status.name.toLowerCase() == val.toLowerCase() ||
          status.label.toLowerCase() == val.toLowerCase()) {
        return status;
      }
    }
    return GoalStatus.active;
  }
}

class FinancialGoal {
  FinancialGoal({
    required this.id,
    required this.name,
    required this.category,
    required this.targetAmount,
    this.currentSavings = 0.0,
    required this.targetMonths,
    required this.targetDate,
    this.isInflationEnabled = true,
    this.annualInflationRate = 6.0,
    this.expectedAnnualReturn = 12.0,
    required this.monthlyContribution,
    this.status = GoalStatus.active,
    required this.createdAt,
    required this.updatedAt,
    this.notes,
  });

  factory FinancialGoal.fromJson(Map<String, dynamic> json) {
    final months = (json['targetMonths'] as num?)?.toInt() ?? 60;
    final created = json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
        : DateTime.now();
    final targetDate = json['targetDate'] != null
        ? DateTime.tryParse(json['targetDate'].toString()) ??
            created.add(Duration(days: months * 30))
        : created.add(Duration(days: months * 30));

    return FinancialGoal(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name'] as String? ?? 'Financial Goal',
      category: GoalCategory.fromString(json['category']?.toString()),
      targetAmount: (json['targetAmount'] as num?)?.toDouble() ?? 100000.0,
      currentSavings: (json['currentSavings'] as num?)?.toDouble() ?? 0.0,
      targetMonths: months,
      targetDate: targetDate,
      isInflationEnabled: json['isInflationEnabled'] as bool? ?? true,
      annualInflationRate: (json['annualInflationRate'] as num?)?.toDouble() ?? 6.0,
      expectedAnnualReturn: (json['expectedAnnualReturn'] as num?)?.toDouble() ?? 12.0,
      monthlyContribution: (json['monthlyContribution'] as num?)?.toDouble() ?? 0.0,
      status: GoalStatus.fromString(json['status']?.toString()),
      createdAt: created,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString()) ?? created
          : created,
      notes: json['notes'] as String?,
    );
  }

  final String id;
  final String name;
  final GoalCategory category;
  final double targetAmount;
  final double currentSavings;
  final int targetMonths;
  final DateTime targetDate;
  final bool isInflationEnabled;
  final double annualInflationRate;
  final double expectedAnnualReturn;
  final double monthlyContribution;
  final GoalStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? notes;

  /// Progress ratio clamped from 0.0 to 1.0.
  double get progress {
    if (targetAmount <= 0) return 1.0;
    return (currentSavings / targetAmount).clamp(0.0, 1.0);
  }

  /// Progress percentage (0.0 to 100.0).
  double get progressPercent => progress * 100.0;

  /// Whether the goal has achieved target or is explicitly marked completed.
  bool get isCompleted =>
      status == GoalStatus.completed || (targetAmount > 0 && currentSavings >= targetAmount);

  /// Whether an active goal is at risk of missing its target date.
  bool get isAtRisk {
    if (isCompleted || status == GoalStatus.paused) return false;
    final now = DateTime.now();
    if (targetDate.isBefore(now)) return true;
    final remainingDays = targetDate.difference(now).inDays;
    // Less than 90 days left with under 75% progress
    return remainingDays <= 90 && progress < 0.75;
  }

  /// Formatted target date string.
  String get formattedTargetDate {
    return DateFormat('MMM y').format(targetDate);
  }

  /// Remaining duration in human-readable terms.
  String get remainingTimeText {
    final now = DateTime.now();
    if (targetDate.isBefore(now)) {
      return 'Target date reached';
    }
    final months = ((targetDate.difference(now).inDays) / 30.44).round();
    if (months < 12) {
      return '$months mos left';
    }
    final years = (months / 12).toStringAsFixed(1);
    return '$years yrs left';
  }

  FinancialGoal copyWith({
    String? id,
    String? name,
    GoalCategory? category,
    double? targetAmount,
    double? currentSavings,
    int? targetMonths,
    DateTime? targetDate,
    bool? isInflationEnabled,
    double? annualInflationRate,
    double? expectedAnnualReturn,
    double? monthlyContribution,
    GoalStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? notes,
  }) {
    return FinancialGoal(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      targetAmount: targetAmount ?? this.targetAmount,
      currentSavings: currentSavings ?? this.currentSavings,
      targetMonths: targetMonths ?? this.targetMonths,
      targetDate: targetDate ?? this.targetDate,
      isInflationEnabled: isInflationEnabled ?? this.isInflationEnabled,
      annualInflationRate: annualInflationRate ?? this.annualInflationRate,
      expectedAnnualReturn: expectedAnnualReturn ?? this.expectedAnnualReturn,
      monthlyContribution: monthlyContribution ?? this.monthlyContribution,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category.name,
      'targetAmount': targetAmount,
      'currentSavings': currentSavings,
      'targetMonths': targetMonths,
      'targetDate': targetDate.toIso8601String(),
      'isInflationEnabled': isInflationEnabled,
      'annualInflationRate': annualInflationRate,
      'expectedAnnualReturn': expectedAnnualReturn,
      'monthlyContribution': monthlyContribution,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      if (notes != null) 'notes': notes,
    };
  }
}
