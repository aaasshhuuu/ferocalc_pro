import 'package:flutter/material.dart';
import '../../../../core/theme/design_system.dart';
import '../../data/models/rate_audit_record.dart';

/// Widget displaying audit records from `rate_audit_log`.
class AuditLogListWidget extends StatelessWidget {
  const AuditLogListWidget({
    Key? key,
    required this.records,
    this.isLoading = false,
  }) : super(key: key);

  final List<RateAuditRecord> records;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(FeroColors.gold),
          ),
        ),
      );
    }

    if (records.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(Icons.history_toggle_off,
                size: 40, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),),
            const SizedBox(height: 12),
            Text(
              'No Audit History',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'No audit logs have been recorded for this rate record yet.',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: records.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: Colors.white.withValues(alpha: 0.06),
      ),
      itemBuilder: (context, index) {
        final rec = records[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: FeroColors.gold.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.history, size: 16, color: FeroColors.gold),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          rec.action.toUpperCase(),
                          style: const TextStyle(
                            color: FeroColors.gold,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        if (rec.performedAt != null)
                          Text(
                            rec.performedAt!.split('T').first,
                            style: TextStyle(
                              color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                    if (rec.notes != null && rec.notes!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        rec.notes!,
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    if (rec.performedBy != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Actor: ${rec.performedBy}',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6) ?? Colors.grey,
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
