import 'package:flutter/material.dart';

/// Represents an immutable educational topic in Financial Management.
class FinancialManagementTopic {
  const FinancialManagementTopic({
    required this.id,
    required this.title,
    required this.shortDescription,
    required this.icon,
    required this.whatIsIt,
    required this.whyItMatters,
    required this.howItWorks,
    this.formulaOrRule,
    this.example,
    this.practicalUses = const [],
    this.importantPoints = const [],
    this.disclaimer,
    this.relatedCalculatorRoute,
    this.relatedCalculatorLabel,
    this.isKeyTopic = false,
  });

  final String id;
  final String title;
  final String shortDescription;
  final IconData icon;
  final String whatIsIt;
  final String whyItMatters;
  final String howItWorks;
  final String? formulaOrRule;
  final String? example;
  final List<String> practicalUses;
  final List<String> importantPoints;
  final String? disclaimer;
  final String? relatedCalculatorRoute;
  final String? relatedCalculatorLabel;
  final bool isKeyTopic;
}
