import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/design_system.dart';
import '../../../../core/widgets/custom_app_bar.dart';
import '../../data/services/admin_api_service.dart';
import '../../data/services/admin_auth_service.dart';

/// Screen allowing administrators and reviewers to authenticate with Supabase.
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({Key? key}) : super(key: key);

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  int _selectedTabIndex = 0; // 0 = Supabase Email/Password, 1 = Direct JWT Token

  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = GetIt.instance<AdminAuthService>();
    final apiService = GetIt.instance<AdminApiService>();

    try {
      if (_selectedTabIndex == 0) {
        // Authenticate with email and password
        await authService.loginWithEmailPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        // Authenticate with direct session token
        await authService.loginWithToken(_tokenController.text.trim());
      }

      // Verify the session server-side against backend
      try {
        await apiService.getStagedCandidates(limit: 1);
      } catch (backendError) {
        // If backend explicitly rejected with 403 or 401
        final errStr = backendError.toString();
        if (errStr.contains('403') || errStr.toLowerCase().contains('insufficient permissions')) {
          await authService.logout();
          throw Exception('Backend authorization failed: User lacks ADMIN or REVIEWER role in app_metadata.');
        } else if (errStr.contains('401') || errStr.toLowerCase().contains('invalid or expired')) {
          await authService.logout();
          throw Exception('Backend session rejected: Invalid or expired token.');
        }
        // If network issue or staging DB empty, session is still client-parsed with valid signature
      }

      if (mounted) {
        context.go('/admin');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    } finally {
      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Admin Console Sign In',
        showBackButton: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Brand / Console header
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: FeroColors.gold.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings_outlined,
                          size: 44,
                          color: FeroColors.gold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Verified Rate Review Console',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in with Supabase credentials or an authorized session token (ADMIN or REVIEWER role required).',
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.grey,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Error banner
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: FeroColors.error.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: FeroColors.error.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline, size: 18, color: FeroColors.error),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: FeroColors.error, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Segmented Tabs: Email vs Token
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildTabButton(
                              index: 0,
                              label: 'Email & Password',
                              icon: Icons.email_outlined,
                            ),
                          ),
                          Expanded(
                            child: _buildTabButton(
                              index: 1,
                              label: 'Session Token',
                              icon: Icons.vpn_key_outlined,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Tab 0: Email & Password
                    if (_selectedTabIndex == 0) ...[
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                        decoration: InputDecoration(
                          labelText: 'Admin / Reviewer Email',
                          prefixIcon: const Icon(Icons.alternate_email, color: FeroColors.gold, size: 20),
                          filled: true,
                          fillColor: Theme.of(context).cardColor,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Email is required';
                          if (!val.contains('@')) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline, color: FeroColors.gold, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          filled: true,
                          fillColor: Theme.of(context).cardColor,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) return 'Password is required';
                          return null;
                        },
                      ),
                    ] else ...[
                      // Tab 1: Direct JWT Token
                      TextFormField(
                        controller: _tokenController,
                        maxLines: 4,
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                        decoration: InputDecoration(
                          labelText: 'Supabase JWT (Bearer Token)',
                          hintText: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
                          alignLabelWithHint: true,
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(bottom: 50),
                            child: Icon(Icons.key, color: FeroColors.gold, size: 20),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).cardColor,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'JWT token is required';
                          if (val.trim().split('.').length != 3) {
                            return 'Invalid JWT format (must have 3 period-separated segments)';
                          }
                          return null;
                        },
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Sign In Button
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: FeroColors.gold,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _isLoading ? null : _handleLogin,
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                ),
                              )
                            : const Text(
                                'Authenticate & Open Dashboard',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required int index,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedTabIndex == index;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTabIndex = index;
          _errorMessage = null;
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? FeroColors.gold.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(color: FeroColors.gold.withValues(alpha: 0.4))
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? FeroColors.gold : Colors.grey),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? FeroColors.gold : Colors.grey,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
