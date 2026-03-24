import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/tip_pools_repository.dart';
import 'tip_pools_screen.dart';

class CreatePoolScreen extends ConsumerStatefulWidget {
  const CreatePoolScreen({super.key});

  @override
  ConsumerState<CreatePoolScreen> createState() => _CreatePoolScreenState();
}

class _CreatePoolScreenState extends ConsumerState<CreatePoolScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _splitMethod = 'EQUAL';
  bool _isLoading = false;

  final List<_PendingMember> _pendingMembers = [];
  final _memberPhoneController = TextEditingController();
  final _memberRoleController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _memberPhoneController.dispose();
    _memberRoleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Tip Pool'),
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.horizontalLg,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.md),

              // Pool name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Pool Name',
                  hintText: 'e.g. Weekend Shift Pool',
                  prefixIcon: Icon(Icons.groups),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Please enter a pool name';
                  }
                  if (v.trim().length > 100) {
                    return 'Name must be 100 characters or less';
                  }
                  return null;
                },
              ),

              const SizedBox(height: AppSpacing.md),

              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'Describe what this pool is for',
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                maxLines: 2,
                maxLength: 500,
              ),

              const SizedBox(height: AppSpacing.lg),

              // Split method
              Text(
                'Split Method',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              _SplitMethodSelector(
                selected: _splitMethod,
                onChanged: (v) => setState(() => _splitMethod = v),
              ),

              const SizedBox(height: AppSpacing.lg),

              // Add members section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Add Members',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${_pendingMembers.length} added',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'You can also add members after creating the pool.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Member input row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _memberPhoneController,
                      decoration: const InputDecoration(
                        hintText: 'Phone number',
                        prefixIcon: Icon(Icons.phone, size: 20),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _memberRoleController,
                      decoration: const InputDecoration(
                        hintText: 'Role',
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _addPendingMember,
                    icon: const Icon(Icons.add_circle,
                        color: AppColors.primary, size: 32),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.sm),

              // Pending members list
              ..._pendingMembers.asMap().entries.map((entry) {
                final idx = entry.key;
                final m = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline,
                            size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${m.phone}${m.role != null ? ' \u2022 ${m.role}' : ''}',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              setState(() => _pendingMembers.removeAt(idx)),
                          icon: const Icon(Icons.close,
                              size: 18, color: AppColors.error),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: AppSpacing.xl),

              // Create button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isLoading ? null : _createPool,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Create Pool'),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  void _addPendingMember() {
    final phone = _memberPhoneController.text.trim();
    if (phone.isEmpty) return;

    setState(() {
      _pendingMembers.add(_PendingMember(
        phone: phone,
        role: _memberRoleController.text.trim().isNotEmpty
            ? _memberRoleController.text.trim()
            : null,
      ));
      _memberPhoneController.clear();
      _memberRoleController.clear();
    });
  }

  Future<void> _createPool() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(tipPoolsRepositoryProvider);

      // Create the pool
      final poolData = await repo.createPool(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        splitMethod: _splitMethod,
      );

      final poolId = poolData['id'] as String;

      // Add pending members (best-effort, don't fail on individual adds)
      for (final member in _pendingMembers) {
        try {
          await repo.addMember(
            poolId,
            phone: member.phone,
            role: member.role,
          );
        } catch (e) {
          // Log but continue
          debugPrint('Failed to add member ${member.phone}: $e');
        }
      }

      ref.invalidate(tipPoolsDataProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pool created successfully')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create pool: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class _PendingMember {
  final String phone;
  final String? role;

  _PendingMember({required this.phone, this.role});
}

class _SplitMethodSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _SplitMethodSelector({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const methods = [
      _SplitOption(
        value: 'EQUAL',
        label: 'Equal Split',
        description: 'Tips divided equally among all members',
        icon: Icons.balance,
      ),
      _SplitOption(
        value: 'PERCENTAGE',
        label: 'Percentage',
        description: 'Custom percentage for each member',
        icon: Icons.pie_chart,
      ),
      _SplitOption(
        value: 'ROLE_BASED',
        label: 'Role Based',
        description: 'Split based on predefined role weights',
        icon: Icons.badge,
      ),
    ];

    return Column(
      children: methods.map((m) {
        final isSelected = selected == m.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.08)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: () => onChanged(m.value),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      m.icon,
                      color:
                          isSelected ? AppColors.primary : AppColors.textSecondary,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.label,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            m.description,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle,
                          color: AppColors.primary, size: 22),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SplitOption {
  final String value;
  final String label;
  final String description;
  final IconData icon;

  const _SplitOption({
    required this.value,
    required this.label,
    required this.description,
    required this.icon,
  });
}
