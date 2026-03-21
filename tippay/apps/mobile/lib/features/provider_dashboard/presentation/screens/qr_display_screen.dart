import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/provider_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final myQrCodesProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final repo = ref.read(providerRepositoryProvider);
  return repo.getMyQrCodes();
});

class QrDisplayScreen extends ConsumerWidget {
  const QrDisplayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qrAsync = ref.watch(myQrCodesProvider);
    final user = ref.watch(authProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My QR Code'),
        actions: [
          IconButton(
            onPressed: () async {
              try {
                final repo = ref.read(providerRepositoryProvider);
                await repo.createQrCode(locationLabel: 'Default');
                ref.invalidate(myQrCodesProvider);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed: $e')),
                  );
                }
              }
            },
            icon: const Icon(Icons.add),
            tooltip: 'Generate New QR',
          ),
        ],
      ),
      body: qrAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (qrCodes) {
          if (qrCodes.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.qr_code, size: 64, color: Colors.grey),
                  const SizedBox(height: AppSpacing.md),
                  const Text('No QR codes yet'),
                  const SizedBox(height: AppSpacing.md),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final repo = ref.read(providerRepositoryProvider);
                      await repo.createQrCode(locationLabel: 'Default');
                      ref.invalidate(myQrCodesProvider);
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Generate QR Code'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: AppSpacing.paddingMd,
            itemCount: qrCodes.length,
            itemBuilder: (context, index) {
              final qr = qrCodes[index] as Map<String, dynamic>;
              final qrId = qr['id'] as String? ?? '';
              final label = qr['locationLabel'] as String? ?? 'Default';
              // Generate local QR with deep link URL
              final qrUrl = 'https://fliq.in/qr/$qrId';

              return Card(
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Padding(
                  padding: AppSpacing.paddingLg,
                  child: Column(
                    children: [
                      Text(
                        user?.name ?? 'Provider',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(label, style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: AppSpacing.md),
                      QrImageView(
                        data: qrUrl,
                        version: QrVersions.auto,
                        size: 220,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Scan to tip',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
