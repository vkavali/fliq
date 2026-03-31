import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/voice_tip_parser.dart';
import '../../data/tips_repository.dart';

class TipAmountScreen extends ConsumerStatefulWidget {
  final String providerId;
  final String providerName;
  final String category;

  const TipAmountScreen({
    super.key,
    required this.providerId,
    required this.providerName,
    required this.category,
  });

  @override
  ConsumerState<TipAmountScreen> createState() => _TipAmountScreenState();
}

class _TipAmountScreenState extends ConsumerState<TipAmountScreen>
    with TickerProviderStateMixin {
  int _selectedAmountRupees = 50;
  final _customController = TextEditingController();
  bool _isCustom = false;
  bool _isLoading = false;
  final _messageController = TextEditingController();
  int _rating = 0;
  Razorpay? _razorpay;
  String? _currentTipId;
  String? _providerUpiVpa;
  bool _loadingVpa = true;

  // ── Voice input state ────────────────────────────────────────────────────
  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  String _voiceStatus = '';
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _razorpay = Razorpay();
      _razorpay!.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      _razorpay!.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    }
    _fetchProviderVpa();
    _initSpeech();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize(
      onError: _onSpeechError,
      onStatus: _onSpeechStatus,
    );
    if (mounted) setState(() => _speechAvailable = available);
  }

  Future<void> _fetchProviderVpa() async {
    try {
      final repo = ref.read(tipsRepositoryProvider);
      final data = await repo.getProviderPublic(widget.providerId);
      if (mounted) {
        setState(() {
          _providerUpiVpa = data['upiVpa'] as String?;
          _loadingVpa = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingVpa = false);
    }
  }

  @override
  void dispose() {
    _razorpay?.clear();
    _customController.dispose();
    _messageController.dispose();
    _speech.stop();
    _pulseController.dispose();
    super.dispose();
  }

  // ── Voice input ──────────────────────────────────────────────────────────

  Future<void> _toggleListening() async {
    if (!_speechAvailable) {
      _showSnack('Speech recognition is not available on this device.');
      return;
    }

    if (_isListening) {
      await _speech.stop();
      _pulseController.stop();
      _pulseController.reset();
      setState(() {
        _isListening = false;
        _voiceStatus = '';
      });
      return;
    }

    setState(() {
      _isListening = true;
      _voiceStatus = 'Listening…';
    });
    _pulseController.repeat(reverse: true);

    await _speech.listen(
      onResult: _onSpeechResult,
      localeId: 'en_IN',
      listenFor: const Duration(seconds: 8),
      pauseFor: const Duration(seconds: 3),
      partialResults: false,
      listenMode: ListenMode.confirmation,
    );
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    if (!result.finalResult) return;

    final transcript = result.recognizedWords;
    final amount = VoiceTipParser.parse(transcript);

    _pulseController.stop();
    _pulseController.reset();
    setState(() => _isListening = false);

    if (amount != null) {
      setState(() {
        _isCustom = true;
        _customController.text = amount.toString();
        _voiceStatus = 'Got ₹$amount';
      });
      // Dismiss keyboard so the amount display is visible
      FocusScope.of(context).unfocus();
    } else {
      setState(() => _voiceStatus = 'Could not parse amount. Please try again.');
    }
  }

  void _onSpeechError(SpeechRecognitionError error) {
    _pulseController.stop();
    _pulseController.reset();
    setState(() {
      _isListening = false;
      _voiceStatus = 'Mic error — use the keypad instead.';
    });
  }

  void _onSpeechStatus(String status) {
    if (status == 'done' || status == 'notListening') {
      if (_isListening) {
        _pulseController.stop();
        _pulseController.reset();
        setState(() => _isListening = false);
      }
    }
  }

  // ── Amount helpers ───────────────────────────────────────────────────────

  int get _amountPaise {
    if (_isCustom) {
      final rupees = int.tryParse(_customController.text) ?? 0;
      return rupees * 100;
    }
    return _selectedAmountRupees * 100;
  }

  int get _amountRupees => (_amountPaise / 100).round();

  double get _commissionPercent => _amountRupees > 100 ? 5.0 : 0.0;
  int get _feePaise => (_amountPaise * _commissionPercent / 100).round();
  int get _feeRupees => (_feePaise / 100).round();

  // ── Payment flow ─────────────────────────────────────────────────────────

  Future<void> _startPayment() async {
    if (_amountPaise < AppConstants.minTipPaise ||
        _amountPaise > AppConstants.maxTipPaise) {
      _showSnack('Amount must be between \u20B910 and \u20B910,000');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(tipsRepositoryProvider);
      final result = await repo.createTip(
        providerId: widget.providerId,
        amountPaise: _amountPaise,
        source: 'QR_CODE',
        message:
            _messageController.text.isEmpty ? null : _messageController.text,
        rating: _rating > 0 ? _rating : null,
      );

      _currentTipId = result.tipId;

      final options = {
        'key': result.razorpayKeyId,
        'amount': result.amount,
        'currency': result.currency,
        'order_id': result.orderId,
        'name': 'Fliq',
        'description': 'Tip for ${widget.providerName}',
        'prefill': {
          'contact': '',
          'email': '',
        },
        'theme': {'color': '#6C63FF'},
      };

      if (kIsWeb) {
        _showSnack('Payments are not available on web. Please use the mobile app.');
        return;
      }
      _razorpay!.open(options);
    } catch (e) {
      _showSnack('Failed to create tip: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    try {
      final repo = ref.read(tipsRepositoryProvider);
      await repo.verifyPayment(
        tipId: _currentTipId!,
        razorpayOrderId: response.orderId!,
        razorpayPaymentId: response.paymentId!,
        razorpaySignature: response.signature!,
      );

      if (mounted) {
        context.go('/payment-success', extra: {
          'amount': _amountPaise,
          'providerName': widget.providerName,
          'rating': _rating,
          'message': _messageController.text,
          'fee': _feePaise,
        });
      }
    } catch (e) {
      if (mounted) _showSnack('Verification failed: $e');
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _showSnack('Payment failed: ${response.message ?? "Unknown error"}');
  }

  // ---------- Tip Later flow ----------

  void _tipLater() {
    if (_amountPaise < AppConstants.minTipPaise ||
        _amountPaise > AppConstants.maxTipPaise) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Amount must be between \u20B91 and \u20B91,00,000')),
      );
      return;
    }

    context.push('/tip-later/confirm', extra: {
      'providerId': widget.providerId,
      'providerName': widget.providerName,
      'amountPaise': _amountPaise,
      'message': _messageController.text.isEmpty ? null : _messageController.text,
      'rating': _rating > 0 ? _rating : null,
    });
  }

  // ── UPI intent flow ──────────────────────────────────────────────────────

  Future<void> _launchUpiApp(String appPackage) async {
    if (_amountPaise < AppConstants.minTipPaise ||
        _amountPaise > AppConstants.maxTipPaise) {
      _showSnack('Amount must be between \u20B910 and \u20B910,000');
      return;
    }

    if (_providerUpiVpa == null || _providerUpiVpa!.isEmpty) {
      _startPayment();
      return;
    }

    final amountStr = (_amountPaise / 100).toStringAsFixed(2);
    final upiUrl = Uri.parse(
      'upi://pay?pa=${Uri.encodeComponent(_providerUpiVpa!)}'
      '&pn=${Uri.encodeComponent(widget.providerName)}'
      '&am=$amountStr'
      '&cu=INR'
      '&tn=${Uri.encodeComponent('Tip via Fliq')}',
    );

    try {
      final launched = await launchUrl(upiUrl, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        _showSnack('Could not open UPI app. Using Razorpay instead.');
        _startPayment();
      }
    } catch (_) {
      if (mounted) {
        _showSnack('UPI app not available. Using Razorpay instead.');
        _startPayment();
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final rupeeDisplay = _amountRupees;

    return Scaffold(
      appBar: AppBar(title: const Text('Send Tip')),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppSpacing.md),

                  // ── Provider info card ─────────────────────────────────
                  _ProviderInfoCard(
                    name: widget.providerName,
                    category: widget.category,
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // ── Amount display ─────────────────────────────────────
                  Center(
                    child: Text(
                      '\u20B9$rupeeDisplay',
                      style: Theme.of(context)
                          .textTheme
                          .displaySmall
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // ── Preset chips + mic button row ──────────────────────
                  Center(
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        ...AppConstants.presetTipAmounts.map(
                          (amount) => _AmountChip(
                            label: '\u20B9$amount',
                            isSelected:
                                !_isCustom && _selectedAmountRupees == amount,
                            onTap: () => setState(() {
                              _isCustom = false;
                              _selectedAmountRupees = amount;
                              _voiceStatus = '';
                            }),
                          ),
                        ),
                        _AmountChip(
                          label: 'Custom',
                          isSelected: _isCustom,
                          onTap: () => setState(() {
                            _isCustom = true;
                            _voiceStatus = '';
                          }),
                        ),
                        // Mic button as a chip-sized widget
                        if (_speechAvailable)
                          _MicChip(
                            isListening: _isListening,
                            pulseAnimation: _pulseAnimation,
                            onTap: _toggleListening,
                          ),
                      ],
                    ),
                  ),

                  // ── Voice status feedback ──────────────────────────────
                  if (_voiceStatus.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    _VoiceStatusBanner(
                      status: _voiceStatus,
                      isListening: _isListening,
                    ),
                  ],

                  // ── Custom amount input ────────────────────────────────
                  if (_isCustom) ...[
                    const SizedBox(height: AppSpacing.md),
                    TextFormField(
                      controller: _customController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        prefixText: '\u20B9 ',
                        hintText: 'Enter amount',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.lg),

                  // ── Commission breakdown ───────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: _commissionPercent > 0
                          ? AppColors.warning.withValues(alpha: 0.08)
                          : AppColors.success.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _commissionPercent > 0
                              ? Icons.info_outline
                              : Icons.check_circle_outline,
                          size: 18,
                          color: _commissionPercent > 0
                              ? AppColors.warning
                              : AppColors.success,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _commissionPercent > 0
                              ? 'Fee: \u20B9$_feeRupees (${_commissionPercent.toStringAsFixed(0)}%)'
                              : 'Fee: \u20B90 (0%)',
                          style: TextStyle(
                            color: _commissionPercent > 0
                                ? AppColors.warning
                                : AppColors.success,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // ── Star rating ────────────────────────────────────────
                  Text('Rate your experience',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          )),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final isSelected = i < _rating;
                      return GestureDetector(
                        onTap: () => setState(() => _rating = i + 1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            isSelected
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: isSelected
                                ? Colors.amber
                                : Colors.grey.shade400,
                            size: 40,
                          ),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  // ── Message ────────────────────────────────────────────
                  TextFormField(
                    controller: _messageController,
                    maxLength: 500,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'Add a message (optional)',
                      counterText: '',
                      prefixIcon: Icon(Icons.message_outlined, size: 20),
                    ),
                  ),

                  // ── UPI quick-pay icons ────────────────────────────────
                  if (!_loadingVpa &&
                      _providerUpiVpa != null &&
                      _providerUpiVpa!.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text('Pay directly with UPI',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            )),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _UpiAppButton(
                          label: 'GPay',
                          icon: Icons.g_mobiledata,
                          color: const Color(0xFF4285F4),
                          onTap: () => _launchUpiApp(
                              'com.google.android.apps.nbu.paisa.user'),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        _UpiAppButton(
                          label: 'PhonePe',
                          icon: Icons.phone_android,
                          color: const Color(0xFF5F259F),
                          onTap: () => _launchUpiApp('com.phonepe.app'),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        _UpiAppButton(
                          label: 'Paytm',
                          icon: Icons.account_balance_wallet,
                          color: const Color(0xFF00BAF2),
                          onTap: () => _launchUpiApp('net.one97.paytm'),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        _UpiAppButton(
                          label: 'Other',
                          icon: Icons.open_in_new,
                          color: AppColors.textSecondary,
                          onTap: () => _launchUpiApp(''),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            ),
          ),

          // ── Pay / Tip Later buttons (sticky bottom) ────────────────
          Container(
            padding: EdgeInsets.only(
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              top: AppSpacing.md,
              bottom: MediaQuery.of(context).padding.bottom + AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pay Now button
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryDark],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _startPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.5, color: Colors.white),
                            )
                          : Text(
                              'Pay \u20B9$rupeeDisplay',
                              style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                    ),
                  ),
                ),
                // Tip Later button — only for logged-in customers
                if (ref.watch(authServiceProvider).isLoggedIn) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _tipLater,
                      icon: const Icon(Icons.schedule, size: 18),
                      label: Text(
                        'Tip Later — Promise \u20B9$rupeeDisplay',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: AppColors.primary),
                        foregroundColor: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Mic chip — pulsing microphone button matching the preset amount chips
// ---------------------------------------------------------------------------

class _MicChip extends StatelessWidget {
  final bool isListening;
  final Animation<double> pulseAnimation;
  final VoidCallback onTap;

  const _MicChip({
    required this.isListening,
    required this.pulseAnimation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: pulseAnimation,
        builder: (context, child) {
          final scale = isListening ? pulseAnimation.value : 1.0;
          return Transform.scale(
            scale: scale,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: isListening
                    ? Colors.red.shade50
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isListening ? Colors.red : AppColors.divider,
                  width: isListening ? 2 : 1,
                ),
                boxShadow: isListening
                    ? [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.25),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isListening ? Icons.mic : Icons.mic_none,
                    size: 18,
                    color: isListening ? Colors.red : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isListening ? 'Stop' : 'Voice',
                    style: TextStyle(
                      color: isListening
                          ? Colors.red
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Voice status banner shown below the chips while listening / after result
// ---------------------------------------------------------------------------

class _VoiceStatusBanner extends StatelessWidget {
  final String status;
  final bool isListening;

  const _VoiceStatusBanner({required this.status, required this.isListening});

  @override
  Widget build(BuildContext context) {
    final isSuccess = status.startsWith('Got');
    final color = isListening
        ? Colors.red
        : isSuccess
            ? AppColors.success
            : AppColors.textSecondary;

    return Center(
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isListening)
              _WaveformIcon(color: color)
            else
              Icon(
                isSuccess ? Icons.check_circle_outline : Icons.info_outline,
                size: 16,
                color: color,
              ),
            const SizedBox(width: 6),
            Text(
              status,
              style: TextStyle(
                  color: color, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple three-bar waveform animation drawn with CustomPaint.
class _WaveformIcon extends StatefulWidget {
  final Color color;
  const _WaveformIcon({required this.color});

  @override
  State<_WaveformIcon> createState() => _WaveformIconState();
}

class _WaveformIconState extends State<_WaveformIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => CustomPaint(
        size: const Size(18, 18),
        painter: _WaveformPainter(progress: _ctrl.value, color: widget.color),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final double progress;
  final Color color;

  _WaveformPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    const bars = 3;
    final spacing = size.width / (bars * 2 - 1);
    for (int i = 0; i < bars; i++) {
      // Each bar oscillates with a phase offset
      final phase = (i / bars) * math.pi;
      final heightFactor = 0.4 + 0.6 * math.sin(progress * math.pi + phase).abs();
      final barHeight = size.height * heightFactor;
      final x = spacing * i * 2 + spacing / 2;
      final top = (size.height - barHeight) / 2;
      canvas.drawLine(
        Offset(x, top),
        Offset(x, top + barHeight),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress || old.color != color;
}

// ---------------------------------------------------------------------------
// Provider Info Card
// ---------------------------------------------------------------------------

class _ProviderInfoCard extends StatelessWidget {
  final String name;
  final String category;

  const _ProviderInfoCard({required this.name, required this.category});

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
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Icon(_categoryIcon, color: AppColors.primary, size: 26),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
          const Icon(Icons.verified, color: AppColors.success, size: 22),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pill-shaped amount chip with animated selection
// ---------------------------------------------------------------------------

class _AmountChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _AmountChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// UPI App Button
// ---------------------------------------------------------------------------

class _UpiAppButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _UpiAppButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
