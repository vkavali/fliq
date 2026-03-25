import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/tip_jar_model.dart';
import '../../data/tip_jars_repository.dart';

final _myJarsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  return ref.read(tipJarsRepositoryProvider).getMyJars();
});

class TipJarsScreen extends ConsumerWidget {
  const TipJarsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jarsAsync = ref.watch(_myJarsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tip Jars'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/tip-jars/create').then((_) => ref.invalidate(_myJarsProvider)),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(_myJarsProvider),
        child: jarsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
          data: (data) {
            final owned = (data['owned'] as List<dynamic>? ?? [])
                .map((j) => TipJarModel.fromJson(j as Map<String, dynamic>))
                .toList();
            final memberOf = (data['memberOf'] as List<dynamic>? ?? [])
                .map((j) => TipJarModel.fromJson(j as Map<String, dynamic>))
                .toList();

            if (owned.isEmpty && memberOf.isEmpty) {
              return _EmptyState(onCreateTap: () => context.push('/tip-jars/create').then((_) => ref.invalidate(_myJarsProvider)));
            }

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                if (owned.isNotEmpty) ...[
                  _SectionHeader(title: 'My Jars', count: owned.length),
                  ...owned.map((jar) => _JarCard(jar: jar, isOwner: true)),
                ],
                if (memberOf.isNotEmpty) ...[
                  _SectionHeader(title: "I'm a Member", count: memberOf.length),
                  ...memberOf.map((jar) => _JarCard(jar: jar, isOwner: false)),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
      child: Row(
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('$count', style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _JarCard extends StatelessWidget {
  final TipJarModel jar;
  final bool isOwner;
  const _JarCard({required this.jar, required this.isOwner});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/tip-jars/${jar.id}'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_eventIcon(jar.eventType), color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(jar.name, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        _EventTypeChip(label: jar.eventTypeLabel),
                        const SizedBox(width: 6),
                        Text(
                          '${jar.members.length} member${jar.members.length != 1 ? "s" : ""}',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '₹${(jar.totalCollectedPaise / 100).toStringAsFixed(0)} collected',
                      style: const TextStyle(fontSize: 13, color: AppColors.success, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  IconData _eventIcon(String eventType) => switch (eventType) {
        'WEDDING' => Icons.favorite,
        'RESTAURANT' => Icons.restaurant,
        'SALON' => Icons.content_cut,
        'EVENT' => Icons.celebration,
        _ => Icons.inventory_2_outlined,
      };
}

class _EventTypeChip extends StatelessWidget {
  final String label;
  const _EventTypeChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w500)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreateTap;
  const _EmptyState({required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 72, color: AppColors.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: AppSpacing.lg),
            Text('No Tip Jars Yet', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Create a shared tip jar for your event, restaurant, or salon.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            ElevatedButton.icon(
              onPressed: onCreateTap,
              icon: const Icon(Icons.add),
              label: const Text('Create Tip Jar'),
            ),
          ],
        ),
      ),
    );
  }
}
