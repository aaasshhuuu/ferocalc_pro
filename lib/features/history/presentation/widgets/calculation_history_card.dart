import 'package:flutter/material.dart';
import '../../data/models/calculation_history_entry.dart';

class CalculationHistoryCard extends StatelessWidget {
  const CalculationHistoryCard({
    Key? key,
    required this.entry,
    required this.onTap,
    this.onDelete,
    this.onRename,
    this.onDuplicate,
    this.onReopen,
  }) : super(key: key);

  final CalculationHistoryEntry entry;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onRename;
  final VoidCallback? onDuplicate;
  final VoidCallback? onReopen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Build a concise secondary summary from the inputs
    final inputSummary = entry.inputs.entries
        .take(2)
        .map((e) => '${e.key}: ${e.value}')
        .join(' • ');

    final hasCustomName = entry.customName != null && entry.customName!.trim().isNotEmpty;
    final isUpdated = entry.updatedAt != null &&
        entry.updatedAt!.difference(entry.timestamp).inSeconds.abs() > 2;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: Semantics(
          button: true,
          label: '${entry.title}, ${entry.calculatorName}, ${entry.primaryResultLabel}: ${entry.primaryResultValue}',
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
                    color: const Color(0xFFC9A96E).withValues(alpha: 0.15),
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
                      // Title row + Badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasCustomName) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFC9A96E).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                entry.calculatorName,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFC9A96E),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Timestamps row
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 11,
                            color: theme.textTheme.bodySmall?.color ?? Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isUpdated
                                ? 'Updated ${entry.formattedUpdatedDateTime}'
                                : entry.formattedDateTime,
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.textTheme.bodySmall?.color ?? Colors.grey,
                            ),
                          ),
                          if (entry.category != null && entry.category!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              '• ${entry.category}',
                              style: TextStyle(
                                fontSize: 11,
                                color: const Color(0xFF00E5FF).withValues(alpha: 0.8),
                              ),
                            ),
                          ],
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
                            color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 6),

                // Popup menu for quick actions
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    size: 18,
                    color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7) ?? Colors.grey,
                  ),
                  tooltip: 'Actions',
                  onSelected: (action) {
                    switch (action) {
                      case 'reopen':
                        if (onReopen != null) {
                          onReopen!();
                        } else {
                          onTap();
                        }
                        break;
                      case 'rename':
                        onRename?.call();
                        break;
                      case 'duplicate':
                        onDuplicate?.call();
                        break;
                      case 'delete':
                        onDelete?.call();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'reopen',
                      child: Row(
                        children: [
                          Icon(Icons.launch, size: 18, color: Color(0xFFC9A96E)),
                          SizedBox(width: 10),
                          Text('Open in Calculator'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18, color: Color(0xFF00E5FF)),
                          SizedBox(width: 10),
                          Text('Rename'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'duplicate',
                      child: Row(
                        children: [
                          Icon(Icons.copy_outlined, size: 18, color: Color(0xFF10B981)),
                          SizedBox(width: 10),
                          Text('Duplicate'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                          SizedBox(width: 10),
                          Text('Delete', style: TextStyle(color: Colors.redAccent)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
}
