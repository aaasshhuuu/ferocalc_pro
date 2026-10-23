import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Data model representing a saved calculation snapshot in local storage.
class CalculationHistoryEntry {
  final String id;
  final String calculatorId;
  final String calculatorName;
  final DateTime timestamp;
  final Map<String, String> inputs;
  final Map<String, String> results;
  final String primaryResultLabel;
  final String primaryResultValue;
  final String? category;
  final Map<String, dynamic>? rawInputs;

  CalculationHistoryEntry({
    required this.id,
    required this.calculatorId,
    required this.calculatorName,
    required this.timestamp,
    required this.inputs,
    required this.results,
    required this.primaryResultLabel,
    required this.primaryResultValue,
    this.category,
    this.rawInputs,
  });

  /// Formatted date string for user presentation (device-local).
  String get formattedDateTime {
    final localTime = timestamp.toLocal();
    final now = DateTime.now();
    final isToday = localTime.year == now.year &&
        localTime.month == now.month &&
        localTime.day == now.day;
    final isYesterday = localTime.year == now.year &&
        localTime.month == now.month &&
        localTime.day == now.day - 1;

    final timeStr = DateFormat('h:mm a').format(localTime);
    if (isToday) {
      return 'Today, $timeStr';
    } else if (isYesterday) {
      return 'Yesterday, $timeStr';
    } else {
      return '${DateFormat('d MMM y').format(localTime)}, $timeStr';
    }
  }

  /// Recognizable calculator icon based on calculatorId or category.
  IconData get icon {
    switch (calculatorId) {
      case 'emi':
      case 'credit_card_emi':
        return Icons.calculate;
      case 'loan_amount':
        return Icons.account_balance_wallet;
      case 'loan_term':
        return Icons.access_time;
      case 'interest_rate':
        return Icons.percent;
      case 'home_loan_eligibility':
        return Icons.home;
      case 'personal_loan_eligibility':
        return Icons.person;
      case 'fd':
        return Icons.account_balance;
      case 'rd':
        return Icons.update;
      case 'savings':
        return Icons.savings;
      case 'ppf':
        return Icons.assured_workload;
      case 'sip':
        return Icons.trending_up;
      case 'swp':
        return Icons.trending_down;
      case 'lumpsum':
        return Icons.monetization_on;
      case 'cagr':
        return Icons.stacked_line_chart;
      case 'stock_return':
        return Icons.candlestick_chart;
      case 'dividend_yield':
        return Icons.payments;
      case 'nps':
        return Icons.elderly;
      case 'epf':
        return Icons.business;
      case 'income_tax':
        return Icons.request_quote;
      case 'gst':
        return Icons.receipt;
      case 'retirement':
      case 'retirement_planner':
        return Icons.beach_access;
      case 'goal':
      case 'goal_planner':
        return Icons.flag;
      case 'education':
      case 'education_planner':
        return Icons.school;
      case 'inflation':
        return Icons.show_chart;
      case 'sukanya':
      case 'sukanya_samriddhi':
        return Icons.child_care;
      case 'simple_interest':
        return Icons.percent;
      case 'compound_interest':
        return Icons.trending_up;
      default:
        return Icons.calculate_outlined;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'calculatorId': calculatorId,
      'calculatorName': calculatorName,
      'timestamp': timestamp.toIso8601String(),
      'inputs': inputs,
      'results': results,
      'primaryResultLabel': primaryResultLabel,
      'primaryResultValue': primaryResultValue,
      'category': category,
      if (rawInputs != null) 'rawInputs': rawInputs,
    };
  }

  factory CalculationHistoryEntry.fromJson(Map<String, dynamic> json) {
    Map<String, String> safeInputs = {};
    if (json['inputs'] is Map) {
      (json['inputs'] as Map).forEach((k, v) {
        if (k != null) safeInputs[k.toString()] = v?.toString() ?? '';
      });
    }

    Map<String, String> safeResults = {};
    if (json['results'] is Map) {
      (json['results'] as Map).forEach((k, v) {
        if (k != null) safeResults[k.toString()] = v?.toString() ?? '';
      });
    }

    Map<String, dynamic>? safeRawInputs;
    if (json['rawInputs'] is Map) {
      safeRawInputs = Map<String, dynamic>.from(json['rawInputs'] as Map);
    }

    return CalculationHistoryEntry(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      calculatorId: json['calculatorId'] as String? ?? 'unknown',
      calculatorName: json['calculatorName'] as String? ?? 'Calculation',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      inputs: safeInputs,
      results: safeResults,
      primaryResultLabel: json['primaryResultLabel'] as String? ?? 'Result',
      primaryResultValue: json['primaryResultValue'] as String? ?? '',
      category: json['category'] as String? ?? 'General',
      rawInputs: safeRawInputs,
    );
  }
}
