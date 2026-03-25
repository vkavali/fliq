import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/tip_jars_repository.dart';

class AddMemberSheet extends ConsumerStatefulWidget {
  final String jarId;
  const AddMemberSheet({super.key, required this.jarId});

  @override
  ConsumerState<AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends ConsumerState<AddMemberSheet> {
  final _providerIdController = TextEditingController();
  final _roleLabelController = TextEditingController();
  double _splitPercentage = 0;
  bool _isLoading = false;

  @override
  void dispose() {
    _providerIdController.dispose();
    _roleLabelController.dispose();
    super.dispose();
  }

  Future<void> _addMember() async {
    if (_providerIdController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Provider ID is required')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await ref.read(tipJarsRepositoryProvider).addMember(
            jarId: widget.jarId,
            providerId: _providerIdController.text.trim(),
            splitPercentage: _splitPercentage,
            roleLabel: _roleLabelController.text.trim().isEmpty ? null : _roleLabelController.text.trim(),
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to add member: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Add Member', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _providerIdController,
            decoration: const InputDecoration(
              labelText: 'Provider ID (UUID)',
              hintText: 'Enter the provider\'s user ID',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _roleLabelController,
            decoration: const InputDecoration(
              labelText: 'Role (optional)',
              hintText: 'e.g. Bride, Groom, Host',
              prefixIcon: Icon(Icons.badge_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Text('Split: ${_splitPercentage.toStringAsFixed(0)}%',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          Slider(
            value: _splitPercentage,
            min: 0,
            max: 100,
            divisions: 100,
            label: '${_splitPercentage.toStringAsFixed(0)}%',
            onChanged: (v) => setState(() => _splitPercentage = v),
          ),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton(
            onPressed: _isLoading ? null : _addMember,
            child: _isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text('Add Member'),
          ),
        ],
      ),
    );
  }
}
