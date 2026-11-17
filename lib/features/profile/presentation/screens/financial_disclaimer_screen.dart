import 'package:flutter/material.dart';

class FinancialDisclaimerScreen extends StatelessWidget {
  const FinancialDisclaimerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final headingColor = theme.colorScheme.primary;
    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(
      height: 1.7,
      fontSize: 14,
    );
    final h2Style = theme.textTheme.titleLarge?.copyWith(
      color: headingColor,
      fontWeight: FontWeight.w700,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Financial Disclaimers')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Financial & Rate Disclaimers',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Transparency & Consumer Protection Notice',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                _section(
                  '1. Educational & Calculative Estimates Only',
                  'All calculators within FeroCalc (including Fixed Deposit, Recurring Deposit, SIP, EMI, PPF, SSY, Inflation, and Goal Planning tools) use mathematical formulas to provide approximate estimates based on the parameters you enter. They do not represent a guarantee of earnings, loan approval, credit terms, or final returns. Factors such as exact bank compounding calendar rules, leap years, broken-period interest, and penalty charges for premature withdrawal can alter final realized yields.',
                  h2Style,
                  bodyStyle,
                ),

                _section(
                  '2. Non-Banking, Non-Lending Notice',
                  'FeroCalc is an independent financial education and calculation utility. FeroCalc:\n\n'
                  '• Is NOT a bank, Non-Banking Financial Company (NBFC), or financial intermediary.\n'
                  '• Does NOT accept customer deposits, open bank accounts, or execute fund transfers.\n'
                  '• Does NOT provide loans, extend credit lines, or originate credit applications.\n'
                  '• Does NOT connect to or request credentials for any consumer bank accounts or UPI identifiers.\n\n'
                  'All financial transactions must be conducted directly with the respective banking institution.',
                  h2Style,
                  bodyStyle,
                ),

                _section(
                  '3. Bank Rate Verification & Timeliness',
                  'Fixed deposit rates listed in FeroCalc are sourced from publicly available official bank websites, schedule circulars, and interest rate notifications in India. Although our automated pipeline and human reviewers regularly verify published schedules, banks reserve the right to revise interest rates at any time without notice. Always verify the current rate directly with the bank branch or official portal before booking an FD.',
                  h2Style,
                  bodyStyle,
                ),

                _section(
                  '4. Senior Citizen Rates & Special Slabs',
                  'Senior citizen interest premiums (typically an additional 0.50% p.a., or higher on select special tenure schemes) are subject to bank-specific age qualification requirements (typically 60 years or older for resident Indians, and 80 years or older for super senior citizens). Senior citizen rates are not universally applicable to all deposit products or schemes, and exact eligibility is governed strictly by each respective bank\'s official terms. Banks require valid age verification documentation (such as Aadhaar, PAN card, or passport) at account opening.',
                  h2Style,
                  bodyStyle,
                ),

                _section(
                  '5. DICGC Deposit Insurance Coverage',
                  'Under the Deposit Insurance and Credit Guarantee Corporation (DICGC), an RBI subsidiary, bank deposits (including savings, current, recurring, and fixed deposits) in eligible registered insured commercial and small finance banks in India are insured up to a statutory maximum of ₹5,00,000 (Rupees Five Lakh) per depositor across all branches of each insured bank in the same right and capacity (inclusive of principal and accrued interest). Deposits held in separate insured banking entities are independently insured up to the limit, while deposits across branches of the same bank are aggregated together.',
                  h2Style,
                  bodyStyle,
                ),

                _section(
                  '6. Taxation and TDS Disclosures',
                  'Interest earned on Fixed Deposits and Recurring Deposits is taxable under applicable Indian income tax law under "Income from Other Sources" at the depositor\'s marginal tax slab rate. Tax Deducted at Source (TDS) is strictly an advance withholding mechanism and does NOT constitute an exemption from income tax; all interest earned remains part of your taxable income.\n\n'
                  'For interest paid or credited on or after 1 April 2026, TDS is governed by Section 393(1), Table Sl. No. 5(ii) of the Income-tax Act, 2025, which sets annual bank interest withholding thresholds across all branches of an institution at ₹1,00,000 for resident senior citizens and ₹50,000 for other individuals. For periods up to 31 March 2026 under Section 194A of the earlier Income-tax Act, 1961, the statutory thresholds were ₹50,000 for senior citizens and ₹40,000 for regular individuals.\n\n'
                  'Where a valid PAN is provided, tax is deducted at the standard statutory withholding rate; if a valid PAN is not furnished, banks are required to deduct tax at higher statutory withholding rates. Eligible depositors whose estimated total annual income is below the basic tax exemption limit may submit Form 15G (under 60) or Form 15H (senior citizens) in accordance with Income Tax Department rules. All FeroCalc calculator figures show gross pre-tax estimates unless calculated within dedicated tax tools.',
                  h2Style,
                  bodyStyle,
                ),

                _section(
                  '7. Not Professional Financial Advice',
                  'Content and tools provided in FeroCalc do not constitute personalized financial planning, legal advice, or tax advice. You should consult a qualified SEBI-registered investment advisor or certified financial professional before making significant financial commitments.',
                  h2Style,
                  bodyStyle,
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _section(
    String title,
    String body,
    TextStyle? titleStyle,
    TextStyle? bodyStyle,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: titleStyle),
          const SizedBox(height: 8),
          Text(body, style: bodyStyle),
        ],
      ),
    );
  }
}
