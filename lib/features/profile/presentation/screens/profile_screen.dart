import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
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

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({Key? key}) : super(key: key);

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
        _buildSectionHeader('About'),
        _buildListTile(context, Icons.info_outline, 'Privacy Policy', () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()));
        }),
        _buildListTile(context, Icons.description_outlined, 'Terms of Service', () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsScreen()));
        }),
        _buildVersionTile(context),
        const SizedBox(height: 16),
        _buildSectionHeader('Support'),
        _buildListTile(context, Icons.star_rate_outlined, 'Rate Us', () {
          showDialog(
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
        _buildSectionHeader('My Data'),
        _buildListTile(context, Icons.history, 'Calculation History', () {}),
        _buildListTile(context, Icons.bookmark_border, 'Saved Calculations', () {}),
        _buildListTile(context, Icons.cloud_done_outlined, 'Cloud Sync Status', () {}, trailing: Icon(Icons.check_circle, color: Theme.of(context).colorScheme.secondary, size: 20)),
        _buildListTile(context, Icons.import_export, 'Export Settings', () {}),
        const SizedBox(height: 16),
        _buildSectionHeader('Account Settings'),
        _buildListTile(context, Icons.lock_outline, 'Change Password', () {}),
        _buildListTile(context, Icons.delete_outline, 'Delete Account', () {}, isDestructive: true),
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
        _buildVersionTile(context),
        const SizedBox(height: 48),
        _buildBranding(context),
      ],
    );
  }

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
    int tapCount = 0;
    return Center(
      child: GestureDetector(
        onTap: () {
          tapCount++;
          if (tapCount >= 3) {
            tapCount = 0;
            // Admin login logic here
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text('Version 1.0.0', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12)),
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
        Text('Made with precision', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color, fontSize: 12)),
      ],
    );
  }
}
