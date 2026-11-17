import 'package:flutter/material.dart';

class WelcomeHeader extends StatelessWidget {

  const WelcomeHeader({
    Key? key,
    required this.userName,
    required this.onNotificationTap,
  }) : super(key: key);
  final String userName;
  final VoidCallback onNotificationTap;

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_getGreeting()},',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                userName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        IconButton(
          key: const ValueKey('home_notification_button'),
          tooltip: 'Notifications',
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          icon: const Icon(Icons.notifications_outlined),
          onPressed: onNotificationTap,
        ),
      ],
    );
  }
}
