import 'package:flutter/material.dart';

import '../models/financial_literacy_topic.dart';
import 'financial_management_data.dart';

/// Categories supported in the Financial Literacy Hub.
class FinancialLiteracyCategories {
  static const String all = 'All';
  static const String financialBasics = 'Financial Basics';
  static const String saving = 'Saving';
  static const String banking = 'Banking';
  static const String loansAndCredit = 'Loans & Credit';
  static const String investing = 'Investing';
  static const String tax = 'Tax';
  static const String insurance = 'Insurance';
  static const String retirement = 'Retirement & Pension';
  static const String personalFinance = 'Personal Finance';
  static const String riskManagement = 'Risk Management';

  static const List<String> values = [
    all,
    financialBasics,
    saving,
    banking,
    loansAndCredit,
    investing,
    tax,
    insurance,
    retirement,
    personalFinance,
    riskManagement,
  ];
}

/// Centralized repository of topics for the Financial Literacy Hub.
class FinancialLiteracyData {
  static final List<FinancialLiteracyTopic> _topics = _buildInitialTopics();

  static List<FinancialLiteracyTopic> _buildInitialTopics() {
    final list = <FinancialLiteracyTopic>[
      // 1. Budgeting Basics
      const FinancialLiteracyTopic(
        id: 'budgeting-basics',
        title: 'Budgeting Fundamentals',
        shortDescription: 'Master the flow of income and expenses to achieve financial peace',
        category: FinancialLiteracyCategories.personalFinance,
        isImportant: true,
        icon: Icons.account_balance_wallet_rounded,
        keywords: ['budget', 'budgeting', 'income', 'expenses', 'cashflow', 'spending', '50/30/20'],
        whatIsIt:
            'Budgeting is the foundational practice of intentionally planning how every rupee of take-home income is distributed across living expenses, debt obligations, future savings, and discretionary lifestyle goals.',
        whyItMatters:
            'Without a spending plan, income tends to expand alongside expenses (lifestyle inflation), leaving individuals vulnerable to month-end deficits, unexpected financial emergencies, and delayed long-term goals.',
        howItWorks:
            'Track your actual monthly net take-home earnings. Categorize historic expenditures into fixed essentials (housing, food, utilities), variable discretionary spending, and savings. Allocate upcoming income before the month begins to guarantee that savings occur first rather than last.',
        formulaOrFramework:
            'Fundamental Cashflow Balance:\n'
            'Net Income = Fixed Essentials + Variable Discretionary + Savings & Debt Prepayments\n\n'
            'Popular Frameworks:\n'
            '• 50/30/20 Rule: 50% Needs, 30% Wants, 20% Savings\n'
            '• 70/20/10 Rule: 70% Living Expenses, 20% Savings & Debt, 10% Giving / Growth\n'
            '• Zero-Based Budgeting: Income minus all allocated expenditures equals exactly zero.',
        example:
            'Monthly Net Income: ₹60,000\n'
            '• Fixed Needs (50%): ₹30,000 (Rent, groceries, utility bills, health insurance)\n'
            '• Discretionary Wants (30%): ₹18,000 (Dining out, streaming subscriptions, shopping)\n'
            '• Savings & Debt (20%): ₹12,000 (Emergency fund deposit, mutual fund SIP)',
        practicalUses: [
          'Pinpointing unnecessary recurring expenses and subscription leaks.',
          'Ensuring on-time payment of essential bills to avoid late fees or interest charges.',
          'Establishing a reliable monthly savings buffer before discretionary spending begins.',
          'Managing cash flow effectively during periods of irregular or freelance income.',
        ],
        importantPoints: [
          'A budget is a personal blueprint, not a punishment; it must allow for realistic flexibility.',
          'Review and adjust allocations quarterly as compensation changes or family expenses shift.',
          'The best budgeting system is the one you can sustain consistently over multiple years.',
        ],
        limitations: [
          'Strict budgeting requires ongoing discipline and periodic manual or automated tracking.',
          'Fixed costs in expensive metropolitan cities can make theoretical percentage splits challenging without proactive lifestyle adjustments.',
        ],
        disclaimer:
            'Budgeting guidelines are educational models. Allocations should be tailored to individual living costs, obligations, dependents, and goals.',
      ),

      // 2. Emergency Fund (Adapted from FinancialManagementData)
      _adaptFromManagement('emergency-fund', FinancialLiteracyCategories.saving, [
        'emergency',
        'fund',
        'reserve',
        'buffer',
        'safety',
        'cash',
      ]),

      // 3. Saving Basics
      const FinancialLiteracyTopic(
        id: 'saving-basics',
        title: 'Saving Fundamentals',
        shortDescription: 'The core habit of preserving capital for short and medium-term security',
        category: FinancialLiteracyCategories.saving,
        isImportant: true,
        icon: Icons.savings_rounded,
        keywords: ['saving', 'savings', 'pay yourself first', 'liquidity', 'short-term goals', 'capital preservation'],
        whatIsIt:
            'Saving is the deliberate act of setting aside unspent income in safe, highly accessible financial instruments to protect against life uncertainties and fund short-to-medium-term milestone purchases.',
        whyItMatters:
            'Saving provides immediate peace of mind and liquidity. It creates the foundational capital base required before taking on market-linked investment risks.',
        howItWorks:
            'Practice the classic rule: "Pay Yourself First". The moment your monthly paycheck arrives, automate an electronic transfer of your target savings amount into a separate high-yield savings or recurring deposit account before paying discretionary bills.',
        formulaOrFramework:
            'Golden Savings Rule:\n'
            'Savings = Income - Fixed Obligations (prioritized first)\n'
            'Spending = What remains after savings are securely deposited',
        example:
            '• If you earn ₹50,000 and save 20% (₹10,000) every month:\n'
            '• 1 Year Accumulation: ₹1,20,000 (plus accrued interest)\n'
            '• 3 Year Accumulation: ₹3,60,000 (providing a substantial safety buffer)',
        practicalUses: [
          'Funding milestone purchases within 1 to 3 years (e.g., laptop, home appliances, vacation).',
          'Building liquidity reserves for medical insurance deductibles or home repairs.',
          'Accumulating down-payment capital for vehicle or housing purchases.',
        ],
        importantPoints: [
          'Prioritize capital safety and liquidity over aggressive return hunting for short-term savings.',
          'Keep your primary savings account separate from your day-to-day spending account to prevent accidental withdrawals.',
          'Remember that long-term savings left in basic cash will gradually lose purchasing power to inflation.',
        ],
        limitations: [
          'Traditional savings instruments typically yield returns near or below inflation, making them unsuitable for multi-decade wealth creation.',
        ],
        disclaimer:
            'Interest rates and deposit insurance limits on savings accounts are regulated by the Reserve Bank of India and participating banking institutions.',
        relatedCalculatorRoute: '/calculator/savings',
        relatedCalculatorLabel: 'Open Savings Calculator',
      ),

      // 4. Simple Interest
      const FinancialLiteracyTopic(
        id: 'simple-interest-basics',
        title: 'Simple Interest Basics',
        shortDescription: 'Interest computed strictly on the initial principal balance',
        category: FinancialLiteracyCategories.financialBasics,
        isImportant: false,
        icon: Icons.percent_rounded,
        keywords: ['simple interest', 'si', 'principal', 'interest formula', 'flat rate', 'fixed returns'],
        whatIsIt:
            'Simple Interest is a straightforward method of calculating interest charges or earnings where the interest amount is determined solely by the original principal balance, rate of interest, and elapsed time.',
        whyItMatters:
            'Understanding Simple Interest helps consumers correctly identify flat-rate loan offers (which can hide significantly higher effective costs) and evaluate short-term debt instruments like treasury bills and promissory notes.',
        howItWorks:
            'Unlike compound interest, previous interest earnings are never added to the principal. The interest accumulated in year one is identical to the interest accumulated in year five.',
        formulaOrFramework:
            'Simple Interest Formula:\n'
            'SI = (P × R × T) / 100\n\n'
            'Total Maturity Amount:\n'
            'A = P + SI = P × (1 + (R × T / 100))\n\n'
            'Where: P = Principal, R = Annual Rate (%), T = Time (Years)',
        example:
            '• Principal (P): ₹1,00,000\n'
            '• Rate (R): 7% p.a.\n'
            '• Time (T): 3 Years\n'
            '• SI = (1,00,000 × 7 × 3) / 100 = ₹21,000\n'
            '• Total Amount = ₹1,21,000',
        practicalUses: [
          'Calculating interest on short-term personal notes and peer-to-peer lending.',
          'Verifying flat-rate consumer durables and two-wheeler financing promotions.',
          'Valuing basic short-term commercial papers or fixed-term sovereign bills.',
        ],
        importantPoints: [
          'Simple interest grows linearly, not exponentially.',
          'Flat-rate loan advertising using simple interest can significantly understate the true reducing-balance annual percentage rate (APR).',
        ],
        limitations: [
          'Does not reflect the true power of long-term compounding for multi-year investments.',
        ],
        disclaimer:
            'Simple Interest calculations illustrate nominal flat calculations. Most commercial loans and bank deposits operate on reducing-balance or compounding schedules.',
        relatedCalculatorRoute: '/calculator/simple_interest',
        relatedCalculatorLabel: 'Open Simple Interest Calculator',
      ),

      // 5. Compound Interest
      const FinancialLiteracyTopic(
        id: 'compound-interest-basics',
        title: 'Compound Interest Basics',
        shortDescription: 'Earning interest on both the principal and previous accumulated interest',
        category: FinancialLiteracyCategories.financialBasics,
        isImportant: true,
        icon: Icons.trending_up_rounded,
        keywords: ['compound interest', 'compounding', 'exponential growth', 'wealth accumulation', 'eighth wonder'],
        whatIsIt:
            'Compound Interest is interest calculated on the initial principal and also on the accumulated interest from previous periods. It is often described as "interest on interest", creating exponential growth over time.',
        whyItMatters:
            'Compounding is the single most powerful mathematical engine for building long-term wealth. Small sums invested consistently early in life can outgrow much larger sums invested later.',
        howItWorks:
            'At each compounding interval (annual, quarterly, or monthly), earned interest is credited to the principal balance. Subsequent interest is calculated on this larger combined balance.',
        formulaOrFramework:
            'Compound Interest Formula:\n'
            'A = P × (1 + R / (100 × n))^(n × T)\n'
            'CI = A - P\n\n'
            'Where: P = Principal, R = Annual Rate, n = Compounding frequency per year, T = Tenure in years',
        example:
            '• Principal: ₹1,00,000 invested at 10% p.a. for 20 years:\n'
            '• Simple Interest total: ₹3,00,000\n'
            '• Compound Interest total: ₹6,72,750 (more than double the simple interest outcome!)',
        practicalUses: [
          'Projecting multi-decade returns in mutual fund SIPs, PPF, and long-term equities.',
          'Understanding how credit card unpaid balances snowball rapidly when revolving debt.',
          'Comparing quarterly versus annual compounding yields on bank deposits.',
        ],
        importantPoints: [
          'Time in the market matters far more than timing the market due to the back-heavy exponential curve.',
          'Higher compounding frequency (e.g., quarterly vs annual) yields slightly higher effective annual return.',
        ],
        limitations: [
          'Real-world investment compounding is subject to market fluctuations, taxes on realized gains, and expense ratios.',
        ],
        disclaimer:
            'Illustrative compounding examples assume continuous reinvestment and fixed rates. Real market investments experience variable rates and market risks.',
        relatedCalculatorRoute: '/calculator/compound_interest',
        relatedCalculatorLabel: 'Open Compound Interest Calculator',
      ),

      // 6. Inflation Basics
      const FinancialLiteracyTopic(
        id: 'inflation-basics',
        title: 'Inflation & Purchasing Power',
        shortDescription: 'How rising general price levels erode the future value of money',
        category: FinancialLiteracyCategories.financialBasics,
        isImportant: true,
        icon: Icons.price_change_rounded,
        keywords: ['inflation', 'purchasing power', 'cpi', 'real return', 'nominal return', 'cost of living'],
        whatIsIt:
            'Inflation is the rate at which the general level of prices for goods and services rises, causing each unit of currency to buy fewer goods and services over time.',
        whyItMatters:
            'If your investment return is lower than the inflation rate, your real wealth is declining even if the nominal account balance appears to be growing.',
        howItWorks:
            'Statisticians measure inflation through consumer price indices (CPI). To measure your true financial progress, calculate your "Real Rate of Return" by subtracting the inflation rate from your nominal investment return.',
        formulaOrFramework:
            'Purchasing Power Future Value:\n'
            'Future Value = Present Value × (1 + Inflation Rate)^Years\n\n'
            'Real Rate of Return (Fisher Approximation):\n'
            'Real Return ≈ Nominal Return (%) - Inflation Rate (%)',
        example:
            '• A basket of household groceries costs ₹10,000 today.\n'
            '• At an annual inflation rate of 6%:\n'
            '  - 10 Years later: Same basket costs ₹17,908\n'
            '  - 20 Years later: Same basket costs ₹32,071 (more than triples!)',
        practicalUses: [
          'Adjusting future retirement corpus targets to account for higher future living costs.',
          'Selecting investment avenues that comfortably beat inflation (like diversified equities and sovereign bonds).',
          'Planning for child higher education costs, where education inflation often outpaces general CPI.',
        ],
        importantPoints: [
          'Cash left idle in non-interest-bearing accounts is guaranteed to lose purchasing power year after year.',
          'Personal inflation can exceed official national CPI depending on health, dietary, and lifestyle preferences.',
        ],
        limitations: [
          'Official inflation figures reflect broad statistical averages and may not match your personal household basket.',
        ],
        disclaimer:
            'Inflation indices are published by governmental statistical authorities. Past inflation rates do not guarantee future inflation trends.',
        relatedCalculatorRoute: '/calculator/inflation',
        relatedCalculatorLabel: 'Open Inflation Calculator',
      ),

      // 7. Risk vs Return
      const FinancialLiteracyTopic(
        id: 'risk-vs-return',
        title: 'Risk vs Return Principle',
        shortDescription: 'The fundamental trade-off: higher potential returns demand higher risk',
        category: FinancialLiteracyCategories.riskManagement,
        isImportant: true,
        icon: Icons.balance_rounded,
        keywords: ['risk', 'return', 'volatility', 'capital loss', 'trade-off', 'risk profile'],
        whatIsIt:
            'The Risk-Return trade-off is an iron law of investing stating that the potential return on an asset rises in proportion to an increase in risk. There is mathematically no such thing as high return with zero risk.',
        whyItMatters:
            'Understanding this principle protects investors from fraudulent financial schemes and predatory products promising "guaranteed 20% annual returns without risk".',
        howItWorks:
            'Low-risk assets (bank fixed deposits, sovereign treasury bills) offer predictable, lower yields because the risk of principal loss is near zero. High-risk assets (equities, real estate, commodities) compensate investors for price volatility and uncertainty with higher expected long-term capital appreciation.',
        formulaOrFramework:
            'Risk Spectrum Hierarchy:\n'
            'Sovereign Debt (Lowest Risk / Moderate Return)\n'
            '  └── High-Grade Corporate Bonds\n'
            '      └── Large-Cap Equities\n'
            '          └── Mid & Small-Cap Equities\n'
            '              └── Venture & Cryptocurrencies (Highest Risk / Highest Return)',
        example:
            '• Investor A puts ₹1,00,000 in a Government Bond at 7% p.a.: Zero volatility, guaranteed return, but limited wealth creation.\n'
            '• Investor B puts ₹1,00,000 in an Equity Index: May fall 20% in year one, rise 35% in year two, but historically compounds at higher rates over 15+ years.',
        practicalUses: [
          'Aligning portfolio holdings with your personal risk tolerance, age, and emotional capacity for loss.',
          'Immediately detecting Ponzi schemes and unrealistic investment sales pitches.',
          'Selecting defensive assets when close to a financial goal deadline.',
        ],
        importantPoints: [
          'Risk does not just mean losing money; it also encompasses volatility, liquidity lock-in, and purchasing power erosion.',
          'Taking zero investment risk is itself a risk (inflation risk).',
        ],
        limitations: [
          'Higher risk does not guarantee higher returns; it only increases the potential upside while expanding downside exposure.',
        ],
        disclaimer:
            'All investments carry degrees of capital and market risk. Past asset class performance is not an indicator of future results.',
      ),

      // 8. Diversification Basics
      const FinancialLiteracyTopic(
        id: 'diversification-basics',
        title: 'Diversification & Portfolio Safety',
        shortDescription: 'Reducing portfolio volatility by spreading capital across diverse assets',
        category: FinancialLiteracyCategories.investing,
        isImportant: true,
        icon: Icons.pie_chart_rounded,
        keywords: ['diversification', 'portfolio', 'unsystematic risk', 'asset classes', 'all eggs in one basket'],
        whatIsIt:
            'Diversification is the risk management strategy of mixing a wide variety of uncorrelated investments within a portfolio to limit exposure to any single asset, company, or sector.',
        whyItMatters:
            'It is the only "free lunch" in finance. By holding assets that behave differently under various economic conditions, you can reduce portfolio volatility without necessarily sacrificing long-term returns.',
        howItWorks:
            'If you own stock in one company and that company faces regulatory issues or poor management, your entire capital is at risk. If you own a diversified index fund containing 100+ businesses across IT, banking, energy, and healthcare, a slump in one sector is cushioned by gains in others.',
        formulaOrFramework:
            'Core Diversification Pillars:\n'
            '1. Across Companies: Holding dozens of businesses rather than 1 or 2 stocks.\n'
            '2. Across Sectors: Banking, IT, Pharma, Consumer Goods, Infrastructure.\n'
            '3. Across Asset Classes: Equities (growth), Debt/Bonds (stability), Gold (hedge), Real Estate.\n'
            '4. Across Geographies: Domestic market plus international exposure.',
        example:
            '• During an economic downturn, company earnings and equities might contract by 15%.\n'
            '• However, high-quality government bonds and gold prices often appreciate or remain steady, protecting the net portfolio value.',
        practicalUses: [
          'Investing via broad mutual funds or ETFs rather than concentrated stock picking.',
          'Protecting accumulated wealth against sudden corporate bankruptcies or localized crises.',
          'Smoothing out annual portfolio fluctuations to prevent emotional panic selling.',
        ],
        importantPoints: [
          'Over-diversification ("diworsification") beyond 25-30 uncorrelated holdings adds complexity with diminishing risk reduction.',
          'Diversification cannot eliminate systemic market risk (e.g., broad economic recessions).',
        ],
        limitations: [
          'During extreme global market liquidity shocks, multiple asset classes may temporarily drop together.',
        ],
        disclaimer:
            'Diversification strategies help manage portfolio risk but cannot guarantee profits or completely insulate against market declines.',
      ),

      // 9. Asset Allocation Basics
      const FinancialLiteracyTopic(
        id: 'asset-allocation-basics',
        title: 'Asset Allocation Strategies',
        shortDescription: 'Balancing equities, fixed income, cash, and gold based on your time horizon',
        category: FinancialLiteracyCategories.investing,
        isImportant: false,
        icon: Icons.layers_rounded,
        keywords: ['asset allocation', 'equity', 'debt', 'gold', 'rebalancing', 'time horizon'],
        whatIsIt:
            'Asset Allocation is the implementation strategy of dividing an investment portfolio among primary asset categories, typically equities (stocks), fixed income (bonds/FDs), cash equivalents, and physical commodities (gold).',
        whyItMatters:
            'Empirical financial studies demonstrate that asset allocation accounts for more than 90% of the variation in a portfolio\'s long-term returns, outweighing individual security selection or market timing.',
        howItWorks:
            'Determine target allocation percentages according to your investment time horizon and risk profile. Periodically "rebalance" the portfolio (typically once a year) by selling over-performing assets and buying under-performing assets to restore target ratios.',
        formulaOrFramework:
            'Traditional Heuristic:\n'
            'Equity Allocation (%) ≈ 100 (or 110) - Investor Age\n'
            'Debt & Cash (%) ≈ Remainder\n\n'
            'Example for a 30-year-old:\n'
            '• 70% Equities (Long-term growth)\n'
            '• 25% Fixed Income / Debt (Capital preservation)\n'
            '• 5% Gold / Liquid Cash (Hedge and liquidity)',
        example:
            '• Target: 60% Equity / 40% Debt.\n'
            '• After an equity bull run, portfolio becomes 75% Equity / 25% Debt.\n'
            '• Rebalancing Action: Shift 15% from equities into debt to lock in profits and de-risk the portfolio.',
        practicalUses: [
          'De-risking a portfolio progressively as you approach retirement or college funding milestones.',
          'Automating disciplined buying low and selling high through annual rebalancing.',
          'Maintaining a clear strategy regardless of market headlines or emotional hype.',
        ],
        importantPoints: [
          'Time horizon is critical: Money needed within 3 years belongs in debt or cash, not volatile equities.',
          'Factor in tax implications when selling assets during annual rebalancing.',
        ],
        limitations: [
          'Age-based heuristics are simplistic and should be adapted for individual income stability, pension availability, and liabilities.',
        ],
        disclaimer:
            'Asset allocation models are illustrative. Consult a certified financial planner for personalized asset allocation advice.',
      ),

      // 10. Credit Score Basics
      const FinancialLiteracyTopic(
        id: 'credit-score-basics',
        title: 'Credit Score & Credit Health',
        shortDescription: 'How your credit history influences loan approvals, rates, and borrowing power',
        category: FinancialLiteracyCategories.loansAndCredit,
        isImportant: true,
        icon: Icons.speed_rounded,
        keywords: ['credit score', 'cibil', 'credit report', 'credit card', 'borrowing', 'loans', 'interest rates'],
        whatIsIt:
            'A Credit Score is a 3-digit numerical summary (ranging between 300 and 900 in India) that measures a consumer\'s creditworthiness based on their repayment track record, borrowing history, and credit usage.',
        whyItMatters:
            'Lenders use credit scores to evaluate loan and credit card applications. A high score (typically 750+) unlocks faster approvals, larger credit limits, and significantly lower interest rates on home and vehicle loans.',
        howItWorks:
            'Credit bureaus (such as CIBIL, Experian, Equifax, and CRIF High Mark) collect monthly data from banks and NBFCs. They assess timely repayments, credit utilization ratios, credit vintage, credit mix, and recent credit inquiries.',
        formulaOrFramework:
            'Credit Score Tiers:\n'
            '• 750 - 900: Excellent (Preferred loan rates, minimal paperwork)\n'
            '• 700 - 749: Good (Eligible for most loans at standard rates)\n'
            '• 650 - 699: Average (Higher interest rates, additional guarantor requirements)\n'
            '• Below 650: Poor (High rejection probability, predatory loan terms)',
        example:
            'On a ₹50,00,000 20-year Home Loan:\n'
            '• Borrower A (Score 780, Rate 8.4%): Monthly EMI = ₹43,075 | Total Interest = ₹53,38,000\n'
            '• Borrower B (Score 670, Rate 9.6%): Monthly EMI = ₹46,929 | Total Interest = ₹62,63,000\n'
            '• High credit score saves Borrower A over ₹9.2 Lakhs in interest!',
        practicalUses: [
          'Checking your free annual credit report from major bureaus to catch reporting errors or identity fraud.',
          'Negotiating lower home loan interest rates with competing financial institutions.',
          'Qualifying for premium credit cards with travel and lifestyle privileges.',
        ],
        importantPoints: [
          'Payment history is the most important factor: Never miss or delay a loan EMI or credit card bill.',
          'Keep credit card utilization below 30% of your available total credit limit.',
          'Avoid applying for multiple credit cards or personal loans in rapid succession (causes hard inquiries).',
        ],
        limitations: [
          'Credit scores take several months to rebuild following a settlement or default.',
        ],
        disclaimer:
            'Credit scoring criteria are determined independently by registered credit information companies and institutional lending policies.',
      ),

      // 11. Debt Management Basics
      const FinancialLiteracyTopic(
        id: 'debt-management-basics',
        title: 'Debt Management & Repayment',
        shortDescription: 'Strategies to eliminate high-interest liabilities and avoid debt traps',
        category: FinancialLiteracyCategories.loansAndCredit,
        isImportant: true,
        icon: Icons.money_off_rounded,
        keywords: ['debt', 'debt payoff', 'avalanche', 'snowball', 'prepayment', 'loans', 'credit card debt'],
        whatIsIt:
            'Debt Management is the systematic framework of structuring, servicing, and rapidly eliminating liabilities to regain financial autonomy and reduce interest expenses.',
        whyItMatters:
            'High-interest debt (especially revolving credit card interest at 36%-45% p.a. and unregulated instant personal loans) creates a compounding cycle that can consume your entire disposable income.',
        howItWorks:
            'Distinguish between productive debt (low-interest, tax-deductible loans for appreciating assets like home mortgages) and destructive debt (unsecured loans for depreciating consumption). Choose a structured debt payoff methodology: the Debt Avalanche or Debt Snowball.',
        formulaOrFramework:
            'Payoff Methodologies:\n'
            '1. Debt Avalanche (Mathematically Optimal):\n'
            '   Order debts from highest interest rate to lowest. Pay minimums on all, channeling all surplus cash into the highest rate debt.\n'
            '2. Debt Snowball (Psychologically Motivating):\n'
            '   Order debts from smallest balance to largest. Pay off the smallest balance first to build emotional momentum.',
        example:
            'Outstanding Debts:\n'
            '• Credit Card: ₹40,000 at 40% p.a.\n'
            '• Personal Loan: ₹1,50,000 at 16% p.a.\n'
            '• Car Loan: ₹3,00,000 at 9% p.a.\n'
            'Avalanche Strategy: Attack the 40% credit card aggressively first, eliminating the most toxic interest drain.',
        practicalUses: [
          'Consolidating scattered high-cost loans into a single lower-interest secured facility.',
          'Prepaying loan principal early in the tenure when the interest component is heaviest.',
          'Setting up automated EMI payments to protect credit standing.',
        ],
        importantPoints: [
          'Paying only the "Minimum Amount Due" on credit card statements is a trap that stretches repayment over decades.',
          'Do not use fresh debt to pay off existing debt without fixing underlying spending habits.',
        ],
        limitations: [
          'Loan prepayment penalties or tax deduction losses (e.g. Section 24b on home loans) should be factored before prepaying.',
        ],
        disclaimer:
            'Debt management principles are educational. Specific loan terms, foreclosure fees, and prepayment clauses are governed by individual loan agreements.',
      ),

      // 12. Loan / EMI Basics
      const FinancialLiteracyTopic(
        id: 'loan-emi-basics',
        title: 'Loan & EMI Basics',
        shortDescription: 'How equated monthly installments, principal, and interest amortization work',
        category: FinancialLiteracyCategories.loansAndCredit,
        isImportant: false,
        icon: Icons.receipt_long_rounded,
        keywords: ['loan', 'emi', 'amortization', 'reducing balance', 'principal', 'interest', 'tenure'],
        whatIsIt:
            'An Equated Monthly Installment (EMI) is a fixed payment amount made by a borrower to a lender at a specified calendar date each month to repay a loan over a designated tenure.',
        whyItMatters:
            'Borrowers often focus only on whether they can afford the monthly EMI figure without realizing how much total interest they will pay over a 15-to-25-year repayment schedule.',
        howItWorks:
            'Each EMI consists of two parts: interest on the outstanding principal and principal repayment. In the early years of a reducing-balance loan, interest constitutes the vast majority of each EMI. Over time, as principal declines, interest drops and more of each payment pays down the loan.',
        formulaOrFramework:
            'Standard EMI Formula:\n'
            'EMI = [P × r × (1 + r)^n] / [(1 + r)^n - 1]\n\n'
            'Where: P = Loan Principal, r = Monthly interest rate (Annual Rate / 12 / 100), n = Tenure in months',
        example:
            '• Loan Amount: ₹20,00,000 | Interest Rate: 9.0% | Tenure: 10 Years (120 months)\n'
            '• Monthly EMI: ₹25,335\n'
            '• Total Amount Paid: ₹30,40,217\n'
            '• Total Interest Paid: ₹10,40,217 (more than 50% of the borrowed amount!)',
        practicalUses: [
          'Calculating loan affordability so that total EMIs remain comfortably below 40% of net monthly income.',
          'Comparing reducing-balance loans against misleading flat-rate dealer loan quotes.',
          'Planning lump-sum partial prepayments to dramatically compress the repayment schedule.',
        ],
        importantPoints: [
          'Prepaying just one extra EMI per year can shorten a 20-year home loan by 3 to 4 years.',
          'Longer tenures lower your monthly EMI but massively inflate the total interest paid over the life of the loan.',
        ],
        limitations: [
          'Floating-rate loans can see tenure or EMI adjustments when central bank benchmark rates change.',
        ],
        disclaimer:
            'Loan EMI calculations are illustrative. Actual lending terms, processing fees, and documentation charges depend on the financing bank.',
        relatedCalculatorRoute: '/calculator/emi',
        relatedCalculatorLabel: 'Open EMI Calculator',
      ),

      // 13. Insurance Basics
      const FinancialLiteracyTopic(
        id: 'insurance-basics',
        title: 'Insurance & Protection Basics',
        shortDescription: 'Transferring catastrophic financial risk through pure protection policies',
        category: FinancialLiteracyCategories.insurance,
        isImportant: true,
        icon: Icons.shield_rounded,
        keywords: ['insurance', 'term insurance', 'health insurance', 'pure protection', 'risk transfer', 'life cover'],
        whatIsIt:
            'Insurance is a risk management contract in which an individual pays a small guaranteed premium to transfer the risk of catastrophic financial losses (such as medical hospitalization, disability, or premature death) to an insurance company.',
        whyItMatters:
            'A single medical crisis or the untimely demise of an earning member can wipe out years of accumulated family savings and derail dependents\' futures.',
        howItWorks:
            'Identify non-negotiable risks. For health, purchase comprehensive family floater health insurance with adequate coverage. For life, purchase pure Term Insurance (where premiums provide pure death-benefit protection with zero savings gimmicks), providing 10-15x your annual income in coverage.',
        formulaOrFramework:
            'Essential Protection Checklist:\n'
            '1. Health Insurance: ₹10 Lakhs to ₹25 Lakhs+ family floater with super top-up.\n'
            '2. Pure Term Life Insurance: 10x to 15x annual income until retirement age.\n'
            '3. Core Rule: Never mix insurance with investment (avoid traditional endowment/money-back plans with low yields and inadequate cover).',
        example:
            '• Traditional Endowment Plan: Premium ₹1,00,000/year for ₹15 Lakhs life cover; typical internal return ~4-5% p.a.\n'
            '• Smart Separation: Pure Term Cover (₹1 Crore cover for ~₹12,000/year) + remaining ₹88,000 invested in index SIPs, resulting in 6x higher protection and significantly larger wealth.',
        practicalUses: [
          'Securing children\'s education and family living expenses in the event of an untimely death.',
          'Shielding investments from being liquidated to settle hospital bills.',
          'Claiming tax deductions under Section 80D (Health Insurance) and Section 80C (Life Insurance).',
        ],
        importantPoints: [
          'Always disclose pre-existing medical conditions truthfully on insurance application forms to prevent claim repudiation.',
          'Employer health insurance terminates upon resignation or retirement; always maintain an independent personal health policy.',
        ],
        limitations: [
          'Insurance policies contain waiting periods, sub-limits, and exclusions that must be reviewed before buying.',
        ],
        disclaimer:
            'Insurance is a subject matter of solicitation. Policy terms, exclusions, and claim ratios are regulated by the Insurance Regulatory and Development Authority of India (IRDAI).',
      ),

      // 14. Retirement Planning Basics
      const FinancialLiteracyTopic(
        id: 'retirement-planning-basics',
        title: 'Retirement Planning Fundamentals',
        shortDescription: 'Building a sustainable corpus to fund living expenses after active income ends',
        category: FinancialLiteracyCategories.retirement,
        isImportant: true,
        icon: Icons.beach_access_rounded,
        keywords: ['retirement', 'pension', 'longevity risk', 'retirement corpus', 'annuity', 'swp', 'nest egg'],
        whatIsIt:
            'Retirement Planning is the multi-decade process of calculating future post-retirement living expenses and systematically investing in growth and income-producing assets to ensure financial independence for life.',
        whyItMatters:
            'In modern society, defined-benefit corporate pensions are largely obsolete. Coupled with increased life expectancy (often 25-30 years in retirement) and relentless healthcare inflation, failing to build an independent corpus is catastrophic.',
        howItWorks:
            'Estimate your current annual living expenses. Project them forward to your target retirement age using inflation (typically 6-7%). Calculate the target corpus needed to support systematic withdrawals (such as a 3%-4% safe withdrawal rate) throughout your retirement lifespan.',
        formulaOrFramework:
            'Corpus Estimation Framework (Rule of 25-30x):\n'
            'Target Retirement Corpus ≈ Projected First-Year Retirement Living Expenses × 25 to 30\n\n'
            'Post-Retirement Bucket Strategy:\n'
            '• Bucket 1 (Immediate 1-3 years): Ultra-safe liquid cash & short FDs\n'
            '• Bucket 2 (Next 4-8 years): Conservative debt funds & senior savings schemes\n'
            '• Bucket 3 (9+ years): Equity index funds to outpace inflation',
        example:
            '• Current Monthly Expenses: ₹40,000 (₹4.8 Lakhs/year)\n'
            '• Age: 30 | Retirement at: 60 | Life Expectancy: 85\n'
            '• Projected expenses at age 60 (at 6% inflation): ~₹2.3 Lakhs/month\n'
            '• Target Corpus required: ~₹5.5 to ₹6.5 Crores to safely fund 25 years of retired life.',
        practicalUses: [
          'Determining the exact monthly SIP contribution required today to meet retirement milestones.',
          'Utilizing tax-advantaged retirement instruments (EPF, PPF, NPS).',
          'Preventing an over-reliance on children or relatives during senior years.',
        ],
        importantPoints: [
          'Start early: Compounding does the heavy lifting in your 20s and 30s. Delaying by 10 years triples the required monthly investment.',
          'Do not withdraw from retirement accounts (like EPF) for discretionary consumer lifestyle purchases.',
        ],
        limitations: [
          'Projections depend on macroeconomic variables including long-term inflation, longevity, and portfolio sequence of returns.',
        ],
        disclaimer:
            'Retirement projections are educational models. Actual retirement security depends on market conditions, healthcare expenditures, and taxation at withdrawal.',
        relatedCalculatorRoute: '/calculator/retirement',
        relatedCalculatorLabel: 'Open Retirement Planner',
      ),

      // 15. Tax Basics
      const FinancialLiteracyTopic(
        id: 'tax-basics',
        title: 'Income Tax Fundamentals',
        shortDescription: 'Understanding tax slabs, deductions, and compliant financial planning',
        category: FinancialLiteracyCategories.tax,
        isImportant: true,
        icon: Icons.receipt_rounded,
        keywords: ['tax', 'income tax', 'tax slabs', 'deductions', 'exemptions', 'section 80c', 'old vs new regime'],
        whatIsIt:
            'Income Tax is a progressive direct tax levied by the Central Government on taxable income generated by individuals and businesses during a financial year.',
        whyItMatters:
            'Legitimate tax planning allows citizens to legally minimize tax liability through eligible investments (PPF, ELSS, NPS, Health Insurance), keeping more of their earned capital to compound for future goals.',
        howItWorks:
            'Assess income from all heads: Salary, House Property, Capital Gains, Business/Profession, and Other Sources. Under the Old Regime, claim eligible deductions (Section 80C, 80D, 24b) to compute net taxable income. Under the New Regime, enjoy lower slab rates with streamlined, minimal deductions.',
        formulaOrFramework:
            'Tax Computation Flow:\n'
            'Gross Total Income\n'
            '  - Eligible Deductions (80C, 80D, 80CCD, etc.)\n'
            '  = Net Taxable Income\n'
            '  Apply Progressive Slab Rates\n'
            '  - Rebate (e.g. Section 87A)\n'
            '  + Health & Education Cess (4%)\n'
            '  = Total Tax Payable',
        example:
            'Under Old Regime:\n'
            '• Gross Salary: ₹10,00,000\n'
            '• Standard Deduction: ₹50,000\n'
            '• Section 80C (PPF/ELSS): ₹1,50,000\n'
            '• Section 80D (Health Insurance): ₹25,000\n'
            '• Section 80CCD(1B) (NPS): ₹50,000\n'
            '• Taxable Income drops to ₹7,25,000, saving substantial tax.',
        practicalUses: [
          'Selecting the most advantageous tax regime (Old vs New) for your income profile and deduction volume.',
          'Scheduling tax-saving investments systematically throughout the year rather than panic investing in March.',
          'Understanding capital gains tax implications on equity and debt asset sales.',
        ],
        importantPoints: [
          'Tax avoidance through legitimate statutory deductions is smart; tax evasion (hiding income) is illegal and punishable.',
          'Never invest solely for tax deduction purposes in a product with poor liquidity or substandard returns.',
        ],
        limitations: [
          'Tax laws, slabs, and exemptions are subject to annual amendments by the Finance Act passed in Parliament.',
        ],
        disclaimer:
            'Tax information is for educational orientation. Consult a chartered accountant or certified tax professional for current fiscal year filing.',
        relatedCalculatorRoute: '/calculator/income_tax',
        relatedCalculatorLabel: 'Open Tax Calculator',
      ),

      // 16. Investing Basics
      const FinancialLiteracyTopic(
        id: 'investing-basics',
        title: 'Investing Fundamentals',
        shortDescription: 'Deploying capital into productive assets to grow wealth over time',
        category: FinancialLiteracyCategories.investing,
        isImportant: true,
        icon: Icons.trending_up_rounded,
        keywords: ['investing', 'investment', 'capital growth', 'stocks', 'mutual funds', 'wealth creation', 'equity'],
        whatIsIt:
            'Investing is the practice of allocating money to assets (such as stocks, mutual funds, real estate, or bonds) with the expectation that they will generate income, capital appreciation, or both over the long run.',
        whyItMatters:
            'Saving alone cannot build substantial wealth because inflation continuously chips away at the purchasing power of idle currency. Investing puts your money to work as an owner or lender in economic enterprises.',
        howItWorks:
            'When you invest in equities, you become a partial owner in commercial businesses that generate profits, develop products, and grow with the national economy. Over multi-year horizons, productive corporate growth compounds your invested capital.',
        formulaOrFramework:
            'Primary Investment Channels:\n'
            '1. Ownership Assets (Equities, Real Estate, Businesses): Higher volatility, high long-term growth potential.\n'
            '2. Lending Assets (Bonds, Bank FDs, Government Securities): Lower volatility, fixed interest income.\n'
            '3. Protective Assets (Gold, Cash Equivalents): Hedge against inflation and geopolitical crises.',
        example:
            '• Over 20 years at a hypothetical 12% annual compounding return:\n'
            '  - Initial Lump Sum: ₹1,00,000\n'
            '  - Value at Year 20: ~₹9,64,629 (nearly a 10x growth in capital)',
        practicalUses: [
          'Funding major life goals such as early financial independence, children\'s higher education, and legacy wealth.',
          'Generating passive cash flows through dividend-yielding stocks or rental properties.',
          'Building resilience against long-term inflationary pressures.',
        ],
        importantPoints: [
          'Investing is not gambling; it requires patience, continuous discipline, and emotional composure during market dips.',
          'Never invest money you will need within the next 3 to 5 years into volatile asset classes like equities.',
        ],
        limitations: [
          'All equity and market investments involve price volatility and risk of capital impairment.',
        ],
        disclaimer:
            'Investment education does not constitute financial advice or investment recommendations. Market investments are subject to market risks.',
      ),

      // 17. SIP Basics
      const FinancialLiteracyTopic(
        id: 'sip-basics',
        title: 'SIP (Systematic Investment Plan)',
        shortDescription: 'Disciplined periodic investing and rupee cost averaging in mutual funds',
        category: FinancialLiteracyCategories.investing,
        isImportant: true,
        icon: Icons.calendar_month_rounded,
        keywords: ['sip', 'systematic investment plan', 'mutual funds', 'rupee cost averaging', 'disciplined investing'],
        whatIsIt:
            'A Systematic Investment Plan (SIP) is an investment facility offered by mutual funds that allows individuals to invest a fixed amount of money at regular intervals (monthly or weekly) into a chosen mutual fund scheme.',
        whyItMatters:
            'SIP removes the psychological stress of trying to time market highs and lows. It automates disciplined investing directly from your salary account, transforming small monthly surpluses into substantial wealth.',
        howItWorks:
            'Through "Rupee Cost Averaging", when market prices drop, your fixed monthly allocation buys more mutual fund units. When market prices rise, it buys fewer units. Over complete market cycles, this lowers your average acquisition cost per unit.',
        formulaOrFramework:
            'Future Value of SIP Formula:\n'
            'FV = P × [((1 + i)^n - 1) / i] × (1 + i)\n\n'
            'Where: P = Monthly Installment, i = Monthly rate of return, n = Total number of monthly installments',
        example:
            '• Monthly SIP: ₹5,000 for 15 Years at an assumed 12% p.a. return:\n'
            '• Total Amount Invested: ₹9,00,000 (₹5,000 × 180 months)\n'
            '• Estimated Wealth Created: ~₹25,22,880\n'
            '• Net Wealth Gain: ~₹16,22,880',
        practicalUses: [
          'Building long-term wealth out of regular monthly salary income.',
          'Automating goal funding without needing large lump-sum capital up front.',
          'Stepping up contributions annually (Step-up SIP) alongside salary raises.',
        ],
        importantPoints: [
          'Never pause or stop your SIP during market corrections; downturns are when your installments accumulate the most units at discounted prices.',
          'Direct mutual fund plans have lower expense ratios than regular plans, saving tens of thousands in fees over decades.',
        ],
        limitations: [
          'Returns from equity mutual funds fluctuate with broader economic conditions and are not guaranteed.',
        ],
        disclaimer:
            'Mutual fund investments are subject to market risks. Read all scheme-related documents carefully before investing.',
        relatedCalculatorRoute: '/calculator/sip',
        relatedCalculatorLabel: 'Open SIP Calculator',
      ),

      // 18. FD Basics
      const FinancialLiteracyTopic(
        id: 'fd-basics',
        title: 'Fixed Deposit (FD) Basics',
        shortDescription: 'Guaranteed-return term deposits backed by banking institutions',
        category: FinancialLiteracyCategories.banking,
        isImportant: false,
        icon: Icons.account_balance_rounded,
        keywords: ['fixed deposit', 'fd', 'term deposit', 'guaranteed returns', 'dicgc insurance', 'senior citizen'],
        whatIsIt:
            'A Fixed Deposit (FD) is a financial instrument provided by commercial banks and NBFCs where investors deposit a lump-sum amount for a fixed tenure at an agreed-upon fixed rate of interest.',
        whyItMatters:
            'Fixed Deposits offer certainty and capital preservation. The interest rate agreed upon at the time of booking remains locked in regardless of subsequent financial market interest rate drops.',
        howItWorks:
            'Choose your deposit amount and tenure (ranging from 7 days to 10 years). Interest can be compounded quarterly and paid upon maturity (Cumulative FD) or paid out monthly/quarterly to provide regular income (Non-Cumulative FD).',
        formulaOrFramework:
            'Quarterly Compounded FD Formula:\n'
            'A = P × (1 + R / 400)^(4 × T)\n\n'
            'Where: P = Principal, R = Annual Interest Rate (%), T = Tenure in years',
        example:
            '• Deposit: ₹2,00,000 at 7.0% p.a. for 5 Years (compounded quarterly):\n'
            '• Maturity Value: ~₹2,82,956\n'
            '• Guaranteed Interest: ~₹82,956',
        practicalUses: [
          'Parking emergency funds in instantly breakable sweep-in or online bank FDs.',
          'Generating predictable quarterly cash flow for senior citizens and retirees.',
          'Preserving capital designated for short-term goals occurring within 1 to 2 years.',
        ],
        importantPoints: [
          'Under DICGC regulations, bank deposits are insured up to ₹5,00,000 (principal + interest) per depositor across all branches of each bank.',
          'FD interest is fully taxable at your marginal income tax slab rate and subject to TDS.',
          'Senior citizens typically enjoy an additional 0.50% interest rate premium across most tenures.',
        ],
        limitations: [
          'Premature withdrawal typically incurs a 0.5% - 1.0% interest rate penalty.',
          'Post-tax FD returns for individuals in 30% tax brackets often lag real inflation.',
        ],
        disclaimer:
            'Bank fixed deposit terms, interest rates, and premature withdrawal penalties vary by institution and are subject to bank board revisions.',
        relatedCalculatorRoute: '/calculator/fd',
        relatedCalculatorLabel: 'Open FD Calculator',
      ),

      // 19. RD Basics
      const FinancialLiteracyTopic(
        id: 'rd-basics',
        title: 'Recurring Deposit (RD) Basics',
        shortDescription: 'Disciplined monthly bank savings with guaranteed interest returns',
        category: FinancialLiteracyCategories.banking,
        isImportant: false,
        icon: Icons.repeat_rounded,
        keywords: ['recurring deposit', 'rd', 'monthly savings', 'guaranteed returns', 'disciplined saving'],
        whatIsIt:
            'A Recurring Deposit (RD) is a specialized banking savings mechanism that allows account holders to deposit a fixed amount every month for a pre-determined tenure while earning guaranteed interest rates comparable to fixed deposits.',
        whyItMatters:
            'It provides a safe, disciplined savings habit for individuals who earn monthly salaries and do not have a large lump sum available to lock into an FD.',
        howItWorks:
            'You commit to depositing a fixed amount (e.g., ₹2,000, ₹5,000, or ₹10,000) on a designated date every month for a chosen tenure (e.g., 6 months to 10 years). The bank applies compound interest on each monthly tranche, paying out the entire accumulated sum at maturity.',
        formulaOrFramework:
            'Standard Bank RD Formula (Quarterly Compounding):\n'
            'Each monthly installment compounds for its respective remaining tenure:\n'
            'Maturity Value = Σ [P × (1 + R / 400)^(4 × t_i)]\n\n'
            'Where: P = Monthly deposit, R = Annual interest rate, t_i = Tenure fraction for installment i',
        example:
            '• Monthly Deposit: ₹5,000 for 24 Months (2 Years) at 6.8% p.a.:\n'
            '• Total Invested: ₹1,20,000\n'
            '• Maturity Amount: ~₹1,28,850\n'
            '• Total Guaranteed Interest: ~₹8,850',
        practicalUses: [
          'Accumulating funds for anticipated annual expenditures (insurance premiums, school fees, festive shopping).',
          'Building short-term savings habits for young earners without market risk.',
        ],
        importantPoints: [
          'Missing monthly installments can lead to minor penalties or account closure depending on bank guidelines.',
          'Like FDs, RD interest is fully taxable at your personal income tax slab rate.',
        ],
        limitations: [
          'Less flexible than liquid savings accounts; interest rates are fixed and do not participate in market growth.',
        ],
        disclaimer:
            'RD rules and premature closure penalties are governed by the respective depository bank or Post Office regulations.',
        relatedCalculatorRoute: '/calculator/rd',
        relatedCalculatorLabel: 'Open RD Calculator',
      ),

      // 20. PPF Basics
      const FinancialLiteracyTopic(
        id: 'ppf-basics',
        title: 'Public Provident Fund (PPF)',
        shortDescription: 'Sovereign-backed 15-year long-term savings with complete EEE tax exemption',
        category: FinancialLiteracyCategories.saving,
        isImportant: false,
        icon: Icons.verified_user_rounded,
        keywords: ['ppf', 'public provident fund', 'eee tax', 'tax exemption', 'sovereign safety', 'long-term savings'],
        whatIsIt:
            'The Public Provident Fund (PPF) is a sovereign-guaranteed long-term savings scheme established by the Central Government of India to provide income security for unorganized and organized workers.',
        whyItMatters:
            'PPF enjoys rare "EEE" (Exempt-Exempt-Exempt) tax status: deposits are tax-deductible under Section 80C, accrued interest is 100% tax-free, and maturity proceeds are completely tax-free.',
        howItWorks:
            'Open a PPF account at any authorized commercial bank or post office. Deposit between ₹500 and ₹1,50,000 per financial year for 15 years. Interest is notified quarterly by the Government and compounded annually.',
        formulaOrFramework:
            'PPF Operational Features:\n'
            '• Tenure: 15 Years (extendable indefinitely in 5-year blocks)\n'
            '• Annual Deposit Range: ₹500 minimum to ₹1,50,000 maximum per fiscal year\n'
            '• Interest Calculation: Calculated on the lowest balance between the 5th and end of each month\n'
            '• Tax Status: EEE (Exempt, Exempt, Exempt)',
        example:
            '• Depositing ₹1,50,000 annually on or before April 5th for 15 years at an indicative 7.1% p.a.:\n'
            '• Total Invested: ₹22,50,000\n'
            '• Estimated Maturity Value: ~₹40.68 Lakhs (all 100% tax-free!)',
        practicalUses: [
          'Building a risk-free, tax-exempt debt pillar for retirement or children\'s higher education.',
          'Maximizing annual deductions under Section 80C while earning competitive sovereign yields.',
          'Protecting capital from creditors: PPF balances cannot be attached by any court decree.',
        ],
        importantPoints: [
          'Deposit by the 5th of each month to maximize interest accrual for that calendar month.',
          'Partial withdrawals are permitted starting from the 7th financial year under prescribed limits.',
        ],
        limitations: [
          'Strict 15-year lock-in makes it unsuitable for short-term liquidity needs.',
        ],
        disclaimer:
            'PPF interest rates are sovereign-notified by the Government of India on a quarterly basis and subject to revision.',
        relatedCalculatorRoute: '/calculator/ppf',
        relatedCalculatorLabel: 'Open PPF Calculator',
      ),

      // 21. NPS Basics
      const FinancialLiteracyTopic(
        id: 'nps-basics',
        title: 'National Pension System (NPS)',
        shortDescription: 'Low-cost voluntary pension architecture for retirement wealth and annuity',
        category: FinancialLiteracyCategories.retirement,
        isImportant: false,
        icon: Icons.account_balance_outlined,
        keywords: ['nps', 'national pension system', 'pension', 'annuity', '80ccd', 'retirement fund', 'pfrda'],
        whatIsIt:
            'The National Pension System (NPS) is a voluntary, market-linked defined-contribution retirement savings scheme regulated by the Pension Fund Regulatory and Development Authority (PFRDA).',
        whyItMatters:
            'NPS offers one of the lowest fund management charges globally and provides unique exclusive tax deductions under Section 80CCD(1B) beyond standard 80C limits.',
        howItWorks:
            'Subscribers contribute regularly to their Tier-1 retirement account until age 60. Funds are managed by professional pension fund managers across equity (E), corporate debt (C), and government bonds (G). At age 60, up to 60% of the corpus can be withdrawn tax-free, with the remaining 40% utilized to purchase a monthly annuity pension.',
        formulaOrFramework:
            'NPS Asset Choices & Allocation:\n'
            '• Auto Choice: Age-based automatic asset rebalancing (Lifecycle funds: Aggressive, Moderate, Conservative)\n'
            '• Active Choice: You decide asset split (up to 75% in Equities until age 50, tapering thereafter)\n\n'
            'Tax Incentives:\n'
            '• Section 80C: Up to ₹1.5 Lakhs\n'
            '• Section 80CCD(1B): Exclusive additional deduction up to ₹50,000',
        example:
            '• Contributing ₹50,000 annually under Section 80CCD(1B):\n'
            '• For an individual in the 30% tax slab, this provides immediate direct tax savings of ₹15,600 every year while accumulating retirement capital.',
        practicalUses: [
          'Creating a disciplined long-term pension reserve with professional low-cost fund management.',
          'Maximizing tax savings when other 80C avenues are exhausted.',
          'Securing guaranteed lifelong monthly pension income through the mandatory annuity portion.',
        ],
        importantPoints: [
          'The 40% mandatory annuity purchase ensures guaranteed lifelong income, but annuity payouts are taxable as income in the year received.',
          'Tier-2 accounts function as open-ended mutual funds with instant liquidity but without Tier-1 tax benefits.',
        ],
        limitations: [
          'Strict withdrawal restrictions apply until age 60 to protect the integrity of the retirement corpus.',
        ],
        disclaimer:
            'NPS investments are market-linked and regulated by the PFRDA. Returns depend on asset allocation and chosen pension fund manager performance.',
        relatedCalculatorRoute: '/calculator/nps',
        relatedCalculatorLabel: 'Open NPS Calculator',
      ),

      // 22. Rule of 72 (Reused from FinancialManagementData)
      _adaptFromManagement('rule-of-72', FinancialLiteracyCategories.financialBasics, [
        'rule of 72',
        'doubling',
        'interest rate',
        'cagr',
        'mental math',
      ]),

      // 23. Rule of 114 (Reused from FinancialManagementData)
      _adaptFromManagement('rule-of-114', FinancialLiteracyCategories.financialBasics, [
        'rule of 114',
        'tripling',
        'compound interest',
        'mental math',
        'approximation',
      ]),

      // 24. 70/20/10 Rule (Reused from FinancialManagementData)
      _adaptFromManagement('70-20-10', FinancialLiteracyCategories.personalFinance, [
        '70/20/10',
        'budgeting',
        'cashflow',
        'savings rule',
        'living expenses',
      ]),
    ];

    return list;
  }

