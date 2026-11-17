import 'package:equatable/equatable.dart';

/// Represents a user's favorite bank for personalized rate tracking.
class FavoriteBank extends Equatable {
  const FavoriteBank({
    required this.bankId,
    required this.bankName,
    required this.bankShortName,
    required this.addedAt,
    this.notes,
  });

  factory FavoriteBank.fromJson(Map<String, dynamic> json) {
    return FavoriteBank(
      bankId: json['bankId']?.toString() ?? '',
      bankName: json['bankName']?.toString() ?? '',
      bankShortName: json['bankShortName']?.toString() ?? '',
      addedAt: json['addedAt'] != null
          ? DateTime.tryParse(json['addedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      notes: json['notes']?.toString(),
    );
  }

  /// Stable unique identifier for the bank (e.g. 'sbi', 'hdfc', 'icici', or UUID).
  final String bankId;

  /// Full official bank name.
  final String bankName;

  /// Short or acronym name (e.g. 'SBI', 'HDFC').
  final String bankShortName;

  /// When this bank was added to favorites.
  final DateTime addedAt;

  /// Optional personal note.
  final String? notes;

  FavoriteBank copyWith({
    String? bankId,
    String? bankName,
    String? bankShortName,
    DateTime? addedAt,
    String? notes,
  }) {
    return FavoriteBank(
      bankId: bankId ?? this.bankId,
      bankName: bankName ?? this.bankName,
      bankShortName: bankShortName ?? this.bankShortName,
      addedAt: addedAt ?? this.addedAt,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'bankId': bankId,
        'bankName': bankName,
        'bankShortName': bankShortName,
        'addedAt': addedAt.toIso8601String(),
        if (notes != null) 'notes': notes,
      };

  @override
  List<Object?> get props => [bankId, bankName, bankShortName, addedAt, notes];
}
