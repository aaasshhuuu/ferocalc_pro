import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../services/notification_service.dart';
import '../../domain/models/notification_preferences.dart';
import '../../domain/repositories/notification_preferences_repository.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  late NotificationPreferencesRepository _repo;
  late NotificationService _notificationService;
  NotificationPreferences _prefs = const NotificationPreferences();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _repo = GetIt.instance<NotificationPreferencesRepository>();
    _notificationService = GetIt.instance<NotificationService>();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await _repo.getPreferences();
    if (mounted) {
      setState(() {
        _prefs = prefs;
        _isLoading = false;
      });
    }
  }

  Future<void> _onMasterToggle(bool value) async {
    if (value && !_prefs.systemPermissionGranted) {
      // Show contextual permission rationale dialog
      final granted = await _showPermissionRationaleDialog();
      if (!granted) {
        return;
      }
      await _notificationService.requestPermission();
    }

    final updated = _prefs.copyWith(
      masterEnabled: value,
      systemPermissionGranted: value ? true : _prefs.systemPermissionGranted,
    );
    setState(() {
      _prefs = updated;
    });
    await _repo.savePreferences(updated);
  }

  Future<bool> _showPermissionRationaleDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: const [
                Icon(Icons.notifications_active_outlined,
                    color: Color(0xFFC9A96E)),
                SizedBox(width: 10),
                Text('Stay Informed'),
              ],
            ),
            content: const Text(
              'Get instant alerts when your favorite banks change verified fixed deposit rates. '
              'You can customize which alerts you receive at any time.\n\n'
              'FeroCalc only sends alerts for publicly verified and promoted rates — never unverified rumors or drafts.',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
            actions: [
              TextButton(
                key: const ValueKey('notification_permission_deny_button'),
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Not Now',
                    style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                key: const ValueKey('notification_permission_allow_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC9A96E),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Enable Alerts',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _updateCategory({
    bool? favoriteBankRateChanges,
    bool? newlyPromotedSlabs,
    bool? significantRateChanges,
    bool? productAnnouncements,
  }) async {
    final updated = _prefs.copyWith(
      favoriteBankRateChanges: favoriteBankRateChanges,
      newlyPromotedSlabs: newlyPromotedSlabs,
      significantRateChanges: significantRateChanges,
      productAnnouncements: productAnnouncements,
    );
    setState(() {
      _prefs = updated;
    });
    await _repo.savePreferences(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const gold = Color(0xFFC9A96E);

    return Scaffold(
      appBar: const CustomAppBar(title: 'Notification Settings'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: gold))
          : SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: Responsive.maxContentWidth(context),
                  ),
                  child: ListView(
                    padding: Responsive.screenPadding(context),
                    children: [
                      // Status Card
                      _buildStatusCard(isDark, gold),
                      const SizedBox(height: 24),

                      // Master Switch
                      _buildMasterSwitchCard(isDark, gold),
                      const SizedBox(height: 24),

                      // Per-Category Settings
                      Text(
                        'Alert Categories',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Select the types of verified updates you want to receive. These alerts are only dispatched once rates are officially audited and published.',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.textTheme.bodyMedium?.color
                              ?.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildCategoryTile(
                        key: const ValueKey('pref_favorite_rates_tile'),
                        title: 'Favorite Bank Rate Changes',
                        subtitle:
                            'Receive notifications when banks in your favorites publish verified rate revisions.',
                        value: _prefs.favoriteBankRateChanges,
                        enabled: _prefs.masterEnabled,
                        onChanged: (val) =>
                            _updateCategory(favoriteBankRateChanges: val),
                        icon: Icons.star_outline_rounded,
                        gold: gold,
                      ),
                      const SizedBox(height: 12),

                      _buildCategoryTile(
                        key: const ValueKey('pref_new_slabs_tile'),
                        title: 'Newly Promoted Rate Slabs',
                        subtitle:
                            'Alerts when new special schemes or tenure buckets pass audit and are added to the verified registry.',
                        value: _prefs.newlyPromotedSlabs,
                        enabled: _prefs.masterEnabled,
                        onChanged: (val) =>
                            _updateCategory(newlyPromotedSlabs: val),
                        icon: Icons.trending_up_rounded,
                        gold: gold,
                      ),
                      const SizedBox(height: 12),

                      _buildCategoryTile(
                        key: const ValueKey('pref_significant_changes_tile'),
                        title: 'Major Rate Revisions',
                        subtitle:
                            'Get notified when any monitored institution changes rates by more than 25 bps.',
                        value: _prefs.significantRateChanges,
                        enabled: _prefs.masterEnabled,
                        onChanged: (val) =>
                            _updateCategory(significantRateChanges: val),
                        icon: Icons.notification_important_outlined,
                        gold: gold,
                      ),
                      const SizedBox(height: 12),

                      _buildCategoryTile(
                        key: const ValueKey('pref_announcements_tile'),
                        title: 'Product Announcements',
                        subtitle:
                            'Occasional feature highlights and calculator updates. (Disabled by default)',
                        value: _prefs.productAnnouncements,
                        enabled: _prefs.masterEnabled,
                        onChanged: (val) =>
                            _updateCategory(productAnnouncements: val),
                        icon: Icons.campaign_outlined,
                        gold: gold,
                      ),
                      const SizedBox(height: 32),

                      // Transparency Note
                      _buildVerificationGuaranteeNotice(isDark),
                      const SizedBox(height: 24),

                      // Data Privacy & Remote Deletion Entry
                      _buildDataPrivacySection(isDark, gold),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildStatusCard(bool isDark, Color gold) {
    final active = _prefs.areNotificationsActive;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: active
            ? gold.withValues(alpha: 0.1)
            : (isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.03)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active
              ? gold.withValues(alpha: 0.3)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: active
                  ? gold.withValues(alpha: 0.15)
                  : Colors.grey.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              active
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_off_outlined,
              color: active ? gold : Colors.grey,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active ? 'Alerts are Active' : 'Alerts are Paused',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  active
                      ? 'You will receive verified rate updates based on your preferences.'
                      : 'Enable notifications to stay updated on bank rate movements.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .textTheme.bodyMedium
                        ?.color
                        ?.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMasterSwitchCard(bool isDark, Color gold) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Allow Notifications',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Master switch for all FeroCalc alerts and inbox updates',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .textTheme.bodyMedium
                        ?.color
                        ?.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            key: const ValueKey('notification_master_switch'),
            value: _prefs.masterEnabled,
            onChanged: _onMasterToggle,
            activeColor: gold,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTile({
    required Key key,
    required String title,
    required String subtitle,
    required bool value,
    required bool enabled,
    required ValueChanged<bool> onChanged,
    required IconData icon,
    required Color gold,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: enabled ? 1.0 : 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: enabled && value ? gold : Colors.grey,
            size: 22,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: enabled
                        ? theme.textTheme.bodyLarge?.color
                        : theme.textTheme.bodyLarge?.color
                            ?.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textTheme.bodyMedium?.color
                        ?.withValues(alpha: enabled ? 0.7 : 0.4),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value && enabled,
            onChanged: enabled ? onChanged : null,
            activeColor: gold,
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationGuaranteeNotice(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_user_outlined,
              color: Color(0xFFC9A96E), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Zero-Noise Guarantee: FeroCalc never sends notifications for unreviewed scraping drafts, in-progress reviews, or failed fetches. Only verified, official rates published by banks trigger notifications.',
              style: TextStyle(
                fontSize: 11.5,
                color: Theme.of(context)
                    .textTheme.bodySmall
                    ?.color
                    ?.withValues(alpha: 0.8),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteRemoteDataDialog() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: const [
                Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
                SizedBox(width: 10),
                Text('Delete Remote Data?'),
              ],
            ),
            content: const Text(
              'This will revoke and delete your anonymous device token, notification preferences, '
              'and favorite bank alert associations from FeroCalc servers.\n\n'
              'Important: Your local saved calculations, goals, and financial profile are stored on your device '
              'and will NOT be deleted.',
              style: TextStyle(fontSize: 13.5, height: 1.4),
            ),
            actions: [
              TextButton(
                key: const ValueKey('cancel_delete_remote_data_button'),
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                key: const ValueKey('confirm_delete_remote_data_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete Remote Data', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed && mounted) {
      final success = await _notificationService.deleteRemoteRegistration();
      if (mounted) {
        final prefs = await _repo.getPreferences();
        setState(() {
          _prefs = prefs;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Remote notification data deleted successfully. Local calculations and goals are preserved.'
                  : 'Failed to complete remote deletion. Please try again or email ferocalc.app@gmail.com.',
            ),
            backgroundColor: success ? const Color(0xFFC9A96E) : Colors.redAccent,
          ),
        );
      }
    }
  }

  Widget _buildDataPrivacySection(bool isDark, Color gold) {
    final instId = _notificationService.installationId;
    final theme = Theme.of(context);

    return Container(
      key: const ValueKey('notification_data_privacy_section'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.privacy_tip_outlined, color: Color(0xFFC9A96E), size: 20),
              SizedBox(width: 8),
              Text(
                'Data Privacy & Deletion',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'FeroCalc operates without consumer accounts. If you enabled notifications, only your anonymous device token and alert preferences are stored remotely.',
            style: TextStyle(
              fontSize: 12.5,
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.75),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Anonymous Installation ID',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 2),
                      SelectableText(
                        instId,
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: 'Copy Installation ID',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: instId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Installation ID copied to clipboard')),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const ValueKey('delete_remote_notification_data_button'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Delete Remote Notification Data', style: TextStyle(fontWeight: FontWeight.w600)),
              onPressed: _showDeleteRemoteDataDialog,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Manual Deletion Requests: If you have uninstalled the app or prefer email handling, email ferocalc.app@gmail.com with your Installation ID.',
            style: TextStyle(
              fontSize: 11,
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
