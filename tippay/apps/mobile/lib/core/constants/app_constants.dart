class AppConstants {
  static const String appName = 'Fliq';

  // Tip amounts (in paise)
  static const int minTipPaise = 1000;     // Rs 10
  static const int maxTipPaise = 1000000;  // Rs 10,000

  // Preset tip amounts (in rupees)
  static const List<int> presetTipAmounts = [20, 50, 100, 200, 500];

  // Razorpay
  static const String razorpayKeyId = 'rzp_test_placeholder'; // Replaced at runtime from API

  // Storage keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userDataKey = 'user_data';
}
