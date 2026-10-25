import 'package:flutter/material.dart';
import '../data/calculator_purpose_data.dart';
import '../models/calculator_purpose_info.dart';
import 'glassmorphic_card.dart';

/// Reusable card displaying "What is this calculator used for?",
/// common real-world use cases, and intended audience/utility.
class CalculatorPurposeCard extends StatelessWidget {
  const CalculatorPurposeCard({
    Key? key,
    this.calculatorId,
    this.info,
  }) : super(key: key);

  final String? calculatorId;
  final CalculatorPurposeInfo? info;

  @override
  Widget build(BuildContext context) {
    final effectiveInfo = info ?? (calculatorId != null ? getCalculatorPurpose(calculatorId!) : null);

    if (effectiveInfo == null) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    const gold = Color(0xFFC9A96E);

    return GlassmorphicCard(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: gold.withAlpha(38),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.help_outline_rounded,
                  size: 18,
                  color: gold,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'What is this calculator used for?',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            effectiveInfo.purpose,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: isDark ? Colors.white.withAlpha(217) : Colors.black87,
            ),
          ),
          if (effectiveInfo.useCases.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text(
              'Common use cases:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: gold,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            ...effectiveInfo.useCases.map(
              (useCase) => Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 5.0, right: 8.0),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: gold,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        useCase,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (effectiveInfo.usefulFor != null && effectiveInfo.usefulFor!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withAlpha(10) : Colors.black.withAlpha(8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? Colors.white.withAlpha(15) : Colors.black.withAlpha(13),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Useful for: ',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: gold,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      effectiveInfo.usefulFor!,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.3,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
