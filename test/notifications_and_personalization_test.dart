import 'package:fincalc_pro/features/favorites/data/repositories/favorite_banks_repository_impl.dart';
import 'package:fincalc_pro/features/favorites/domain/models/favorite_bank.dart';
import 'package:fincalc_pro/features/favorites/domain/repositories/favorite_banks_repository.dart';
import 'package:fincalc_pro/features/favorites/presentation/bloc/favorite_banks_bloc.dart';
import 'package:fincalc_pro/features/favorites/presentation/bloc/favorite_banks_event.dart';
import 'package:fincalc_pro/features/favorites/presentation/bloc/favorite_banks_state.dart';
import 'package:fincalc_pro/features/favorites/presentation/screens/favorite_banks_screen.dart';
import 'package:fincalc_pro/features/notifications/data/repositories/notification_inbox_repository_impl.dart';
import 'package:fincalc_pro/features/notifications/data/repositories/notification_preferences_repository_impl.dart';
import 'package:fincalc_pro/features/notifications/domain/models/app_notification.dart';
import 'package:fincalc_pro/features/notifications/domain/models/notification_preferences.dart';
import 'package:fincalc_pro/features/notifications/domain/repositories/notification_inbox_repository.dart';
import 'package:fincalc_pro/features/notifications/domain/repositories/notification_preferences_repository.dart';
import 'package:fincalc_pro/features/notifications/presentation/screens/notification_settings_screen.dart';
import 'package:fincalc_pro/features/notifications/presentation/screens/notifications_screen.dart';
import 'package:fincalc_pro/features/profile/presentation/screens/profile_screen.dart';
import 'package:fincalc_pro/features/theme/bloc/theme_bloc.dart';
import 'package:fincalc_pro/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late FavoriteBanksRepository favoriteRepo;
  late NotificationPreferencesRepository prefRepo;
  late NotificationInboxRepository inboxRepo;
  late NotificationService notificationService;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();

    final sl = GetIt.instance;
    await sl.reset();

    sl.registerLazySingleton<SharedPreferences>(() => prefs);

    favoriteRepo = FavoriteBanksRepositoryImpl(preferences: prefs);
    sl.registerLazySingleton<FavoriteBanksRepository>(() => favoriteRepo);
    sl.registerFactory(() => FavoriteBanksBloc(repository: sl()));

    prefRepo = NotificationPreferencesRepositoryImpl(preferences: prefs);
    sl.registerLazySingleton<NotificationPreferencesRepository>(() => prefRepo);

    inboxRepo = NotificationInboxRepositoryImpl(preferences: prefs);
    sl.registerLazySingleton<NotificationInboxRepository>(() => inboxRepo);

    notificationService = NotificationService(
      preferences: prefs,
      preferencesRepository: prefRepo,
      inboxRepository: inboxRepo,
    );
    await notificationService.initialize();
    sl.registerLazySingleton<NotificationService>(() => notificationService);

    sl.registerFactory(() => ThemeBloc(preferences: sl()));
  });

  tearDown(() async {
    NotificationService.resetForTesting();
    await GetIt.instance.reset();
  });

  group('Group 1: Favorite Banks Persistence & Integrity', () {
    test('FavoriteBank JSON roundtrip preserves all attributes', () {
      final now = DateTime(2026, 11, 12, 10, 30);
      final bank = FavoriteBank(
        bankId: 'sbi-retail-domestic',
        bankName: 'State Bank of India',
        bankShortName: 'SBI',
        addedAt: now,
        notes: 'Primary salary account bank',
      );

      final json = bank.toJson();
      final restored = FavoriteBank.fromJson(json);

      expect(restored.bankId, 'sbi-retail-domestic');
      expect(restored.bankName, 'State Bank of India');
      expect(restored.bankShortName, 'SBI');
      expect(restored.addedAt, now);
      expect(restored.notes, 'Primary salary account bank');
      expect(restored, bank);
    });

    test('FavoriteBanksRepository adds bank and prevents duplicate favorites', () async {
      final bank1 = FavoriteBank(
        bankId: 'hdfc',
        bankName: 'HDFC Bank',
        bankShortName: 'HDFC',
        addedAt: DateTime.now(),
      );

      final addedFirst = await favoriteRepo.addFavorite(bank1);
      expect(addedFirst, isTrue);

      final isFav = await favoriteRepo.isFavorite('hdfc');
      expect(isFav, isTrue);

      // Attempting to add duplicate bankId returns false
      final addedSecond = await favoriteRepo.addFavorite(bank1);
      expect(addedSecond, isFalse);

      final favorites = await favoriteRepo.getFavorites();
      expect(favorites.length, 1);
    });

    test('FavoriteBanksRepository survives restart and loads persisted entries', () async {
      await favoriteRepo.addFavorite(FavoriteBank(
        bankId: 'icici',
        bankName: 'ICICI Bank',
        bankShortName: 'ICICI',
        addedAt: DateTime.now(),
      ));

      // Create new repo instance reading same SharedPreferences
      final newRepo = FavoriteBanksRepositoryImpl(preferences: prefs);
      final loaded = await newRepo.getFavorites();

      expect(loaded.length, 1);
      expect(loaded.first.bankId, 'icici');
      expect(loaded.first.bankShortName, 'ICICI');
    });

    test('Deleted or corrupt bank catalog entries are handled gracefully', () async {
      // Seed corrupt JSON in storage
      await prefs.setString(
        'ferocalc_favorite_banks_v1',
        '[{"invalid": true}, "corrupted_string", {"bankId": "", "bankName": "Unknown"}]',
      );

      final list = await favoriteRepo.getFavorites();
      expect(list, isEmpty); // Gracefully excludes invalid entries without throwing
    });

    test('FavoriteBanksRepository removeFavorite and toggleFavorite operate deterministically', () async {
      final bank = FavoriteBank(
        bankId: 'bob',
        bankName: 'Bank of Baroda',
        bankShortName: 'BOB',
        addedAt: DateTime.now(),
      );

      // Toggle ON
      final toggledOn = await favoriteRepo.toggleFavorite(bank);
      expect(toggledOn, isTrue);
      expect(await favoriteRepo.isFavorite('bob'), isTrue);

      // Toggle OFF
      final toggledOff = await favoriteRepo.toggleFavorite(bank);
      expect(toggledOff, isFalse);
      expect(await favoriteRepo.isFavorite('bob'), isFalse);

      // Add back and remove
      await favoriteRepo.addFavorite(bank);
      final removed = await favoriteRepo.removeFavorite('bob');
      expect(removed, isTrue);
      expect(await favoriteRepo.isFavorite('bob'), isFalse);
    });

    test('FavoriteBanksBloc emits loaded states on load and toggle', () async {
      final bloc = FavoriteBanksBloc(repository: favoriteRepo);

      expectLater(
        bloc.stream,
        emitsInOrder([
          isA<FavoriteBanksLoading>(),
          isA<FavoriteBanksLoaded>().having((s) => s.favorites.length, 'len', 0),
          isA<FavoriteBanksLoaded>().having((s) => s.favorites.length, 'len', 1),
        ]),
      );

      bloc.add(const LoadFavoriteBanks());
      await Future<void>.delayed(const Duration(milliseconds: 20));

      bloc.add(ToggleFavoriteBank(FavoriteBank(
        bankId: 'kotak',
        bankName: 'Kotak Mahindra Bank',
        bankShortName: 'Kotak',
        addedAt: DateTime.now(),
      )));
    });
  });

  group('Group 2: Notification Preferences & Permission Handling', () {
    test('Default preferences require explicit opt-in (masterEnabled: false)', () {
      const prefsDefault = NotificationPreferences();
      expect(prefsDefault.masterEnabled, isFalse);
      expect(prefsDefault.favoriteBankRateChanges, isTrue);
      expect(prefsDefault.productAnnouncements, isFalse);
      expect(prefsDefault.areNotificationsActive, isFalse);
    });

    test('NotificationPreferencesRepository persists and updates category toggles', () async {
      final custom = const NotificationPreferences().copyWith(
        masterEnabled: true,
        systemPermissionGranted: true,
        favoriteBankRateChanges: true,
        newlyPromotedSlabs: false,
        significantRateChanges: true,
        productAnnouncements: true,
      );

      await prefRepo.savePreferences(custom);

      final loaded = await prefRepo.getPreferences();
      expect(loaded.masterEnabled, isTrue);
      expect(loaded.systemPermissionGranted, isTrue);
      expect(loaded.newlyPromotedSlabs, isFalse);
      expect(loaded.productAnnouncements, isTrue);
      expect(loaded.areNotificationsActive, isTrue);
    });

    test('Permission denial prevents active notifications even if master is enabled', () async {
      final prefsWithDenied = const NotificationPreferences().copyWith(
        masterEnabled: true,
        systemPermissionGranted: false, // Denied by user at OS level
      );

      expect(prefsWithDenied.areNotificationsActive, isFalse);

      await prefRepo.savePreferences(prefsWithDenied);
      final loaded = await prefRepo.getPreferences();
      expect(loaded.areNotificationsActive, isFalse);
    });
  });

  group('Group 3: Verified-Only Event Filtering & In-App Inbox', () {
    test('AppNotification JSON serialization preserves genuine rate change details', () {
      final now = DateTime(2026, 11, 12, 11, 0);
      final notif = AppNotification(
        id: 'notif_1',
        eventId: 'evt_sbi_1y_7.1',
        bankId: 'sbi',
        bankName: 'State Bank of India',
        type: AppNotificationType.verifiedRateChange,
        title: 'State Bank of India Rate Update',
        message: '1 Year FD rate increased to 7.10% p.a.',
        effectiveDate: '2026-11-01',
        verifiedTimestamp: now,
        isRead: false,
        actionRoute: '/bank/State%20Bank%20of%20India',
      );

      final json = notif.toJson();
      final restored = AppNotification.fromJson(json);

      expect(restored.id, 'notif_1');
      expect(restored.eventId, 'evt_sbi_1y_7.1');
      expect(restored.bankId, 'sbi');
      expect(restored.type, AppNotificationType.verifiedRateChange);
      expect(restored.message, '1 Year FD rate increased to 7.10% p.a.');
      expect(restored.effectiveDate, '2026-11-01');
      expect(restored.isRead, isFalse);
    });

    test('NotificationInboxRepository suppresses duplicate event IDs', () async {
      final notif1 = AppNotification(
        id: 'notif_a',
        eventId: 'evt_hdfc_5y',
        bankId: 'hdfc',
        bankName: 'HDFC Bank',
        type: AppNotificationType.newPromotedSlab,
        title: 'New Slab',
        message: '5 Year slab promoted',
        verifiedTimestamp: DateTime.now(),
      );

      final added1 = await inboxRepo.addNotification(notif1);
      expect(added1, isTrue);

      // Attempting to add with same eventId
      final notifDuplicate = notif1.copyWith(id: 'notif_b');
      final added2 = await inboxRepo.addNotification(notifDuplicate);
      expect(added2, isFalse);

      final all = await inboxRepo.getNotifications();
      expect(all.length, 1);
    });

    test('NotificationInboxRepository marks read, marks all read, and deletes', () async {
      final notif1 = AppNotification(
        id: 'n1',
        eventId: 'e1',
        bankId: 'sbi',
        bankName: 'SBI',
        type: AppNotificationType.verifiedRateChange,
        title: 'Rate Change',
        message: 'Rate up',
        verifiedTimestamp: DateTime.now(),
        isRead: false,
      );
      final notif2 = AppNotification(
        id: 'n2',
        eventId: 'e2',
        bankId: 'icici',
        bankName: 'ICICI',
        type: AppNotificationType.newPromotedSlab,
        title: 'New Slab',
        message: 'New slab',
        verifiedTimestamp: DateTime.now(),
        isRead: false,
      );

      await inboxRepo.addNotification(notif1);
      await inboxRepo.addNotification(notif2);

      expect(await inboxRepo.getUnreadCount(), 2);

      // Mark single read
      await inboxRepo.markAsRead('n1');
      expect(await inboxRepo.getUnreadCount(), 1);

      // Mark all read
      await inboxRepo.markAllAsRead();
      expect(await inboxRepo.getUnreadCount(), 0);

      // Delete one
      final deleted = await inboxRepo.deleteNotification('n1');
      expect(deleted, isTrue);

      final remaining = await inboxRepo.getNotifications();
      expect(remaining.length, 1);
      expect(remaining.first.id, 'n2');

      // Clear all
      await inboxRepo.clearAllNotifications();
      expect(await inboxRepo.getNotifications(), isEmpty);
    });

    test('NotificationService filters events by user master switch and categories', () async {
      // 1. When master switch is disabled, event is rejected
      await prefRepo.savePreferences(const NotificationPreferences(
        masterEnabled: false,
        systemPermissionGranted: true,
      ));

      final notif = AppNotification(
        id: 'n_filter_1',
        eventId: 'e_filter_1',
        bankId: 'sbi',
        bankName: 'SBI',
        type: AppNotificationType.verifiedRateChange,
        title: 'SBI Rate',
        message: 'Rate updated',
        verifiedTimestamp: DateTime.now(),
      );

      final handledWhenDisabled = await notificationService.handleVerifiedRateEvent(
        notification: notif,
        isFavoriteBank: true,
      );
      expect(handledWhenDisabled, isFalse);

      // 2. Enable master switch and permissions, but disable announcements
      await prefRepo.savePreferences(const NotificationPreferences(
        masterEnabled: true,
        systemPermissionGranted: true,
        favoriteBankRateChanges: true,
        productAnnouncements: false,
      ));

      // Announcement is rejected
      final announcementNotif = notif.copyWith(
        id: 'n_announcement',
        eventId: 'e_announcement',
        type: AppNotificationType.announcement,
      );
      final handledAnnouncement = await notificationService.handleVerifiedRateEvent(
        notification: announcementNotif,
        isFavoriteBank: false,
      );
      expect(handledAnnouncement, isFalse);

      // Favorite bank rate change is accepted!
      final handledFavorite = await notificationService.handleVerifiedRateEvent(
        notification: notif,
        isFavoriteBank: true,
      );
      expect(handledFavorite, isTrue);

      final inbox = await inboxRepo.getNotifications();
      expect(inbox.length, 1);
      expect(inbox.first.id, 'n_filter_1');
    });

    test('NotificationService manages device tokens, refresh, and installation ID safely', () async {
      final instId = notificationService.installationId;
      expect(instId.startsWith('inst_'), isTrue);

      // Update token
      await notificationService.updateDeviceToken('test_fcm_token_123');
      expect(await notificationService.getToken(), 'test_fcm_token_123');

      // Invalidate / cleanup token
      await notificationService.updateDeviceToken(null);
      expect(await notificationService.getToken(), isNull);

      // Push configured honestly returns false
      expect(notificationService.isPushConfigured, isFalse);
      expect(notificationService.missingPushRequirements.length, greaterThanOrEqualTo(3));
    });
  });

  group('Group 4: UI & Widget Integration Tests', () {
    testWidgets('FavoriteBanksScreen renders tabs and handles search', (tester) async {
      await favoriteRepo.addFavorite(FavoriteBank(
        bankId: 'sbi',
        bankName: 'State Bank of India',
        bankShortName: 'SBI',
        addedAt: DateTime.now(),
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<FavoriteBanksBloc>(
            create: (_) => GetIt.instance<FavoriteBanksBloc>()..add(const LoadFavoriteBanks()),
            child: const FavoriteBanksScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check Tabs exist
      expect(find.byKey(const ValueKey('tab_my_favorites')), findsOneWidget);
      expect(find.byKey(const ValueKey('tab_bank_catalog')), findsOneWidget);

      // Check Search TextField exists
      expect(find.byKey(const ValueKey('bank_search_text_field')), findsOneWidget);

      // Check Favorited bank card exists
      expect(find.text('State Bank of India'), findsOneWidget);
    });

    testWidgets('NotificationSettingsScreen toggles master switch with permission dialog', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const NotificationSettingsScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Master switch is initially off
      final masterSwitchFinder = find.byKey(const ValueKey('notification_master_switch'));
      expect(masterSwitchFinder, findsOneWidget);

      // Tap master switch -> triggers rationale dialog
      await tester.tap(masterSwitchFinder);
      await tester.pumpAndSettle();

      expect(find.text('Stay Informed'), findsOneWidget);
      expect(find.byKey(const ValueKey('notification_permission_allow_button')), findsOneWidget);

      // Tap Allow button in dialog
      await tester.tap(find.byKey(const ValueKey('notification_permission_allow_button')));
      await tester.pumpAndSettle();

      // Check status updated to active
      expect(find.text('Alerts are Active'), findsOneWidget);
    });

    testWidgets('NotificationsScreen renders inbox and filter chips', (tester) async {
      await inboxRepo.addNotification(AppNotification(
        id: 'test_n1',
        eventId: 'test_e1',
        bankId: 'hdfc',
        bankName: 'HDFC Bank',
        type: AppNotificationType.verifiedRateChange,
        title: 'HDFC Bank Rate Update',
        message: 'Fixed deposit rate updated to 7.25% p.a.',
        verifiedTimestamp: DateTime.now(),
        isRead: false,
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: const NotificationsScreen(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Notification Center'), findsOneWidget);
      expect(find.byKey(const ValueKey('filter_all_notifications_chip')), findsOneWidget);
      expect(find.byKey(const ValueKey('filter_unread_notifications_chip')), findsOneWidget);
      expect(find.text('HDFC Bank'), findsOneWidget);
      expect(find.text('Fixed deposit rate updated to 7.25% p.a.'), findsOneWidget);
    });

    testWidgets('ProfileScreen renders Favorite Banks and Notification sections', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await favoriteRepo.addFavorite(FavoriteBank(
        bankId: 'sbi',
        bankName: 'State Bank of India',
        bankShortName: 'SBI',
        addedAt: DateTime.now(),
      ));

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<ThemeBloc>(create: (_) => GetIt.instance<ThemeBloc>()),
              BlocProvider<FavoriteBanksBloc>(
                create: (_) => GetIt.instance<FavoriteBanksBloc>()..add(const LoadFavoriteBanks()),
              ),
            ],
            child: const ProfileScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Favorite Banks section
      expect(find.text('FAVORITE BANKS'), findsOneWidget);
      expect(find.byKey(const ValueKey('profile_favorite_banks_tile')), findsOneWidget);

      // Verify My Calculations section (Preserved)
      expect(find.byKey(const ValueKey('profile_calculation_history_tile')), findsOneWidget);
      expect(find.byKey(const ValueKey('profile_goal_planner_tile')), findsOneWidget);

      // Verify Notifications & Alerts section
      expect(find.text('NOTIFICATIONS & ALERTS'), findsOneWidget);
      expect(find.byKey(const ValueKey('profile_notification_inbox_tile')), findsOneWidget);
      expect(find.byKey(const ValueKey('profile_notification_settings_tile')), findsOneWidget);
    });
  });
}
