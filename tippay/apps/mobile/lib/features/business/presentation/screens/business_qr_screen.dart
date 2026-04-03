import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/business_repository.dart';

class BusinessQrScreen extends ConsumerStatefulWidget {
  final String businessId;
  const BusinessQrScreen({super.key, required this.businessId});

  @override
  ConsumerState<BusinessQrScreen> createState() => _BusinessQrScreenState();
}

class _BusinessQrScreenState extends ConsumerState<BusinessQrScreen> {
  List<dynamic> _staffQr = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadQrCodes();
  }

  Future<void> _loadQrCodes() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final repo = ref.read(businessRepositoryProvider);
      final data = await repo.getBulkQrCodes(widget.businessId);
      if (mounted) setState(() { _staffQr = data; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  void _shareQrUrl(String url, String name) {
    Share.share(
      'Tip $name on Fliq: $url',
      subject: 'Tip $name on Fliq',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff QR Codes'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadQrCodes,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : RefreshIndicator(
                  onRefresh: _loadQrCodes,
                  child: _staffQr.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.qr_code_2, size: 64, color: AppColors.primary),
                              const SizedBox(height: 16),
                              Text('No QR Codes', style: theme.textTheme.titleMedium),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Text(
                                  'Staff members need to generate QR codes from their provider dashboard first.',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16.0),
                          itemCount: _staffQr.length,
                          itemBuilder: (context, i) {
                            final member = _staffQr[i] as Map<String, dynamic>;
                            final name = member['displayName'] as String? ?? 'Staff';
                            final qrCodes = (member['qrCodes'] as List?) ?? [];

                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor:
                                              AppColors.primary.withOpacity(0.1),
                                          child: Text(
                                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                                            style: const TextStyle(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: theme.textTheme.titleSmall?.copyWith(
                                                fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        Text(
                                          '${qrCodes.length} QR code${qrCodes.length != 1 ? 's' : ''}',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                    if (qrCodes.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        height: 120,
                                        child: ListView.separated(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: qrCodes.length,
                                          separatorBuilder: (_, __) =>
                                              const SizedBox(width: 10),
                                          itemBuilder: (ctx, j) {
                                            final qr = qrCodes[j] as Map<String, dynamic>;
                                            final imageUrl = qr['qrImageUrl'] as String?;
                                            final label = qr['locationLabel'] as String?;
                                            final upiUrl = qr['upiUrl'] as String?;

                                            return Column(
                                              children: [
                                                Container(
                                                  width: 80,
                                                  height: 80,
                                                  decoration: BoxDecoration(
                                                    border: Border.all(
                                                        color: AppColors.primary
                                                            .withOpacity(0.3)),
                                                    borderRadius:
                                                        BorderRadius.circular(8),
                                                  ),
                                                  child: imageUrl != null
                                                      ? ClipRRect(
                                                          borderRadius:
                                                              BorderRadius.circular(7),
                                                          child: Image.network(
                                                            imageUrl,
                                                            fit: BoxFit.contain,
                                                            errorBuilder: (_, __, ___) =>
                                                                const Icon(Icons.qr_code),
                                                          ),
                                                        )
                                                      : const Icon(Icons.qr_code,
                                                          color: AppColors.primary),
                                                ),
                                                if (label != null) ...[
                                                  const SizedBox(height: 4),
                                                  SizedBox(
                                                    width: 80,
                                                    child: Text(
                                                      label,
                                                      style: const TextStyle(fontSize: 10),
                                                      textAlign: TextAlign.center,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                                if (upiUrl != null) ...[
                                                  const SizedBox(height: 2),
                                                  GestureDetector(
                                                    onTap: () =>
                                                        _shareQrUrl(upiUrl, name),
                                                    child: const Icon(
                                                      Icons.share,
                                                      size: 14,
                                                      color: AppColors.primary,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                    ] else ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'No QR codes generated yet',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(color: Colors.grey),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
