import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../core/constants/api_constants.dart';
import '../auth/presentation/providers/auth_provider.dart';

const _languages = {
  'en': 'English',
  'hi': 'Hindi',
  'ta': 'Tamil',
  'te': 'Telugu',
  'kn': 'Kannada',
  'mr': 'Marathi',
};

const _payoutPreferences = ['INSTANT', 'DAILY', 'WEEKLY'];

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _upiVpaController;
  String _selectedLanguage = 'en';
  String _payoutPreference = 'INSTANT';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _upiVpaController = TextEditingController();
    _selectedLanguage = user?.languagePreference ?? 'en';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _upiVpaController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final dio = ref.read(dioProvider);

      // Update user profile
      await dio.patch(ApiConstants.userProfile, data: {
        if (_nameController.text.isNotEmpty) 'name': _nameController.text,
        if (_emailController.text.isNotEmpty) 'email': _emailController.text,
        'languagePreference': _selectedLanguage,
      });

      // Update provider-specific settings
      await dio.patch(ApiConstants.providerProfile, data: {
        'payoutPreference': _payoutPreference,
        if (_upiVpaController.text.isNotEmpty) 'upiVpa': _upiVpaController.text,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authProvider.notifier).logout();
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: AppSpacing.paddingMd,
        children: [
          // User info header
          Container(
            padding: AppSpacing.paddingLg,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: Text(
                    (user?.name ?? 'P').isNotEmpty
                        ? (user?.name ?? 'P')[0].toUpperCase()
                        : 'P',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? 'Provider',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.phone ?? '',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 14,
                        ),
                      ),
                      if (user?.email != null)
                        Text(
                          user!.email!,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Edit name
          _SectionHeader(title: 'Personal Information'),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Display Name',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Language
          _SectionHeader(title: 'Language'),
          const SizedBox(height: AppSpacing.sm),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: _languages.entries.map((entry) {
                return RadioListTile<String>(
                  title: Text(entry.value),
                  value: entry.key,
                  groupValue: _selectedLanguage,
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedLanguage = val);
                  },
                  dense: true,
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Provider-only: Payout preference
          _SectionHeader(title: 'Payout Preference'),
          const SizedBox(height: AppSpacing.sm),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: _payoutPreferences.map((pref) {
                final label = switch (pref) {
                  'INSTANT' => 'Instant',
                  'DAILY' => 'Daily Batch',
                  'WEEKLY' => 'Weekly',
                  _ => pref,
                };
                final subtitle = switch (pref) {
                  'INSTANT' => 'Payout as soon as payment settles',
                  'DAILY' => 'Accumulated payouts once per day',
                  'WEEKLY' => 'Accumulated payouts once per week',
                  _ => '',
                };
                return RadioListTile<String>(
                  title: Text(label),
                  subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
                  value: pref,
                  groupValue: _payoutPreference,
                  onChanged: (val) {
                    if (val != null) setState(() => _payoutPreference = val);
                  },
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // UPI VPA
          _SectionHeader(title: 'UPI VPA'),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _upiVpaController,
            decoration: const InputDecoration(
              labelText: 'UPI VPA (e.g. name@upi)',
              prefixIcon: Icon(Icons.account_balance_wallet_outlined),
              hintText: 'yourname@okicici',
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // App version
          Center(
            child: Text(
              'Fliq v1.0.0',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Logout
          OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: AppColors.error),
            label: const Text('Logout'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
    );
  }
}
