import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../domain/models/app_notification.dart';
import '../../domain/repositories/notification_inbox_repository.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const Color _gold = Color(0xFFC9A96E);
  late NotificationInboxRepository _inboxRepo;
  List<AppNotification> _notifications = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // 'all' or 'unread'

  @override
  void initState() {
    super.initState();
    _inboxRepo = GetIt.instance<NotificationInboxRepository>();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final list = await _inboxRepo.getNotifications();
    if (mounted) {
      setState(() {
        _notifications = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(AppNotification notification) async {
    if (!notification.isRead) {
      await _inboxRepo.markAsRead(notification.id);
      await _loadNotifications();
    }
  }

  Future<void> _markAllAsRead() async {
    await _inboxRepo.markAllAsRead();
    await _loadNotifications();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All notifications marked as read'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deleteNotification(String id) async {
    await _inboxRepo.deleteNotification(id);
    await _loadNotifications();
  }

  Future<void> _confirmClearAll() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Theme.of(context).cardColor,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Clear Notification Inbox?'),
            content: const Text(
              'This will permanently remove all verified rate notifications from this device. This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Clear All'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed) {
      await _inboxRepo.clearAllNotifications();
      await _loadNotifications();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Notification inbox cleared')),
        );
      }
    }
  }

  void _onNotificationTap(AppNotification item) async {
    await _markAsRead(item);
    if (!mounted) return;

    if (item.actionRoute != null && item.actionRoute!.isNotEmpty) {
      context.push(item.actionRoute!);
    } else if (item.bankName.isNotEmpty) {
      // Default to bank detail page
      context.push('/bank/${Uri.encodeComponent(item.bankName)}');
    } else {
      // Fallback to data trust center
      context.push('/data-trust-center');
    }
  }

  List<AppNotification> get _filteredNotifications {
    if (_selectedFilter == 'unread') {
      return _notifications.where((n) => !n.isRead).toList();
    }
    return _notifications;
  }

  int get _unreadCount => _notifications.where((n) => !n.isRead).length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Notification Center',
        actions: [
          IconButton(
            key: const ValueKey('notification_settings_icon_button'),
            icon: const Icon(Icons.tune_rounded, color: _gold),
            tooltip: 'Notification Settings',
            onPressed: () => context.push('/settings/notifications'),
          ),
          if (_notifications.isNotEmpty)
            PopupMenuButton<String>(
              key: const ValueKey('notification_more_options_button'),
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (val) {
                if (val == 'mark_all_read') {
                  _markAllAsRead();
                } else if (val == 'clear_all') {
                  _confirmClearAll();
                }
              },
              itemBuilder: (ctx) => [
                if (_unreadCount > 0)
                  const PopupMenuItem(
                    value: 'mark_all_read',
                    child: Text('Mark all as read'),
                  ),
                const PopupMenuItem(
                  value: 'clear_all',
                  child: Text('Clear all notifications',
                      style: TextStyle(color: Colors.redAccent)),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _gold))
          : SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: Responsive.maxContentWidth(context),
                  ),
                  child: Column(
                    children: [
                      // Filter bar
                      _buildFilterBar(isDark),

                      // List
                      Expanded(
                        child: _filteredNotifications.isEmpty
                            ? _buildEmptyState()
                            : ListView.separated(
                                padding: Responsive.screenPadding(context),
                                itemCount: _filteredNotifications.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  final item = _filteredNotifications[index];
                                  return _buildNotificationCard(
                                      item, isDark);
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildFilterBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.2)
            : Colors.grey.withValues(alpha: 0.05),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              ChoiceChip(
                key: const ValueKey('filter_all_notifications_chip'),
                label: Text('All (${_notifications.length})'),
                selected: _selectedFilter == 'all',
                onSelected: (selected) {
                  if (selected) setState(() => _selectedFilter = 'all');
                },
                selectedColor: _gold.withValues(alpha: 0.2),
                labelStyle: TextStyle(
                  color: _selectedFilter == 'all'
                      ? _gold
                      : Theme.of(context).textTheme.bodyMedium?.color,
                  fontWeight: _selectedFilter == 'all'
                      ? FontWeight.bold
                      : FontWeight.normal,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                key: const ValueKey('filter_unread_notifications_chip'),
                label: Text('Unread ($_unreadCount)'),
                selected: _selectedFilter == 'unread',
                onSelected: (selected) {
                  if (selected) setState(() => _selectedFilter = 'unread');
                },
                selectedColor: _gold.withValues(alpha: 0.2),
                labelStyle: TextStyle(
                  color: _selectedFilter == 'unread'
                      ? _gold
                      : Theme.of(context).textTheme.bodyMedium?.color,
                  fontWeight: _selectedFilter == 'unread'
                      ? FontWeight.bold
                      : FontWeight.normal,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
          if (_unreadCount > 0)
            TextButton.icon(
              key: const ValueKey('mark_all_read_button'),
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all_rounded, size: 16, color: _gold),
              label: const Text(
                'Mark read',
                style: TextStyle(
                    color: _gold, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(AppNotification item, bool isDark) {
    final theme = Theme.of(context);
    final formattedTime =
        DateFormat('MMM d, y • h:mm a').format(item.verifiedTimestamp);

    return Dismissible(
      key: ValueKey('dismiss_${item.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.white, size: 24),
      ),
      onDismissed: (_) => _deleteNotification(item.id),
      child: Semantics(
        button: true,
        label: '${item.isRead ? "Read" : "Unread"} notification for ${item.bankName.isNotEmpty ? item.bankName : "Monitored Bank"}: ${item.title}. ${item.message}',
        child: InkWell(
          key: ValueKey('notification_item_${item.id}'),
          onTap: () => _onNotificationTap(item),
          borderRadius: BorderRadius.circular(16),
          child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: item.isRead
                ? (isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.black.withValues(alpha: 0.02))
                : (isDark
                    ? _gold.withValues(alpha: 0.07)
                    : _gold.withValues(alpha: 0.04)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: item.isRead
                  ? (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06))
                  : _gold.withValues(alpha: 0.45),
              width: item.isRead ? 1.0 : 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Type Badge + Bank Name + Unread indicator
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _gold.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_getIconForType(item.type),
                        color: _gold, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              item.bankName.isNotEmpty
                                  ? item.bankName
                                  : 'Monitored Bank',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: _gold.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.type.label,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: _gold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formattedTime,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.textTheme.bodySmall?.color
                                ?.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!item.isRead)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: _gold,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Title
              Text(
                item.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 6),

              // Change Summary Message
              Text(
                item.message,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: theme.textTheme.bodyMedium?.color
                      ?.withValues(alpha: 0.85),
                ),
              ),

              if (item.effectiveDate != null &&
                  item.effectiveDate!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 13, color: _gold),
                    const SizedBox(width: 5),
                    Text(
                      'Effective: ${item.effectiveDate}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 12),
              // Action prompt
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'View Verified Details',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _gold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward_rounded,
                      size: 14, color: _gold),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  IconData _getIconForType(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.verifiedRateChange:
        return Icons.trending_up_rounded;
      case AppNotificationType.newPromotedSlab:
        return Icons.add_chart_rounded;
      case AppNotificationType.significantRateChange:
        return Icons.bolt_rounded;
      case AppNotificationType.announcement:
        return Icons.campaign_rounded;
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: EmptyState(
        icon: Icons.notifications_none_rounded,
        title: _selectedFilter == 'unread'
            ? 'No Unread Notifications'
            : 'No Notifications Yet',
        subtitle: _selectedFilter == 'unread'
            ? 'All caught up! Any new rate changes will appear here.'
            : 'When your favorite banks update verified deposit rates or new slabs are promoted, alerts will appear here.',
      ),
    );
  }
}
