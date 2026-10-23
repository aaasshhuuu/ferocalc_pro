import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../../../core/widgets/empty_state.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<Map<String, dynamic>> _notifications = [
    {
      'id': 'welcome',
      'title': 'Welcome to FeroCalc',
      'message':
          'Explore 28 financial calculators, compare live FD rates, and discover Financial Literacy in English, Hindi, and Gujarati.',
      'time': 'Recent',
      'icon': Icons.celebration_rounded,
      'isNew': true,
      'route': '/calculators',
    },
    {
      'id': 'fd_rates',
      'title': 'Bank FD Rates Updated',
      'message':
          'Fixed deposit rates from leading banks have been verified. Check the Compare section for side-by-side rates.',
      'time': 'Updated',
      'icon': Icons.account_balance_rounded,
      'isNew': false,
      'route': '/compare',
    },
    {
      'id': 'financial_literacy',
      'title': 'Financial Literacy Hub',
      'message':
          'Master money concepts including Rule of 72, 70/20/10 Rule, and Emergency Fund planning in the Insights tab.',
      'time': 'Guide',
      'icon': Icons.school_rounded,
      'isNew': false,
      'route': '/financial-literacy',
    },
  ];

  void _clearAll() {
    setState(() {
      _notifications.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const gold = Color(0xFFC9A96E);

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Notifications',
        actions: _notifications.isNotEmpty
            ? [
                TextButton(
                  key: const ValueKey('clear_notifications_button'),
                  onPressed: _clearAll,
                  child: const Text(
                    'Clear all',
                    style: TextStyle(
                      color: gold,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ]
            : null,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: Responsive.maxContentWidth(context)),
          child: _notifications.isEmpty
              ? const EmptyState(
                  icon: Icons.notifications_none_rounded,
                  title: 'No Notifications',
                  subtitle:
                      "You're all caught up! Bank rate changes, scheme revisions, and updates will appear here.",
                )
              : ListView.separated(
                  padding: Responsive.screenPadding(context),
                  itemCount: _notifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = _notifications[index];
                    final isNew = item['isNew'] as bool;
                    final route = item['route'] as String?;

                    return InkWell(
                      key: ValueKey('notification_item_${item['id']}'),
                      onTap: route != null ? () => context.go(route) : null,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.04)
                              : Colors.black.withOpacity(0.02),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isNew
                                ? gold.withOpacity(0.4)
                                : (isDark
                                    ? Colors.white.withOpacity(0.08)
                                    : Colors.black.withOpacity(0.06)),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: gold.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(item['icon'] as IconData, color: gold, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item['title'] as String,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: theme.textTheme.bodyLarge?.color,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isNew
                                              ? gold.withOpacity(0.15)
                                              : (isDark ? Colors.white10 : Colors.black12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          item['time'] as String,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight:
                                                isNew ? FontWeight.bold : FontWeight.normal,
                                            color: isNew
                                                ? gold
                                                : theme.textTheme.bodySmall?.color,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    item['message'] as String,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.4,
                                      color: theme.textTheme.bodyMedium?.color
                                          ?.withOpacity(0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
