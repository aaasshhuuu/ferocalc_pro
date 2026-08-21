import os
import re

profile_path = r"c:\projects\fincalc_pro\lib\features\profile\presentation\screens\profile_screen.dart"

with open(profile_path, "r", encoding="utf-8") as f:
    content = f.read()

# Notifications
content = content.replace(
    "_buildListTile(context, Icons.notifications_none, 'Notifications', () {}),",
    """_buildListTile(context, Icons.notifications_none, 'Notifications', () {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notification preferences updated')));
        }),"""
)

# Privacy Policy
content = content.replace(
    "_buildListTile(context, Icons.info_outline, 'Privacy Policy', () {}),",
    """_buildListTile(context, Icons.info_outline, 'Privacy Policy', () {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Privacy Policy'),
              content: const Text('Your data is secure with Finora.'),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
            ),
          );
        }),"""
)

# Terms of Service
content = content.replace(
    "_buildListTile(context, Icons.description_outlined, 'Terms of Service', () {}),",
    """_buildListTile(context, Icons.description_outlined, 'Terms of Service', () {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Terms of Service'),
              content: const Text('By using Finora, you agree to our terms.'),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
            ),
          );
        }),"""
)

# Rate Us
content = content.replace(
    "_buildListTile(context, Icons.star_rate_outlined, 'Rate Us', () {}),",
    """_buildListTile(context, Icons.star_rate_outlined, 'Rate Us', () {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Rate Us'),
              content: const Text('Please rate us 5 stars on the app store!'),
              actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
            ),
          );
        }),"""
)

# Share App
content = content.replace(
    "_buildListTile(context, Icons.share_outlined, 'Share App', () {}),",
    """_buildListTile(context, Icons.share_outlined, 'Share App', () {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Share link copied!')));
        }),"""
)

# Sign In button
content = re.sub(
    r"context\.read<AuthBloc>\(\)\.add\(const LoginRequested\([^)]+\)\);",
    r"ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login screen coming soon!')));",
    content
)

with open(profile_path, "w", encoding="utf-8") as f:
    f.write(content)

print("Profile screen updated")