  static FinancialLiteracyTopic _adaptFromManagement(
    String id,
    String category,
    List<String> keywords,
  ) {
    final mgmtTopic = FinancialManagementData.getTopicById(id);
    if (mgmtTopic == null) {
      throw StateError('FinancialManagementTopic with id "$id" not found.');
    }
    return FinancialLiteracyTopic.fromFinancialManagement(
      managementTopic: mgmtTopic,
      category: category,
      keywords: keywords,
      isImportant: mgmtTopic.isKeyTopic,
    );
  }

  static List<FinancialLiteracyTopic> getAllTopics() => List.unmodifiable(_topics);

  static List<FinancialLiteracyTopic> getImportantTopics() =>
      _topics.where((t) => t.isImportant).toList();

  static List<FinancialLiteracyTopic> getTopicsByCategory(String category) {
    if (category == FinancialLiteracyCategories.all) return getAllTopics();
    return _topics
        .where((t) => t.category.toLowerCase() == category.toLowerCase())
        .toList();
  }

  static FinancialLiteracyTopic? getTopicById(String id) {
    final normalized = id.toLowerCase().replaceAll('_', '-').trim();
    try {
      return _topics.firstWhere(
        (t) => t.id.toLowerCase().replaceAll('_', '-').trim() == normalized,
      );
    } catch (_) {
      return null;
    }
  }

  static List<FinancialLiteracyTopic> searchTopics({
    required String query,
    String category = FinancialLiteracyCategories.all,
  }) {
    final cleanQuery = query.trim().toLowerCase();
    return _topics.where((topic) {
      final matchesCategory = category == FinancialLiteracyCategories.all ||
          topic.category.toLowerCase() == category.toLowerCase();
      if (!matchesCategory) return false;
      if (cleanQuery.isEmpty) return true;

      final inTitle = topic.title.toLowerCase().contains(cleanQuery);
      final inDesc = topic.shortDescription.toLowerCase().contains(cleanQuery);
      final inCategory = topic.category.toLowerCase().contains(cleanQuery);
      final inKeywords =
          topic.keywords.any((k) => k.toLowerCase().contains(cleanQuery));

      return inTitle || inDesc || inCategory || inKeywords;
    }).toList();
  }
}
