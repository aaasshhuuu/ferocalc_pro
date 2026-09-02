import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:get_it/get_it.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_state.dart';
import '../../../../features/auth/presentation/bloc/auth_event.dart';
import '../../../../features/theme/bloc/theme_bloc.dart';
import '../../../../features/theme/bloc/theme_event.dart';
import '../../../../features/theme/bloc/theme_state.dart';
import '../../../../core/utils/responsive.dart';
import 'package:fincalc_pro/features/profile/presentation/screens/privacy_policy_screen.dart';
import 'package:fincalc_pro/features/profile/presentation/screens/terms_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadCustomerType();
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
          child: BlocBuilder<AuthBloc, AuthState>(
            builder: (context, state) {
              if (state is AuthAuthenticated) {
                return _buildAuthenticatedProfile(context, state);
              } else {
                return _buildGuestProfile(context);
              }
            },
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildGuestProfile(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Center(
          child: CircleAvatar(
            radius: 50,
            backgroundColor: Colors.transparent,
            child: Icon(Icons.person_outline, size: 50, color: Color(0xFFC9A96E)),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text('Welcome, Guest', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
        ),
        const SizedBox(height: 24),
        Center(
          child: Container(
            width: Responsive.isDesktop(context) ? 300 : double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(colors: [Theme.of(context).colorScheme.secondary, Theme.of(context).colorScheme.primary]),
            ),
            child: ElevatedButton(
              onPressed: () {
                context.push('/login');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Sign In / Create Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white))),
            ),
          ),
        ),
        const SizedBox(height: 32),

        // --- Customer Type ---
        _buildSectionHeader('Customer Type'),
        _buildCustomerTypeSelector(context),
        const SizedBox(height: 16),

        // --- App Settings ---
        _buildSectionHeader('App Settings'),
        BlocBuilder<ThemeBloc, ThemeState>(
          builder: (context, themeState) {
            final isDark = themeState is ThemeDark || (themeState is ThemeSystem && Theme.of(context).brightness == Brightness.dark);
            return _buildListTile(
              context,
              Icons.color_lens, 
              isDark ? 'Dark Theme' : 'Light Theme', 
              () {
                context.read<ThemeBloc>().add(ToggleTheme());
              },
              trailing: Switch(
                value: isDark,
                onChanged: (_) {
                  context.read<ThemeBloc>().add(ToggleTheme());
                },
                activeColor: const Color(0xFFC9A96E),
              )
            );
          },
        ),
        _buildListTile(context, Icons.notifications_none, 'Notifications', () {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification preferences updated')));
        }),
        const SizedBox(height: 16),

        // --- Data & Trust ---
        _buildSectionHeader('Data & Trust'),
        _buildDataTrustSection(context),
        const SizedBox(height: 16),

        // --- About FeroCalc ---
        _buildSectionHeader('About FeroCalc'),
        _buildListTile(context, Icons.info_outline, 'Privacy Policy', () {
          Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const PrivacyPolicyScreen()));
        }),
        _buildListTile(context, Icons.description_outlined, 'Terms of Service', () {
          Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const TermsScreen()));
        }),
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
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
            ),
          );
        }),
        _buildListTile(context, Icons.share_outlined, 'Share App', () {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Share link copied!')));
        }),
        const SizedBox(height: 48),
        _buildBranding(context),
      ],
    );
  }

  Widget _buildAuthenticatedProfile(BuildContext context, AuthAuthenticated state) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: CircleAvatar(
            radius: 50,
            backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
            child: Text(
              state.user.displayName.isNotEmpty ? state.user.displayName[0].toUpperCase() : 'U',
              style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(state.user.displayName, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(state.user.email, style: TextStyle(fontSize: 14, color: Theme.of(context).textTheme.bodyMedium?.color)),
        ),
        const SizedBox(height: 32),

        // --- Customer Type ---
        _buildSectionHeader('Customer Type'),
        _buildCustomerTypeSelector(context),
        const SizedBox(height: 16),

        // --- My Data ---
        _buildSectionHeader('My Data'),
        _buildListTile(context, Icons.history, 'Calculation History', () {}),
        _buildListTile(context, Icons.bookmark_border, 'Saved Calculations', () {}),
        _buildListTile(context, Icons.cloud_done_outlined, 'Cloud Sync Status', () {}, trailing: Icon(Icons.check_circle, color: Theme.of(context).colorScheme.secondary, size: 20)),
        _buildListTile(context, Icons.import_export, 'Export Settings', () {}),
        const SizedBox(height: 16),

        // --- Account Settings ---
        _buildSectionHeader('Account Settings'),
        _buildListTile(context, Icons.lock_outline, 'Change Password', () {}),
        _buildListTile(context, Icons.delete_outline, 'Delete Account', () {}, isDestructive: true),
        const SizedBox(height: 16),

        // --- Data & Trust ---
        _buildSectionHeader('Data & Trust'),
        _buildDataTrustSection(context),
        const SizedBox(height: 16),

        // --- About FeroCalc ---
        _buildSectionHeader('About FeroCalc'),
        _buildListTile(context, Icons.info_outline, 'Privacy Policy', () {
          Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const PrivacyPolicyScreen()));
        }),
        _buildListTile(context, Icons.description_outlined, 'Terms of Service', () {
          Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const TermsScreen()));
        }),
        _buildVersionTile(context),
        const SizedBox(height: 16),

        ListTile(
          leading: const Icon(Icons.logout, color: Colors.redAccent),
          title: const Text('Sign Out', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
          onTap: () {
            context.read<AuthBloc>().add(LogoutRequested());
          },
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          tileColor: Theme.of(context).cardColor,
        ),
        const SizedBox(height: 32),
        _buildBranding(context),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Customer Type Selector
  // ---------------------------------------------------------------------------

  Widget _buildCustomerTypeSelector(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          RadioListTile<String>(
            title: Row(
              children: [
                Icon(Icons.person_outline, size: 20, color: Theme.of(context).colorScheme.secondary),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          Divider(height: 1, indent: 16, endIndent: 16, color: Colors.white.withOpacity(0.08)),
          RadioListTile<String>(
            title: Row(
              children: [
                Icon(Icons.elderly, size: 20, color: Theme.of(context).colorScheme.secondary),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Data & Trust Section
  // ---------------------------------------------------------------------------

  Widget _buildDataTrustSection(BuildContext context) {
    final subtitleColor = Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user_outlined, size: 22, color: Colors.orange.shade400),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Rate Verification Status',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.schedule, size: 16, color: Colors.orange.shade400),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'All rates: PENDING_REVIEW',
                    style: TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Financial data shown in this app has not been independently verified. '
            'Always cross-check rates with official bank or government sources before making decisions.',
            style: TextStyle(fontSize: 12, color: subtitleColor, height: 1.5),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () {
              Navigator.push(context, MaterialPageRoute<void>(builder: (_) => const TermsScreen()));
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.open_in_new, size: 14, color: Color(0xFFC9A96E)),
                SizedBox(width: 6),
                Text(
                  'View Full Disclaimer',
                  style: TextStyle(
                    color: Color(0xFFC9A96E),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: Color(0xFFC9A96E),
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8, top: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Color(0xFFC9A96E),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildListTile(BuildContext context, IconData icon, String title, VoidCallback onTap, {Widget? trailing, bool isDestructive = false}) {
    final textColor = isDestructive ? Colors.redAccent : Theme.of(context).textTheme.bodyLarge?.color;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: isDestructive ? Colors.redAccent : Theme.of(context).colorScheme.secondary),
        title: Text(title, style: TextStyle(color: textColor)),
        trailing: trailing ?? Icon(Icons.arrow_forward_ios, size: 14, color: Theme.of(context).textTheme.bodySmall?.color),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      child: ListTile(
        leading: Icon(Icons.smartphone, color: Theme.of(context).colorScheme.secondary),
        title: Text('Version', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
        trailing: Text('1.0.0', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 14)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        Text('Made with precision', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12)),
      ],
    );
  }
}
