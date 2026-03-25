import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/onboarding_repository.dart';

enum OnboardingStep { registration, bankDetails, kycStatus, qrGeneration, success }

enum OnboardingStatus { idle, loading, success, error }

class OnboardingState {
  final OnboardingStep step;
  final OnboardingStatus status;
  final String? error;

  // Data collected across steps
  final String displayName;
  final String category;
  final String bio;
  final String upiVpa;
  final String bankAccountNumber;
  final String ifscCode;
  final String pan;
  final String kycStatus;
  final String? qrImageUrl;

  const OnboardingState({
    this.step = OnboardingStep.registration,
    this.status = OnboardingStatus.idle,
    this.error,
    this.displayName = '',
    this.category = '',
    this.bio = '',
    this.upiVpa = '',
    this.bankAccountNumber = '',
    this.ifscCode = '',
    this.pan = '',
    this.kycStatus = 'PENDING',
    this.qrImageUrl,
  });

  OnboardingState copyWith({
    OnboardingStep? step,
    OnboardingStatus? status,
    String? error,
    String? displayName,
    String? category,
    String? bio,
    String? upiVpa,
    String? bankAccountNumber,
    String? ifscCode,
    String? pan,
    String? kycStatus,
    String? qrImageUrl,
  }) {
    return OnboardingState(
      step: step ?? this.step,
      status: status ?? this.status,
      error: error,
      displayName: displayName ?? this.displayName,
      category: category ?? this.category,
      bio: bio ?? this.bio,
      upiVpa: upiVpa ?? this.upiVpa,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      ifscCode: ifscCode ?? this.ifscCode,
      pan: pan ?? this.pan,
      kycStatus: kycStatus ?? this.kycStatus,
      qrImageUrl: qrImageUrl ?? this.qrImageUrl,
    );
  }
}

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  final OnboardingRepository _repo;

  OnboardingNotifier(this._repo) : super(const OnboardingState());

  /// Step 1: create provider profile.
  Future<void> submitRegistration({
    required String displayName,
    required String category,
    String? bio,
  }) async {
    state = state.copyWith(status: OnboardingStatus.loading);
    try {
      await _repo.createProfile(
        displayName: displayName,
        category: category,
        bio: bio,
      );
      state = state.copyWith(
        status: OnboardingStatus.success,
        step: OnboardingStep.bankDetails,
        displayName: displayName,
        category: category,
        bio: bio ?? '',
      );
    } catch (e) {
      state = state.copyWith(
        status: OnboardingStatus.error,
        error: _friendlyError(e),
      );
    }
  }

  /// Step 2: save bank details.
  Future<void> submitBankDetails({
    required String upiVpa,
    required String bankAccountNumber,
    required String ifscCode,
    required String pan,
  }) async {
    state = state.copyWith(status: OnboardingStatus.loading);
    try {
      await _repo.saveBankDetails(
        upiVpa: upiVpa,
        bankAccountNumber: bankAccountNumber,
        ifscCode: ifscCode,
        pan: pan,
      );

      // Fetch current KYC status
      final profile = await _repo.getProfile();
      final kycStatus = (profile['user'] as Map<String, dynamic>?)?['kycStatus'] as String? ?? 'PENDING';

      state = state.copyWith(
        status: OnboardingStatus.success,
        step: OnboardingStep.kycStatus,
        upiVpa: upiVpa,
        bankAccountNumber: bankAccountNumber,
        ifscCode: ifscCode,
        pan: pan,
        kycStatus: kycStatus,
      );
    } catch (e) {
      state = state.copyWith(
        status: OnboardingStatus.error,
        error: _friendlyError(e),
      );
    }
  }

  /// Step 3: proceed past KYC screen.
  void proceedFromKyc() {
    state = state.copyWith(
      step: OnboardingStep.qrGeneration,
      status: OnboardingStatus.idle,
    );
  }

  /// Step 4: generate QR code.
  Future<void> generateQrCode({String? locationLabel}) async {
    state = state.copyWith(status: OnboardingStatus.loading);
    try {
      final result = await _repo.generateQrCode(locationLabel: locationLabel);
      final qrImageUrl = result['qrImageUrl'] as String?;
      state = state.copyWith(
        status: OnboardingStatus.success,
        step: OnboardingStep.success,
        qrImageUrl: qrImageUrl,
      );
    } catch (e) {
      state = state.copyWith(
        status: OnboardingStatus.error,
        error: _friendlyError(e),
      );
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('Provider profile already exists')) {
      return 'You already have a provider profile.';
    }
    if (msg.contains('Invalid UPI VPA')) return 'Invalid UPI ID format.';
    if (msg.contains('Invalid IFSC')) return 'Invalid IFSC code.';
    if (msg.contains('Invalid PAN')) return 'Invalid PAN number.';
    if (msg.contains('SocketException') || msg.contains('DioException')) {
      return 'Network error. Please check your connection.';
    }
    return 'Something went wrong. Please try again.';
  }
}

final onboardingProvider =
    StateNotifierProvider.autoDispose<OnboardingNotifier, OnboardingState>((ref) {
  return OnboardingNotifier(ref.read(onboardingRepositoryProvider));
});
