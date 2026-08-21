import 'package:flutter/material.dart';
import '../../config/themes/app_gradients.dart';
import 'glassmorphic_card.dart';

class ResultDisplayCard extends StatelessWidget {
  final String? label;
  final String? mainLabel;
  final String? amount;
  final String? mainValue;
  final Color? mainValueColor;
  final bool isPremium;
  final List<Map<String, String>>? details;
  final List<Map<String, String>>? subResults;

  const ResultDisplayCard({
    Key? key,
    this.label,
    this.mainLabel,
    this.amount,
    this.mainValue,
    this.mainValueColor,
    this.isPremium = false,
    this.details,
    this.subResults,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final displayLabel = mainLabel ?? label ?? '';
    final displayValue = mainValue ?? amount ?? '';
    final allDetails = details ?? subResults;

    return GlassmorphicCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(displayLabel, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          mainValueColor != null
              ? Text(
                  displayValue,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: mainValueColor,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : ShaderMask(
                  shaderCallback: (bounds) => (isPremium ? AppGradients.primaryDarkGradient : AppGradients.successGradient).createShader(bounds),
                  child: Text(
                    displayValue,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
          if (allDetails != null && allDetails.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            ...allDetails.map((detail) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(detail.keys.first, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  )),
                  Text(detail.values.first, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }
}

/// Helper function used by calculator screens to create sub-result entries
/// for the ResultDisplayCard widget.
Map<String, String> SubResult({required String label, required String value}) {
  return {label: value};
}
