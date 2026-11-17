import 'package:flutter/material.dart';
import '../../../../core/theme/design_system.dart';

/// Clean status badge for Admin Dashboard and Candidate Review.
class AdminStatusBadge extends StatelessWidget {
  const AdminStatusBadge({
    Key? key,
    required this.label,
    this.color,
    this.icon,
    this.fontSize = 11,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  }) : super(key: key);

  factory AdminStatusBadge.forStagingStatus(String status) {
    Color bg;
    IconData ic;
    switch (status.toUpperCase()) {
      case 'PROMOTED':
      case 'VERIFIED':
        bg = FeroColors.verified;
        ic = Icons.verified;
        break;
      case 'IN_REVIEW':
        bg = FeroColors.pendingReview;
        ic = Icons.hourglass_top;
        break;
      case 'REJECTED':
        bg = FeroColors.error;
        ic = Icons.cancel_outlined;
        break;
      case 'DRAFT':
      default:
        bg = FeroColors.info;
        ic = Icons.edit_note;
        break;
    }
    return AdminStatusBadge(label: status.toUpperCase(), color: bg, icon: ic);
  }

  factory AdminStatusBadge.forValidationStatus(String status) {
    Color bg;
    IconData ic;
    switch (status.toUpperCase()) {
      case 'VALID':
        bg = FeroColors.verified;
        ic = Icons.check_circle_outline;
        break;
      case 'INVALID':
        bg = FeroColors.error;
        ic = Icons.error_outline;
        break;
      case 'WARNING':
      default:
        bg = FeroColors.warning;
        ic = Icons.warning_amber_rounded;
        break;
    }
    return AdminStatusBadge(label: status.toUpperCase(), color: bg, icon: ic);
  }

  factory AdminStatusBadge.forRole(String role) {
    final isAdmin = role.toUpperCase() == 'ADMIN';
    return AdminStatusBadge(
      label: role.toUpperCase(),
      color: isAdmin ? FeroColors.gold : const Color(0xFF64FFDA),
      icon: isAdmin ? Icons.admin_panel_settings : Icons.fact_check,
    );
  }

  factory AdminStatusBadge.forDiffType(String diffType, {double? rateDelta}) {
    Color color;
    IconData icon;
    String text;

    switch (diffType.toUpperCase()) {
      case 'RATE_INCREASE':
        color = FeroColors.verified;
        icon = Icons.trending_up;
        text = rateDelta != null ? '+${rateDelta.toStringAsFixed(2)}%' : 'INCREASE';
        break;
      case 'RATE_DECREASE':
        color = FeroColors.error;
        icon = Icons.trending_down;
        text = rateDelta != null ? '${rateDelta.toStringAsFixed(2)}%' : 'DECREASE';
        break;
      case 'UNCHANGED':
        color = FeroColors.stale;
        icon = Icons.horizontal_rule;
        text = 'UNCHANGED';
        break;
      case 'NEW_RATE':
      default:
        color = const Color(0xFF64FFDA);
        icon = Icons.fiber_new;
        text = 'NEW';
        break;
    }

    return AdminStatusBadge(label: text, color: color, icon: icon);
  }

  final String label;
  final Color? color;
  final IconData? icon;
  final double fontSize;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? FeroColors.gold;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: effectiveColor.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 2, color: effectiveColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: effectiveColor,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
