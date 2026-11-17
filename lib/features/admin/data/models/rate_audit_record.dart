import 'package:equatable/equatable.dart';

/// Represents a rate audit log entry from `rate_audit_log`.
class RateAuditRecord extends Equatable {
  const RateAuditRecord({
    required this.id,
    required this.rateId,
    required this.action,
    this.oldValue,
    this.newValue,
    this.performedBy,
    this.performedAt,
    this.notes,
  });

  factory RateAuditRecord.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? parseMap(dynamic map) {
      if (map is Map<String, dynamic>) return map;
      if (map is Map) return Map<String, dynamic>.from(map);
      return null;
    }

    return RateAuditRecord(
      id: json['id']?.toString() ?? '',
      rateId: (json['rateId'] ?? json['rate_id'])?.toString() ?? '',
      action: json['action']?.toString() ?? '',
      oldValue: parseMap(json['oldValue'] ?? json['old_value']),
      newValue: parseMap(json['newValue'] ?? json['new_value']),
      performedBy: (json['performedBy'] ?? json['performed_by'])?.toString(),
      performedAt: (json['performedAt'] ?? json['performed_at'])?.toString(),
      notes: json['notes']?.toString(),
    );
  }

  final String id;
  final String rateId;
  final String action;
  final Map<String, dynamic>? oldValue;
  final Map<String, dynamic>? newValue;
  final String? performedBy;
  final String? performedAt;
  final String? notes;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'rateId': rateId,
      'action': action,
      'oldValue': oldValue,
      'newValue': newValue,
      'performedBy': performedBy,
      'performedAt': performedAt,
      'notes': notes,
    };
  }

  @override
  List<Object?> get props => [id, rateId, action, performedBy, performedAt, notes];
}
