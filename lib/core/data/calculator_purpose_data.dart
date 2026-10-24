import '../models/calculator_purpose_info.dart';

const Map<String, CalculatorPurposeInfo> calculatorPurposeRegistry = {
  // --- General Interest (2) ---
  'simple_interest': CalculatorPurposeInfo(
    id: 'simple_interest',
    calculatorName: 'Simple Interest Calculator',
    purpose:
        'Calculates the interest accrued on a principal sum where interest is earned strictly on the original principal without compounding over time.',
    useCases: [
      'Estimating returns on short-term personal or informal loans',
      'Calculating payouts for corporate debt or bonds paying flat periodic coupons',
      'Understanding basic interest accrual across days, months, or years',
    ],
    usefulFor: 'Students, private lenders, debt analysts, and basic loan calculations',
  ),

  'compound_interest': CalculatorPurposeInfo(
    id: 'compound_interest',
    calculatorName: 'Compound Interest Calculator',
    purpose:
        'Determines the accumulated future value of an investment or loan where earned interest is reinvested across specific compounding frequencies.',
    useCases: [
      'Projecting growth of reinvested deposits over medium to long horizons',
      'Comparing how annual, half-yearly, quarterly, or monthly compounding impacts net returns',
      'Evaluating interest costs on compound-accruing credit or debt instruments',
    ],
    usefulFor: 'Long-term savers, fixed-income investors, and personal finance planning',
  ),

  // --- Loans & Borrowing (7) ---
  'emi': CalculatorPurposeInfo(
    id: 'emi',
    calculatorName: 'EMI Calculator',
    purpose:
        'Computes the fixed monthly installment payable towards a loan, splitting each payment into principal repayment and interest components.',
    useCases: [
      'Evaluating monthly cash-flow commitments before taking a home, car, or personal loan',
      'Comparing Reducing Balance vs Flat Rate interest cost differences',
      'Assessing the total interest burden over different repayment tenures',
    ],
    usefulFor: 'Prospective borrowers, mortgage applicants, and budgeting households',
  ),

  'loan_amount': CalculatorPurposeInfo(
    id: 'loan_amount',
    calculatorName: 'Loan Amount Calculator',
    purpose:
        'Calculates the maximum loan principal you can borrow based on your target affordable monthly EMI, prevailing interest rate, and preferred tenure.',
    useCases: [
      'Determining borrowing capacity within your monthly salary budget',
      'Negotiating loan requests with banks based on comfortable EMI limits',
      'Comparing loan entitlement between Reducing Balance and Flat Rate terms',
    ],
    usefulFor: 'Home buyers, vehicle loan planners, and salaried individuals',
  ),

  'loan_term': CalculatorPurposeInfo(
    id: 'loan_term',
    calculatorName: 'Loan Tenure Calculator',
    purpose:
        'Estimates the exact number of months or years needed to fully pay off a loan given a fixed borrowing amount, interest rate, and monthly installment.',
    useCases: [
      'Checking how quickly a loan can be closed by increasing your monthly EMI',
      'Evaluating payoff timelines when refinancing or restructuring an existing loan',
      'Balancing monthly affordability against total interest paid over time',
    ],
    usefulFor: 'Borrowers aiming to become debt-free sooner and loan restructuring',
  ),

  'interest_rate': CalculatorPurposeInfo(
    id: 'interest_rate',
    calculatorName: 'Interest Rate Calculator',
    purpose:
        'Derives the effective annual interest rate being charged on a loan based on the borrowed principal, tenure, and monthly installment amount.',
    useCases: [
      'Uncovering the true annual interest rate hidden in dealer financing or consumer loans',
      'Verifying if an offered bank interest quote matches the required EMI',
      'Comparing financing schemes from different non-banking lenders',
    ],
    usefulFor: 'Consumer durables shoppers, vehicle buyers, and loan comparison',
  ),

  'home_loan_eligibility': CalculatorPurposeInfo(
    id: 'home_loan_eligibility',
    calculatorName: 'Home Loan Eligibility Calculator',
    purpose:
        'Estimates the maximum home loan amount banks are likely to approve based on your monthly income, existing EMIs, FOIR standards, and tenure.',
    useCases: [
      'Checking maximum home loan limits before property hunting or booking a house',
      'Understanding the impact of existing debt obligations on your borrowing capacity',
      'Assessing how adding a co-applicant or extending tenure improves eligibility',
    ],
    usefulFor: 'Home seekers, property investors, and mortgage applicants',
  ),

  'personal_loan_eligibility': CalculatorPurposeInfo(
    id: 'personal_loan_eligibility',
    calculatorName: 'Personal Loan Eligibility Calculator',
    purpose:
        'Estimates eligible unsecured personal loan borrowing limits based on net monthly take-home salary, fixed obligation ratios, and repayment capacity.',
    useCases: [
      'Evaluating personal loan eligibility for medical, travel, or family emergencies',
      'Checking realistic borrowing ceilings without triggering multiple credit enquiries',
      'Determining comfortable monthly repayment commitments within disposable income',
    ],
    usefulFor: 'Salaried employees and individuals planning emergency funding',
  ),

  'credit_card_emi': CalculatorPurposeInfo(
    id: 'credit_card_emi',
    calculatorName: 'Credit Card EMI & Payoff Calculator',
    purpose:
        'Calculates monthly installment amounts, processing fees, and total interest when converting outstanding credit card dues into term EMIs.',
    useCases: [
      'Comparing card EMI conversion options against paying standard minimum dues',
      'Understanding total financing charges and GST on credit card interest',
      'Planning structured card debt payoff to avoid compounding revolving interest',
    ],
    usefulFor: 'Credit cardholders managing large card purchases or balance payoffs',
  ),

  // --- Deposits & Fixed Income (4) ---
  'fd': CalculatorPurposeInfo(
    id: 'fd',
    calculatorName: 'Fixed Deposit (FD) Calculator',
    purpose:
        'Calculates maturity proceeds and interest earned on term deposits, supporting quarterly compounding, simple interest, and senior citizen rate premiums.',
    useCases: [
      'Forecasting guaranteed maturity values for bank fixed deposit investments',
      'Comparing returns between standard investor rates and senior citizen rate slabs',
      'Evaluating reinvestment cumulative growth versus regular payout options',
    ],
    usefulFor: 'Conservative investors, retirees, and short-to-medium term savers',
  ),

  'rd': CalculatorPurposeInfo(
    id: 'rd',
    calculatorName: 'Recurring Deposit (RD) Calculator',
    purpose:
        'Computes the maturity sum and total interest accumulated from disciplined monthly deposits compounded quarterly per standard banking conventions.',
    useCases: [
      'Planning targeted savings through regular monthly installments from income',
      'Forecasting savings corpus for annual insurance premiums, festivals, or vacations',
      'Comparing cumulative RD returns against lump-sum bank deposits',
    ],
    usefulFor: 'Salaried individuals, disciplined monthly savers, and goal budgeting',
  ),

  'savings': CalculatorPurposeInfo(
    id: 'savings',
    calculatorName: 'Savings Account Interest Calculator',
    purpose:
        'Estimates interest earnings on daily balance balances in savings bank accounts based on prevailing annual interest rates and crediting cycles.',
    useCases: [
      'Calculating annual returns on liquid cash balances kept in savings accounts',
      'Assessing the tax benefits under Section 80TTA/80TTB for savings interest',
      'Evaluating the opportunity cost of idle funds versus higher-yield instruments',
    ],
    usefulFor: 'Everyday bank account holders and cash-management planners',
  ),

  'ppf': CalculatorPurposeInfo(
    id: 'ppf',
    calculatorName: 'Public Provident Fund (PPF) Calculator',
    purpose:
        'Projects maturity wealth, annual interest accrual, and government-backed EEE tax-saving returns for a 15-year Public Provident Fund account.',
    useCases: [
      'Planning annual tax-saving investments up to ₹1.5 Lakh under Section 80C',
      'Visualizing long-term compound wealth accumulation with zero sovereign credit risk',
      'Forecasting maturity proceeds after mandatory 15-year lock-in and extensions',
    ],
    usefulFor: 'Long-term risk-averse investors, tax planners, and retirement builders',
  ),

  // --- Investments & Wealth (8) ---
  'sip': CalculatorPurposeInfo(
    id: 'sip',
    calculatorName: 'Systematic Investment Plan (SIP) Calculator',
    purpose:
        'Projects estimated corpus growth and wealth gain from periodic monthly mutual fund investments over time using rupee cost averaging principles.',
    useCases: [
      'Visualizing long-term wealth creation from disciplined monthly mutual fund contributions',
      'Evaluating the compounding difference between short and long investment horizons',
      'Planning monthly contribution targets to achieve specific financial milestones',
    ],
    usefulFor: 'Mutual fund investors, salaried wealth builders, and goal seekers',
  ),

  'swp': CalculatorPurposeInfo(
    id: 'swp',
    calculatorName: 'Systematic Withdrawal Plan (SWP) Calculator',
    purpose:
        'Models regular periodic cash withdrawals from an invested mutual fund corpus while calculating remaining capital balance and sustainability.',
    useCases: [
      'Designing a monthly pension-like income stream during retirement',
      'Checking how long an accumulated investment portfolio can sustain specific monthly withdrawals',
      'Optimizing capital preservation while generating regular secondary cash flow',
    ],
    usefulFor: 'Retirees, freelance earners, and individuals seeking regular portfolio income',
  ),

  'lumpsum': CalculatorPurposeInfo(
    id: 'lumpsum',
    calculatorName: 'Lumpsum Investment Calculator',
    purpose:
        'Calculates the compounded future maturity value and capital gain on a one-time lump-sum mutual fund or equity investment.',
    useCases: [
      'Forecasting returns on bonus payouts, inheritance, or surplus funds invested today',
      'Comparing lump-sum equity returns against fixed deposits over multi-year horizons',
      'Understanding the exponential power of uninterrupted compounding over time',
    ],
    usefulFor: 'Investors with windfall gains, asset allocators, and long-term savers',
  ),

  'cagr': CalculatorPurposeInfo(
    id: 'cagr',
    calculatorName: 'CAGR Calculator',
    purpose:
        'Determines the Compound Annual Growth Rate, measuring the smoothed annual return rate of an investment over a multi-year timeframe.',
    useCases: [
      'Evaluating the true annualized performance of stocks, mutual funds, or real estate',
      'Comparing inconsistent multi-year returns across different investment avenues',
      'Assessing portfolio performance against benchmark market indices',
    ],
    usefulFor: 'Equity investors, portfolio managers, and wealth performance tracking',
  ),

  'stock_return': CalculatorPurposeInfo(
    id: 'stock_return',
    calculatorName: 'Stock Return Calculator',
    purpose:
        'Calculates net profit, absolute percentage return, and brokerage/tax deductions from buying and selling company shares or traded securities.',
    useCases: [
      'Determining net trading profit or loss after accounting for buy and sell prices',
      'Evaluating transaction costs including brokerage, STT, and exchange charges',
      'Calculating realized returns on individual stock investments or swing trades',
    ],
    usefulFor: 'Retail stock traders, equity investors, and portfolio reviewers',
  ),

  'dividend_yield': CalculatorPurposeInfo(
    id: 'dividend_yield',
    calculatorName: 'Dividend Yield Calculator',
    purpose:
        'Calculates the annual dividend yield percentage and expected dividend income relative to the current market price or cost basis of a stock.',
    useCases: [
      'Assessing cash dividend payout returns relative to share price',
      'Comparing dividend-paying value stocks against fixed-income yields',
      'Building a predictable dividend-growth passive income portfolio',
    ],
    usefulFor: 'Income-focused investors, dividend stock pickers, and retirees',
  ),

  'nps': CalculatorPurposeInfo(
    id: 'nps',
    calculatorName: 'National Pension System (NPS) Calculator',
    purpose:
        'Projects retirement wealth, lumpsum withdrawal sum, and monthly annuity pension generated through regular National Pension System contributions.',
    useCases: [
      'Estimating retirement corpus and monthly pension starting at age 60',
      'Planning tax-deductible retirement savings under Section 80CCD(1B)',
      'Balancing lump-sum retirement withdrawal with annuity allocation percentages',
    ],
    usefulFor: 'Corporate employees, government workers, and retirement planners',
  ),

  'epf': CalculatorPurposeInfo(
    id: 'epf',
    calculatorName: 'EPF Calculator',
    purpose:
        'Estimates retirement savings accumulated in the Employees’ Provident Fund from employee and employer monthly contributions with annual interest compounding.',
    useCases: [
      'Forecasting total provident fund accumulation until retirement age',
      'Understanding monthly wage deductions between EPF and EPS allocations',
      'Evaluating the impact of annual salary hikes on final retirement corpus',
    ],
    usefulFor: 'Salaried employees in formal employment and retirement planners',
  ),

  // --- Tax & Regulatory (2) ---
  'gst': CalculatorPurposeInfo(
    id: 'gst',
    calculatorName: 'GST Calculator',
    purpose:
        'Calculates Goods and Services Tax amounts, determining base price or gross total across standard tax slabs (5%, 12%, 18%, 28%) for inclusive or exclusive goods.',
    useCases: [
      'Calculating GST to add onto invoices for taxable goods and services',
      'Extracting net base cost and tax component from inclusive retail price tags',
      'Splitting GST into CGST and SGST for intra-state commercial billing',
    ],
    usefulFor: 'Business owners, freelancers, traders, and retail consumers',
  ),

  'income_tax': CalculatorPurposeInfo(
    id: 'income_tax',
    calculatorName: 'Income Tax Calculator',
    purpose:
        'Computes income tax liability under Indian tax regulations, providing a side-by-side comparison between the Old and New Tax Regimes with applicable deductions.',
    useCases: [
      'Comparing tax payable under the New Regime versus the Old Regime to pick the best option',
      'Calculating the exact tax savings from Section 80C, 80D, and HRA exemptions',
      'Estimating annual TDS deductions from gross annual salary income',
    ],
    usefulFor: 'Salaried professionals, self-employed taxpayers, and tax planning',
  ),

  // --- Planning & Future Goals (5) ---
  'retirement': CalculatorPurposeInfo(
    id: 'retirement',
    calculatorName: 'Retirement Planner',
    purpose:
        'Estimates the total financial corpus required to sustain your desired post-retirement living expenses, factoring in inflation, life expectancy, and return rates.',
    useCases: [
      'Determining how much total retirement corpus you must accumulate before retiring',
      'Calculating the required monthly savings today to bridge retirement shortfall',
      'Analyzing how post-retirement inflation affects long-term purchasing power',
    ],
    usefulFor: 'Long-term financial planners, working professionals, and early retirement (FIRE) seekers',
  ),

  'goal': CalculatorPurposeInfo(
    id: 'goal',
    calculatorName: 'Goal Planner',
    purpose:
        'Determines the periodic monthly investment needed to build a target financial sum for a future milestone like buying a home, car, or funding an event.',
    useCases: [
      'Targeting specific future milestones (e.g. house down payment, vacation, dream vehicle)',
      'Adjusting target amounts for expected inflation over the saving duration',
      'Determining required monthly SIP or savings allocation to achieve the goal on time',
    ],
    usefulFor: 'Milestone savers, families, and goal-oriented investors',
  ),

  'education': CalculatorPurposeInfo(
    id: 'education',
    calculatorName: 'Child Education Planner',
    purpose:
        'Projects the future inflated cost of higher education or university degrees and calculates the monthly savings required to fund it comfortably.',
    useCases: [
      'Forecasting college tuition fees adjusted for higher education inflation rates',
      'Creating a dedicated education fund before children reach college age',
      'Balancing monthly investments across child growth stages to avoid high education loans',
    ],
    usefulFor: 'Parents, guardians, and families planning children’s higher education',
  ),

  'inflation': CalculatorPurposeInfo(
    id: 'inflation',
    calculatorName: 'Inflation Calculator',
    purpose:
        'Measures the erosion of purchasing power over time and projects how much money will be needed in the future to match today’s living costs.',
    useCases: [
      'Understanding what today’s household expenses will cost 10, 20, or 30 years from now',
      'Assessing the real inflation-adjusted purchasing power of long-term savings',
      'Stress-testing financial goals against moderate and high inflation scenarios',
    ],
    usefulFor: 'Financial planners, long-term investors, and family budgeting',
  ),

  'sukanya': CalculatorPurposeInfo(
    id: 'sukanya',
    calculatorName: 'Sukanya Samriddhi Yojana (SSY) Calculator',
    purpose:
        'Calculates maturity wealth and interest accrued in a government-backed Sukanya Samriddhi account for the financial security and education of a girl child.',
    useCases: [
      'Planning annual deposits up to ₹1.5 Lakh for a daughter’s higher education or marriage',
      'Estimating the final maturity value after completing the 21-year tenure',
      'Maximizing tax-free EEE benefits under Section 80C dedicated to girl child welfare',
    ],
    usefulFor: 'Parents and guardians of girl children under 10 years of age',
  ),
};

CalculatorPurposeInfo? getCalculatorPurpose(String id) {
  return calculatorPurposeRegistry[id];
}
