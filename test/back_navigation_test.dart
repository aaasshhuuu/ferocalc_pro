import 'package:fincalc_pro/config/routes/app_router.dart';
import 'package:fincalc_pro/features/auth/presentation/bloc/auth_bloc.dart';
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
    child: MaterialApp.router(routerConfig: appRouter),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await di.init();
  });

  group('Android Back Navigation Tests', () {
    testWidgets(
        'Issue #2B: Home -> Compare -> Bank Details -> Back -> Compare -> Back -> Home -> Back exits',
        (tester) async {
      appRouter.go('/home');
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Popular Calculators'), findsOneWidget);

      // Step 1: Navigate to Compare tab
      appRouter.go('/compare');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Compare FD Rates'), findsOneWidget);

      // Step 2: Push Bank Details
      appRouter.push('/bank/State%20Bank%20of%20India');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('State Bank of India'), findsWidgets);

      // First Android Back: Bank Details -> Compare
      final handledFirst = await tester.binding.handlePopRoute();
      expect(handledFirst, isTrue);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Compare FD Rates'), findsOneWidget);

      // Second Android Back: Compare root -> Home
      final handledSecond = await tester.binding.handlePopRoute();
      expect(handledSecond, isTrue);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Popular Calculators'), findsOneWidget);

      // Third Android Back: Home root -> normal Android root behavior (unhandled)
      final handledThird = await tester.binding.handlePopRoute();
      expect(handledThird, isFalse);

      // Clean up widget tree
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets(
        'From Compare root -> Android Back returns to Home',
        (tester) async {
      appRouter.go('/compare');
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Compare FD Rates'), findsOneWidget);

      // Android Back from Compare root returns to Home
      final handled = await tester.binding.handlePopRoute();
      expect(handled, isTrue);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Popular Calculators'), findsOneWidget);

      // Clean up widget tree
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets(
        'Home root screen -> Android Back reports unhandled for normal Android exit',
        (tester) async {
      appRouter.go('/home');
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // At root /home
      expect(appRouter.canPop(), isFalse);

      // Simulating system back returns false (not handled) so Android finishes activity
      final handled = await tester.binding.handlePopRoute();
      expect(handled, isFalse);

      // Clean up widget tree
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets(
        'Existing calculator Back: Home -> push calculator -> Android Back returns to Home',
        (tester) async {
      appRouter.go('/home');
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(appRouter.canPop(), isFalse);

      // Push calculator
      appRouter.push('/calculator/emi');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(appRouter.canPop(), isTrue);
      expect(find.text('EMI Calculator'), findsOneWidget);

      // Simulate Android system back button
      final handled = await tester.binding.handlePopRoute();
      expect(handled, isTrue);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Returns to Home, nothing left to pop
      expect(find.text('EMI Calculator'), findsNothing);
      expect(appRouter.canPop(), isFalse);

      // Clean up widget tree
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets(
        'Multi-level stack: Home -> calculator -> bank details -> back navigates through stack',
        (tester) async {
      appRouter.go('/home');
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Step 1: Push FD calculator
      appRouter.push('/calculator/fd');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(appRouter.canPop(), isTrue);
      expect(find.text('FD Calculator'), findsOneWidget);

      // Step 2: Push Bank details screen
      appRouter.push('/bank/State%20Bank%20of%20India');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(appRouter.canPop(), isTrue);
      expect(find.text('State Bank of India'), findsWidgets);

      // First Android Back: returns to FD calculator
      final handledFirst = await tester.binding.handlePopRoute();
      expect(handledFirst, isTrue);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('FD Calculator'), findsOneWidget);
      expect(appRouter.canPop(), isTrue);

      // Second Android Back: returns to Home
      final handledSecond = await tester.binding.handlePopRoute();
      expect(handledSecond, isTrue);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('FD Calculator'), findsNothing);
      expect(appRouter.canPop(), isFalse);

      // Clean up widget tree
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets(
        'Calculators root -> Android Back returns to Home -> Android Back exits',
        (tester) async {
      appRouter.go('/calculators');
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // "Calculators" appears in both AppBar title and BottomNav label
      expect(find.text('Calculators'), findsWidgets);

      // First Android Back from Calculators root returns to Home
      final handledFirst = await tester.binding.handlePopRoute();
      expect(handledFirst, isTrue);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Popular Calculators'), findsOneWidget);

      // Second Android Back from Home root reports unhandled for normal Android OS exit
      final handledSecond = await tester.binding.handlePopRoute();
      expect(handledSecond, isFalse);

      // Clean up widget tree
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets(
        'Bottom navigation -> switch tab -> push screen -> Android Back returns to tab -> Android Back returns to Home',
        (tester) async {
      appRouter.go('/calculators');
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // "Calculators" appears in both AppBar title and BottomNav label
      expect(find.text('Calculators'), findsWidgets);

      // Push calculator from hub
      appRouter.push('/calculator/sip');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(appRouter.canPop(), isTrue);
      expect(find.text('SIP Calculator'), findsOneWidget);

      // First Android Back pops calculator and returns to Calculators tab
      final handledFirst = await tester.binding.handlePopRoute();
      expect(handledFirst, isTrue);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('SIP Calculator'), findsNothing);
      expect(find.text('Calculators'), findsWidgets);

      // Second Android Back from Calculators tab returns to Home
      final handledSecond = await tester.binding.handlePopRoute();
      expect(handledSecond, isTrue);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Popular Calculators'), findsOneWidget);

      // Clean up widget tree
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets(
        'Existing dialog: Open dialog -> Android Back dismisses dialog first before route',
        (tester) async {
      appRouter.go('/home');
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Push calculator
      appRouter.push('/calculator/emi');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('EMI Calculator'), findsOneWidget);

      // Show dialog
      final scaffoldContext = tester.element(find.byType(Scaffold).last);
      showDialog<void>(
        context: scaffoldContext,
        builder: (_) => const AlertDialog(title: Text('Test Dialog')),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Test Dialog'), findsOneWidget);

      // First Back: dismisses dialog
      final handledDialog = await tester.binding.handlePopRoute();
      expect(handledDialog, isTrue);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Test Dialog'), findsNothing);
      expect(find.text('EMI Calculator'), findsOneWidget);
      expect(appRouter.canPop(), isTrue);

      // Second Back: pops calculator, returns to Home
      final handledScreen = await tester.binding.handlePopRoute();
      expect(handledScreen, isTrue);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('EMI Calculator'), findsNothing);
      expect(appRouter.canPop(), isFalse);

      // Clean up widget tree
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets(
        'Existing bottom navigation behavior still works normally',
        (tester) async {
      appRouter.go('/home');
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Popular Calculators'), findsOneWidget);

      // Switch to Calculators
      appRouter.go('/calculators');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Calculators'), findsWidgets);

      // Switch to Compare
      appRouter.go('/compare');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Compare FD Rates'), findsOneWidget);

      // Switch back to Home
      appRouter.go('/home');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Popular Calculators'), findsOneWidget);

      // Clean up widget tree
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets(
        'Privacy Policy -> Android Back returns to previous route',
        (tester) async {
      appRouter.go('/home');
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Push Privacy Policy
      appRouter.push('/privacy');
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(appRouter.canPop(), isTrue);
      expect(find.text('Privacy Policy'), findsWidgets);

      // Android Back pops Privacy Policy and returns to previous route
      final handled = await tester.binding.handlePopRoute();
      expect(handled, isTrue);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Privacy Policy'), findsNothing);
      expect(appRouter.canPop(), isFalse);

      // Clean up widget tree
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
