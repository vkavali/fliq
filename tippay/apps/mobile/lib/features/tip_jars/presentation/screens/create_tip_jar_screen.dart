import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/tip_jars_repository.dart';

const _eventTypes = [
  ('WEDDING', 'Wedding', Icons.favorite),
  ('RESTAURANT', 'Restaurant', Icons.restaurant),
  ('SALON', 'Salon', Icons.content_cut),
  ('EVENT', 'Event', Icons.celebration),
  ('CUSTOM', 'Custom', Icons.inventory_2_outlined),
];

class CreateTipJarScreen extends ConsumerStatefulWidget {
  const CreateTipJarScreen({super.key});

  @override
  ConsumerState<CreateTipJarScreen> createState() => _CreateTipJarScreenState();
}

class _CreateTipJarScreenState extends ConsumerState<CreateTipJarScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedEventType = 'CUSTOM';
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createJar() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    try {
      final jar = await ref.read(tipJarsRepositoryProvider).createJar(
            name: _nameController.text.trim(),
            eventType: _selectedEventType,
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
          );

      if (mounted) {
        context.pushReplacement('/tip-jars/${jar.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create jar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Tip Jar')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            // ── Event type selector ─────────────────────────────────
            Text('Event Type', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _eventTypes.map(((type, label, icon)) {
                final selected = _selectedEventType == type;
                return GestureDetector(
                  onTap: () => setState(() => _selectedEventType = type),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: selected ? AppColors.primary : AppColors.divider),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 16, color: selected ? Colors.white : AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text(label, style: TextStyle(color: selected ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w500, fontSize: 13)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: AppSpacing.lg),

            // ── Jar name ─────────────────────────────────────────────
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Jar Name',
                hintText: "e.g. Rohan & Priya's Wedding",
                prefixIcon: Icon(Icons.label_outline),
              ),
              maxLength: 100,
              validator: (v) => (v?.trim().isEmpty ?? true) ? 'Name is required' : null,
            ),

            const SizedBox(height: AppSpacing.md),

            // ── Description ──────────────────────────────────────────
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'Add details about the event or team...',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
              maxLines: 3,
              maxLength: 500,
            ),

            const SizedBox(height: AppSpacing.sm),

            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'You\'ll be added as the first member (100%). Add more members and adjust splits after creating.',
                      style: TextStyle(fontSize: 13, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _createJar,
              child: _isLoading
                  ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Text('Create Tip Jar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ),
    );
  }
}
