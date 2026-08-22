import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_state.dart';
import '../../features/auth/presentation/bloc/auth_event.dart';

class LoginGate extends StatelessWidget {
  final Widget child;
  final String featureName;

  const LoginGate({
    Key? key,
    required this.child,
    required this.featureName,
  }) : super(key: key);

  void _showLoginPrompt(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LoginPromptSheet(featureName: featureName),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Guest mode bypasses authentication completely
    return child;
  }
}

class _LoginPromptSheet extends StatelessWidget {
  final String featureName;

  const _LoginPromptSheet({Key? key, required this.featureName}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFC9A96E), Color(0xFFE8D399)],
            ).createShader(bounds),
            child: const Icon(Icons.workspace_premium, size: 64, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            'Unlock $featureName',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFFC9A96E),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Sign in to unlock $featureName, save your calculations to the cloud, export reports, and access detailed insights.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
          ),
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                colors: [Color(0xFF00B4D8), Color(0xFF0077B6)],
              ),
            ),
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Instead of hardcoded fake login, just show Guest flow or real auth flow trigger
                // We'll leave this button just popping the dialog as per guest flow requirement
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Sign In', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Continue as Guest',
              style: TextStyle(color: Colors.white54, fontSize: 16),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
