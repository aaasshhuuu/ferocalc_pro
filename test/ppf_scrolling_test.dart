import 'package:fincalc_pro/core/utils/financial_math.dart';
import 'package:fincalc_pro/features/calculators/presentation/screens/ppf_calculator_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

Widget _buildTestApp({required Widget child}) {
  return MaterialApp(
    home: child,
  );
}

void main() {
  final currencyFormat = NumberFormat.currency(locale: 'en_IN', symbol: '\u20B9', decimalDigits: 0);

  testWidgets('PPF Time Period scrolling/slider verification test', (tester) async {
    await tester.pumpWidget(_buildTestApp(child: const PpfCalculatorScreen()));
    await tester.pumpAndSettle();

    final sliders = find.byType(Slider);
    expect(sliders, findsNWidgets(2));

    // The second slider is the Time Period slider
    final timeSlider = sliders.at(1);
    final textFields = find.byType(TextField);
    final periodTextField = textFields.at(1);

    // 1. Default period value
    final initialSlider = tester.widget<Slider>(timeSlider);
    expect(initialSlider.value, 15.0);
    expect(initialSlider.min, 15.0);
    expect(initialSlider.max, 50.0);
    expect(initialSlider.divisions, 35);

    final initialTf = tester.widget<TextField>(periodTextField);
    expect(initialTf.controller?.text, '15');

    // Default calculations at 15 years
    final default15Results = FinancialMath.calculatePPF(
      yearlyDeposit: 150000,
      annualRate: 7.1,
      years: 15,
    );
    expect(
      find.text(currencyFormat.format(default15Results['maturityValue'])),
      findsOneWidget,
    );
    expect(
      find.text(currencyFormat.format(default15Results['totalDeposit'])),
      findsOneWidget,
    );

    // 2. Scrolling / dragging changes the value cleanly to an integer
    await tester.drag(timeSlider, const Offset(100, 0));
    await tester.pumpAndSettle();

    final draggedSlider = tester.widget<Slider>(timeSlider);
    expect(draggedSlider.value, greaterThan(15.0));
    expect(draggedSlider.value, lessThanOrEqualTo(50.0));
    // Verify it is snapped to a whole integer year
    expect(draggedSlider.value, equals(draggedSlider.value.roundToDouble()));

    final draggedTf = tester.widget<TextField>(periodTextField);
    expect(draggedTf.controller?.text, draggedSlider.value.toInt().toString());

    // 3. Minimum boundary respected
    await tester.drag(timeSlider, const Offset(-1000, 0));
    await tester.pumpAndSettle();

    final minSlider = tester.widget<Slider>(timeSlider);
    expect(minSlider.value, 15.0);
    final minTf = tester.widget<TextField>(periodTextField);
    expect(minTf.controller?.text, '15');

    // 4. Maximum boundary respected
    await tester.drag(timeSlider, const Offset(1000, 0));
    await tester.pumpAndSettle();

    final maxSlider = tester.widget<Slider>(timeSlider);
    expect(maxSlider.value, 50.0);
    final maxTf = tester.widget<TextField>(periodTextField);
    expect(maxTf.controller?.text, '50');

    // 5. Calculation updates when period changes
    final max50Results = FinancialMath.calculatePPF(
      yearlyDeposit: 150000,
      annualRate: 7.1,
      years: 50,
    );
    expect(
      find.text(currencyFormat.format(max50Results['maturityValue'])),
      findsOneWidget,
    );
    expect(
      find.text(currencyFormat.format(max50Results['totalDeposit'])),
      findsOneWidget,
    );
    expect(
      find.text(currencyFormat.format(max50Results['totalInterest'])),
      findsOneWidget,
    );
  });
}
