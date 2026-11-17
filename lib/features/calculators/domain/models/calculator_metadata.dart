import 'package:flutter/material.dart';

/// Categories for organizing financial calculators in FeroCalc.
enum CalculatorCategory {
  loans,
  investments,
  deposits,
  tax,
  stocks,
  retirement,
  other;

  /// User-facing category display title.
  String get displayName {
    switch (this) {
      case CalculatorCategory.loans:
        return 'Loans';
      case CalculatorCategory.investments:
        return 'Investments';
      case CalculatorCategory.deposits:
        return 'Deposits';
      case CalculatorCategory.tax:
        return 'Tax';
      case CalculatorCategory.stocks:
        return 'Stocks';
      case CalculatorCategory.retirement:
        return 'Retirement';
      case CalculatorCategory.other:
        return 'Other';
    }
  }

  /// Icon representing this category.
  IconData get icon {
    switch (this) {
      case CalculatorCategory.loans:
        return Icons.account_balance;
      case CalculatorCategory.investments:
        return Icons.trending_up;
      case CalculatorCategory.deposits:
        return Icons.savings;
      case CalculatorCategory.tax:
        return Icons.receipt_long;
      case CalculatorCategory.stocks:
        return Icons.candlestick_chart;
      case CalculatorCategory.retirement:
        return Icons.beach_access;
      case CalculatorCategory.other:
        return Icons.grid_view;
    }
  }
}

/// Metadata model describing a registered calculator tool.
class CalculatorMeta {

  const CalculatorMeta({
    required this.id,
    required this.name,
    required this.shortDescription,
    required this.category,
    required this.icon,
    required this.keywords,
    required this.destinationRoute,
    this.isAvailable = true,
    this.isDiscovery = false,
    this.badgeText,
  });
  /// Unique identifier (e.g. 'emi', 'fd', 'sip', 'best_for_me_fd').
  final String id;

  /// Display name shown on the card (e.g. 'EMI', 'FD', 'SIP').
  final String name;

  /// Short explanatory description (1-2 lines).
  final String shortDescription;

  /// Primary functional category.
  final CalculatorCategory category;

  /// Icon for visual identification.
  final IconData icon;

  /// Search aliases and indexing keywords.
  final List<String> keywords;

  /// Route path for GoRouter navigation.
  final String destinationRoute;

  /// Whether the destination screen is implemented and available.
  final bool isAvailable;

  /// Whether this entry represents a smart discovery experience.
  final bool isDiscovery;

  /// Optional badge label (e.g. 'Smart Match', 'Verified').
  final String? badgeText;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CalculatorMeta &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Centralized registry holding all registered FeroCalc calculators.
class CalculatorRegistry {
  CalculatorRegistry._();

