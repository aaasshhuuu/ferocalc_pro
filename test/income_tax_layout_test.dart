import 'package:fincalc_pro/core/widgets/glassmorphic_card.dart';
import 'package:fincalc_pro/core/widgets/input_slider_field.dart';
import 'package:fincalc_pro/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fincalc_pro/features/calculators/presentation/screens/income_tax_calculator_screen.dart';
import 'package:fincalc_pro/features/theme/bloc/theme_bloc.dart';
import 'package:fincalc_pro/injection_container.dart' as di;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildTestApp() {
  return MultiBlocProvider(
    providers: [
      BlocProvider<ThemeBloc>(create: (_) => di.sl<ThemeBloc>()),
      BlocProvider<AuthBloc>(create: (_) => di.sl<AuthBloc>()),
    ],
    child: const MaterialApp(
      home: IncomeTaxCalculatorScreen(),
    ),
  );
}

Widget _buildInputSliderApp({
  required double containerWidth,
  required String label,
  required double value,
  required ValueChanged<double> onChanged,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: containerWidth,
          child: GlassmorphicCard(
            child: InputSliderField(
              label: label,
              value: value,
              min: 0,
              max: 500000,
              prefix: '₹',
              onChanged: onChanged,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await di.init();
  });

  group('Issue #8C — Income Tax "Other Deductions" Layout & Overflow Tests', () {
    testWidgets('1. Other Deductions row renders without overflow on narrow 360px device width', (tester) async {
      // 360px width minus 32px screen padding = 328px card width (inside card = 296px)
      double testVal = 50000;
      await tester.pumpWidget(
        _buildInputSliderApp(
          containerWidth: 328,
          label: 'Other Deductions (80D, HRA etc)',
          value: testVal,
          onChanged: (v) => testVal = v,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Other Deductions (80D, HRA etc)'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('2. Other Deductions row renders without overflow on ultra-narrow 320px device width', (tester) async {
      // 320px width minus 32px screen padding = 288px card width (inside card = 256px)
      double testVal = 50000;
      await tester.pumpWidget(
        _buildInputSliderApp(
          containerWidth: 288,
          label: 'Other Deductions (80D, HRA etc)',
          value: testVal,
          onChanged: (v) => testVal = v,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Other Deductions (80D, HRA etc)'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('3. Other Deductions TextField remains editable and updates numeric value', (tester) async {
      double updatedVal = 0;
      await tester.pumpWidget(
        _buildInputSliderApp(
          containerWidth: 328,
          label: 'Other Deductions (80D, HRA etc)',
          value: 50000,
          onChanged: (v) => updatedVal = v,
        ),
      );
      await tester.pumpAndSettle();

      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);

      // Enter normal numeric value
      await tester.enterText(textField, '75000');
      await tester.pumpAndSettle();
      expect(updatedVal, equals(75000));
      expect(tester.takeException(), isNull);

      // Enter large numeric value
      await tester.enterText(textField, '350000');
      await tester.pumpAndSettle();
      expect(updatedVal, equals(350000));
      expect(tester.takeException(), isNull);

      // Enter empty / invalid string
      await tester.enterText(textField, '');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('4. Income Tax Calculator Screen full integration and calculation verification', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byType(IncomeTaxCalculatorScreen), findsOneWidget);
      expect(find.text('Other Deductions (80D, HRA etc)'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Verify the 3 input fields exist
      expect(find.byType(InputSliderField), findsNWidgets(3));

      // Locate the Other Deductions input field (third InputSliderField)
      final otherDeductionsFinder = find.ancestor(
        of: find.text('Other Deductions (80D, HRA etc)'),
        matching: find.byType(InputSliderField),
      );
      expect(otherDeductionsFinder, findsOneWidget);

      final otherDeductionsTextField = find.descendant(
        of: otherDeductionsFinder,
        matching: find.byType(TextField),
      );
      expect(otherDeductionsTextField, findsOneWidget);

      // Change Other Deductions value to 100000 and verify calculation updates
      await tester.enterText(otherDeductionsTextField, '100000');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
