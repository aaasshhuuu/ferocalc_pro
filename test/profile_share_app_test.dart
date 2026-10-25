import 'package:fincalc_pro/config/constants/app_constants.dart';
import 'package:fincalc_pro/config/routes/app_router.dart';
import 'package:fincalc_pro/core/utils/calculator_share_helper.dart';
import 'package:fincalc_pro/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fincalc_pro/features/profile/presentation/screens/profile_screen.dart';
import 'package:fincalc_pro/features/theme/bloc/theme_bloc.dart';
import 'package:fincalc_pro/injection_container.dart' as di;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:share_plus/share_plus.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeSharePlatform extends Fake with MockPlatformInterfaceMixin implements SharePlatform {
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
  late FakeSharePlatform fakeSharePlatform;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await di.init();
  });

  setUp(() {
    fakeSharePlatform = FakeSharePlatform();
    CalculatorShareHelper.sharePlusInstance = SharePlus.custom(fakeSharePlatform);
  });

  tearDown(() {
    CalculatorShareHelper.sharePlusInstance = null;
  });

  group('Issue #9: Profile -> "Share App" Tests', () {
    test('1. formatAppShareText contains app name, description, and canonical Play Store URL', () {
      final text = CalculatorShareHelper.formatAppShareText();

      expect(text, contains('FeroCalc'));
      expect(text, contains('Financial'));
      expect(text, contains('Download FeroCalc:'));
      expect(text, contains(AppConstants.playStoreUrl));
      expect(AppConstants.playStoreUrl, 'https://play.google.com/store/apps/details?id=com.ferocalc.app');
    });

    testWidgets('2. Share App action exists in ProfileScreen with share icon', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      appRouter.go('/profile');
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      expect(find.byType(ProfileScreen), findsOneWidget);
      final shareTile = find.byKey(const ValueKey('profile_share_app_tile'));
      await tester.scrollUntilVisible(shareTile, 300);
      expect(shareTile, findsOneWidget);
      expect(find.text('Share App'), findsOneWidget);
      expect(find.byIcon(Icons.share_outlined), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('3. Tapping Share App invokes native share mechanism with promotional content', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      appRouter.go('/profile');
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final shareTile = find.byKey(const ValueKey('profile_share_app_tile'));
      await tester.scrollUntilVisible(shareTile, 300);
      expect(shareTile, findsOneWidget);

      await tester.tap(shareTile);
      await tester.pumpAndSettle();

      expect(fakeSharePlatform.lastParams, isNotNull);
      final params = fakeSharePlatform.lastParams!;
      expect(params.text, contains('FeroCalc'));
      expect(params.text, contains('https://play.google.com/store/apps/details?id=com.ferocalc.app'));
      expect(params.subject, contains('FeroCalc'));

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    testWidgets('4. Error handling: displays error SnackBar when native share fails without crashing', (tester) async {
      fakeSharePlatform.shouldThrow = true;

      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      appRouter.go('/profile');
      await tester.pumpWidget(_buildTestApp());
      await tester.pumpAndSettle();

      final shareTile = find.byKey(const ValueKey('profile_share_app_tile'));
      await tester.scrollUntilVisible(shareTile, 300);
      await tester.tap(shareTile);
      await tester.pumpAndSettle();

      expect(find.textContaining('Failed to share app:'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });

    test('5. Existing calculator sharing format remains intact', () {
      final text = CalculatorShareHelper.formatShareText(
        title: 'FD Calculator',
        inputs: {'Principal': '₹1,00,000', 'Rate': '7.5%'},
        results: {'Maturity': '₹1,07,500'},
      );

      expect(text, contains('FeroCalc FD Calculator'));
      expect(text, contains('Principal: ₹1,00,000'));
      expect(text, contains('Maturity: ₹1,07,500'));
      expect(text, contains('Download FeroCalc for more!'));
    });
  });
}
