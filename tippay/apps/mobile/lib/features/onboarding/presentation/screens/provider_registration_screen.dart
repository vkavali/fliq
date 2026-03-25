import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/onboarding_provider.dart';

// Category data: enum value → display label + icon
const _categories = [
  {'value': 'DELIVERY', 'label': 'Delivery', 'icon': '🛵'},
  {'value': 'SALON', 'label': 'Salon', 'icon': '✂️'},
  {'value': 'RESTAURANT', 'label': 'Restaurant', 'icon': '🍽️'},
  {'value': 'HOTEL', 'label': 'Hotel', 'icon': '🏨'},
  {'value': 'HOUSEHOLD', 'label': 'Household', 'icon': '🏠'},
  {'value': 'HEALTHCARE', 'label': 'Healthcare', 'icon': '💊'},
  {'value': 'EDUCATION', 'label': 'Education', 'icon': '📚'},
  {'value': 'TRANSPORT', 'label': 'Transport', 'icon': '🚗'},
  {'value': 'FITNESS', 'label': 'Fitness', 'icon': '💪'},
  {'value': 'OTHER', 'label': 'Other', 'icon': '⭐'},
];

class ProviderRegistrationScreen extends ConsumerStatefulWidget {
  const ProviderRegistrationScreen({super.key});

  @override
  ConsumerState<ProviderRegistrationScreen> createState() =>
      _ProviderRegistrationScreenState();
}

class _ProviderRegistrationScreenState
    extends ConsumerState<ProviderRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  String? _selectedCategory;

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    ref.read(onboardingProvider.notifier).submitRegistration(
          displayName: _displayNameCtrl.text.trim(),
          category: _selectedCategory!,
          bio: _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    final theme = Theme.of(context);

    ref.listen(onboardingProvider, (_, next) {
      if (next.status == OnboardingStatus.success &&
          next.step == OnboardingStep.bankDetails) {
        context.go('/onboarding/bank-details');
      } else if (next.status == OnboardingStatus.error && next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            backgroundColor: AppColors.error,
          ),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Become a Provider'),
        leading: BackButton(onPressed: () => context.go('/home')),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AppSpacing.horizontalLg,
          children: [
            const SizedBox(height: AppSpacing.lg),

            // Progress indicator
            _OnboardingProgress(step: 1, total: 4),
            const SizedBox(height: AppSpacing.xl),

            Text(
              'Tell us about yourself',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Customers will see this information when they tip you.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Display name
            TextFormField(
              controller: _displayNameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Display Name *',
                hintText: 'e.g. Amit Kumar',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Display name is required';
                if (v.trim().length < 2) return 'Must be at least 2 characters';
                if (v.trim().length > 100) return 'Must be under 100 characters';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // Bio
            TextFormField(
              controller: _bioCtrl,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Bio (optional)',
                hintText: 'A short description about your work…',
                prefixIcon: Icon(Icons.info_outline),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Category selection
            Text(
              'Select Your Category *',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.md),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.1,
              ),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory == cat['value'];
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = cat['value']),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.grey.shade200,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          cat['icon']!,
                          style: const TextStyle(fontSize: 28),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          cat['label']!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.normal,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: AppSpacing.xl),

            ElevatedButton(
              onPressed: state.status == OnboardingStatus.loading ? null : _submit,
              child: state.status == OnboardingStatus.loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Continue'),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}

// ── Shared progress indicator widget ────────────────────────────────────────

class _OnboardingProgress extends StatelessWidget {
  final int step;
  final int total;

  const _OnboardingProgress({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step $step of $total',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: step / total,
          backgroundColor: Colors.grey.shade200,
          valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          borderRadius: BorderRadius.circular(4),
          minHeight: 6,
        ),
      ],
    );
  }
}
