import 'package:fincalc_pro/features/compare/presentation/screens/bank_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  final List<MethodCall> log = <MethodCall>[];
  bool canLaunchResult = true;
  bool launchResult = true;

  setUp(() {
    log.clear();
    canLaunchResult = true;
    launchResult = true;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      log.add(methodCall);
      if (methodCall.method == 'canLaunch') {
        return canLaunchResult;
      }
      if (methodCall.method == 'launch') {
        return launchResult;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('BankDetailScreen URL Normalization Unit Tests', () {
    test('preserves existing https scheme', () {
      final uri = BankDetailScreen.normalizeWebsiteUri('https://sbi.co.in');
      expect(uri, isNotNull);
      expect(uri!.scheme, 'https');
      expect(uri.host, 'sbi.co.in');
      expect(uri.toString(), 'https://sbi.co.in');
    });

    test('preserves existing http scheme', () {
      final uri = BankDetailScreen.normalizeWebsiteUri('http://bankofbaroda.in');
      expect(uri, isNotNull);
      expect(uri!.scheme, 'http');
      expect(uri.host, 'bankofbaroda.in');
    });

    test('adds https:// if scheme is missing', () {
      final uri = BankDetailScreen.normalizeWebsiteUri('pnbindia.in');
      expect(uri, isNotNull);
      expect(uri!.scheme, 'https');
      expect(uri.host, 'pnbindia.in');
      expect(uri.toString(), 'https://pnbindia.in');
    });

    test('handles leading/trailing whitespace gracefully', () {
      final uri = BankDetailScreen.normalizeWebsiteUri('   hdfcbank.com   ');
      expect(uri, isNotNull);
      expect(uri!.scheme, 'https');
      expect(uri.host, 'hdfcbank.com');
    });

    test('returns null for null, empty, or whitespace-only inputs without crashing', () {
      expect(BankDetailScreen.normalizeWebsiteUri(null), isNull);
      expect(BankDetailScreen.normalizeWebsiteUri(''), isNull);
      expect(BankDetailScreen.normalizeWebsiteUri('   '), isNull);
    });

    test('returns null for invalid or malformed URLs without crashing', () {
      expect(BankDetailScreen.normalizeWebsiteUri(':::not-a-valid-url:::'), isNull);
    });
  });

  group('BankDetailScreen Official Website Widget & Tap Tests', () {
    testWidgets('renders Official Website with open_in_new icon and launches external browser on tap', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(
          home: BankDetailScreen(bankName: 'State Bank of India'),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to ensure Bank Information section is visible
      await tester.scrollUntilVisible(
        find.text('Official Website'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Verify "Official Website" section is present
      expect(find.text('Official Website'), findsOneWidget);

      // Verify the stored bank website text is displayed
      expect(find.text('https://sbi.co.in'), findsOneWidget);

      // Verify open_in_new external link icon is rendered
      expect(find.byIcon(Icons.open_in_new), findsOneWidget);

      // Tap the website link
      await tester.tap(find.text('https://sbi.co.in'));
      await tester.pumpAndSettle();

      // Verify that url_launcher method channel was invoked with the exact stored URL
      expect(log, isNotEmpty);
      final launchCall = log.firstWhere((call) => call.method == 'launch');
      expect(launchCall.arguments['url'], 'https://sbi.co.in');
      expect(launchCall.arguments['useWebView'], isFalse);
    });

    testWidgets('gracefully shows snackbar when website launch fails without crashing', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      canLaunchResult = false;
      launchResult = false;

      await tester.pumpWidget(
        const MaterialApp(
          home: BankDetailScreen(bankName: 'State Bank of India'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Official Website'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Tap the website link
      await tester.tap(find.text('https://sbi.co.in'));
      await tester.pumpAndSettle();

      // App should not crash and should show error feedback
      expect(find.text('Could not open bank website'), findsOneWidget);
    });

    testWidgets('launchBankWebsite handles empty or invalid URL safely without crashing', (tester) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                capturedContext = context;
                return const SizedBox();
              },
            ),
          ),
        ),
      );

      final resultEmpty = await BankDetailScreen.launchBankWebsite(capturedContext, '');
      expect(resultEmpty, isFalse);
      await tester.pumpAndSettle();
      expect(find.text('Invalid or unavailable bank website URL'), findsOneWidget);

      final resultNull = await BankDetailScreen.launchBankWebsite(capturedContext, null);
      expect(resultNull, isFalse);
    });
  });
}
