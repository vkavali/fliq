import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/services/offline_queue_service.dart';
import '../../core/theme/app_theme.dart';

/// Shows a dismissible banner at the bottom of the screen when offline.
/// Also shows a badge when there are queued tips.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOfflineAsync = ref.watch(isOfflineProvider);
    final pendingCountAsync = ref.watch(pendingTipCountProvider);

    final isOffline = isOfflineAsync.valueOrNull ?? false;
    final pendingCount = pendingCountAsync.valueOrNull ?? 0;

    if (!isOffline && pendingCount == 0) return const SizedBox.shrink();

    return GestureDetector(
      onTap: pendingCount > 0 ? () => context.push('/pending-tips') : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: isOffline ? AppColors.warning : AppColors.primary,
        child: Row(
          children: [
            Icon(
              isOffline ? Icons.wifi_off : Icons.schedule,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isOffline
                    ? 'You\'re offline — tips will be queued'
                    : '$pendingCount pending tip${pendingCount != 1 ? "s" : ""} — tap to complete',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
            if (pendingCount > 0 && !isOffline)
              const Icon(Icons.chevron_right, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }
}
