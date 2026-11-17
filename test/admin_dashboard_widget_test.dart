import 'package:fincalc_pro/config/routes/app_router.dart';
import 'package:fincalc_pro/features/admin/data/models/admin_user_session.dart';
import 'package:fincalc_pro/features/admin/data/models/candidate_rate_diff.dart';
import 'package:fincalc_pro/features/admin/data/models/staged_candidate.dart';
import 'package:fincalc_pro/features/admin/data/services/admin_auth_service.dart';
import 'package:fincalc_pro/features/admin/presentation/screens/admin_access_denied_screen.dart';
import 'package:fincalc_pro/features/admin/presentation/screens/admin_dashboard_screen.dart';
import 'package:fincalc_pro/features/admin/presentation/screens/admin_login_screen.dart';
import 'package:fincalc_pro/features/admin/presentation/screens/candidate_review_screen.dart';
import 'package:fincalc_pro/features/admin/presentation/widgets/operational_metrics_grid.dart';
import 'package:fincalc_pro/features/admin/presentation/widgets/rate_review_queue_card.dart';
import 'package:fincalc_pro/features/admin/presentation/widgets/review_confirmation_dialog.dart';
import 'package:fincalc_pro/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:fincalc_pro/features/theme/bloc/theme_bloc.dart';
import 'package:fincalc_pro/injection_container.dart' as di;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _buildTestApp({Widget? homeWidget}) {
  return MultiBlocProvider(
    providers: [
      BlocProvider<ThemeBloc>(create: (_) => di.sl<ThemeBloc>()),
      BlocProvider<AuthBloc>(create: (_) => di.sl<AuthBloc>()),
    ],
    child: homeWidget != null
        ? MaterialApp(home: homeWidget)
        : MaterialApp.router(routerConfig: appRouter),
  );
}

