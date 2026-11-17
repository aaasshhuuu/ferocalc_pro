import 'package:fincalc_pro/features/profile/presentation/screens/terms_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../config/constants/app_constants.dart';
import '../../../../core/theme/design_system.dart';
import '../../../../core/utils/calculator_share_helper.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../features/theme/bloc/theme_bloc.dart';
import '../../../../features/theme/bloc/theme_event.dart';
import '../../../../features/theme/bloc/theme_state.dart';
import '../../../admin/data/services/admin_auth_service.dart';
import '../../../admin/presentation/widgets/admin_status_badge.dart';
import '../../../favorites/domain/models/favorite_bank.dart';
import '../../../favorites/presentation/bloc/favorite_banks_bloc.dart';
import '../../../favorites/presentation/bloc/favorite_banks_event.dart';
import '../../../favorites/presentation/bloc/favorite_banks_state.dart';
import '../../../notifications/domain/repositories/notification_inbox_repository.dart';
import '../../../notifications/domain/repositories/notification_preferences_repository.dart';

/// Key used to persist customer type in SharedPreferences.
const String _kCustomerTypeKey = 'customer_type';

/// Customer type values.
const String _kRegular = 'regular';
const String _kSeniorCitizen = 'senior_citizen';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _customerType = _kRegular;
  int _unreadNotifications = 0;
  bool _notificationsActive = false;

  FavoriteBanksBloc? _getFavoriteBanksBloc(BuildContext context) {
    try {
      return BlocProvider.of<FavoriteBanksBloc>(context);
    } catch (_) {
      try {
        if (GetIt.instance.isRegistered<FavoriteBanksBloc>()) {
          return GetIt.instance<FavoriteBanksBloc>();
        }
      } catch (_) {}
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadCustomerType();
    _loadNotificationStatus();
    final favBloc = _getFavoriteBanksBloc(context);
    favBloc?.add(const LoadFavoriteBanks());
  }

  Future<void> _loadCustomerType() async {
    final prefs = GetIt.instance<SharedPreferences>();
    final saved = prefs.getString(_kCustomerTypeKey);
    if (saved != null && mounted) {
      setState(() {
        _customerType = saved;
      });
    }
  }

  Future<void> _loadNotificationStatus() async {
    try {
      final inboxRepo = GetIt.instance<NotificationInboxRepository>();
      final prefsRepo = GetIt.instance<NotificationPreferencesRepository>();
      final unread = await inboxRepo.getUnreadCount();
      final prefs = await prefsRepo.getPreferences();
      if (mounted) {
        setState(() {
          _unreadNotifications = unread;
          _notificationsActive = prefs.areNotificationsActive;
        });
      }
    } catch (_) {}
  }

  Future<void> _setCustomerType(String value) async {
    setState(() {
      _customerType = value;
    });
    final prefs = GetIt.instance<SharedPreferences>();
    await prefs.setString(_kCustomerTypeKey, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Profile', showBackButton: false),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: _buildProfile(context),
          ),
        ),
      ),
    );
  }

  Widget _buildProfile(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Center(
          child: CircleAvatar(
            radius: 44,
            backgroundColor: Colors.transparent,
            child:
                Icon(Icons.person_outline, size: 50, color: Color(0xFFC9A96E)),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text('FeroCalc Profile',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,),),
        ),
        const SizedBox(height: 28),

        // --- Customer Type ---
        _buildSectionHeader('Customer Type'),
        _buildCustomerTypeSelector(context),
        const SizedBox(height: 16),

        // --- Favorite Banks ---
        _buildFavoriteBanksSection(context),
        const SizedBox(height: 16),

        // --- My Calculations ---
        _buildSectionHeader('My Planning & Insights'),
        _buildListTile(
          context,
          Icons.auto_graph_outlined,
          'Financial Insights & Dashboard',
          () {
            context.push('/financial-insights');
          },
          key: const ValueKey('profile_financial_insights_tile'),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFC9A96E).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'NEW',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFFC9A96E),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _buildListTile(
          context,
          Icons.history,
          'Calculation History',
          () {
            context.push('/history');
          },
          key: const ValueKey('profile_calculation_history_tile'),
        ),
        const SizedBox(height: 10),
        _buildListTile(
          context,
          Icons.track_changes,
          'Financial Goal Planner',
          () {
            context.push('/calculator/goal');
          },
          key: const ValueKey('profile_goal_planner_tile'),
        ),
        const SizedBox(height: 16),

        // --- Notifications & Alerts ---
        _buildNotificationsSection(context),
        const SizedBox(height: 16),

        // --- App Settings ---
        _buildSectionHeader('App Settings'),
        BlocBuilder<ThemeBloc, ThemeState>(
          builder: (context, themeState) {
            final isDark = themeState is ThemeDark ||
                (themeState is ThemeSystem &&
                    Theme.of(context).brightness == Brightness.dark);
            return _buildListTile(context, Icons.color_lens,
                isDark ? 'Dark Theme' : 'Light Theme', () {
              context.read<ThemeBloc>().add(ToggleTheme());
            },
                trailing: Switch(
                  value: isDark,
                  onChanged: (_) {
                    context.read<ThemeBloc>().add(ToggleTheme());
                  },
                  activeThumbColor: const Color(0xFFC9A96E),
                ),);
          },
        ),
        const SizedBox(height: 16),

        // --- Data & Trust ---
        _buildSectionHeader('Data & Trust'),
        _buildDataTrustSection(context),
        const SizedBox(height: 16),

        // --- Administration & Verified Rate Console ---
        _buildAdminSection(context),
        const SizedBox(height: 16),

        // --- Legal, Privacy & Disclosures ---
        _buildSectionHeader(
          'Legal, Privacy & Disclosures',
          key: const ValueKey('profile_legal_section_header'),
        ),
        _buildListTile(
          context,
          Icons.shield_outlined,
          'Privacy Policy',
          () {
            context.push('/privacy');
          },
          key: const ValueKey('profile_privacy_policy_tile'),
        ),
        const SizedBox(height: 8),
        _buildListTile(
          context,
          Icons.description_outlined,
          'Terms of Use',
          () {
            context.push('/terms');
          },
          key: const ValueKey('profile_terms_of_use_tile'),
        ),
        const SizedBox(height: 8),
        _buildListTile(
          context,
          Icons.gavel_outlined,
          'Financial Disclaimers',
          () {
            context.push('/financial-disclaimer');
          },
          key: const ValueKey('profile_financial_disclaimer_tile'),
        ),
        const SizedBox(height: 8),
        _buildListTile(
          context,
          Icons.campaign_outlined,
          'Advertising Disclosures',
          () {
            context.push('/ad-disclosure');
          },
          key: const ValueKey('profile_ad_disclosure_tile'),
        ),
        const SizedBox(height: 8),
        _buildListTile(
          context,
          Icons.source_outlined,
          'Open Source Licenses',
          () {
            showLicensePage(
              context: context,
              applicationName: 'FeroCalc',
              applicationVersion: AppConstants.appVersion,
              applicationLegalese: '© 2026 FeroCalc. Financial Calculator & Rate Discovery.',
            );
          },
          key: const ValueKey('profile_licenses_tile'),
        ),
        const SizedBox(height: 8),
        _buildVersionTile(context),
        const SizedBox(height: 16),

        // --- Support ---
        _buildSectionHeader('Support'),
        _buildListTile(context, Icons.star_rate_outlined, 'Rate Us', () {
          showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Rate Us'),
              content: const Text('Please rate us 5 stars on the app store!'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),),
              ],
            ),
          );
        }),
        _buildListTile(
          context,
          Icons.share_outlined,
          'Share App',
          () {
            CalculatorShareHelper.shareApp(context);
          },
          key: const ValueKey('profile_share_app_tile'),
        ),
        const SizedBox(height: 48),
        _buildBranding(context),
      ],
    );
  }


  // ---------------------------------------------------------------------------
  // Favorite Banks Section
  // ---------------------------------------------------------------------------

  Widget _buildFavoriteBanksSection(BuildContext context) {
    const gold = Color(0xFFC9A96E);
    final theme = Theme.of(context);
    final favBloc = _getFavoriteBanksBloc(context);
    if (favBloc == null) {
      return const SizedBox.shrink();
    }

    return BlocBuilder<FavoriteBanksBloc, FavoriteBanksState>(
      bloc: favBloc,
      builder: (context, state) {
        final favorites =
            state is FavoriteBanksLoaded ? state.favorites : <FavoriteBank>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader('Favorite Banks'),
                if (favorites.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: gold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${favorites.length} saved',
                      style: const TextStyle(
                        color: gold,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            if (favorites.isNotEmpty) ...[
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: favorites.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final bank = favorites[index];
                    return InkWell(
                      key: ValueKey('profile_fav_chip_${bank.bankId}'),
                      onTap: () {
                        context.push(
                            '/bank/${Uri.encodeComponent(bank.bankName)}');
                      },
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: gold.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded,
                                color: gold, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              bank.bankShortName.isNotEmpty
                                  ? bank.bankShortName
                                  : bank.bankName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
            _buildListTile(
              context,
              Icons.account_balance_outlined,
              favorites.isEmpty
                  ? 'Browse Banks & Add Favorites'
                  : 'Manage Favorite Banks & Catalog',
              () async {
                await context.push('/profile/favorites');
                if (context.mounted) {
                  context
                      .read<FavoriteBanksBloc>()
                      .add(const LoadFavoriteBanks());
                }
              },
              key: const ValueKey('profile_favorite_banks_tile'),
              trailing: const Icon(Icons.chevron_right_rounded,
                  color: gold, size: 20),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Notifications & Alerts Section
  // ---------------------------------------------------------------------------

  Widget _buildNotificationsSection(BuildContext context) {
    const gold = Color(0xFFC9A96E);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Notifications & Alerts'),
        _buildListTile(
          context,
          Icons.notifications_none_rounded,
          'Notification Inbox',
          () async {
            await context.push('/notifications');
            _loadNotificationStatus();
          },
          key: const ValueKey('profile_notification_inbox_tile'),
          trailing: _unreadNotifications > 0
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: gold,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_unreadNotifications',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : const Icon(Icons.chevron_right_rounded,
                  color: Colors.grey, size: 20),
        ),
        const SizedBox(height: 10),
        _buildListTile(
          context,
          Icons.tune_rounded,
          'Notifications',
          () async {
            await context.push('/settings/notifications');
            _loadNotificationStatus();
          },
          key: const ValueKey('profile_notification_settings_tile'),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _notificationsActive
                  ? gold.withValues(alpha: 0.15)
                  : Colors.grey.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _notificationsActive ? 'Active' : 'Paused',
              style: TextStyle(
                color: _notificationsActive ? gold : Colors.grey,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Customer Type Selector
  // ---------------------------------------------------------------------------

  Widget _buildCustomerTypeSelector(BuildContext context) {
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
        children: [
          RadioListTile<String>(
            title: Row(
              children: [
                Icon(Icons.person_outline,
                    size: 20, color: Theme.of(context).colorScheme.secondary,),
                const SizedBox(width: 12),
                Text('Regular', style: TextStyle(color: textColor)),
              ],
            ),
            value: _kRegular,
            groupValue: _customerType,
            onChanged: (value) {
              if (value != null) _setCustomerType(value);
            },
            activeColor: const Color(0xFFC9A96E),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: Colors.white.withValues(alpha: 0.08),),
          RadioListTile<String>(
            title: Row(
              children: [
                Icon(Icons.elderly,
                    size: 20, color: Theme.of(context).colorScheme.secondary,),
                const SizedBox(width: 12),
                Text('Senior Citizen', style: TextStyle(color: textColor)),
              ],
            ),
            value: _kSeniorCitizen,
            groupValue: _customerType,
            onChanged: (value) {
              if (value != null) _setCustomerType(value);
            },
            activeColor: const Color(0xFFC9A96E),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ],
      ),
    ),
  );
  }

  // ---------------------------------------------------------------------------
  // Data & Trust Section
  // ---------------------------------------------------------------------------

  Widget _buildDataTrustSection(BuildContext context) {
    final subtitleColor =
        Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey;
    const gold = Color(0xFFC9A96E);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: gold.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_rounded,
                  size: 22, color: gold,),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Data Trust Center',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'ACTIVE',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Explore data coverage, official bank source circulars, telemetry freshness, and audited rate history transitions.',
            style: TextStyle(fontSize: 12, color: subtitleColor, height: 1.4),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => context.push('/trust-center'),
              icon: const Icon(Icons.shield_outlined, size: 16, color: Colors.black87),
              label: const Text(
                'Open Data Trust Center',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: gold,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () {
              Navigator.push(context,
                  MaterialPageRoute<void>(builder: (_) => const TermsScreen()),);
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.open_in_new, size: 13, color: gold),
                SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'View Full Disclaimer',
                    style: TextStyle(
                      color: gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: gold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared helpers (preserved from original)
  // ---------------------------------------------------------------------------

  Widget _buildSectionHeader(String title, {Key? key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(left: 8, bottom: 8, top: 8),
      child: Semantics(
        header: true,
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFFC9A96E),
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildListTile(
      BuildContext context, IconData icon, String title, VoidCallback onTap,
      {Widget? trailing, bool isDestructive = false, Key? key,}) {
    final textColor = isDestructive
        ? Colors.redAccent
        : Theme.of(context).textTheme.bodyLarge?.color;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: Semantics(
          button: true,
          label: title,
          child: ListTile(
            key: key,
            leading: Icon(icon,
                color: isDestructive
                    ? Colors.redAccent
                    : Theme.of(context).colorScheme.secondary,),
            title: Text(title, style: TextStyle(color: textColor)),
            trailing: trailing ??
                Icon(Icons.arrow_forward_ios,
                    size: 14, color: Theme.of(context).textTheme.bodySmall?.color,),
            onTap: onTap,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }

  Widget _buildVersionTile(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          leading: Icon(Icons.smartphone,
              color: Theme.of(context).colorScheme.secondary,),
          title: Text('Version',
              style:
                  TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),),
          trailing: Text(AppConstants.appVersion,
              style: TextStyle(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  fontSize: 14,),),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildBranding(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.calculate_rounded, size: 40, color: Color(0xFFC9A96E)),
        const SizedBox(height: 8),
        const Text(
          'FeroCalc',
          style: TextStyle(
            color: Color(0xFFC9A96E),
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Text('Made with precision',
            style: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
                fontSize: 12,),),
      ],
    );
  }

  Widget _buildAdminSection(BuildContext context) {
    AdminAuthService? authService;
    if (GetIt.instance.isRegistered<AdminAuthService>()) {
      authService = GetIt.instance<AdminAuthService>();
    }

    final isAuthenticated = authService?.isAuthenticated ?? false;
    final role = authService?.currentSession?.role ?? '';
    final email = authService?.currentSession?.email ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Administration'),
        if (isAuthenticated) ...[
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: FeroColors.gold.withValues(alpha: 0.25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.admin_panel_settings, size: 22, color: FeroColors.gold),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Verified Rate Review Console',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                    ),
                    AdminStatusBadge.forRole(role),
                  ],
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Signed in: $email',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FeroColors.gold,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          context.push('/admin');
                        },
                        icon: const Icon(Icons.dashboard_outlined, size: 16),
                        label: const Text('Open Admin Console', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: FeroColors.error,
                        side: BorderSide(color: FeroColors.error.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        await authService?.logout();
                        if (mounted) setState(() {});
                      },
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ] else ...[
          _buildListTile(
            context,
            Icons.admin_panel_settings_outlined,
            'Admin & Reviewer Console',
            () {
              context.push('/admin/login');
            },
            key: const ValueKey('profile_admin_console_tile'),
          ),
        ],
      ],
    );
  }
}
