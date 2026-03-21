class ApiConstants {
  static const String baseUrl = 'http://10.0.2.2:3000'; // Android emulator -> host

  // Auth
  static const String sendOtp = '/auth/otp/send';
  static const String verifyOtp = '/auth/otp/verify';

  // Users
  static const String userProfile = '/users/me';

  // Providers
  static const String providerProfile = '/providers/profile';
  static String providerPublic(String id) => '/providers/$id/public';

  // Tips
  static const String createTip = '/tips';
  static const String createTipAuthenticated = '/tips/authenticated';
  static String verifyTipPayment(String tipId) => '/tips/$tipId/verify';
  static const String providerTips = '/tips/provider';
  static const String customerTips = '/tips/customer';

  // Payouts
  static const String requestPayout = '/payouts/request';
  static const String payoutHistory = '/payouts/history';

  // QR Codes
  static const String createQrCode = '/qrcodes';
  static const String myQrCodes = '/qrcodes/my';
  static String resolveQrCode(String id) => '/qrcodes/$id/resolve';
}
