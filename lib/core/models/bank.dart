/// Production-grade bank model for FeroCalc
/// Supports bank lifecycle: active, merged, acquired, inactive, archived
enum BankStatus { active, merged, acquired, inactive, archived }
enum BankType { public, private, smallFinance, foreign, cooperativeBank, paymentBank }

class Bank {
  final String id;
  final String name;
  final String shortName;
  final BankType type;
  final BankStatus status;
  final String? successorBankId;
  final String? officialWebsite;
  final String? established;
  final String? headquarters;
  final String? customerCareNumber;
  final String? totalBranches;

  const Bank({
    required this.id,
    required this.name,
    required this.shortName,
    required this.type,
    this.status = BankStatus.active,
    this.successorBankId,
    this.officialWebsite,
    this.established,
    this.headquarters,
    this.customerCareNumber,
    this.totalBranches,
  });

  /// Human-readable type label
  String get typeLabel {
    switch (type) {
      case BankType.public: return 'Public Sector Bank';
      case BankType.private: return 'Private Bank';
      case BankType.smallFinance: return 'Small Finance Bank';
      case BankType.foreign: return 'Foreign Bank';
      case BankType.cooperativeBank: return 'Cooperative Bank';
      case BankType.paymentBank: return 'Payment Bank';
    }
  }

  /// Whether this bank is currently operational
  bool get isOperational => status == BankStatus.active;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'shortName': shortName,
    'type': type.name,
    'status': status.name,
    'successorBankId': successorBankId,
    'officialWebsite': officialWebsite,
    'established': established,
    'headquarters': headquarters,
    'customerCareNumber': customerCareNumber,
    'totalBranches': totalBranches,
  };

  factory Bank.fromJson(Map<String, dynamic> json) => Bank(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    shortName: json['shortName']?.toString() ?? '',
    type: BankType.values.firstWhere(
      (e) => e.name == json['type']?.toString(),
      orElse: () => BankType.private,
    ),
    status: BankStatus.values.firstWhere(
      (e) => e.name == json['status']?.toString(),
      orElse: () => BankStatus.active,
    ),
    successorBankId: json['successorBankId']?.toString(),
    officialWebsite: json['officialWebsite']?.toString(),
    established: json['established']?.toString(),
    headquarters: json['headquarters']?.toString(),
    customerCareNumber: json['customerCareNumber']?.toString(),
    totalBranches: json['totalBranches']?.toString(),
  );
}
