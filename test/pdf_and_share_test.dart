import 'dart:io';

import 'package:fincalc_pro/core/utils/calculator_share_helper.dart';
import 'package:fincalc_pro/core/utils/pdf_generator.dart';
import 'package:fincalc_pro/features/calculators/presentation/screens/emi_calculator_screen.dart';
import 'package:fincalc_pro/features/calculators/presentation/screens/sip_calculator_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PdfGenerator Tests', () {
    test('sanitizeForPdf replaces Rupee symbol with Rs.', () {
      expect(PdfGenerator.sanitizeForPdf('₹50,000'), 'Rs. 50,000');
      expect(PdfGenerator.sanitizeForPdf('Investment: ₹1,00,000'), 'Investment: Rs. 1,00,000');
    });

    test('generatePdfBytes produces valid non-empty PDF bytes', () async {
      final bytes = await PdfGenerator.generatePdfBytes(
        title: 'EMI Calculator',
        inputs: {
          'Loan Amount': '₹5,00,000',
          'Interest Rate': '8.50%',
          'Tenure': '5 Years',
        },
        results: {
          'Monthly EMI': '₹10,258',
          'Total Interest': '₹1,15,498',
          'Total Payment': '₹6,15,498',
        },
      );

      expect(bytes, isNotEmpty);
      // PDF documents start with '%PDF-'
      final header = String.fromCharCodes(bytes.sublist(0, 5));
      expect(header, '%PDF-');
    });

    test('generateReport writes PDF file to target directory', () async {
      final tempDir = Directory.systemTemp.createTempSync('pdf_test_dir');
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      final file = await PdfGenerator.generateReport(
        title: 'SIP Calculator',
        inputs: {
          'Monthly Investment': '₹5,000',
          'Expected Return': '12.00%',
          'Time Period': '10 Years',
        },
        results: {
          'Invested Amount': '₹6,00,000',
          'Estimated Returns': '₹5,61,695',
          'Total Value': '₹11,61,695',
        },
        outputDir: tempDir,
      );

      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(0));
      expect(file.path, contains('FeroCalc_SIP_Calculator'));
      expect(file.path, endsWith('.pdf'));
    });
  });

  group('CalculatorShareHelper Tests', () {
    test('formatShareText formats title, inputs, results, and branding', () {
      final text = CalculatorShareHelper.formatShareText(
        title: 'SIP Calculator',
        inputs: {
          'Monthly Investment': '₹5,000',
          'Expected Return Rate': '12.00% p.a.',
          'Time Period': '10 Years',
        },
        results: {
          'Invested Amount': '₹6,00,000',
          'Estimated Returns': '₹5,61,695',
          'Total Value': '₹11,61,695',
        },
      );

      expect(text, contains('FeroCalc SIP Calculator'));
      expect(text, contains('Monthly Investment: ₹5,000'));
      expect(text, contains('Expected Return Rate: 12.00% p.a.'));
      expect(text, contains('Time Period: 10 Years'));
      expect(text, contains('Invested Amount: ₹6,00,000'));
      expect(text, contains('Estimated Returns: ₹5,61,695'));
      expect(text, contains('Total Value: ₹11,61,695'));
      expect(text, contains('Download FeroCalc for more!'));
    });
  });

  group('All 28 Calculator Screens Code Consistency Audit', () {
    const calculatorFiles = [
      'cagr_calculator_screen.dart',
      'compound_interest_calculator_screen.dart',
      'credit_card_emi_screen.dart',
      'dividend_yield_calculator_screen.dart',
      'education_planner_screen.dart',
      'emi_calculator_screen.dart',
      'epf_calculator_screen.dart',
      'fd_calculator_screen.dart',
      'goal_planner_screen.dart',
      'gst_calculator_screen.dart',
      'home_loan_eligibility_screen.dart',
      'income_tax_calculator_screen.dart',
      'inflation_calculator_screen.dart',
      'interest_rate_calculator_screen.dart',
      'loan_amount_calculator_screen.dart',
      'loan_term_calculator_screen.dart',
      'lumpsum_calculator_screen.dart',
      'nps_calculator_screen.dart',
      'personal_loan_eligibility_screen.dart',
      'ppf_calculator_screen.dart',
      'rd_calculator_screen.dart',
      'retirement_planner_screen.dart',
      'savings_calculator_screen.dart',
      'simple_interest_calculator_screen.dart',
      'sip_calculator_screen.dart',
      'stock_return_calculator_screen.dart',
      'sukanya_samriddhi_screen.dart',
      'swp_calculator_screen.dart',
    ];

    test('All 28 calculator files exist and have PDF + Share actions configured', () {
      final dir = Directory('lib/features/calculators/presentation/screens');
      expect(dir.existsSync(), isTrue);

      expect(calculatorFiles.length, 28);

      for (final fileName in calculatorFiles) {
        final file = File('${dir.path}/$fileName');
        expect(file.existsSync(), isTrue, reason: '$fileName should exist');

        final content = file.readAsStringSync();
        expect(
          content.contains('calculator_share_helper.dart'),
          isTrue,
          reason: '$fileName should import calculator_share_helper.dart',
        );
        expect(
          content.contains('_exportPdf'),
          isTrue,
          reason: '$fileName should define _exportPdf',
        );
        expect(
          content.contains('_shareResult'),
          isTrue,
          reason: '$fileName should define _shareResult',
        );
        expect(
          content.contains('Icons.picture_as_pdf'),
          isTrue,
          reason: '$fileName should contain Icons.picture_as_pdf in appBar',
        );
        expect(
          content.contains('Icons.share'),
          isTrue,
          reason: '$fileName should contain Icons.share in appBar',
        );
      }
    });
  });

  group('Widget Tests: Calculator AppBar Action Icons', () {
    testWidgets('SipCalculatorScreen renders PDF and Share icons in AppBar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SipCalculatorScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.picture_as_pdf), findsOneWidget);
      expect(find.byIcon(Icons.share), findsOneWidget);
    });

    testWidgets('EmiCalculatorScreen renders PDF and Share icons in AppBar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: EmiCalculatorScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.picture_as_pdf), findsOneWidget);
      expect(find.byIcon(Icons.share), findsOneWidget);
    });
  });
}
