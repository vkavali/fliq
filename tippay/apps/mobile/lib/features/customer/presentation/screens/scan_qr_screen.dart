import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/tips_repository.dart';

class ScanQrScreen extends ConsumerStatefulWidget {
  const ScanQrScreen({super.key});

  @override
  ConsumerState<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends ConsumerState<ScanQrScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;
  bool _torchOn = false;
  String? _errorMessage;

  // Resolved provider info (shown as card overlay)
  Map<String, dynamic>? _resolvedProvider;

  late AnimationController _animController;
  late Animation<double> _scanLineAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scanLineAnim =
        Tween<double>(begin: 0, end: 1).animate(_animController);
  }

  @override
  void dispose() {
    _animController.dispose();
    _controller.dispose();
    super.dispose();
  }

  // ---------- QR detection ----------

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final qrData = barcode.rawValue!;
      final qrCodeId = _extractQrCodeId(qrData);

      final repo = ref.read(tipsRepositoryProvider);
      final providerInfo = await repo.resolveQrCode(qrCodeId);

      if (mounted) {
        setState(() {
          _resolvedProvider = providerInfo;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not read this QR code. Please try again.';
          _isProcessing = false;
        });
      }
    }
  }

  String _extractQrCodeId(String rawValue) {
    final uri = Uri.tryParse(rawValue);
    if (uri != null &&
        uri.pathSegments.length >= 2 &&
        uri.pathSegments[0] == 'qr') {
      return uri.pathSegments[1];
    }
    return rawValue;
  }

  void _navigateToTip() {
    if (_resolvedProvider == null) return;
    context.push('/tip', extra: {
      'providerId': _resolvedProvider!['providerId'],
      'providerName': _resolvedProvider!['providerName'],
      'category': _resolvedProvider!['category'],
    });
  }

  void _retry() {
    setState(() {
      _isProcessing = false;
      _errorMessage = null;
      _resolvedProvider = null;
    });
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scanAreaSize = size.width * 0.7;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            onPressed: () {
              _controller.toggleTorch();
              setState(() => _torchOn = !_torchOn);
            },
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
            tooltip: 'Toggle flash',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // Dark overlay with transparent cut-out
          _ScanOverlay(
            scanAreaSize: scanAreaSize,
            scanLineAnim: _scanLineAnim,
          ),

          // Instruction text
          Positioned(
            bottom: _resolvedProvider != null ? 260 : 120,
            left: 0,
            right: 0,
            child: Text(
              "Point camera at provider's QR code",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),

          // Error message
          if (_errorMessage != null)
            Positioned(
              bottom: 100,
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.white, size: 32),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: _retry,
                      child: const Text('Try Again',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),

          // Loading overlay
          if (_isProcessing && _resolvedProvider == null && _errorMessage == null)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: AppSpacing.md),
                    Text('Reading QR code...',
                        style: TextStyle(color: Colors.white)),
                  ],
                ),
              ),
            ),

          // Provider card (after successful scan)
          if (_resolvedProvider != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _ProviderCard(
                providerName:
                    _resolvedProvider!['providerName'] as String? ?? 'Provider',
                category:
                    _resolvedProvider!['category'] as String? ?? 'OTHER',
                onTipNow: _navigateToTip,
                onCancel: _retry,
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Scan overlay with animated line
// ---------------------------------------------------------------------------

class _ScanOverlay extends StatelessWidget {
  final double scanAreaSize;
  final Animation<double> scanLineAnim;

  const _ScanOverlay(
      {required this.scanAreaSize, required this.scanLineAnim});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: scanLineAnim,
      builder: (context, child) {
        return CustomPaint(
          size: MediaQuery.of(context).size,
          painter: _OverlayPainter(
            scanAreaSize: scanAreaSize,
            lineProgress: scanLineAnim.value,
          ),
        );
      },
    );
  }
}

/// Thin wrapper around [AnimatedWidget] to use a builder callback.
class AnimatedBuilder extends AnimatedWidget {
  final Widget Function(BuildContext context, Widget? child) builder;

  const AnimatedBuilder({
    super.key,
    required Animation<double> animation,
    required this.builder,
  }) : super(listenable: animation);

  @override
  Widget build(BuildContext context) => builder(context, null);
}

class _OverlayPainter extends CustomPainter {
  final double scanAreaSize;
  final double lineProgress;

  _OverlayPainter({required this.scanAreaSize, required this.lineProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 - 40);
    final rect = Rect.fromCenter(
        center: center, width: scanAreaSize, height: scanAreaSize);

    // Dark overlay
    final overlayPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.55);
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16))),
      ),
      overlayPaint,
    );

    // Corner brackets
    const cornerLength = 30.0;
    const cornerWidth = 4.0;
    final cornerPaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = cornerWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final topLeft = rect.topLeft;
    final topRight = rect.topRight;
    final bottomLeft = rect.bottomLeft;
    final bottomRight = rect.bottomRight;

    // Top-left
    canvas.drawLine(topLeft, topLeft + const Offset(cornerLength, 0), cornerPaint);
    canvas.drawLine(topLeft, topLeft + const Offset(0, cornerLength), cornerPaint);
    // Top-right
    canvas.drawLine(topRight, topRight + const Offset(-cornerLength, 0), cornerPaint);
    canvas.drawLine(topRight, topRight + const Offset(0, cornerLength), cornerPaint);
    // Bottom-left
    canvas.drawLine(bottomLeft, bottomLeft + const Offset(cornerLength, 0), cornerPaint);
    canvas.drawLine(bottomLeft, bottomLeft + const Offset(0, -cornerLength), cornerPaint);
    // Bottom-right
    canvas.drawLine(bottomRight, bottomRight + const Offset(-cornerLength, 0), cornerPaint);
    canvas.drawLine(bottomRight, bottomRight + const Offset(0, -cornerLength), cornerPaint);

    // Animated scan line
    final lineY = rect.top + (scanAreaSize * lineProgress);
    final linePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppColors.primary.withValues(alpha: 0),
          AppColors.primary.withValues(alpha: 0.8),
          AppColors.primary.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromLTWH(rect.left, lineY, scanAreaSize, 2));
    canvas.drawLine(
      Offset(rect.left + 10, lineY),
      Offset(rect.right - 10, lineY),
      linePaint..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => old.lineProgress != lineProgress;
}

// ---------------------------------------------------------------------------
// Provider card (after scan)
// ---------------------------------------------------------------------------

class _ProviderCard extends StatelessWidget {
  final String providerName;
  final String category;
  final VoidCallback onTipNow;
  final VoidCallback onCancel;

  const _ProviderCard({
    required this.providerName,
    required this.category,
    required this.onTipNow,
    required this.onCancel,
  });

  IconData get _categoryIcon => switch (category.toUpperCase()) {
        'DELIVERY' => Icons.delivery_dining,
        'SALON' => Icons.content_cut,
        'RESTAURANT' => Icons.restaurant,
        'HOTEL' => Icons.hotel,
        'HOUSEHOLD' => Icons.home_repair_service,
        _ => Icons.person,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: AppSpacing.lg,
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.lg,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Provider info
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Icon(_categoryIcon, color: AppColors.primary, size: 28),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(providerName,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        category,
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.verified, color: AppColors.success),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          // Buttons
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTipNow,
              child: const Text('Tip Now'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onCancel,
              child:
                  const Text('Scan Again', style: TextStyle(color: Colors.grey)),
            ),
          ),
        ],
      ),
    );
  }
}
