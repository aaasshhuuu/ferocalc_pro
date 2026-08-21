import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../config/routes/route_names.dart';
import '../../../../core/widgets/glassmorphic_card.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../../../../config/themes/app_gradients.dart';
import '../../../../core/utils/responsive.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  void _handleLogin() {
    if (_formKey.currentState?.validate() ?? false) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logging in...')),
      );
      context.goNamed(RouteNames.home);
    }
  }

  void _handleGuest() {
    context.goNamed(RouteNames.home);
  }

  void _forgotPassword() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Forgot Password link clicked')),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryGold = const Color(0xFFC9A96E);
    final backgroundColor = isDark ? Theme.of(context).scaffoldBackgroundColor : theme.colorScheme.surface;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: Responsive.screenPadding(context),
            child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFFC9A96E), Color(0xFFE8D399)],
                ).createShader(bounds),
                child: const Icon(Icons.account_circle, size: 80, color: Colors.white),
              ).animate(),
              const SizedBox(height: 16),
              Text(
                'Welcome to FeroCalc',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ).animate().fade(delay: 200.ms),
              const SizedBox(height: 8),
              Text(
                'Premium Financial Tools',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
              ).animate().fade(delay: 300.ms),
              const SizedBox(height: 48),
              GlassmorphicCard(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _emailController,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                        decoration: InputDecoration(
                          labelText: 'Email',
                          labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                          prefixIcon: Icon(Icons.email, color: primaryGold),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: primaryGold),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty || !value.contains('@')) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                          prefixIcon: Icon(Icons.lock, color: primaryGold),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: primaryGold),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _forgotPassword,
                          child: Text('Forgot Password?', style: TextStyle(color: primaryGold)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: GradientButton(
                          text: 'Sign In',
                          gradient: AppGradients.primaryDarkGradient,
                          onPressed: () {
                            if (_formKey.currentState?.validate() ?? false) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Login feature will be available soon with Firebase')),
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Google Sign-in coming soon with Firebase')),
                            );
                          },
                          icon: const Icon(Icons.login),
                          label: const Text('Sign in with Google'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryGold,
                            side: BorderSide(color: primaryGold),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text('or', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _handleGuest,
                        child: Text('Continue as Guest', style: TextStyle(color: primaryGold, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ],
                  ),
                ),
              ).animate().fade(),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
