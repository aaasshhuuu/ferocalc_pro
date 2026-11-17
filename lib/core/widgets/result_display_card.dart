import 'package:flutter/material.dart';
import '../../config/themes/app_gradients.dart';
import 'glassmorphic_card.dart';

export '../utils/sub_result.dart';

class ResultDisplayCard extends StatelessWidget {

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
  final String? label;
  final String? mainLabel;
  final String? amount;
  final String? mainValue;
  final Color? mainValueColor;
  final bool isPremium;
  final List<Map<String, String>>? details;
  final List<Map<String, String>>? subResults;

  @override
  Widget build(BuildContext context) {
    final displayLabel = mainLabel ?? label ?? '';
    final displayValue = mainValue ?? amount ?? '';
    final allDetails = details ?? subResults;

    final isNegative = displayValue.startsWith('-') || displayValue.startsWith('−');
    final semanticValue = isNegative
        ? 'Negative ${displayValue.replaceFirst(RegExp(r'^[-−]\s*'), '')}'
        : displayValue;

    return Semantics(
      container: true,
      label: '$displayLabel: $semanticValue',
      child: GlassmorphicCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(displayLabel, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Semantics(
              label: '$displayLabel is $semanticValue',
              child: mainValueColor != null
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
            ),
            if (allDetails != null && allDetails.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              ...allDetails.map((detail) {
                final key = detail.keys.first;
                final val = detail.values.first;
                return Semantics(
                  label: '$key: $val',
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Text(
                            key,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).textTheme.bodySmall?.color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 6,
                          child: Text(
                            val,
                            textAlign: TextAlign.end,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
            const SizedBox(height: 10),
            Text(
              'Indicative estimate for illustrative purposes. Actual returns or terms may vary by financial institution.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
