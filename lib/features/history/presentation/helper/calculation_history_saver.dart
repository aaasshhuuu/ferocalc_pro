import 'package:flutter/material.dart';
import '../../../../injection_container.dart' as di;
import '../../domain/repositories/calculation_history_repository.dart';

class CalculationHistorySaver {
  /// Asynchronously saves a completed calculation to local history.
  /// Guarantees that any exception is safely caught and will never crash the calculator.
  static Future<void> save({
    BuildContext? context,
    required String calculatorId,
    required String calculatorName,
    required Map<String, String> inputs,
    required Map<String, String> results,
    String? primaryResultLabel,
    String? primaryResultValue,
    String? category,
    Map<String, dynamic>? rawInputs,
    bool showFeedback = true,
  }) async {
    try {
      // Guard against empty / incomplete calculation results
      if (inputs.isEmpty || results.isEmpty) {
        return;
      }

      final label = primaryResultLabel ?? results.keys.first;
      final value = primaryResultValue ?? results.values.first;

      final entry = CalculationHistoryEntry(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        calculatorId: calculatorId,
        calculatorName: calculatorName,
        timestamp: DateTime.now(),
        inputs: Map<String, String>.from(inputs),
        results: Map<String, String>.from(results),
        primaryResultLabel: label,
        primaryResultValue: value,
        category: category,
        rawInputs: rawInputs,
      );

      final repository = di.sl<CalculationHistoryRepository>();
      await repository.saveEntry(entry);

      if (showFeedback && context != null && context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Calculation saved to history'),
            duration: Duration(seconds: 2),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      // Resilient: never crash the calling calculator
      debugPrint('CalculationHistorySaver error: $e');
    }
  }
}
