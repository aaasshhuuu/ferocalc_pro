import 'package:equatable/equatable.dart';

enum AppNotificationType {
  verifiedRateChange,
  newPromotedSlab,
  significantRateChange,
  announcement;

  String get label {
    switch (this) {
      case AppNotificationType.verifiedRateChange:
        return 'Rate Change';
      case AppNotificationType.newPromotedSlab:
        return 'New Slabs Promoted';
      case AppNotificationType.significantRateChange:
        return 'Major Rate Revision';
      case AppNotificationType.announcement:
        return 'Product Update';
    }
  }
}

/// Represents an authentic in-app notification for verified rate changes.
class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.eventId,
    required this.bankId,
    required this.bankName,
    required this.type,
    required this.title,
    required this.message,
    this.effectiveDate,
    required this.verifiedTimestamp,
    this.isRead = false,
    this.actionRoute,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id']?.toString() ?? '',
      eventId: json['eventId']?.toString() ?? '',
      bankId: json['bankId']?.toString() ?? '',
      bankName: json['bankName']?.toString() ?? '',
      type: AppNotificationType.values.firstWhere(
        (e) => e.name == json['type']?.toString(),
        orElse: () => AppNotificationType.verifiedRateChange,
      ),
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      effectiveDate: json['effectiveDate']?.toString(),
      verifiedTimestamp: json['verifiedTimestamp'] != null
          ? DateTime.tryParse(json['verifiedTimestamp'].toString()) ??
              DateTime.now()
          : DateTime.now(),
      isRead: json['isRead'] as bool? ?? false,
      actionRoute: json['actionRoute']?.toString(),
    );
  }

  /// Unique notification ID.
  final String id;

  /// Idempotent event identifier preventing duplicate notifications.
  final String eventId;

  /// Associated bank identifier.
  final String bankId;

  /// Associated bank name.
  final String bankName;

  /// Classification of notification.
  final AppNotificationType type;

  /// Notification headline.
  final String title;

  /// Genuine verified rate change summary.
  final String message;

  /// Effective date of verified rate if published by official source.
  final String? effectiveDate;

  /// When this change was verified and committed.
  final DateTime verifiedTimestamp;

  /// Whether the user has marked or viewed this notification.
  final bool isRead;

  /// Optional deep-link route (e.g. '/bank/HDFC%20Bank' or '/trust-center').
  final String? actionRoute;

  AppNotification copyWith({
    String? id,
    String? eventId,
    String? bankId,
    String? bankName,
    AppNotificationType? type,
    String? title,
    String? message,
    String? effectiveDate,
    DateTime? verifiedTimestamp,
    bool? isRead,
    String? actionRoute,
  }) {
    return AppNotification(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      bankId: bankId ?? this.bankId,
      bankName: bankName ?? this.bankName,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      effectiveDate: effectiveDate ?? this.effectiveDate,
      verifiedTimestamp: verifiedTimestamp ?? this.verifiedTimestamp,
      isRead: isRead ?? this.isRead,
      actionRoute: actionRoute ?? this.actionRoute,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'eventId': eventId,
        'bankId': bankId,
        'bankName': bankName,
        'type': type.name,
        'title': title,
        'message': message,
        if (effectiveDate != null) 'effectiveDate': effectiveDate,
        'verifiedTimestamp': verifiedTimestamp.toIso8601String(),
        'isRead': isRead,
        if (actionRoute != null) 'actionRoute': actionRoute,
      };

  @override
  List<Object?> get props => [
        id,
        eventId,
        bankId,
        bankName,
        type,
        title,
        message,
        effectiveDate,
        verifiedTimestamp,
        isRead,
        actionRoute,
      ];
}
