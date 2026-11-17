import 'package:flutter/material.dart';

enum InsightSeverity {
  positive(Color(0xFF10B981), Icons.check_circle_outline),
  info(Color(0xFF00D2D3), Icons.info_outline),
  warning(Color(0xFFF59E0B), Icons.warning_amber_rounded),
  alert(Color(0xFFEF4444), Icons.error_outline),
  neutral(Color(0xFF94A3B8), Icons.lightbulb_outline);

  const InsightSeverity(this.color, this.icon);
  final Color color;
  final IconData icon;
}

enum HabitInsightType {
  cashFlowBalance,
  savingsRate,
  emergencyReadiness,
  emiBurden,
  goalAffordability,
  budgetAllocation503020,
}

/// A deterministic, transparent rule-based financial insight derived purely from user-entered inputs.
class HabitInsight {
  const HabitInsight({
    required this.id,
    required this.type,
    required this.title,
    required this.calculatedValue,
    required this.explanation,
    required this.disclaimer,
    required this.severity,
    this.actionLabel,
    this.actionRoute,
    this.actionPayload,
  });

  final String id;
  final HabitInsightType type;
  final String title;
  final String calculatedValue;
  final String explanation;
  final String disclaimer;
  final InsightSeverity severity;
  final String? actionLabel;
  final String? actionRoute;
  final dynamic actionPayload;
}
