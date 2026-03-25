import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/tip_jar_model.dart';
import '../../data/tip_jars_repository.dart';
import '../widgets/add_member_sheet.dart';

final _jarDetailProvider = FutureProvider.autoDispose.family<TipJarModel, String>((ref, jarId) async {
  return ref.read(tipJarsRepositoryProvider).getJarById(jarId);
});

final _jarStatsProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, jarId) async {
  return ref.read(tipJarsRepositoryProvider).getJarStats(jarId);
});

class TipJarDetailScreen extends ConsumerWidget {
  final String jarId;
  const TipJarDetailScreen({super.key, required this.jarId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jarAsync = ref.watch(_jarDetailProvider(jarId));
    final statsAsync = ref.watch(_jarStatsProvider(jarId));
    final currentUserId = ref.watch(currentUserProvider)?.id;

    return Scaffold(
      appBar: AppBar(
        title: jarAsync.maybeWhen(data: (jar) => Text(jar.name), orElse: () => const Text('Tip Jar')),
        actions: [
          jarAsync.maybeWhen(
            data: (jar) => jar.createdById == currentUserId
                ? PopupMenuButton<String>(
                    onSelected: (val) => _handleMenuAction(context, ref, jar, val),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'add_member', child: Text('Add Member')),
                      PopupMenuItem(value: 'close', child: Text('Close Jar')),
                    ],
                  )
                : const SizedBox.shrink(),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_jarDetailProvider(jarId));
          ref.invalidate(_jarStatsProvider(jarId));
        },
        child: jarAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
          data: (jar) => ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              // ── Progress card ───────────────────────────────────────
              _ProgressCard(jar: jar),

              const SizedBox(height: AppSpacing.md),

              // ── Share button ────────────────────────────────────────
              if (jar.shareableUrl != null)
                _ShareCard(url: jar.shareableUrl!),

              const SizedBox(height: AppSpacing.md),

              // ── Members & splits ────────────────────────────────────
              Text('Members & Splits',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: AppSpacing.sm),

              statsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (stats) {
                  final breakdown = stats['memberBreakdown'] as List<dynamic>? ?? [];
                  return Column(
                    children: breakdown
                        .map((b) => _MemberEarningsCard(data: b as Map<String, dynamic>))
                        .toList(),
                  );
                },
              ),

              const SizedBox(height: AppSpacing.md),

              // ── Recent contributions ─────────────────────────────────
              if ((jar.contributionCount) > 0) ...[
                Text('Recent Tips',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: AppSpacing.sm),
                _RecentContributions(jarId: jar.id),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _handleMenuAction(BuildContext context, WidgetRef ref, TipJarModel jar, String action) {
    switch (action) {
      case 'add_member':
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (_) => AddMemberSheet(jarId: jar.id),
        ).then((_) {
          ref.invalidate(_jarDetailProvider(jarId));
          ref.invalidate(_jarStatsProvider(jarId));
        });
      case 'close':
        _confirmClose(context, ref, jar);
    }
  }

  void _confirmClose(BuildContext context, WidgetRef ref, TipJarModel jar) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Close Tip Jar?'),
        content: Text('No more tips can be collected for "${jar.name}".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(tipJarsRepositoryProvider).closeJar(jar.id);
                if (context.mounted) context.pop();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Close Jar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final TipJarModel jar;
  const _ProgressCard({required this.jar});

  @override
  Widget build(BuildContext context) {
    final collected = jar.totalCollectedPaise / 100;
    final target = jar.targetAmountPaise != null ? jar.targetAmountPaise! / 100 : null;
    final progress = target != null && target > 0 ? (collected / target).clamp(0.0, 1.0) : null;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_eventIcon(jar.eventType), color: Colors.white.withValues(alpha: 0.8), size: 18),
              const SizedBox(width: 6),
              Text(jar.eventTypeLabel, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 4),
          Text(jar.name, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          if (jar.description != null) ...[
            const SizedBox(height: 4),
            Text(jar.description!, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text('₹${collected.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          Text('collected from ${jar.contributionCount} tip${jar.contributionCount != 1 ? "s" : ""}',
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          if (progress != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                color: Colors.white,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 4),
            Text('Goal: ₹${target!.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ],
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

class _ShareCard extends StatelessWidget {
  final String url;
  const _ShareCard({required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.share_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Share Tip Jar', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(child: Text(url, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: url));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied!')));
                  },
                  child: const Icon(Icons.copy, size: 18, color: AppColors.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.message, size: 18),
                  label: const Text('WhatsApp'),
                  onPressed: () => _shareWhatsApp(url),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('More'),
                  onPressed: () => _shareOther(url),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _shareWhatsApp(String url) {
    final waUrl = Uri.parse('https://wa.me/?text=${Uri.encodeComponent("Tip us here! $url")}');
    launchUrl(waUrl, mode: LaunchMode.externalApplication);
  }

  void _shareOther(String url) {
    // TODO: integrate share_plus if available
    Clipboard.setData(ClipboardData(text: url));
  }
}

class _MemberEarningsCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _MemberEarningsCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final name = data['providerName'] as String? ?? 'Unknown';
    final role = data['roleLabel'] as String?;
    final pct = (data['splitPercentage'] as num).toDouble();
    final earnedPaise = (data['earnedPaise'] as num?)?.toInt() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (role != null)
                  Text(role, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${pct.toStringAsFixed(1)}%', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
              Text('₹${(earnedPaise / 100).toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, color: AppColors.success)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentContributions extends ConsumerWidget {
  final String jarId;
  const _RecentContributions({required this.jarId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jarAsync = ref.watch(_jarDetailProvider(jarId));
    return jarAsync.maybeWhen(
      data: (jar) {
        final contribs = jar.contributionCount;
        return Text(
          '$contribs contribution${contribs != 1 ? "s" : ""} received',
          style: const TextStyle(color: AppColors.textSecondary),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
