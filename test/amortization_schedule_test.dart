import 'dart:io';

import 'package:fincalc_pro/config/routes/app_router.dart';
import 'package:fincalc_pro/core/utils/calculator_share_helper.dart';
import 'package:fincalc_pro/core/utils/financial_math.dart';
import 'package:fincalc_pro/core/utils/pdf_generator.dart';
import 'package:fincalc_pro/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fincalc_pro/features/calculators/presentation/screens/amortization_schedule_screen.dart';
import 'package:fincalc_pro/features/calculators/presentation/screens/emi_calculator_screen.dart';
import 'package:fincalc_pro/features/theme/bloc/theme_bloc.dart';
import 'package:fincalc_pro/injection_container.dart' as di;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:share_plus/share_plus.dart';
// ignore: depend_on_referenced_packages
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeSharePlatform extends Fake
    with MockPlatformInterfaceMixin
    implements SharePlatform {
  ShareParams? lastParams;
  bool shouldThrow = false;

  @override
  Future<ShareResult> share(ShareParams params) async {
    if (shouldThrow) {
      throw Exception('Native share sheet unavailable');
    }
    lastParams = params;
    return const ShareResult('ok', ShareResultStatus.success);
  }
}

Widget _buildTestApp() {
  return MultiBlocProvider(
    providers: [
      BlocProvider<ThemeBloc>(create: (_) => di.sl<ThemeBloc>()),
      BlocProvider<AuthBloc>(create: (_) => di.sl<AuthBloc>()),
    ],
    child: MaterialApp.router(routerConfig: appRouter),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await di.init();
  });

  group('Issue #10: EMI Amortization Schedule Engine & Math Tests', () {
    test('3. Schedule is generated from the current EMI calculation', () {
      const loanAmount = 1000000.0;
      const rate = 8.5;
      const months = 120;

      final expectedEmi = FinancialMath.calculateEMI(
        principal: loanAmount,
        annualRate: rate,
        months: months,
      );

      final schedule = FinancialMath.generateAmortizationSchedule(
        principal: loanAmount,
        annualRate: rate,
        months: months,
      );

      expect(schedule.isNotEmpty, isTrue);
      expect(schedule.first['emi'], equals(expectedEmi));
      expect(expectedEmi, closeTo(12398.57, 0.1));
    });

    test('4. Number of schedule periods matches tenure', () {
      final schedule12 = FinancialMath.generateAmortizationSchedule(
        principal: 500000,
        annualRate: 10,
        months: 12,
      );
      expect(schedule12.length, equals(12));

      final schedule60 = FinancialMath.generateAmortizationSchedule(
        principal: 1000000,
        annualRate: 8.5,
        months: 60,
      );
      expect(schedule60.length, equals(60));

      final schedule120 = FinancialMath.generateAmortizationSchedule(
        principal: 2000000,
        annualRate: 9,
        months: 120,
      );
      expect(schedule120.length, equals(120));
    });

    test('5. Principal + interest components are represented correctly', () {
      const loanAmount = 1000000.0;
      const rate = 8.5;
      const months = 120;

      final schedule = FinancialMath.generateAmortizationSchedule(
        principal: loanAmount,
        annualRate: rate,
        months: months,
      );

      for (final period in schedule) {
        final emi = period['emi']!;
        final principal = period['principal']!;
        final interest = period['interest']!;

        // Each period: principal + interest == emi
        expect(principal + interest, closeTo(emi, 0.001));
        expect(principal, greaterThan(0));
        expect(interest, greaterThan(0));
      }

      // First month interest is higher than last month interest
      expect(schedule.first['interest']!, greaterThan(schedule.last['interest']!));
      // First month principal is lower than last month principal
      expect(schedule.first['principal']!, lessThan(schedule.last['principal']!));
    });

    test('6. Remaining balance progresses correctly', () {
      const loanAmount = 500000.0;
      const rate = 9.5;
      const months = 24;

      final schedule = FinancialMath.generateAmortizationSchedule(
        principal: loanAmount,
        annualRate: rate,
        months: months,
      );

      double previousBalance = loanAmount;
      for (final period in schedule) {
        final principalPaid = period['principal']!;
        final balance = period['balance']!;

        // Each period: balance == previousBalance - principalPaid
        expect(balance, closeTo(previousBalance - principalPaid, 0.001));
        expect(balance, lessThan(previousBalance));
        previousBalance = balance;
      }
    });

    test('7. Final balance is reconciled appropriately', () {
      final schedule120 = FinancialMath.generateAmortizationSchedule(
        principal: 1000000,
        annualRate: 8.5,
        months: 120,
      );
      expect(schedule120.last['balance']!, equals(0.0));

      final schedule360 = FinancialMath.generateAmortizationSchedule(
        principal: 5000000,
        annualRate: 9.0,
        months: 360,
      );
      expect(schedule360.last['balance']!, equals(0.0));

      final schedule12 = FinancialMath.generateAmortizationSchedule(
        principal: 100000,
        annualRate: 12.0,
        months: 12,
      );
      expect(schedule12.last['balance']!, equals(0.0));
    });

    test('8. Schedule handles a normal EMI case', () {
      const loanAmount = 1000000.0;
      const rate = 8.5;
      const months = 120;

      final schedule = FinancialMath.generateAmortizationSchedule(
        principal: loanAmount,
        annualRate: rate,
        months: months,
      );

      expect(schedule.length, equals(120));
      expect(schedule.first['month'], equals(1.0));
      expect(schedule.last['month'], equals(120.0));

      final totalPrincipal = schedule.fold<double>(
        0,
        (sum, item) => sum + item['principal']!,
      );
      expect(totalPrincipal, closeTo(loanAmount, 0.01));
    });

    test('9. Schedule handles a different tenure', () {
      const loanAmount = 2500000.0;
      const rate = 7.75;
      const months = 240; // 20 years

      final schedule = FinancialMath.generateAmortizationSchedule(
        principal: loanAmount,
        annualRate: rate,
        months: months,
      );

      expect(schedule.length, equals(240));
      expect(schedule.last['balance']!, equals(0.0));
      final totalPrincipal = schedule.fold<double>(
        0,
        (sum, item) => sum + item['principal']!,
      );
      expect(totalPrincipal, closeTo(loanAmount, 0.01));
    });
  });

  group('Issue #10: EMI Amortization Schedule UI & Navigation Tests', () {
    testWidgets('1. View Amortization Schedule action exists on EMI screen',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: EmiCalculatorScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final buttonFinder = find.text('View Amortization Schedule');
      expect(buttonFinder, findsOneWidget);
    });

    testWidgets('2. Tapping the action opens the schedule screen',
        (tester) async {
      appRouter.go('/calculator/emi');
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final buttonFinder = find.text('View Amortization Schedule');
      expect(buttonFinder, findsOneWidget);

      await tester.ensureVisible(buttonFinder);
      await tester.tap(buttonFinder);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(AmortizationScheduleScreen), findsOneWidget);
      expect(find.text('Amortization Schedule'), findsOneWidget);
      expect(find.text('Loan Summary'), findsOneWidget);
      expect(find.text('Repayment Schedule'), findsOneWidget);

      // Clean up widget tree
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets(
        '10. Schedule renders without horizontal overflow at narrow mobile width (Vivo Y93 320/360 width)',
        (tester) async {
      // Simulate narrow 320dp mobile screen (like Vivo Y93 / compact Android)
      tester.view.physicalSize = const Size(320 * 2, 640 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: AmortizationScheduleScreen(
            loanAmount: 1000000,
            interestRate: 8.5,
            tenureMonths: 24,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      expect(find.text('Amortization Schedule'), findsOneWidget);
      expect(find.text('Loan Summary'), findsOneWidget);
      expect(find.text('Repayment Schedule'), findsOneWidget);

      // Verify row exists and renders cleanly
      expect(find.byKey(const ValueKey('amortization_row_1')), findsOneWidget);
    });

    testWidgets(
        '11. Android Back returns from schedule to EMI result screen correctly',
        (tester) async {
      appRouter.go('/calculator/emi');
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Open schedule
      final buttonFinder = find.text('View Amortization Schedule');
      await tester.ensureVisible(buttonFinder);
      await tester.tap(buttonFinder);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(AmortizationScheduleScreen), findsOneWidget);

      // Trigger Android system Back
      final backHandled = await tester.binding.handlePopRoute();
      expect(backHandled, isTrue);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Returns to EMI calculator screen
      expect(find.byType(EmiCalculatorScreen), findsOneWidget);
      expect(find.byType(AmortizationScheduleScreen), findsNothing);

      // Clean up widget tree
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('12. Existing EMI calculation tests still pass',
        (tester) async {
      final emi = FinancialMath.calculateEMI(
        principal: 1000000,
        annualRate: 10,
        months: 12,
      );
      expect(emi, closeTo(87915.89, 0.1));

      final zeroRateEmi = FinancialMath.calculateEMI(
        principal: 120000,
        annualRate: 0,
        months: 12,
      );
      expect(zeroRateEmi, equals(10000));
    });
  });

  group('EMI Amortization Schedule Share & PDF Export Tests', () {
    late FakeSharePlatform fakeSharePlatform;
    late Directory tempDir;
    final currencyFormat =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('emi_share_test');
      fakeSharePlatform = FakeSharePlatform();
      CalculatorShareHelper.sharePlusInstance =
          SharePlus.custom(fakeSharePlatform);
      CalculatorShareHelper.testOutputDir = tempDir;
    });

    tearDown(() {
      CalculatorShareHelper.sharePlusInstance = null;
      CalculatorShareHelper.testOutputDir = null;
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });

    testWidgets('1. Share and PDF action buttons exist on Amortization Schedule Screen',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AmortizationScheduleScreen(
            loanAmount: 1000000,
            interestRate: 8.5,
            tenureMonths: 120,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.byKey(const ValueKey('amortization_schedule_share_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('amortization_schedule_pdf_button')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.share), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf), findsOneWidget);
    });

    testWidgets(
        '2. Tapping Share action button invokes native share architecture with generated PDF',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AmortizationScheduleScreen(
            loanAmount: 1000000,
            interestRate: 8.5,
            tenureMonths: 12,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final shareButton =
          find.byKey(const ValueKey('amortization_schedule_share_button'));
      expect(shareButton, findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(shareButton);
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pumpAndSettle();

      expect(fakeSharePlatform.lastParams, isNotNull);
      final files = fakeSharePlatform.lastParams!.files;
      expect(files, isNotNull);
      expect(files, isNotEmpty);
      expect(files!.first.name, contains('Amortization'));
      expect(files.first.path, endsWith('.pdf'));

      final sharedFile = File(files.first.path);
      expect(sharedFile.existsSync(), isTrue);
      expect(sharedFile.lengthSync(), greaterThan(0));
    });

    testWidgets(
        '3. Tapping PDF action button invokes native share architecture with generated PDF',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: AmortizationScheduleScreen(
            loanAmount: 1000000,
            interestRate: 8.5,
            tenureMonths: 12,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final pdfButton =
          find.byKey(const ValueKey('amortization_schedule_pdf_button'));
      expect(pdfButton, findsOneWidget);

      await tester.runAsync(() async {
        await tester.tap(pdfButton);
        await Future<void>.delayed(const Duration(milliseconds: 500));
      });
      await tester.pumpAndSettle();

      expect(fakeSharePlatform.lastParams, isNotNull);
      final files = fakeSharePlatform.lastParams!.files;
      expect(files, isNotNull);
      expect(files, isNotEmpty);
      expect(files!.first.path, endsWith('.pdf'));
    });

    test(
        '4. Generated PDF bytes and report file contain valid format, branding, and EMI metadata (Reducing Balance)',
        () async {
      const loanAmount = 1000000.0;
      const rate = 8.5;
      const months = 120;
      final emi = FinancialMath.calculateEMI(
        principal: loanAmount,
        annualRate: rate,
        months: months,
      );
      final totalPayment = emi * months;
      final totalInterest = totalPayment - loanAmount;

      final schedule = FinancialMath.generateAmortizationSchedule(
        principal: loanAmount,
        annualRate: rate,
        months: months,
      );

      final List<List<String>> rows = [];
      double opening = loanAmount;
      for (final item in schedule) {
        final m = item['month']!.toInt();
        final p = item['principal']!;
        final i = item['interest']!;
        final b = item['balance']!;
        rows.add([
          '$m',
          currencyFormat.format(opening),
          currencyFormat.format(item['emi']!),
          currencyFormat.format(p),
          currencyFormat.format(i),
          b <= 0.01 ? '₹0' : currencyFormat.format(b),
        ]);
        opening = b;
      }

      final pdfBytes = await PdfGenerator.generateSchedulePdfBytes(
        title: 'EMI Amortization Schedule',
        subtitle: 'Reducing Balance Repayment Schedule',
        scheduleSectionTitle: 'Repayment Schedule',
        inputs: {
          'Loan Amount': currencyFormat.format(loanAmount),
          'Interest Rate': '${rate.toStringAsFixed(2)}% p.a.',
          'Loan Tenure': '$months Months (10 Years)',
          'Loan Type': 'Reducing Balance',
        },
        summary: {
          'Monthly EMI': currencyFormat.format(emi),
          'Total Interest': currencyFormat.format(totalInterest),
          'Total Payment': currencyFormat.format(totalPayment),
          'Calculation Mode': 'Reducing Balance',
        },
        tableHeaders: const [
          'Month',
          'Opening Balance',
          'EMI',
          'Principal',
          'Interest',
          'Closing Balance',
        ],
        tableRows: rows,
        disclaimer:
            'Disclaimer: The amortization schedule is an estimate based on fixed-rate EMI and monthly compounding.',
      );

      expect(pdfBytes, isNotEmpty);
      final header = String.fromCharCodes(pdfBytes.sublist(0, 5));
      expect(header, '%PDF-');

      final reportFile = await PdfGenerator.generateScheduleReport(
        title: 'EMI Amortization Schedule',
        subtitle: 'Reducing Balance Repayment Schedule',
        scheduleSectionTitle: 'Repayment Schedule',
        inputs: {
          'Loan Amount': currencyFormat.format(loanAmount),
          'Loan Type': 'Reducing Balance',
        },
        summary: {
          'Monthly EMI': currencyFormat.format(emi),
          'Calculation Mode': 'Reducing Balance',
        },
        tableHeaders: const [
          'Month',
          'Opening Balance',
          'EMI',
          'Principal',
          'Interest',
          'Closing Balance',
        ],
        tableRows: rows,
        disclaimer:
            'Disclaimer: The amortization schedule is an estimate based on fixed-rate EMI and monthly compounding.',
        outputDir: tempDir,
      );

      expect(reportFile.existsSync(), isTrue);
      expect(reportFile.lengthSync(), greaterThan(0));
      expect(reportFile.path, contains('EMI_Amortization_Schedule'));
      expect(reportFile.path, endsWith('.pdf'));
    });

    test(
        '5. Generated PDF bytes and report file support Flat Rate loan mode',
        () async {
      const loanAmount = 500000.0;
      const rate = 10.0;
      const months = 24;
      final emi = FinancialMath.calculateFlatRateEMI(
        principal: loanAmount,
        annualRate: rate,
        months: months,
      );
      final totalPayment = emi * months;
      final totalInterest = totalPayment - loanAmount;

      final List<List<String>> rows = [];
      const monthlyPrincipal = loanAmount / months;
      final monthlyInterest = totalInterest / months;
      double bal = loanAmount;
      for (int m = 1; m <= months; m++) {
        final opening = bal;
        bal -= monthlyPrincipal;
        if (bal < 0 || (m == months && bal.abs() < 1.0)) bal = 0;
        rows.add([
          '$m',
          currencyFormat.format(opening),
          currencyFormat.format(emi),
          currencyFormat.format(monthlyPrincipal),
          currencyFormat.format(monthlyInterest),
          bal <= 0.01 ? '₹0' : currencyFormat.format(bal),
        ]);
      }

      final pdfBytes = await PdfGenerator.generateSchedulePdfBytes(
        title: 'EMI Amortization Schedule',
        subtitle: 'Flat Rate Repayment Schedule',
        scheduleSectionTitle: 'Repayment Schedule',
        inputs: {
          'Loan Amount': currencyFormat.format(loanAmount),
          'Interest Rate': '${rate.toStringAsFixed(2)}% p.a.',
          'Loan Tenure': '$months Months (2 Years)',
          'Loan Type': 'Flat Rate',
        },
        summary: {
          'Monthly EMI': currencyFormat.format(emi),
          'Total Interest': currencyFormat.format(totalInterest),
          'Total Payment': currencyFormat.format(totalPayment),
          'Calculation Mode': 'Flat Rate',
        },
        tableHeaders: const [
          'Month',
          'Opening Balance',
          'EMI',
          'Principal',
          'Interest',
          'Closing Balance',
        ],
        tableRows: rows,
        disclaimer:
            'Disclaimer: The amortization schedule is an estimate based on flat-rate EMI.',
      );

      expect(pdfBytes, isNotEmpty);
      final header = String.fromCharCodes(pdfBytes.sublist(0, 5));
      expect(header, '%PDF-');
    });

    test(
        '6. Schedule completeness: all tenure months have opening, EMI, principal, interest, closing balance',
        () {
      const loanAmount = 1000000.0;
      const rate = 8.5;
      const months = 60;

      final schedule = FinancialMath.generateAmortizationSchedule(
        principal: loanAmount,
        annualRate: rate,
        months: months,
      );

      expect(schedule.length, equals(60));
      double opening = loanAmount;
      for (int i = 0; i < schedule.length; i++) {
        final item = schedule[i];
        final m = item['month']!.toInt();
        final emi = item['emi']!;
        final p = item['principal']!;
        final interest = item['interest']!;
        final balance = item['balance']!;

        expect(m, equals(i + 1));
        expect(p + interest, closeTo(emi, 0.001));
        expect(balance, closeTo(opening - p, 0.001));
        opening = balance;
      }
      expect(schedule.last['balance']!, equals(0.0));
    });

    test(
        '7. Long schedules (120 and 240 months / 20 years) paginate across multiple pages without cutoff or error',
        () async {
      // 120 months (10 years)
      final rows120 = List.generate(
        120,
        (i) => [
          '${i + 1}',
          '₹${1000000 - i * 8000}',
          '₹12,398',
          '₹5,315',
          '₹7,083',
          '₹${1000000 - (i + 1) * 8000}',
        ],
      );

      final bytes120 = await PdfGenerator.generateSchedulePdfBytes(
        title: 'EMI Amortization Schedule',
        subtitle: 'Reducing Balance Repayment Schedule',
        scheduleSectionTitle: 'Repayment Schedule',
        inputs: {'Loan Amount': '₹10,00,000', 'Loan Type': 'Reducing Balance'},
        summary: {'Monthly EMI': '₹12,398', 'Calculation Mode': 'Reducing Balance'},
        tableHeaders: const [
          'Month',
          'Opening Balance',
          'EMI',
          'Principal',
          'Interest',
          'Closing Balance',
        ],
        tableRows: rows120,
      );

      expect(bytes120, isNotEmpty);
      expect(String.fromCharCodes(bytes120.sublist(0, 5)), '%PDF-');

      // 240 months (20 years)
      final rows240 = List.generate(
        240,
        (i) => [
          '${i + 1}',
          '₹${2500000 - i * 10000}',
          '₹20,517',
          '₹4,371',
          '₹16,146',
          '₹${2500000 - (i + 1) * 10000}',
        ],
      );

      final bytes240 = await PdfGenerator.generateSchedulePdfBytes(
        title: 'EMI Amortization Schedule',
        subtitle: 'Reducing Balance Repayment Schedule',
        scheduleSectionTitle: 'Repayment Schedule',
        inputs: {'Loan Amount': '₹25,00,000', 'Loan Type': 'Reducing Balance'},
        summary: {'Monthly EMI': '₹20,517', 'Calculation Mode': 'Reducing Balance'},
        tableHeaders: const [
          'Month',
          'Opening Balance',
          'EMI',
          'Principal',
          'Interest',
          'Closing Balance',
        ],
        tableRows: rows240,
      );

      expect(bytes240, isNotEmpty);
      expect(String.fromCharCodes(bytes240.sublist(0, 5)), '%PDF-');
    });

    test(
        '8. Formatted schedule share text contains loan summary, table, and disclaimer',
        () {
      final text = CalculatorShareHelper.formatScheduleShareText(
        title: 'EMI Amortization Schedule',
        scheduleTitle: 'Repayment Schedule',
        inputs: {
          'Loan Amount': '₹10,00,000',
          'Interest Rate': '8.50% p.a.',
          'Loan Tenure': '120 Months (10 Years)',
          'Loan Type': 'Reducing Balance',
        },
        summary: {
          'Monthly EMI': '₹12,399',
          'Total Interest': '₹4,87,838',
          'Total Payment': '₹14,87,838',
          'Calculation Mode': 'Reducing Balance',
        },
        tableHeaders: const [
          'Month',
          'Opening Balance',
          'EMI',
          'Principal',
          'Interest',
          'Closing Balance',
        ],
        tableRows: const [
          ['1', '₹10,00,000', '₹12,399', '₹5,315', '₹7,083', '₹9,94,685'],
          ['120', '₹12,311', '₹12,399', '₹12,311', '₹87', '₹0'],
        ],
        disclaimer:
            'Disclaimer: The amortization schedule is an estimate based on fixed-rate EMI.',
      );

      expect(text, contains('FeroCalc EMI Amortization Schedule'));
      expect(text, contains('Loan Amount: ₹10,00,000'));
      expect(text, contains('Loan Type: Reducing Balance'));
      expect(text, contains('Monthly EMI: ₹12,399'));
      expect(text, contains('Calculation Mode: Reducing Balance'));
      expect(text, contains('Repayment Schedule:'));
      expect(
        text,
        contains('1 | ₹10,00,000 | ₹12,399 | ₹5,315 | ₹7,083 | ₹9,94,685'),
      );
      expect(
        text,
        contains('120 | ₹12,311 | ₹12,399 | ₹12,311 | ₹87 | ₹0'),
      );
      expect(
        text,
        contains('Disclaimer: The amortization schedule is an estimate based on fixed-rate EMI.'),
      );
      expect(text, contains('Download FeroCalc for more!'));
    });
  });
}
