import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../data/tips_repository.dart';

class ScanQrScreen extends ConsumerStatefulWidget {
  const ScanQrScreen({super.key});

  @override
  ConsumerState<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends ConsumerState<ScanQrScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    setState(() => _isProcessing = true);

    try {
      final qrData = barcode.rawValue!;
      // Extract QR code ID from the URL or use raw value
      final qrCodeId = _extractQrCodeId(qrData);

      final repo = ref.read(tipsRepositoryProvider);
      final providerInfo = await repo.resolveQrCode(qrCodeId);

      if (mounted) {
        context.push('/tip', extra: {
          'providerId': providerInfo['providerId'],
          'providerName': providerInfo['providerName'],
          'category': providerInfo['category'],
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid QR code: ${e.toString()}')),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  String _extractQrCodeId(String rawValue) {
    // If it's a URL like https://fliq.in/qr/UUID, extract the UUID
    final uri = Uri.tryParse(rawValue);
    if (uri != null && uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'qr') {
      return uri.pathSegments[1];
    }
    // Otherwise treat the raw value as the QR code ID
    return rawValue;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Scan overlay
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          // Bottom instruction
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Text(
              'Point camera at a Fliq QR code',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Colors.white,
              ),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
        ],
      ),
    );
  }
}
