class ApiConstants {
  static const String baseUrl = 'https://fliq-dev.up.railway.app';

  // Auth
  static const String sendOtp = '/auth/otp/send';
  static const String verifyOtp = '/auth/otp/verify';
  static const String refreshToken = '/auth/refresh';

  // Users
  static const String userProfile = '/users/me';

  // Providers
  static const String providerProfile = '/providers/profile';
  static String providerPublic(String id) => '/providers/$id/public';
  static const String searchProviders = '/providers/search';

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

  // Payment Links
  static const String createPaymentLink = '/payment-links';
  static const String myPaymentLinks = '/payment-links/my';
  static String deletePaymentLink(String id) => '/payment-links/$id';

  // Tip Pools
  static const String tipPools = '/tip-pools';
  static const String myTipPools = '/tip-pools/my';
  static String tipPoolDetail(String id) => '/tip-pools/$id';
  static String tipPoolMembers(String id) => '/tip-pools/$id/members';
  static String tipPoolRemoveMember(String id, String memberId) =>
      '/tip-pools/$id/members/$memberId';
  static String tipPoolEarnings(String id) => '/tip-pools/$id/earnings';

  // Gamification
  static const String badges = '/gamification/badges';
  static const String streak = '/gamification/streak';
  static const String leaderboardTippers = '/gamification/leaderboard';
  static const String leaderboardProviders = '/gamification/leaderboard/providers';

  // Push Notifications
  static const String registerFcmToken = '/notifications/fcm-token';
  static const String removeFcmToken = '/notifications/fcm-token';

  // Recurring Tips
  static const String recurringTips = '/recurring-tips';
  static const String myRecurringTips = '/recurring-tips';
  static const String providerRecurringTips = '/recurring-tips/provider';
  static String pauseRecurringTip(String id) => '/recurring-tips/$id/pause';
  static String resumeRecurringTip(String id) => '/recurring-tips/$id/resume';
  static String cancelRecurringTip(String id) => '/recurring-tips/$id';

  // Business (B2B)
  static const String registerBusiness = '/business/register';
  static const String myBusiness = '/business/mine';
  static const String myInvitations = '/business/invitations/mine';
  static String businessById(String id) => '/business/$id';
  static String inviteMember(String id) => '/business/$id/invite';
  static String removeMember(String id, String memberId) =>
      '/business/$id/members/$memberId';
  static String respondInvitation(String id) => '/business/invitations/$id/respond';
  static String businessDashboard(String id) => '/business/$id/dashboard';
  static String businessStaff(String id) => '/business/$id/staff';
  static String businessSatisfaction(String id) => '/business/$id/satisfaction';
  static String businessQrCodes(String id) => '/business/$id/qrcodes';
  static String businessExport(String id) => '/business/$id/export';
}
