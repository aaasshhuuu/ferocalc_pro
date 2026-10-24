import 'package:flutter/material.dart';

import '../models/financial_management_topic.dart';

/// Centralized repository of financial management topics.
class FinancialManagementData {
  static const List<FinancialManagementTopic> topics = [
    FinancialManagementTopic(
      id: 'rule-of-72',
      title: 'Rule of 72',
      shortDescription: 'Divide 72 by interest rate to know doubling time',
      icon: Icons.calculate,
      isKeyTopic: true,
      whatIsIt:
          'The Rule of 72 is a quick mathematical mental shortcut used to estimate the number of years required to double an invested amount at a constant annual rate of compounding interest.',
      whyItMatters:
          'It provides an immediate benchmark for evaluating investment growth and comparing opportunities without requiring complex logarithmic calculations or a financial calculator.',
      howItWorks:
          'You divide the number 72 by the anticipated annual interest rate (expressed as a percentage). The resulting quotient indicates the approximate number of years it takes for your investment principal to double.',
      formulaOrRule:
          'Years to Double ≈ 72 / Annual Interest Rate (%)\n\n'
          'Alternatively:\n'
          'Required Interest Rate (%) ≈ 72 / Years to Double',
      example:
          '• At 8% annual return: 72 / 8 = 9 years to double.\n'
          '• At 12% annual return: 72 / 12 = 6 years to double.\n'
          '• At 6% inflation rate: Purchasing power halves in 72 / 6 = 12 years.',
      practicalUses: [
        'Quickly comparing growth potential across fixed deposits, mutual funds, or sovereign bonds.',
        'Estimating the erosive impact of inflation on cash holdings over time.',
        'Setting realistic milestone expectations for retirement or educational savings goals.',
        'Determining the interest rate needed to achieve a target corpus within a desired timeframe.',
      ],
      importantPoints: [
        'Most accurate for interest rates between 6% and 10%. Approximation error increases at extreme rates.',
        'Assumes continuous annual compounding and reinvestment of all earnings.',
        'Does not factor in capital gains taxes, fund expense ratios, or interim market volatility.',
        'For lower rates (under 5%), the Rule of 69 or 70 offers slightly closer mathematical precision.',
      ],
      disclaimer:
          'The Rule of 72 is an educational approximation rule. Actual investment doubling time depends on exact compounding frequencies, portfolio volatility, management fees, and applicable taxes.',
      relatedCalculatorRoute: '/calculator/cagr',
      relatedCalculatorLabel: 'Open CAGR Calculator',
    ),
    FinancialManagementTopic(
      id: 'emergency-fund',
      title: 'Emergency Fund',
      shortDescription: 'Emergency fund should cover 6 months of expenses',
      icon: Icons.security,
      isKeyTopic: true,
      whatIsIt:
          'An Emergency Fund is a dedicated, highly liquid cash reserve set aside exclusively for unforeseen financial disruptions such as medical emergencies, job loss, or essential repairs.',
      whyItMatters:
          'It forms the cornerstone of financial security. Without an emergency buffer, unexpected crises often force individuals into high-interest debt or distress selling of long-term investments at market lows.',
      howItWorks:
          'Identify your non-negotiable monthly living expenses (housing, utilities, food, insurance, school fees, and minimum debt payments). Multiply this base by 3 to 6 months to determine your reserve target.',
      formulaOrRule:
          'Emergency Fund Target = Essential Monthly Living Expenses × 3 to 6\n\n'
          'Example: ₹40,000 monthly living costs × 6 months = ₹2,40,000 target',
      example:
          'If your family requires ₹45,000 per month for essential bills:\n'
          '• Minimal safety net (3 months) = ₹1,35,000\n'
          '• Prudent safety net (6 months) = ₹2,70,000\n'
          '• Higher safety net for volatile income / freelancers (9-12 months) = ₹4,05,000 to ₹5,40,000.',
      practicalUses: [
        'Buffer against unexpected hospitalisation expenses before health insurance claims settle.',
        'Sustain household expenses during temporary unemployment or career transitions.',
        'Handle critical home, plumbing, or vehicle repairs without revolving credit debt.',
        'Prevent premature liquidation of tax-advantaged instruments like PPF or equity investments.',
      ],
      importantPoints: [
        'Prioritise capital safety and liquidity over high investment returns.',
        'Best parked in high-yield savings accounts, sweep-in fixed deposits, or liquid mutual funds.',
        'Never invest emergency funds in volatile equities, real estate, or long lock-in products.',
        'Must be replenished systematically as soon as any withdrawal is made.',
      ],
      disclaimer:
          'Recommended emergency fund sizing varies based on individual job stability, number of dependents, health conditions, and existing insurance coverage.',
      relatedCalculatorRoute: '/calculator/savings',
      relatedCalculatorLabel: 'Open Savings Calculator',
    ),
    FinancialManagementTopic(
      id: 'start-sip-early',
      title: 'Start SIP Early',
      shortDescription: '₹5000/mo for 30 years at 12% = ₹1.76 Cr',
      icon: Icons.trending_up,
      isKeyTopic: true,
      whatIsIt:
          'A Systematic Investment Plan (SIP) allows individuals to invest a predetermined amount at regular intervals into equity or mutual fund schemes, harnessing the twin engines of rupee cost averaging and compounding.',
      whyItMatters:
          'Starting early leverages the most potent variable in compounding: time. Dollars invested in your early twenties have far more compounding cycles to multiply than larger sums invested later in life.',
      howItWorks:
          'A fixed sum is automatically debited every month. When markets dip, your fixed contribution purchases more fund units; when markets rise, it buys fewer units, averaging out purchase cost over time.',
      formulaOrRule:
          'Future Value of SIP:\n'
          'FV = P × [((1 + i)^n - 1) / i] × (1 + i)\n\n'
          'where P = monthly contribution, i = periodic rate, n = total months',
      example:
          'Starting at age 25:\n'
          '• ₹5,000/month for 30 years at assumed 12% p.a.\n'
          '• Total Principal Invested: ₹18,00,000\n'
          '• Estimated Maturity Corpus: ~₹1.76 Crores\n\n'
          'Starting at age 35 (10-year delay):\n'
          '• Same ₹5,000/month for 20 years at 12% p.a. yields only ~₹49.95 Lakhs.',
      practicalUses: [
        'Long-term wealth creation for retirement and financial independence.',
        'Funding long-range milestones like children\'s college education or a first home.',
        'Overcoming emotional trading biases and market timing anxiety through automated discipline.',
        'Utilising Step-up SIPs to increase investments annually alongside career salary increments.',
      ],
      importantPoints: [
        'Market-linked equity investments fluctuate; returns are not fixed or guaranteed.',
        'Staying invested through bear markets is critical for rupee cost averaging to work effectively.',
        'Small, steady contributions held over long horizons outperform erratic lump sums.',
      ],
      disclaimer:
          'Mutual fund and equity investments are subject to market risks. Illustrated growth rates are for educational demonstration and do not represent guaranteed returns.',
      relatedCalculatorRoute: '/calculator/sip',
      relatedCalculatorLabel: 'Open SIP Calculator',
    ),
    FinancialManagementTopic(
      id: 'tax-saving',
      title: 'Tax Saving',
      shortDescription: 'Section 80C allows ₹1.5L deduction',
      icon: Icons.account_balance,
      isKeyTopic: false,
      whatIsIt:
          'Tax planning involves legitimately utilising statutory exemptions, deductions, and tax-saving investment instruments to optimise net tax liability under prevailing tax laws.',
      whyItMatters:
          'Effective tax management increases disposable household income and directs capital into productive long-term savings vehicles rather than incurring avoidable tax leakage.',
      howItWorks:
          'Eligible investments and qualifying expenses are deducted from Gross Total Income to reduce Net Taxable Income, lowering the final tax liability calculated under applicable tax slab rates.',
      formulaOrRule:
          'Taxable Income = Gross Total Income - Eligible Exemptions - Eligible Deductions\n\n'
          'Tax Saved = Deductible Amount × Marginal Tax Slab Rate (including cess)',
      example:
          'Under the Old Tax Regime in India:\n'
          '• Section 80C offers up to ₹1,50,000 deduction across eligible instruments.\n'
          '• An individual in the 30% slab investing the full ₹1.5L saves ₹46,800 in taxes (including 4% cess).\n'
          '• Additional deductions like 80D (Health Insurance) and 80CCD(1B) (NPS) can provide further relief.',
      practicalUses: [
        'Evaluating whether the Old or New Tax Regime yields lower tax for your specific deduction profile.',
        'Channeling surplus earnings into high-utility instruments like ELSS, PPF, and EPF.',
        'Coordinating family health insurance and preventive checkups with Section 80D deductions.',
      ],
      importantPoints: [
        'Never make financial decisions purely for tax saving; ensure instruments match your risk profile and horizon.',
        'The New Tax Regime (Section 115BAC) offers concessional slab rates but disallows most common deductions.',
        'Each tax-saving instrument has distinct lock-in rules (e.g., ELSS: 3 years; PPF: 15 years; Tax-Saver FD: 5 years).',
      ],
      disclaimer:
          'Tax provisions, slabs, and deduction eligibility change periodically with Union Budgets and statutory amendments. Consult a certified tax advisor for individual tax planning.',
      relatedCalculatorRoute: '/calculator/income_tax',
      relatedCalculatorLabel: 'Open Income Tax Calculator',
    ),
    FinancialManagementTopic(
      id: 'ppf-returns',
      title: 'PPF Returns',
      shortDescription: 'PPF gives 7.1% tax-free returns',
      icon: Icons.account_balance_wallet,
      isKeyTopic: false,
      whatIsIt:
          'Public Provident Fund (PPF) is a sovereign, central government-backed long-term savings scheme created to mobilize small savings and provide guaranteed, tax-free retirement security.',
      whyItMatters:
          'PPF offers the rare and coveted "EEE" (Exempt-Exempt-Exempt) tax status: deposits are eligible for Section 80C deductions, interest earned is completely tax-free, and maturity proceeds are exempt from tax.',
      howItWorks:
          'Individuals can open one PPF account and contribute between ₹500 and ₹1,50,000 per financial year. Interest is calculated on the minimum balance between the 5th and the last day of each month and credited annually on March 31.',
      formulaOrRule:
          'Interest Calculation Rule:\n'
          'Calculated monthly on the lowest balance between the close of the 5th day and the end of the month.\n'
          'Compounded and credited annually on March 31.',
      example:
          '• Investing ₹1,50,000 on or before April 5 each year for 15 years:\n'
          '• Total Investment: ₹22,50,000\n'
          '• Indicative Maturity Corpus at 7.1% p.a.: ~₹40.68 Lakhs (completely tax-free).\n'
          '• Depositing early in the month maximizes interest earned across the full 12 months.',
      practicalUses: [
        'Building a guaranteed, zero-credit-risk corpus for retirement or child education.',
        'Serving as the conservative debt anchor in an overall balanced investment portfolio.',
        'Generating completely tax-exempt interest income unaffected by personal income tax brackets.',
      ],
      importantPoints: [
        'Has a 15-year statutory lock-in, with partial withdrawals and loan facilities available after specified tenures.',
        'Can be extended indefinitely in 5-year blocks with or without fresh contributions.',
        'Backed by the Government of India, making it sovereign-guaranteed with zero default risk.',
        'Interest rates are reviewed and notified quarterly by the Ministry of Finance.',
      ],
      disclaimer:
          'PPF interest rates are sovereign-notified by the Government of India and subject to quarterly revision. Past notified rates do not guarantee future quarterly rates.',
      relatedCalculatorRoute: '/calculator/ppf',
      relatedCalculatorLabel: 'Open PPF Calculator',
    ),
    FinancialManagementTopic(
      id: 'nps-benefits',
      title: 'NPS Benefits',
      shortDescription: 'NPS gives extra ₹50,000 deduction under 80CCD(1B)',
      icon: Icons.savings,
      isKeyTopic: false,
      whatIsIt:
          'The National Pension System (NPS) is a voluntary, long-term, market-linked retirement scheme regulated by the Pension Fund Regulatory and Development Authority (PFRDA).',
      whyItMatters:
          'NPS combines ultra-low fund management costs, disciplined asset allocation across equities and debt, and exclusive tax deductions not available with any other financial product.',
      howItWorks:
          'Subscribers contribute systematically into a Tier-I retirement account. Funds are managed by institutional pension fund managers across Equity (E), Corporate Debt (C), and Government Securities (G). Upon age 60, up to 60% can be withdrawn tax-free as a lump sum, while minimum 40% purchases an annuity.',
      formulaOrRule:
          'Special Tax Advantage:\n'
          'Section 80CCD(1B) provides an exclusive deduction of up to ₹50,000 over and above the ₹1.5 Lakh limit of Section 80C under the Old Tax Regime.',
      example:
          'An individual in the 30% tax bracket:\n'
          '• Maxes out Section 80C (₹1.5 Lakhs).\n'
          '• Invests an additional ₹50,000 in NPS Tier-I under Section 80CCD(1B).\n'
          '• Total Taxable Income reduced by ₹2,00,000.\n'
          '• Generates an additional ₹15,600 tax savings directly from the NPS contribution.',
      practicalUses: [
        'Constructing a dedicated retirement nest egg with built-in annuity income.',
        'Maximizing annual income tax deductions under the Old Tax Regime.',
        'Accessing low-cost institutional equity and corporate debt management.',
      ],
      importantPoints: [
        'Tier-I funds are strictly locked until superannuation at age 60 (with limited early partial withdrawal rules).',
        'At retirement, 60% lump-sum withdrawal is 100% tax-free, while the 40% annuity generates regular taxable pension.',
        'Subscribers can choose Active Choice (self-directed asset allocation) or Auto Choice (lifecycle de-risking).',
      ],
      disclaimer:
          'NPS returns are market-linked and not guaranteed. Annuity payout amounts depend on prevailing insurance annuity rates at the time of retirement.',
      relatedCalculatorRoute: '/calculator/nps',
      relatedCalculatorLabel: 'Open NPS Calculator',
    ),
    FinancialManagementTopic(
      id: 'fd-taxation',
      title: 'FD Taxation',
      shortDescription: 'FD interest is taxable; consider tax-saver FDs',
      icon: Icons.request_quote,
      isKeyTopic: false,
      whatIsIt:
          'Fixed Deposit (FD) taxation refers to the income tax rules governing interest earned from bank and corporate term deposits, which is treated as "Income from Other Sources".',
      whyItMatters:
          'Headline interest rates can be misleading. For taxpayers in higher tax brackets, income tax substantially reduces real net returns, making post-tax yield calculations critical.',
      howItWorks:
          'Banks deduct Tax Deducted at Source (TDS) at 10% (or 20% if PAN is not linked) if annual interest exceeds statutory thresholds. If your marginal income tax bracket is higher than 10%, you must pay the differential tax during income tax filing.',
      formulaOrRule:
          'Post-Tax Interest Rate = Pre-Tax FD Rate × (1 - Marginal Tax Rate)\n\n'
          'Example at 7% FD rate in 30% slab:\n'
          'Post-Tax Yield = 7.0% × (1 - 0.312) = 4.82% p.a.',
      example:
          '• Regular depositor earning ₹50,000 FD interest in 30% bracket:\n'
          '  - Bank deducts TDS @ 10% = ₹5,000\n'
          '  - Total tax liability @ 31.2% = ₹15,600\n'
          '  - Depositor must pay remaining ₹10,600 when filing tax returns.\n'
          '• Senior citizen benefit under Section 80TTB: Up to ₹50,000 deposit interest is fully deductible.',
      practicalUses: [
        'Calculating true post-tax returns before committing capital to long-term deposits.',
        'Submitting Form 15G (below 60) or Form 15H (senior citizens) to prevent TDS when total income is below the taxable threshold.',
        'Utilizing 5-Year Tax Saver FDs to claim Section 80C deductions.',
      ],
      importantPoints: [
        'TDS is merely an advance collection of tax; it does not represent your final tax liability.',
        '5-Year Tax-Saver FDs have a mandatory 5-year lock-in with zero premature withdrawal or loan facility.',
        'Interest is taxed on an accrual basis each financial year, not just upon final deposit maturity.',
      ],
      disclaimer:
          'TDS limits and slab rates are governed by Indian Income Tax statutes and differ between regular and senior citizen depositors. Verify current thresholds with bank and tax guidelines.',
      relatedCalculatorRoute: '/calculator/fd',
      relatedCalculatorLabel: 'Open FD Calculator',
    ),
    FinancialManagementTopic(
      id: 'sukanya-samriddhi',
      title: 'Sukanya Samriddhi',
      shortDescription: '8.2% for girl child savings',
      icon: Icons.child_care,
      isKeyTopic: false,
      whatIsIt:
          'Sukanya Samriddhi Yojana (SSY) is a government-backed small savings initiative under the "Beti Bachao, Beti Padhao" campaign, designed to help parents build an education and marriage fund for a girl child.',
      whyItMatters:
          'Offers one of the highest interest rates among government-backed small savings schemes, coupled with complete EEE (Exempt-Exempt-Exempt) tax-exempt status.',
      howItWorks:
          'An account can be opened by parents or legal guardians for a girl child below 10 years of age (up to two girls per family). Contributions are made for 15 years from account opening, and the account matures after 21 years.',
      formulaOrRule:
          'Eligibility & Deposit Framework:\n'
          '• Maximum entry age: 10 years.\n'
          '• Deposit tenure: 15 years from opening date.\n'
          '• Account maturity: 21 years from opening date.\n'
          '• Annual limits: ₹250 minimum, ₹1,50,000 maximum per financial year.',
      example:
          '• Contributing ₹1,50,000 annually for 15 years at an indicative sovereign rate of 8.2% p.a.:\n'
          '• Total Investment: ₹22,50,000\n'
          '• Estimated Maturity Value at 21 years: ~₹69.8 Lakhs completely tax-free.\n'
          '• Compound growth continues during the non-contribution years (years 16 to 21).',
      practicalUses: [
        'Accumulating a guaranteed college and higher education fund for daughters.',
        'Building a wedding or career milestone fund with sovereign default safety.',
        'Maximizing annual tax deductions under Section 80C while earning high sovereign-backed returns.',
      ],
      importantPoints: [
        'Partial withdrawal up to 50% of the preceding financial year balance is allowed after the girl turns 18 for documented higher education.',
        'Full maturity proceeds are payable to the girl child upon completing 21 years from account opening or upon marriage after age 18.',
        'Backed fully by the Central Government with zero risk of capital loss.',
      ],
      disclaimer:
          'Sukanya Samriddhi interest rates are sovereign-notified by the Government of India and subject to quarterly adjustments. Past rates do not guarantee future quarterly notifications.',
      relatedCalculatorRoute: '/calculator/sukanya',
      relatedCalculatorLabel: 'Open Sukanya Samriddhi Calculator',
    ),
    FinancialManagementTopic(
      id: 'rule-of-114',
      title: 'Rule of 114',
      shortDescription: 'Divide 114 by interest rate to estimate tripling time',
      icon: Icons.auto_graph_rounded,
      isKeyTopic: true,
      whatIsIt:
          'The Rule of 114 is a fast mental math rule-of-thumb used to estimate the number of years required for an investment to triple in value (reach 3x its starting principal) at a constant annual compounding interest rate.',
      whyItMatters:
          'While the famous Rule of 72 helps gauge capital doubling, serious long-term wealth creation—such as preparing for children\'s higher education or retirement—requires multi-fold asset expansion. The Rule of 114 allows investors to quickly project 3x capital accumulation timelines and benchmark target return requirements without complex financial calculators.',
      howItWorks:
          'Divide the constant number 114 by the expected annual rate of return (expressed as a whole percentage). The resulting number represents the approximate years needed to triple your principal.\n\n'
          'Conversely, if you have a target time horizon in years, divide 114 by that number of years to determine the required annual return rate needed to achieve a 3x portfolio gain.',
      formulaOrRule:
          'Years to Triple ≈ 114 / Annual Return Rate (%)\n\n'
          'Alternatively:\n'
          'Required Annual Rate (%) ≈ 114 / Target Number of Years\n\n'
          'Mathematical Basis:\n'
          'Derived from (1 + r)^t = 3  =>  t = ln(3) / ln(1 + r).\n'
          'Since ln(3) ≈ 1.0986, adjusting for discrete annual compounding yields 114 as a convenient practical numerator.',
      example:
          '• At 6% annual return: 114 / 6 = 19.0 years to triple.\n'
          '• At 8% annual return: 114 / 8 = 14.25 years (~14 years and 3 months).\n'
          '• At 9.5% annual return: 114 / 9.5 = 12.0 years to triple.\n'
          '• At 12% annual return: 114 / 12 = 9.5 years to triple.\n\n'
          'Target Timeline Example:\n'
          'To turn ₹10 Lakhs into ₹30 Lakhs over 10 years, you need an annual compound return of approximately 114 / 10 = 11.4% p.a.',
      practicalUses: [
        'Evaluating long-term financial goals such as accumulating a college corpus or retirement fund.',
        'Comparing the real-world impact of earning an extra 2% to 3% annual compound return on wealth tripling timelines.',
        'Assessing how long sustained inflation will take to erode purchasing power (at 6% average inflation, living costs triple in ~19 years).',
        'Quickly sanity-checking investment sales pitches claiming 3x capital returns within unrealistic timelines.',
      ],
      importantPoints: [
        'Mental shortcut only: It provides a practical estimation, not an exact mathematical outcome or guaranteed yield.',
        'Assumes steady compounding: Requires uninterrupted annual compounding with all returns reinvested and zero withdrawals.',
        'Ignores taxes and costs: Does not account for capital gains taxes, fund expense ratios (TER), brokerage fees, or exit loads.',
        'Optimal rate range: Most accurate for annual returns between 6% and 12%; estimation error widens at extreme return percentages.',
        'No market guarantee: Does not guarantee future market behavior or protect against downside volatility.',
      ],
      disclaimer:
          'The Rule of 114 is an educational mental framework and mathematical approximation. It does not predict, promise, or guarantee investment performance. Actual wealth accumulation depends on compounding schedule, portfolio risk, fees, and applicable taxes.',
      relatedCalculatorRoute: '/calculator/compound_interest',
      relatedCalculatorLabel: 'Open Compound Interest Calculator',
    ),
    FinancialManagementTopic(
      id: '70-20-10',
      title: '70/20/10 Rule',
      shortDescription: 'Budgeting framework: 70% needs, 20% savings, 10% giving/wants',
      icon: Icons.pie_chart_rounded,
      isKeyTopic: true,
      whatIsIt:
          'The 70/20/10 Rule is a popular personal cash-flow and budgeting framework designed to organize take-home income into three broad buckets: 70% for Living Expenses, 20% for Savings, Investments & Debt Reduction, and 10% for Giving, Personal Growth, or Discretionary Spending.',
      whyItMatters:
          'Itemized line-by-line budgeting can be rigid, stressful, and difficult to maintain month after month. The 70/20/10 framework offers a sustainable macro-level cash allocation system that guarantees consistent wealth building and debt payoff while allowing freedom for lifestyle and charitable causes.',
      howItWorks:
          'Allocate your monthly net (post-tax) take-home income across three foundational pillars:\n\n'
          '1. 70% for Living Expenses (Needs & Operations): Non-negotiable costs required for daily living, including rent or home loan EMI, groceries, utilities, transportation, health/life insurance premiums, and schooling.\n\n'
          '2. 20% for Savings, Investments & Debt Reduction: Dedicated wealth-building capital, such as emergency reserve contributions, mutual fund SIPs, PPF, retirement accounts, or extra prepayments on high-interest loans.\n\n'
          '3. 10% for Giving, Learning & Discretionary (Wants & Growth): Flexible funds for philanthropic donations, family support, religious giving, upskilling courses, books, or personal recreational pursuits.',
      formulaOrRule:
          'Take-Home Monthly Income (100%)\n'
          '├── 70% Living Expenses & Day-to-Day Needs\n'
          '├── 20% Savings, Investments & Debt Reduction\n'
          '└── 10% Giving, Self-Improvement & Discretionary',
      example:
          'Monthly Take-Home Income: ₹50,000\n\n'
          '• 70% Living Expenses (₹35,000):\n'
          '  - House rent / EMI: ₹16,000\n'
          '  - Groceries & household food: ₹9,000\n'
          '  - Utilities, internet & phone: ₹4,000\n'
          '  - Commute & fuel: ₹3,500\n'
          '  - Insurance premiums: ₹2,500\n\n'
          '• 20% Savings & Debt (₹10,000):\n'
          '  - Systematic Investment Plan (SIP): ₹6,000\n'
          '  - Emergency cash buffer / PPF: ₹4,000\n\n'
          '• 10% Giving & Growth (₹5,000):\n'
          '  - Charitable giving & family gifts: ₹2,000\n'
          '  - Upskilling, books & learning: ₹1,500\n'
          '  - Leisure & dining out: ₹1,500',
      practicalUses: [
        'Setting up a straightforward, sustainable monthly budget immediately upon salary credit.',
        'Preventing lifestyle inflation as personal income and career compensation increase over time.',
        'Ensuring disciplined wealth-building without having to track every minor daily expense receipt.',
        'Balancing long-term financial security with immediate philanthropic giving and personal fulfillment.',
      ],
      importantPoints: [
        'Guideline, not a universal mandate: Cost of living varies significantly across tier-1 cities versus smaller towns; living expenses may initially exceed 70%.',
        'Adaptable for debt emergencies: Individuals carrying expensive debt (credit cards, personal loans) should channel the 20% savings and parts of the 10% discretionary bucket toward aggressive debt clearance first.',
        'Life stage adjustments: Fresh graduates with low obligations might save 30%–40%, whereas growing families may temporarily expand living expense allocations.',
        'Not personalized financial advice: This guideline provides a general budgeting reference and must be adjusted according to personal liabilities, family size, and financial goals.',
      ],
      disclaimer:
          'The 70/20/10 Rule is an educational budgeting guideline and personal finance model, not individualized financial advice or a mandatory formula. Budget allocations should be tailored to individual income levels, cost of living, liabilities, and financial goals.',
      relatedCalculatorRoute: '/calculator/sip',
      relatedCalculatorLabel: 'Plan 20% Savings with SIP',
    ),
  ];

  static List<FinancialManagementTopic> getAllTopics() => List.unmodifiable(topics);

  static FinancialManagementTopic? getTopicById(String id) {
    final normalized = id.toLowerCase().replaceAll('_', '-').trim();
    try {
      return topics.firstWhere(
        (t) => t.id.toLowerCase().replaceAll('_', '-').trim() == normalized,
      );
    } catch (_) {
      return null;
    }
  }

  static FinancialManagementTopic? getTopicByTitle(String title) {
    final normalized = title.trim().toLowerCase();
    try {
      return topics.firstWhere(
        (t) => t.title.trim().toLowerCase() == normalized,
      );
    } catch (_) {
      return null;
    }
  }
}
