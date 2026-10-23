import 'package:flutter/material.dart';

import 'financial_management_topic.dart';

/// Represents an immutable educational topic in the Financial Literacy Hub.
class FinancialLiteracyTopic {
  const FinancialLiteracyTopic({
    required this.id,
    required this.title,
    required this.shortDescription,
    required this.category,
    this.keywords = const [],
    this.isImportant = false,
    this.icon = Icons.menu_book_rounded,
    required this.whatIsIt,
    required this.whyItMatters,
    required this.howItWorks,
    this.formulaOrFramework,
    this.example,
    this.practicalUses = const [],
    this.importantPoints = const [],
    this.limitations = const [],
    this.disclaimer,
    this.relatedCalculatorRoute,
    this.relatedCalculatorLabel,
    this.financialManagementTopicId,
  });

  /// Factory adapter to reuse an existing [FinancialManagementTopic] without duplicating content.
  factory FinancialLiteracyTopic.fromFinancialManagement({
    required FinancialManagementTopic managementTopic,
    required String category,
    List<String> keywords = const [],
    bool? isImportant,
    List<String> limitations = const [],
  }) {
    return FinancialLiteracyTopic(
      id: managementTopic.id,
      title: managementTopic.title,
      shortDescription: managementTopic.shortDescription,
      category: category,
      keywords: keywords,
      isImportant: isImportant ?? managementTopic.isKeyTopic,
      icon: managementTopic.icon,
      whatIsIt: managementTopic.whatIsIt,
      whyItMatters: managementTopic.whyItMatters,
      howItWorks: managementTopic.howItWorks,
      formulaOrFramework: managementTopic.formulaOrRule,
      example: managementTopic.example,
      practicalUses: managementTopic.practicalUses,
      importantPoints: managementTopic.importantPoints,
      limitations: limitations,
      disclaimer: managementTopic.disclaimer,
      relatedCalculatorRoute: managementTopic.relatedCalculatorRoute,
      relatedCalculatorLabel: managementTopic.relatedCalculatorLabel,
      financialManagementTopicId: managementTopic.id,
    );
  }

  final String id;
  final String title;
  final String shortDescription;
  final String category;
  final List<String> keywords;
  final bool isImportant;
  final IconData icon;
  final String whatIsIt;
  final String whyItMatters;
  final String howItWorks;
  final String? formulaOrFramework;
  final String? example;
  final List<String> practicalUses;
  final List<String> importantPoints;
  final List<String> limitations;
  final String? disclaimer;
  final String? relatedCalculatorRoute;
  final String? relatedCalculatorLabel;
  final String? financialManagementTopicId;
}
