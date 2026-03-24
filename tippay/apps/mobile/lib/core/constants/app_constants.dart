class AppConstants {
  static const String appName = 'Fliq';

  // Commission model (matching backend)
  static const int zeroCommissionThresholdPaise = 10000; // Rs 100
  static const double defaultCommissionRate = 0.05; // 5%
  static const double gstRate = 0.18; // 18%

  // Tip amounts (in paise)
  static const int minTipPaise = 1000; // Rs 10
  static const int maxTipPaise = 1000000; // Rs 10,000

  // Payout limits (in paise)
  static const int minPayoutPaise = 10000; // Rs 100

  // Preset tip amounts (in rupees)
  static const List<int> presetTipAmounts = [20, 50, 100, 200, 500];

  // Razorpay
  static const String razorpayKeyId = 'rzp_test_placeholder'; // Replaced at runtime from API

  // Provider categories
  static const List<String> providerCategories = [
    'DELIVERY',
    'SALON',
    'HOUSEHOLD',
    'RESTAURANT',
    'HOTEL',
    'OTHER',
  ];

  // Payout modes
  static const List<String> payoutModes = ['UPI', 'IMPS', 'NEFT'];

  // Supported languages
  static const List<String> supportedLanguages = ['en', 'hi', 'ta', 'te', 'kn', 'mr'];

  // Storage keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userDataKey = 'user_data';

  /// Calculate commission for a tip amount in paise.
  static int calculateCommissionPaise(int amountPaise) {
    if (amountPaise <= zeroCommissionThresholdPaise) return 0;
    return (amountPaise * defaultCommissionRate).round();
  }

  /// Calculate GST on commission in paise.
  static int calculateGstOnCommissionPaise(int commissionPaise) {
    return (commissionPaise * gstRate).round();
  }

  /// Calculate net amount after commission and GST.
  static int calculateNetAmountPaise(int amountPaise) {
    final commission = calculateCommissionPaise(amountPaise);
    final gst = calculateGstOnCommissionPaise(commission);
    return amountPaise - commission - gst;
  }
}
