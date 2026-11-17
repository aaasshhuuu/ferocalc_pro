import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/design_system.dart';
import '../../../../core/widgets/custom_app_bar.dart';

/// Screen displayed when an unauthenticated or unauthorized user attempts to access admin routes.
class AdminAccessDeniedScreen extends StatelessWidget {
  const AdminAccessDeniedScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Admin Access Denied',
        showBackButton: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: FeroColors.error.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: FeroColors.error.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(
                      Icons.gpp_bad_outlined,
                      size: 64,
                      color: FeroColors.error,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Administrative Authorization Required',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'This console is reserved exclusively for authenticated FeroCalc administrators '
                    'and rate reviewers with verified credentials.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.8) ?? Colors.grey,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: FeroColors.gold,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        context.push('/admin/login');
                      },
                      icon: const Icon(Icons.lock_open, size: 18),
                      label: const Text(
                        'Sign In as Administrator',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).textTheme.bodyLarge?.color,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        context.go('/home');
                      },
                      child: const Text('Return to Home'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
