import 'dart:io';

import 'package:fincalc_pro/config/routes/app_router.dart';
import 'package:fincalc_pro/core/utils/calculator_share_helper.dart';
import 'package:fincalc_pro/core/utils/financial_math.dart';
import 'package:fincalc_pro/core/utils/pdf_generator.dart';
import 'package:fincalc_pro/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fincalc_pro/features/calculators/presentation/screens/ssy_schedule_screen.dart';
import 'package:fincalc_pro/features/calculators/presentation/screens/sukanya_samriddhi_screen.dart';
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
  final currencyFormat =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await di.init();
  });

  group('SSY Schedule Engine & Math Tests', () {
    test('1. Schedule generates 21 rows for girlAge = 0 with 15 deposit years', () {
      final deposits = List.filled(15, 150000.0);
      final schedule = FinancialMath.generateSSYSchedule(
        yearlyDeposits: deposits,
        annualRate: 8.2,
        girlAge: 0,
      );

      expect(schedule.length, equals(21));
      expect(schedule.first['year'], equals(1.0));
      expect(schedule.first['age'], equals(1.0));
      expect(schedule.first['openingBalance'], equals(0.0));
      expect(schedule.first['deposit'], equals(150000.0));
      expect(schedule.first['interest'], closeTo(150000.0 * 0.082, 0.01));
      expect(schedule.first['closingBalance'], closeTo(150000.0 * 1.082, 0.01));

      // Years 16 to 21 must have 0 deposit
      for (int i = 15; i < 21; i++) {
        expect(schedule[i]['deposit'], equals(0.0));
        expect(schedule[i]['interest'], greaterThan(0.0));
      }
    });

    test('2. Schedule totals match calculateSSY exactly', () {
      final deposits = List.filled(15, 150000.0);
      const rate = 8.2;
      const girlAge = 0;

      final ssy = FinancialMath.calculateSSY(
        yearlyDeposits: deposits,
        annualRate: rate,
        girlAge: girlAge,
      );

      final schedule = FinancialMath.generateSSYSchedule(
        yearlyDeposits: deposits,
        annualRate: rate,
        girlAge: girlAge,
      );

      final totalDepositsFromSchedule = schedule.fold<double>(
        0,
        (sum, item) => sum + item['deposit']!,
      );
      final totalInterestFromSchedule = schedule.fold<double>(
        0,
        (sum, item) => sum + item['interest']!,
      );

      expect(totalDepositsFromSchedule, equals(ssy['totalDeposit']!));
      expect(totalInterestFromSchedule, closeTo(ssy['totalInterest']!, 0.01));
      expect(schedule.last['closingBalance']!, closeTo(ssy['maturityValue']!, 0.01));
    });

    test('3. Schedule handles older girl age (e.g. Age 5)', () {
      final deposits = List.filled(15, 100000.0);
      final schedule = FinancialMath.generateSSYSchedule(
        yearlyDeposits: deposits,
        annualRate: 8.2,
        girlAge: 5,
      );

      // Maturity years = 21 - 5 = 16
      expect(schedule.length, equals(16));
      expect(schedule.first['age'], equals(6.0));
      expect(schedule.last['age'], equals(21.0));
    });

    test('4. Schedule handles variable deposits', () {
      final variableDeposits = List.generate(15, (index) => (index + 1) * 10000.0);
      final schedule = FinancialMath.generateSSYSchedule(
        yearlyDeposits: variableDeposits,
        annualRate: 8.2,
        girlAge: 0,
      );

      final ssy = FinancialMath.calculateSSY(
        yearlyDeposits: variableDeposits,
        annualRate: 8.2,
        girlAge: 0,
      );

      expect(schedule.length, equals(21));
      expect(schedule[0]['deposit'], equals(10000.0));
      expect(schedule[14]['deposit'], equals(150000.0));
      expect(schedule.last['closingBalance']!, closeTo(ssy['maturityValue']!, 0.01));
    });
  });

  group('SSY Schedule UI & Navigation Tests', () {
    testWidgets('1. "View Year-wise Schedule" button presence on SSY screen',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SukanyaSamriddhiScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final buttonFinder = find.byKey(const ValueKey('view_ssy_schedule_button'));
      expect(buttonFinder, findsOneWidget);
      expect(find.text('View Year-wise Schedule'), findsOneWidget);
    });

    testWidgets('2. Tapping the button successfully opens SSY Year-wise Schedule',
        (tester) async {
      appRouter.go('/calculator/sukanya');
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final buttonFinder = find.byKey(const ValueKey('view_ssy_schedule_button'));
      expect(buttonFinder, findsOneWidget);

      await tester.ensureVisible(buttonFinder);
      await tester.tap(buttonFinder);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(SsyScheduleScreen), findsOneWidget);
      expect(find.text('SSY Year-wise Schedule'), findsOneWidget);
      expect(find.text('Account Summary'), findsOneWidget);
      expect(find.text('Year-wise Schedule'), findsOneWidget);

      // Clean up widget tree
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets('3. Schedule data is displayed correctly on schedule screen',
        (tester) async {
      final deposits = List.filled(15, 150000.0);
      final ssy = FinancialMath.calculateSSY(
        yearlyDeposits: deposits,
        annualRate: 8.2,
        girlAge: 0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SsyScheduleScreen(
            girlAge: 0,
            interestRate: 8.2,
            yearlyDeposits: deposits,
            isVariable: false,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify Account Summary content
      expect(find.text('Account Summary'), findsOneWidget);
      expect(find.text('0 Years'), findsOneWidget);
      expect(find.text('Fixed'), findsOneWidget);
      expect(find.text('8.20% p.a.'), findsOneWidget);
      expect(find.text('15 Years'), findsOneWidget);
      expect(find.text(currencyFormat.format(ssy['totalDeposit'])), findsAtLeastNWidgets(1));
      expect(find.text(currencyFormat.format(ssy['totalInterest'])), findsAtLeastNWidgets(1));
      expect(find.text(currencyFormat.format(ssy['maturityValue'])), findsAtLeastNWidgets(1));

      // Verify schedule rows exist
      expect(find.byKey(const ValueKey('ssy_row_1')), findsOneWidget);
      expect(find.text('21 Years'), findsOneWidget);
    });

    testWidgets('4. Back navigation returns correctly to SSY Calculator',
        (tester) async {
      appRouter.go('/calculator/sukanya');
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Navigate to schedule
      final buttonFinder = find.byKey(const ValueKey('view_ssy_schedule_button'));
      await tester.ensureVisible(buttonFinder);
      await tester.tap(buttonFinder);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(SsyScheduleScreen), findsOneWidget);

      // Trigger Back navigation via system PopRoute
      final backHandled = await tester.binding.handlePopRoute();
      expect(backHandled, isTrue);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Verify returned to SukanyaSamriddhiScreen
      expect(find.byType(SukanyaSamriddhiScreen), findsOneWidget);
      expect(find.byType(SsyScheduleScreen), findsNothing);

      // Clean up widget tree
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    });

    testWidgets(
        '5. Schedule renders without overflow on narrow width (320px mobile viewport)',
        (tester) async {
      tester.view.physicalSize = const Size(320 * 2, 640 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: SsyScheduleScreen(
            girlAge: 0,
            interestRate: 8.2,
            yearlyDeposits: List.filled(15, 150000.0),
            isVariable: false,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      expect(find.text('SSY Year-wise Schedule'), findsOneWidget);
      expect(find.text('Account Summary'), findsOneWidget);
      expect(find.text('Year-wise Schedule'), findsOneWidget);
      expect(find.byKey(const ValueKey('ssy_row_1')), findsOneWidget);
    });
  });

  group('SSY Schedule Share & PDF Export Tests', () {
    late FakeSharePlatform fakeSharePlatform;
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('ssy_share_test');
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

    testWidgets('1. Share and PDF action buttons exist on SSY Schedule Screen',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SsyScheduleScreen(
            girlAge: 0,
            interestRate: 8.2,
            yearlyDeposits: List.filled(15, 150000.0),
            isVariable: false,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(
        find.byKey(const ValueKey('ssy_schedule_share_button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('ssy_schedule_pdf_button')),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.share), findsOneWidget);
      expect(find.byIcon(Icons.picture_as_pdf), findsOneWidget);
    });

    testWidgets(
        '2. Tapping Share action button invokes native share architecture with generated PDF',
        (tester) async {
      final tempDir = Directory.systemTemp.createTempSync('ssy_share_test');
      addTearDown(() {
        try {
          if (tempDir.existsSync()) {
            tempDir.deleteSync(recursive: true);
          }
        } catch (_) {}
      });

      await tester.pumpWidget(
        MaterialApp(
          home: SsyScheduleScreen(
            girlAge: 0,
            interestRate: 8.2,
            yearlyDeposits: List.filled(15, 150000.0),
            isVariable: false,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final shareButton =
          find.byKey(const ValueKey('ssy_schedule_share_button'));
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
      expect(files!.first.name, contains('Sukanya_Samriddhi'));
      expect(files.first.path, endsWith('.pdf'));

      final sharedFile = File(files.first.path);
      expect(sharedFile.existsSync(), isTrue);
      expect(sharedFile.lengthSync(), greaterThan(0));
    });

    testWidgets(
        '3. Tapping PDF action button invokes native share architecture with generated PDF',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SsyScheduleScreen(
            girlAge: 0,
            interestRate: 8.2,
            yearlyDeposits: List.filled(15, 150000.0),
            isVariable: false,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final pdfButton = find.byKey(const ValueKey('ssy_schedule_pdf_button'));
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
        '4. Generated PDF bytes and report file contain valid format and header',
        () async {
      final deposits = List.filled(15, 150000.0);
      final schedule = FinancialMath.generateSSYSchedule(
        yearlyDeposits: deposits,
        annualRate: 8.2,
        girlAge: 0,
      );

      final pdfBytes = await PdfGenerator.generateSchedulePdfBytes(
        title: 'Sukanya Samriddhi (SSY)',
        subtitle: 'Year-wise Deposit & Interest Schedule',
        inputs: {
          'Girl Child Age': '0 Years',
          'Deposit Mode': 'Fixed',
          'Yearly Deposit': '₹1,50,000',
          'Interest Rate': '8.20% p.a.',
          'Deposit Period': '15 Years',
        },
        summary: {
          'Total Deposits': '₹22,50,000',
          'Total Interest': '₹47,39,122',
          'Maturity Value (at Age 21)': '₹69,89,122',
          'Maturity Period': '21 Years',
        },
        tableHeaders: const [
          'Year',
          'Age',
          'Opening Balance',
          'Deposit',
          'Interest Earned',
          'Closing Balance',
        ],
        tableRows: schedule
            .map(
              (row) => [
                'Yr ${(row['year'] ?? 0).toInt()}',
                '${(row['age'] ?? 0).toInt()} Yrs',
                currencyFormat.format(row['openingBalance'] ?? 0),
                currencyFormat.format(row['deposit'] ?? 0),
                currencyFormat.format(row['interest'] ?? 0),
                currencyFormat.format(row['closingBalance'] ?? 0),
              ],
            )
            .toList(),
      );

      expect(pdfBytes, isNotEmpty);
      final header = String.fromCharCodes(pdfBytes.sublist(0, 5));
      expect(header, '%PDF-');

      final tempDir = Directory.systemTemp.createTempSync('ssy_report_test');
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      final reportFile = await PdfGenerator.generateScheduleReport(
        title: 'Sukanya Samriddhi (SSY)',
        subtitle: 'Year-wise Deposit & Interest Schedule',
        inputs: {
          'Girl Child Age': '0 Years',
        },
        summary: {
          'Maturity Value': '₹69,89,122',
        },
        tableHeaders: const ['Year', 'Age', 'Deposit'],
        tableRows: const [
          ['Yr 1', '1 Yrs', '₹1,50,000'],
        ],
        outputDir: tempDir,
      );

      expect(reportFile.existsSync(), isTrue);
      expect(reportFile.lengthSync(), greaterThan(0));
      expect(reportFile.path, contains('FeroCalc_Sukanya_Samriddhi'));
      expect(reportFile.path, endsWith('.pdf'));
    });

    test(
        '5. Formatted schedule share text contains summary and year-wise schedule data',
        () {
      final text = CalculatorShareHelper.formatScheduleShareText(
        title: 'Sukanya Samriddhi (SSY) Year-wise Schedule',
        inputs: {
          'Girl Child Age': '0 Years',
          'Deposit Mode': 'Fixed',
          'Interest Rate': '8.20% p.a.',
        },
        summary: {
          'Total Deposits': '₹22,50,000',
          'Total Interest': '₹47,39,122',
          'Maturity Value (at Age 21)': '₹69,89,122',
        },
        tableHeaders: const [
          'Year',
          'Age',
          'Opening Balance',
          'Deposit',
          'Interest Earned',
          'Closing Balance',
        ],
        tableRows: const [
          ['Yr 1', '1 Yrs', '₹0', '₹1,50,000', '₹12,300', '₹1,62,300'],
          ['Yr 21', '21 Yrs', '₹64,59,447', '₹0', '₹5,29,675', '₹69,89,122'],
        ],
      );

      expect(
        text,
        contains('FeroCalc Sukanya Samriddhi (SSY) Year-wise Schedule'),
      );
      expect(text, contains('Girl Child Age: 0 Years'));
      expect(text, contains('Total Deposits: ₹22,50,000'));
      expect(text, contains('Total Interest: ₹47,39,122'));
      expect(text, contains('Maturity Value (at Age 21): ₹69,89,122'));
      expect(
        text,
        contains('Yr 1 | 1 Yrs | ₹0 | ₹1,50,000 | ₹12,300 | ₹1,62,300'),
      );
      expect(
        text,
        contains(
          'Yr 21 | 21 Yrs | ₹64,59,447 | ₹0 | ₹5,29,675 | ₹69,89,122',
        ),
      );
      expect(
        text,
        contains(
          'Disclaimer: Results are for informational purposes only. Not financial advice.',
        ),
      );
      expect(text, contains('Download FeroCalc for more!'));
    });

    test(
        '6. Long and multi-page schedules are generated correctly without errors',
        () async {
      final longRows = List.generate(
        50,
        (i) => [
          'Yr ${i + 1}',
          '${i + 1} Yrs',
          'Rs. ${i * 10000}',
          'Rs. 1,50,000',
          'Rs. ${i * 500}',
          'Rs. ${i * 10500 + 150000}',
        ],
      );

      final bytes = await PdfGenerator.generateSchedulePdfBytes(
        title: 'Sukanya Samriddhi Long Schedule Test',
        inputs: {'Test': 'True'},
        summary: {'Total Rows': '50'},
        tableHeaders: const [
          'Year',
          'Age',
          'Opening',
          'Deposit',
          'Interest',
          'Closing',
        ],
        tableRows: longRows,
      );

      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
    });
  });
}
