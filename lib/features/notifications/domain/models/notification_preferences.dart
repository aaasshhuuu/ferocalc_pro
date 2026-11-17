import 'package:equatable/equatable.dart';

/// User-controlled notification preferences and category toggles.
class NotificationPreferences extends Equatable {
  const NotificationPreferences({
    this.masterEnabled = false,
    this.favoriteBankRateChanges = true,
    this.newlyPromotedSlabs = true,
    this.significantRateChanges = true,
    this.productAnnouncements = false,
    this.systemPermissionGranted = false,
    this.lastUpdated,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) {
    return NotificationPreferences(
      masterEnabled: json['masterEnabled'] as bool? ?? false,
      favoriteBankRateChanges: json['favoriteBankRateChanges'] as bool? ?? true,
      newlyPromotedSlabs: json['newlyPromotedSlabs'] as bool? ?? true,
      significantRateChanges: json['significantRateChanges'] as bool? ?? true,
      productAnnouncements: json['productAnnouncements'] as bool? ?? false,
      systemPermissionGranted: json['systemPermissionGranted'] as bool? ?? false,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.tryParse(json['lastUpdated'].toString())
          : null,
    );
  }

  /// Master notification switch. Must be explicitly opted in.
  final bool masterEnabled;

  /// Notify when user's favorite banks publish verified rate changes.
  final bool favoriteBankRateChanges;

  /// Notify when newly promoted verified rate slabs become active.
  final bool newlyPromotedSlabs;

  /// Notify on important/significant rate revisions across monitored banks.
  final bool significantRateChanges;

  /// Notify on FeroCalc feature announcements (optional, default false).
  final bool productAnnouncements;

  /// Whether system-level notification permissions were granted by user.
  final bool systemPermissionGranted;

  /// Timestamp when preferences were last modified.
  final DateTime? lastUpdated;

  /// True if the user has opted in and notifications are actively allowable.
  bool get areNotificationsActive => masterEnabled && systemPermissionGranted;

  NotificationPreferences copyWith({
    bool? masterEnabled,
    bool? favoriteBankRateChanges,
    bool? newlyPromotedSlabs,
    bool? significantRateChanges,
    bool? productAnnouncements,
    bool? systemPermissionGranted,
    DateTime? lastUpdated,
  }) {
    return NotificationPreferences(
      masterEnabled: masterEnabled ?? this.masterEnabled,
      favoriteBankRateChanges:
          favoriteBankRateChanges ?? this.favoriteBankRateChanges,
      newlyPromotedSlabs: newlyPromotedSlabs ?? this.newlyPromotedSlabs,
      significantRateChanges:
          significantRateChanges ?? this.significantRateChanges,
      productAnnouncements: productAnnouncements ?? this.productAnnouncements,
      systemPermissionGranted:
          systemPermissionGranted ?? this.systemPermissionGranted,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  Map<String, dynamic> toJson() => {
        'masterEnabled': masterEnabled,
        'favoriteBankRateChanges': favoriteBankRateChanges,
        'newlyPromotedSlabs': newlyPromotedSlabs,
        'significantRateChanges': significantRateChanges,
        'productAnnouncements': productAnnouncements,
        'systemPermissionGranted': systemPermissionGranted,
        if (lastUpdated != null) 'lastUpdated': lastUpdated!.toIso8601String(),
      };

  @override
  List<Object?> get props => [
        masterEnabled,
        favoriteBankRateChanges,
        newlyPromotedSlabs,
        significantRateChanges,
        productAnnouncements,
        systemPermissionGranted,
        lastUpdated,
      ];
}
