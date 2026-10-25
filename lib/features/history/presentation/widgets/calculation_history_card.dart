import 'package:flutter/material.dart';
import '../../data/models/calculation_history_entry.dart';

class CalculationHistoryCard extends StatelessWidget {
  final CalculationHistoryEntry entry;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const CalculationHistoryCard({
    Key? key,
    required this.entry,
    required this.onTap,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Build a concise secondary summary from the inputs
    final inputSummary = entry.inputs.entries
        .take(2)
        .map((e) => '${e.key}: ${e.value}')
        .join(' • ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon avatar
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC9A96E).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    entry.icon,
                    color: const Color(0xFFC9A96E),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              entry.calculatorName,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              entry.formattedDateTime,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.textTheme.bodySmall?.color ?? Colors.grey,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Primary result highlight
                      Text(
                        '${entry.primaryResultLabel.isNotEmpty ? '${entry.primaryResultLabel}: ' : ''}${entry.primaryResultValue}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFC9A96E),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      if (inputSummary.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          inputSummary,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.5) ?? Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
