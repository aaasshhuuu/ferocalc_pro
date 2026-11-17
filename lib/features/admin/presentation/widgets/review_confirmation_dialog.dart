import 'package:flutter/material.dart';
import '../../../../core/theme/design_system.dart';
import '../../data/models/staged_candidate.dart';

enum ReviewActionType { promote, reject, rollback }

/// Explicit confirmation dialog before performing admin mutations.
class ReviewConfirmationDialog extends StatefulWidget {
  const ReviewConfirmationDialog({
    Key? key,
    required this.actionType,
    this.candidate,
    this.rateDescription,
  }) : super(key: key);

  final ReviewActionType actionType;
  final StagedCandidate? candidate;
  final String? rateDescription;

  static Future<String?> show({
    required BuildContext context,
    required ReviewActionType actionType,
    StagedCandidate? candidate,
    String? rateDescription,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ReviewConfirmationDialog(
        actionType: actionType,
        candidate: candidate,
        rateDescription: rateDescription,
      ),
    );
  }

  @override
  State<ReviewConfirmationDialog> createState() => _ReviewConfirmationDialogState();
}

class _ReviewConfirmationDialogState extends State<ReviewConfirmationDialog> {
  final TextEditingController _textController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPromote = widget.actionType == ReviewActionType.promote;
    final isReject = widget.actionType == ReviewActionType.reject;
    final isRollback = widget.actionType == ReviewActionType.rollback;

    final title = isPromote
        ? 'Confirm Rate Promotion'
        : isReject
            ? 'Confirm Candidate Rejection'
            : 'Confirm Rate Rollback';

    final actionColor = isPromote
        ? FeroColors.verified
        : isReject
            ? FeroColors.error
            : FeroColors.warning;

    final actionLabel = isPromote
        ? 'Promote & Publish'
        : isReject
            ? 'Reject Candidate'
            : 'Execute Rollback';

    final promptText = isPromote
        ? 'This action will atomically publish this rate as the active VERIFIED rate in FeroCalc. Any active verified rate matching this tenure domain and customer category will be superseded.'
        : isReject
            ? 'This action will reject this staged candidate. The record will remain in the database for auditing with status REJECTED.'
            : 'This action will restore the previous verified rate record. The current active rate will be superseded.';

    final inputLabel = isPromote
        ? 'Reviewer Notes (Optional)'
        : isReject
            ? 'Rejection Reason (Required)'
            : 'Rollback Justification (Required)';

    return AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            isPromote
                ? Icons.verified
                : isReject
                    ? Icons.cancel_outlined
                    : Icons.restore,
            color: actionColor,
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.candidate != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.candidate!.bankCode} — ${widget.candidate!.displayTenure}',
                        style: const TextStyle(
                          color: FeroColors.gold,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Rate: ${widget.candidate!.interestRate.toStringAsFixed(2)}% | Customer: ${widget.candidate!.customerType}',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ] else if (widget.rateDescription != null) ...[
                Text(
                  widget.rateDescription!,
                  style: const TextStyle(color: FeroColors.gold, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                promptText,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.85) ?? Colors.white70,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _textController,
                maxLines: 2,
                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                decoration: InputDecoration(
                  labelText: inputLabel,
                  labelStyle: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.04),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: actionColor),
                  ),
                ),
                validator: (val) {
                  if ((isReject || isRollback) && (val == null || val.trim().isEmpty)) {
                    return 'A reason is required before proceeding';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: actionColor,
            foregroundColor: isPromote ? Colors.black : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.of(context).pop(_textController.text.trim());
            }
          },
          child: Text(actionLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