StagedCandidate _createSampleCandidate({
  String id = 'cand-1',
  String bankCode = 'HDFC',
  String stagingStatus = 'IN_REVIEW',
  String validationStatus = 'VALID',
  List<String> validationErrors = const [],
  List<String> anomalyFlags = const [],
  double interestRate = 7.10,
}) {
  return StagedCandidate(
    id: id,
    bankCode: bankCode,
    productType: 'Retail Domestic FD',
    customerType: 'REGULAR',
    tenureDomain: 'DAYS',
    displayTenure: '1 Year to < 15 Months',
    minTenureDays: 365,
    maxTenureDays: 454,
    interestRate: interestRate,
    seniorCitizenRate: interestRate + 0.50,
    minDeposit: 1000,
    maxDeposit: 20000000,
    isCallable: true,
    effectiveFrom: '2026-08-19',
    sourceUrl: 'https://www.hdfcbank.com/fd-rates',
    validationStatus: validationStatus,
    validationErrors: validationErrors,
    anomalyFlags: anomalyFlags,
    stagingStatus: stagingStatus,
    diff: const CandidateRateDiff(
      diffType: 'RATE_INCREASE',
      previousVerifiedRate: 6.85,
      rateDelta: 0.25,
      details: 'Rate increased by 25 bps',
    ),
  );
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    await di.init();
  });

  tearDown(() async {
    final authService = di.sl<AdminAuthService>();
    await authService.logout();
  });

  group('Admin Route Guard & Access Security Tests', () {
    testWidgets('Unauthenticated user deep-linking to /admin receives Access Denied screen', (tester) async {
      final authService = di.sl<AdminAuthService>();
      await authService.logout();

      appRouter.go('/admin');
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(AdminAccessDeniedScreen), findsOneWidget);
      expect(find.text('Administrative Authorization Required'), findsOneWidget);
      expect(find.text('Sign In as Administrator'), findsOneWidget);
    });

    testWidgets('Tapping Sign In on Access Denied screen navigates to AdminLoginScreen', (tester) async {
      final authService = di.sl<AdminAuthService>();
      await authService.logout();

      appRouter.go('/admin/access-denied');
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AdminAccessDeniedScreen), findsOneWidget);

      final signInButton = find.text('Sign In as Administrator');
      expect(signInButton, findsOneWidget);
      await tester.tap(signInButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AdminLoginScreen), findsOneWidget);
      expect(find.text('Verified Rate Review Console'), findsOneWidget);
    });

    testWidgets('Authenticated ADMIN user accessing /admin successfully displays AdminDashboardScreen', (tester) async {
      final authService = di.sl<AdminAuthService>();
      authService.setSessionForTesting(
        const AdminUserSession(
          token: 'mock.admin.token',
          userId: 'admin-1',
          email: 'admin@ferocalc.in',
          role: 'ADMIN',
        ),
      );

      appRouter.go('/admin');
      await tester.pumpWidget(_buildTestApp());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(AdminDashboardScreen), findsOneWidget);
      expect(find.text('Rate Review Console'), findsOneWidget);
      expect(find.text('ADMIN'), findsWidgets);
    });
  });

  group('Admin Dashboard & Candidate Queue Widget Tests', () {
    testWidgets('OperationalMetricsGrid renders metric items accurately', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          homeWidget: const Scaffold(
            body: SingleChildScrollView(
              child: OperationalMetricsGrid(
                metrics: null,
                isLoading: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('OPERATIONAL METRICS'), findsOneWidget);
      expect(find.text('Total Staged'), findsOneWidget);
      expect(find.text('In Review'), findsOneWidget);
      expect(find.text('Draft'), findsOneWidget);
      expect(find.text('Promoted'), findsOneWidget);
      expect(find.text('Rejected'), findsOneWidget);
      expect(find.text('Anomalies'), findsOneWidget);
    });

    testWidgets('RateReviewQueueCard renders bank, tenure, rate, diff, and customer category', (tester) async {
      final sample = _createSampleCandidate();
      bool tapped = false;

      await tester.pumpWidget(
        _buildTestApp(
          homeWidget: Scaffold(
            body: RateReviewQueueCard(
              candidate: sample,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('HDFC'), findsOneWidget);
      expect(find.text('7.10%'), findsOneWidget);
      expect(find.text('+0.25%'), findsOneWidget);
      expect(find.text('Sr: 7.60%'), findsOneWidget);
      expect(find.text('1 Year to < 15 Months'), findsOneWidget);
      expect(find.text('REGULAR'), findsOneWidget);
      expect(find.text('IN_REVIEW'), findsOneWidget);

      await tester.tap(find.byType(RateReviewQueueCard));
      expect(tapped, isTrue);
    });

    testWidgets('ReviewConfirmationDialog requires reason for reject and validates input', (tester) async {
      final sample = _createSampleCandidate();
      String? submittedReason;

      await tester.pumpWidget(
        _buildTestApp(
          homeWidget: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  submittedReason = await ReviewConfirmationDialog.show(
                    context: ctx,
                    actionType: ReviewActionType.reject,
                    candidate: sample,
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Open dialog
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Confirm Candidate Rejection'), findsOneWidget);
      expect(find.text('Reject Candidate'), findsWidgets);

      // Tap reject with empty text -> must show validation error
      await tester.tap(find.widgetWithText(ElevatedButton, 'Reject Candidate'));
      await tester.pumpAndSettle();

      expect(find.text('A reason is required before proceeding'), findsOneWidget);
      expect(submittedReason, isNull);

      // Enter reason and submit
      await tester.enterText(find.byType(TextFormField), 'Published interest rate tier is obsolete');
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Reject Candidate'));
      await tester.pumpAndSettle();

      expect(submittedReason, 'Published interest rate tier is obsolete');
    });

    testWidgets('CandidateReviewScreen disables Promote button for REVIEWER and enables for ADMIN', (tester) async {
      final authService = di.sl<AdminAuthService>();

      // 1. As REVIEWER: Promote button is disabled
      authService.setSessionForTesting(
        const AdminUserSession(
          token: 'mock.reviewer.token',
          userId: 'rev-1',
          email: 'reviewer@ferocalc.in',
          role: 'REVIEWER',
        ),
      );

      final candidate = _createSampleCandidate();

      await tester.pumpWidget(
        _buildTestApp(
          homeWidget: CandidateReviewScreen(candidate: candidate),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Candidate promotion strictly requires ADMIN privileges'), findsOneWidget);

      final promoteButton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Approve & Promote'));
      expect(promoteButton.onPressed, isNull); // disabled!

      // 2. Switch to ADMIN: Promote button is enabled!
      authService.setSessionForTesting(
        const AdminUserSession(
          token: 'mock.admin.token',
          userId: 'admin-1',
          email: 'admin@ferocalc.in',
          role: 'ADMIN',
        ),
      );

      await tester.pumpWidget(
        _buildTestApp(
          homeWidget: CandidateReviewScreen(candidate: candidate),
        ),
      );
      await tester.pumpAndSettle();

      final adminPromoteButton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Approve & Promote'));
      expect(adminPromoteButton.onPressed, isNotNull); // enabled!
    });

    testWidgets('CandidateReviewScreen disables Promote button when candidate status is INVALID', (tester) async {
      final authService = di.sl<AdminAuthService>();
      authService.setSessionForTesting(
        const AdminUserSession(
          token: 'mock.admin.token',
          userId: 'admin-1',
          email: 'admin@ferocalc.in',
          role: 'ADMIN',
        ),
      );

      final invalidCandidate = _createSampleCandidate(
        validationStatus: 'INVALID',
        validationErrors: ['Deposit amount exceeds maximum allowable regulatory limit'],
      );

      await tester.pumpWidget(
        _buildTestApp(
          homeWidget: CandidateReviewScreen(candidate: invalidCandidate),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Promote disabled: Candidate validation status is INVALID.'), findsOneWidget);

      final promoteButton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Approve & Promote'));
      expect(promoteButton.onPressed, isNull); // strictly disabled!

      // Scroll to validation errors
      await tester.scrollUntilVisible(find.text('Deposit amount exceeds maximum allowable regulatory limit'), 200);
      expect(find.text('Deposit amount exceeds maximum allowable regulatory limit'), findsOneWidget);
    });
  });
}