  /// Complete list of all 29 functional calculators and discovery tools.
  static const List<CalculatorMeta> all = [
    // ═══════════════════════════════════════════════════════════════════════
    // 1. LOANS (7 Calculators)
    // ═══════════════════════════════════════════════════════════════════════
    CalculatorMeta(
      id: 'emi',
      name: 'EMI',
      shortDescription: 'Equated Monthly Installment',
      category: CalculatorCategory.loans,
      icon: Icons.calculate,
      keywords: [
        'emi',
        'equated monthly installment',
        'loan',
        'home loan',
        'car loan',
        'personal loan',
        'monthly payment',
        'repayment',
        'installment',
        'schedule',
      ],
      destinationRoute: '/calculator/emi',
    ),
    CalculatorMeta(
      id: 'loan_amount',
      name: 'Loan Amount',
      shortDescription: 'Max affordable loan',
      category: CalculatorCategory.loans,
      icon: Icons.account_balance_wallet,
      keywords: [
        'loan amount',
        'max loan',
        'affordable loan',
        'borrowing capacity',
        'eligibility',
        'principal',
        'affordability',
      ],
      destinationRoute: '/calculator/loan_amount',
    ),
    CalculatorMeta(
      id: 'loan_term',
      name: 'Loan Term',
      shortDescription: 'Repayment duration',
      category: CalculatorCategory.loans,
      icon: Icons.access_time,
      keywords: [
        'loan term',
        'tenure',
        'duration',
        'repayment duration',
        'months',
        'years',
        'payoff period',
      ],
      destinationRoute: '/calculator/loan_term',
    ),
    CalculatorMeta(
      id: 'interest_rate',
      name: 'Interest Rate',
      shortDescription: 'True interest rate',
      category: CalculatorCategory.loans,
      icon: Icons.percent,
      keywords: [
        'interest rate',
        'true rate',
        'apr',
        'effective rate',
        'loan rate',
        'percentage',
      ],
      destinationRoute: '/calculator/interest_rate',
    ),
    CalculatorMeta(
      id: 'home_loan_eligibility',
      name: 'Home Loan Eligibility',
      shortDescription: 'Max home loan',
      category: CalculatorCategory.loans,
      icon: Icons.home,
      keywords: [
        'home loan',
        'home loan eligibility',
        'housing loan',
        'property',
        'mortgage',
        'foir',
        'property loan',
      ],
      destinationRoute: '/calculator/home_loan_eligibility',
    ),
    CalculatorMeta(
      id: 'personal_loan_eligibility',
      name: 'Personal Loan Eligibility',
      shortDescription: 'Max personal loan',
      category: CalculatorCategory.loans,
      icon: Icons.person,
      keywords: [
        'personal loan',
        'personal loan eligibility',
        'unsecured loan',
        'salary loan',
        'instant loan',
      ],
      destinationRoute: '/calculator/personal_loan_eligibility',
    ),
    CalculatorMeta(
      id: 'credit_card_emi',
      name: 'Credit Card EMI',
      shortDescription: 'Card repayment',
      category: CalculatorCategory.loans,
      icon: Icons.credit_card,
      keywords: [
        'credit card',
        'credit card emi',
        'card repayment',
        'debt payoff',
        'revolving credit',
        'minimum due',
      ],
      destinationRoute: '/calculator/credit_card_emi',
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // 2. INVESTMENTS (6 Calculators)
    // ═══════════════════════════════════════════════════════════════════════
    CalculatorMeta(
      id: 'sip',
      name: 'SIP',
      shortDescription: 'Systematic Investment',
      category: CalculatorCategory.investments,
      icon: Icons.trending_up,
      keywords: [
        'sip',
        'systematic investment',
        'monthly investment',
        'mutual fund',
        'wealth',
        'sip return',
        'compounding',
      ],
      destinationRoute: '/calculator/sip',
    ),
    CalculatorMeta(
      id: 'swp',
      name: 'SWP',
      shortDescription: 'Systematic Withdrawal',
      category: CalculatorCategory.investments,
      icon: Icons.trending_down,
      keywords: [
        'swp',
        'systematic withdrawal',
        'monthly cashflow',
        'mutual fund payout',
        'pension cashflow',
        'regular income',
      ],
      destinationRoute: '/calculator/swp',
    ),
    CalculatorMeta(
      id: 'lumpsum',
      name: 'Lumpsum',
      shortDescription: 'One-time investment',
      category: CalculatorCategory.investments,
      icon: Icons.monetization_on,
      keywords: [
        'lumpsum',
        'one-time investment',
        'mutual fund',
        'single deposit',
        'wealth growth',
      ],
      destinationRoute: '/calculator/lumpsum',
    ),
    CalculatorMeta(
      id: 'cagr',
      name: 'CAGR',
      shortDescription: 'Compound Annual Growth',
      category: CalculatorCategory.investments,
      icon: Icons.stacked_line_chart,
      keywords: [
        'cagr',
        'compound annual growth',
        'annualized return',
        'growth rate',
        'return on investment',
        'compounding',
      ],
      destinationRoute: '/calculator/cagr',
    ),
    CalculatorMeta(
      id: 'ppf',
      name: 'PPF',
      shortDescription: 'Public Provident Fund',
      category: CalculatorCategory.investments,
      icon: Icons.assured_workload,
      keywords: [
        'ppf',
        'public provident fund',
        'tax saving',
        'section 80c',
        'government scheme',
        'long term',
        'tax free',
      ],
      destinationRoute: '/calculator/ppf',
    ),
    CalculatorMeta(
      id: 'sukanya',
      name: 'Sukanya Samriddhi',
      shortDescription: 'SSY Scheme',
      category: CalculatorCategory.investments,
      icon: Icons.child_care,
      keywords: [
        'sukanya samriddhi',
        'ssy',
        'girl child',
        'government scheme',
        'samriddhi',
        'daughter',
        'tax free',
        'section 80c',
      ],
      destinationRoute: '/calculator/sukanya',
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // 3. DEPOSITS (4 Calculators / Discovery)
    // ═══════════════════════════════════════════════════════════════════════
    CalculatorMeta(
      id: 'best_for_me_fd',
      name: 'Best for Me FD',
      shortDescription: 'Find highest verified FD rates',
      category: CalculatorCategory.deposits,
      icon: Icons.auto_awesome,
      keywords: [
        'best for me fd',
        'smart fd',
        'fd discovery',
        'highest fd rate',
        'compare verified fd',
        'top rates',
        'best rates',
        'verified fd',
        'fixed deposit finder',
      ],
      destinationRoute: '/discovery/best-for-me',
      isDiscovery: true,
      badgeText: 'Smart Match',
    ),
    CalculatorMeta(
      id: 'fd',
      name: 'FD',
      shortDescription: 'Fixed Deposit returns',
      category: CalculatorCategory.deposits,
      icon: Icons.account_balance,
      keywords: [
        'fd',
        'fixed deposit',
        'term deposit',
        'quarterly compounding',
        'bank deposit',
        'guaranteed return',
        'interest',
      ],
      destinationRoute: '/calculator/fd',
    ),
    CalculatorMeta(
      id: 'rd',
      name: 'RD',
      shortDescription: 'Recurring Deposit',
      category: CalculatorCategory.deposits,
      icon: Icons.update,
      keywords: [
        'rd',
        'recurring deposit',
        'monthly deposit',
        'bank saving',
        'cumulative deposit',
      ],
      destinationRoute: '/calculator/rd',
    ),
    CalculatorMeta(
      id: 'savings',
      name: 'Savings',
      shortDescription: 'Bank savings account',
      category: CalculatorCategory.deposits,
      icon: Icons.savings,
      keywords: [
        'savings',
        'savings account',
        'bank interest',
        'daily balance interest',
        'liquid savings',
      ],
      destinationRoute: '/calculator/savings',
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // 4. TAX (2 Calculators)
    // ═══════════════════════════════════════════════════════════════════════
    CalculatorMeta(
      id: 'income_tax',
      name: 'Income Tax',
      shortDescription: 'Tax calculator',
      category: CalculatorCategory.tax,
      icon: Icons.request_quote,
      keywords: [
        'income tax',
        'tax slab',
        'old regime',
        'new regime',
        'tax liability',
        'salary tax',
        'tds',
        'it return',
        'tax rebate',
      ],
      destinationRoute: '/calculator/income_tax',
    ),
    CalculatorMeta(
      id: 'gst',
      name: 'GST',
      shortDescription: 'Goods and Services Tax',
      category: CalculatorCategory.tax,
      icon: Icons.receipt,
      keywords: [
        'gst',
        'goods and services tax',
        'tax',
        'inclusive gst',
        'exclusive gst',
        'cgst',
        'sgst',
        'igst',
      ],
      destinationRoute: '/calculator/gst',
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // 5. STOCKS (2 Calculators)
    // ═══════════════════════════════════════════════════════════════════════
    CalculatorMeta(
      id: 'stock_return',
      name: 'Stock Return',
      shortDescription: 'Profit/Loss',
      category: CalculatorCategory.stocks,
      icon: Icons.candlestick_chart,
      keywords: [
        'stock return',
        'shares',
        'equity',
        'profit loss',
        'stock market',
        'trading',
        'capital gains',
        'share price',
      ],
      destinationRoute: '/calculator/stock_return',
    ),
    CalculatorMeta(
      id: 'dividend_yield',
      name: 'Dividend Yield',
      shortDescription: 'Dividend returns',
      category: CalculatorCategory.stocks,
      icon: Icons.payments,
      keywords: [
        'dividend yield',
        'dividend',
        'passive income',
        'stock dividend',
        'payout ratio',
        'dividend return',
      ],
      destinationRoute: '/calculator/dividend_yield',
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // 6. RETIREMENT (3 Calculators)
    // ═══════════════════════════════════════════════════════════════════════
    CalculatorMeta(
      id: 'retirement',
      name: 'Retirement',
      shortDescription: 'Retirement corpus',
      category: CalculatorCategory.retirement,
      icon: Icons.beach_access,
      keywords: [
        'retirement',
        'pension',
        'retirement corpus',
        'post retirement',
        'financial freedom',
        'fire',
        'nest egg',
      ],
      destinationRoute: '/calculator/retirement',
    ),
    CalculatorMeta(
      id: 'nps',
      name: 'NPS',
      shortDescription: 'National Pension System',
      category: CalculatorCategory.retirement,
      icon: Icons.elderly,
      keywords: [
        'nps',
        'national pension system',
        'pension',
        'tier 1',
        'tier 2',
        'annuity',
        'tax saving',
        'section 80ccd',
      ],
      destinationRoute: '/calculator/nps',
    ),
    CalculatorMeta(
      id: 'epf',
      name: 'EPF',
      shortDescription: 'Employee Provident Fund',
      category: CalculatorCategory.retirement,
      icon: Icons.business,
      keywords: [
        'epf',
        'pf',
        'provident fund',
        'salary pf',
        'employer contribution',
        'employee provident fund',
        'vpf',
      ],
      destinationRoute: '/calculator/epf',
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // 7. OTHER (5 Calculators)
    // ═══════════════════════════════════════════════════════════════════════
    CalculatorMeta(
      id: 'simple_interest',
      name: 'Simple Interest',
      shortDescription: 'Principal, rate & time',
      category: CalculatorCategory.other,
      icon: Icons.percent,
      keywords: [
        'simple interest',
        'si',
        'general interest',
        'flat interest',
        'principal rate time',
        'basic interest',
      ],
      destinationRoute: '/calculator/simple_interest',
    ),
    CalculatorMeta(
      id: 'compound_interest',
      name: 'Compound Interest',
      shortDescription: 'Interest with compounding',
      category: CalculatorCategory.other,
      icon: Icons.trending_up,
      keywords: [
        'compound interest',
        'ci',
        'general interest',
        'compounding',
        'annual compounding',
        'exponential growth',
      ],
      destinationRoute: '/calculator/compound_interest',
    ),
    CalculatorMeta(
      id: 'inflation',
      name: 'Inflation',
      shortDescription: 'Future value',
      category: CalculatorCategory.other,
      icon: Icons.show_chart,
      keywords: [
        'inflation',
        'future value',
        'purchasing power',
        'cost of living',
        'price rise',
        'cpi',
      ],
      destinationRoute: '/calculator/inflation',
    ),
    CalculatorMeta(
      id: 'goal',
      name: 'Goal',
      shortDescription: 'Financial goals',
      category: CalculatorCategory.other,
      icon: Icons.flag,
      keywords: [
        'goal',
        'financial goal',
        'target saving',
        'milestone',
        'car goal',
        'vacation goal',
        'wealth planning',
      ],
      destinationRoute: '/calculator/goal',
    ),
    CalculatorMeta(
      id: 'education',
      name: 'Education',
      shortDescription: 'Child education',
      category: CalculatorCategory.other,
      icon: Icons.school,
      keywords: [
        'education',
        'child education',
        'higher studies',
        'college fund',
        'school fees',
        'higher education',
      ],
      destinationRoute: '/calculator/education',
    ),
  ];

  /// Total count of registered tools.
  static int get totalCount => all.length;

  /// Find a calculator by its unique ID.
  static CalculatorMeta? findById(String id) {
    try {
      return all.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Find a calculator by its destination route.
  static CalculatorMeta? findByRoute(String route) {
    try {
      return all.firstWhere((c) => c.destinationRoute == route);
    } catch (_) {
      return null;
    }
  }

  /// Get all calculators belonging to a specific category.
  static List<CalculatorMeta> getByCategory(CalculatorCategory category) {
    return all.where((c) => c.category == category).toList();
  }

  /// Filter and search across calculators using name, category, description, and keywords.
  static List<CalculatorMeta> search(
    String query, {
    CalculatorCategory? category,
    bool favoritesOnly = false,
    Set<String>? favoriteIds,
  }) {
    final cleanQuery = query.trim().toLowerCase();

    return all.where((calc) {
      // 1. Category filter
      if (category != null && calc.category != category) {
        return false;
      }

      // 2. Favorites-only filter
      if (favoritesOnly && (favoriteIds == null || !favoriteIds.contains(calc.id))) {
        return false;
      }

      // 3. Search query matching
      if (cleanQuery.isEmpty) {
        return true;
      }

      final nameMatch = calc.name.toLowerCase().contains(cleanQuery);
      final categoryMatch = calc.category.displayName.toLowerCase().contains(cleanQuery);
      final descMatch = calc.shortDescription.toLowerCase().contains(cleanQuery);
      final keywordMatch = calc.keywords.any(
        (kw) => kw.toLowerCase().contains(cleanQuery) || cleanQuery.contains(kw.toLowerCase()),
      );

      return nameMatch || categoryMatch || descMatch || keywordMatch;
    }).toList();
  }
}
