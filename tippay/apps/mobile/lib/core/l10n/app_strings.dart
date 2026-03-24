/// Simple map-based localization for Fliq.
/// Supported locales: en, hi, ta, te, kn, mr.
class AppStrings {
  AppStrings._();

  static const supportedLocales = ['en', 'hi', 'ta', 'te', 'kn', 'mr'];

  static const Map<String, String> localeNames = {
    'en': 'English',
    'hi': 'हिंदी',
    'ta': 'தமிழ்',
    'te': 'తెలుగు',
    'kn': 'ಕನ್ನಡ',
    'mr': 'मराठी',
  };

  static const Map<String, Map<String, String>> _strings = {
    'en': _en,
    'hi': _hi,
    'ta': _ta,
    'te': _te,
    'kn': _kn,
    'mr': _mr,
  };

  /// Returns the localized string for [key] in [locale].
  /// Falls back to English, then to the raw key.
  static String get(String key, String locale) {
    return _strings[locale]?[key] ?? _strings['en']![key] ?? key;
  }

  // ---------------------------------------------------------------------------
  // English
  // ---------------------------------------------------------------------------
  static const Map<String, String> _en = {
    // Auth
    'login_title': 'Welcome to Fliq',
    'login_subtitle': 'Enter your phone number to get started',
    'enter_phone': 'Phone Number',
    'send_otp': 'Send OTP',
    'verify_otp': 'Verify OTP',
    'enter_otp': 'Enter the 6-digit code sent to',
    'resend_otp': 'Resend OTP',

    // Customer
    'scan_to_tip': 'Scan to Tip',
    'scan_instruction': "Point camera at provider's QR code",
    'tip_amount': 'Tip Amount',
    'custom_amount': 'Custom',
    'commission_free': 'No fee',
    'commission_rate': '5% fee',
    'add_rating': 'Rate the service',
    'add_message': 'Add a message (optional)',
    'pay_button': 'Pay',
    'payment_success': 'Payment Successful!',
    'sent_to': 'sent to',
    'share_fliq': 'Share Fliq',
    'back_to_home': 'Back to Home',
    'view_history': 'View History',
    'tips_given': 'Tips Given',
    'total_amount': 'Total',
    'recent_tips': 'Recent Tips',
    'browse_categories': 'Browse Categories',
    'no_tips_yet': 'No tips yet',
    'search_providers': 'Search providers',
    'search_by_name': 'Search by name or phone',

    // Provider
    'dashboard': 'Dashboard',
    'my_qr_code': 'My QR Code',
    'earnings': 'Earnings',
    'payouts': 'Payouts',
    'settings': 'Settings',
    'wallet_balance': 'Wallet Balance',
    'today_earnings': 'Today',
    'week_earnings': 'This Week',
    'month_earnings': 'This Month',
    'total_earnings': 'Total Earnings',
    'commission_paid': 'Commission Paid',
    'net_earnings': 'Net Earnings',
    'request_payout': 'Request Payout',
    'payout_amount': 'Payout Amount',
    'payout_mode': 'Payout Mode',
    'generate_qr': 'Generate QR Code',
    'share_via_whatsapp': 'Share via WhatsApp',
    'recent_activity': 'Recent Activity',
    'no_earnings': 'No earnings yet',
    'no_payouts': 'No payouts yet',

    // Categories
    'category_delivery': 'Delivery',
    'category_salon': 'Salon',
    'category_restaurant': 'Restaurant',
    'category_hotel': 'Hotel',
    'category_household': 'Household',
    'category_other': 'Other',

    // Settings
    'profile': 'Profile',
    'language': 'Language',
    'payout_preference': 'Payout Preference',
    'upi_address': 'UPI Address',
    'logout': 'Logout',
    'save': 'Save',
    'name': 'Name',
    'email': 'Email',
    'phone': 'Phone',

    // General
    'loading': 'Loading...',
    'error': 'Something went wrong',
    'retry': 'Retry',
    'cancel': 'Cancel',
    'confirm': 'Confirm',
    'success': 'Success',
  };

  // ---------------------------------------------------------------------------
  // Hindi (हिंदी)
  // ---------------------------------------------------------------------------
  static const Map<String, String> _hi = {
    // Auth
    'login_title': 'Fliq में आपका स्वागत है',
    'login_subtitle': 'शुरू करने के लिए अपना फ़ोन नंबर डालें',
    'enter_phone': 'फ़ोन नंबर',
    'send_otp': 'OTP भेजें',
    'verify_otp': 'OTP सत्यापित करें',
    'enter_otp': '6 अंकों का कोड डालें, भेजा गया',
    'resend_otp': 'OTP दोबारा भेजें',

    // Customer
    'scan_to_tip': 'टिप देने के लिए स्कैन करें',
    'scan_instruction': 'कैमरा प्रोवाइडर के QR कोड पर रखें',
    'tip_amount': 'टिप राशि',
    'custom_amount': 'अन्य राशि',
    'commission_free': 'कोई शुल्क नहीं',
    'commission_rate': '5% शुल्क',
    'add_rating': 'सेवा को रेटिंग दें',
    'add_message': 'संदेश लिखें (वैकल्पिक)',
    'pay_button': 'भुगतान करें',
    'payment_success': 'भुगतान सफल!',
    'sent_to': 'को भेजा गया',
    'share_fliq': 'Fliq शेयर करें',
    'back_to_home': 'होम पर वापस जाएँ',
    'view_history': 'इतिहास देखें',
    'tips_given': 'दी गई टिप्स',
    'total_amount': 'कुल',
    'recent_tips': 'हाल की टिप्स',
    'browse_categories': 'कैटेगरी देखें',
    'no_tips_yet': 'अभी तक कोई टिप नहीं',
    'search_providers': 'प्रोवाइडर खोजें',
    'search_by_name': 'नाम या फ़ोन से खोजें',

    // Provider
    'dashboard': 'डैशबोर्ड',
    'my_qr_code': 'मेरा QR कोड',
    'earnings': 'कमाई',
    'payouts': 'भुगतान',
    'settings': 'सेटिंग्स',
    'wallet_balance': 'वॉलेट बैलेंस',
    'today_earnings': 'आज',
    'week_earnings': 'इस हफ़्ते',
    'month_earnings': 'इस महीने',
    'total_earnings': 'कुल कमाई',
    'commission_paid': 'कमीशन दिया',
    'net_earnings': 'शुद्ध कमाई',
    'request_payout': 'पेआउट का अनुरोध करें',
    'payout_amount': 'पेआउट राशि',
    'payout_mode': 'पेआउट का तरीका',
    'generate_qr': 'QR कोड बनाएँ',
    'share_via_whatsapp': 'WhatsApp से शेयर करें',
    'recent_activity': 'हाल की गतिविधि',
    'no_earnings': 'अभी तक कोई कमाई नहीं',
    'no_payouts': 'अभी तक कोई पेआउट नहीं',

    // Categories
    'category_delivery': 'डिलीवरी',
    'category_salon': 'सैलून',
    'category_restaurant': 'रेस्टोरेंट',
    'category_hotel': 'होटल',
    'category_household': 'घरेलू सेवा',
    'category_other': 'अन्य',

    // Settings
    'profile': 'प्रोफ़ाइल',
    'language': 'भाषा',
    'payout_preference': 'पेआउट प्राथमिकता',
    'upi_address': 'UPI पता',
    'logout': 'लॉगआउट',
    'save': 'सेव करें',
    'name': 'नाम',
    'email': 'ईमेल',
    'phone': 'फ़ोन',

    // General
    'loading': 'लोड हो रहा है...',
    'error': 'कुछ गड़बड़ हो गई',
    'retry': 'फिर से कोशिश करें',
    'cancel': 'रद्द करें',
    'confirm': 'पुष्टि करें',
    'success': 'सफल',
  };

  // ---------------------------------------------------------------------------
  // Tamil (தமிழ்)
  // ---------------------------------------------------------------------------
  static const Map<String, String> _ta = {
    // Auth
    'login_title': 'Fliq-க்கு வரவேற்கிறோம்',
    'login_subtitle': 'தொடங்க உங்கள் போன் நம்பரை உள்ளிடுங்கள்',
    'enter_phone': 'போன் நம்பர்',
    'send_otp': 'OTP அனுப்பு',
    'verify_otp': 'OTP சரிபார்',
    'enter_otp': '6 இலக்க குறியீட்டை உள்ளிடுங்கள், அனுப்பப்பட்டது',
    'resend_otp': 'OTP மீண்டும் அனுப்பு',

    // Customer
    'scan_to_tip': 'டிப் கொடுக்க ஸ்கேன் செய்யுங்கள்',
    'scan_instruction': 'கேமராவை QR கோடு மீது காட்டுங்கள்',
    'tip_amount': 'டிப் தொகை',
    'custom_amount': 'வேறு தொகை',
    'commission_free': 'கட்டணம் இல்லை',
    'commission_rate': '5% கட்டணம்',
    'add_rating': 'சேவைக்கு மதிப்பீடு கொடுங்கள்',
    'add_message': 'செய்தி எழுதுங்கள் (விரும்பினால்)',
    'pay_button': 'பணம் செலுத்து',
    'payment_success': 'பணம் செலுத்தப்பட்டது!',
    'sent_to': 'அனுப்பப்பட்டது',
    'share_fliq': 'Fliq பகிரவும்',
    'back_to_home': 'முகப்புக்குச் செல்',
    'view_history': 'வரலாறு பார்',
    'tips_given': 'கொடுத்த டிப்ஸ்',
    'total_amount': 'மொத்தம்',
    'recent_tips': 'சமீபத்திய டிப்ஸ்',
    'browse_categories': 'வகைகளை பார்க்கவும்',
    'no_tips_yet': 'இதுவரை டிப்ஸ் இல்லை',
    'search_providers': 'வழங்குநரைத் தேடு',
    'search_by_name': 'பெயர் அல்லது போன் மூலம் தேடு',

    // Provider
    'dashboard': 'டாஷ்போர்டு',
    'my_qr_code': 'என் QR கோடு',
    'earnings': 'வருமானம்',
    'payouts': 'பணம் பெறுதல்',
    'settings': 'அமைப்புகள்',
    'wallet_balance': 'வாலட் இருப்பு',
    'today_earnings': 'இன்று',
    'week_earnings': 'இந்த வாரம்',
    'month_earnings': 'இந்த மாதம்',
    'total_earnings': 'மொத்த வருமானம்',
    'commission_paid': 'கமிஷன் செலுத்தியது',
    'net_earnings': 'நிகர வருமானம்',
    'request_payout': 'பேஅவுட் கோரிக்கை',
    'payout_amount': 'பேஅவுட் தொகை',
    'payout_mode': 'பேஅவுட் முறை',
    'generate_qr': 'QR கோடு உருவாக்கு',
    'share_via_whatsapp': 'WhatsApp-ல் பகிரு',
    'recent_activity': 'சமீபத்திய செயல்பாடு',
    'no_earnings': 'இதுவரை வருமானம் இல்லை',
    'no_payouts': 'இதுவரை பேஅவுட் இல்லை',

    // Categories
    'category_delivery': 'டெலிவரி',
    'category_salon': 'சலூன்',
    'category_restaurant': 'உணவகம்',
    'category_hotel': 'ஹோட்டல்',
    'category_household': 'வீட்டு வேலை',
    'category_other': 'மற்றவை',

    // Settings
    'profile': 'சுயவிவரம்',
    'language': 'மொழி',
    'payout_preference': 'பேஅவுட் விருப்பம்',
    'upi_address': 'UPI முகவரி',
    'logout': 'வெளியேறு',
    'save': 'சேமி',
    'name': 'பெயர்',
    'email': 'மின்னஞ்சல்',
    'phone': 'போன்',

    // General
    'loading': 'ஏற்றுகிறது...',
    'error': 'ஏதோ தவறு நடந்தது',
    'retry': 'மீண்டும் முயற்சி',
    'cancel': 'ரத்து',
    'confirm': 'உறுதிசெய்',
    'success': 'வெற்றி',
  };

  // ---------------------------------------------------------------------------
  // Telugu (తెలుగు)
  // ---------------------------------------------------------------------------
  static const Map<String, String> _te = {
    // Auth
    'login_title': 'Fliqకి స్వాగతం',
    'login_subtitle': 'ప్రారంభించడానికి మీ ఫోన్ నంబర్ నమోదు చేయండి',
    'enter_phone': 'ఫోన్ నంబర్',
    'send_otp': 'OTP పంపండి',
    'verify_otp': 'OTP ధృవీకరించండి',
    'enter_otp': '6 అంకెల కోడ్ నమోదు చేయండి, పంపబడింది',
    'resend_otp': 'OTP మళ్ళీ పంపండి',

    // Customer
    'scan_to_tip': 'టిప్ ఇవ్వడానికి స్కాన్ చేయండి',
    'scan_instruction': 'కెమెరాను QR కోడ్ మీద చూపించండి',
    'tip_amount': 'టిప్ మొత్తం',
    'custom_amount': 'ఇతర మొత్తం',
    'commission_free': 'ఫీజు లేదు',
    'commission_rate': '5% ఫీజు',
    'add_rating': 'సేవకు రేటింగ్ ఇవ్వండి',
    'add_message': 'సందేశం రాయండి (ఐచ్ఛికం)',
    'pay_button': 'చెల్లించండి',
    'payment_success': 'చెల్లింపు విజయవంతం!',
    'sent_to': 'కు పంపబడింది',
    'share_fliq': 'Fliq షేర్ చేయండి',
    'back_to_home': 'హోమ్‌కు వెళ్ళండి',
    'view_history': 'చరిత్ర చూడండి',
    'tips_given': 'ఇచ్చిన టిప్స్',
    'total_amount': 'మొత్తం',
    'recent_tips': 'ఇటీవలి టిప్స్',
    'browse_categories': 'కేటగిరీలు చూడండి',
    'no_tips_yet': 'ఇంకా టిప్స్ లేవు',
    'search_providers': 'ప్రొవైడర్‌ను వెతకండి',
    'search_by_name': 'పేరు లేదా ఫోన్ ద్వారా వెతకండి',

    // Provider
    'dashboard': 'డాష్‌బోర్డ్',
    'my_qr_code': 'నా QR కోడ్',
    'earnings': 'సంపాదన',
    'payouts': 'చెల్లింపులు',
    'settings': 'సెట్టింగ్స్',
    'wallet_balance': 'వాలెట్ బ్యాలెన్స్',
    'today_earnings': 'ఈ రోజు',
    'week_earnings': 'ఈ వారం',
    'month_earnings': 'ఈ నెల',
    'total_earnings': 'మొత్తం సంపాదన',
    'commission_paid': 'కమీషన్ చెల్లించింది',
    'net_earnings': 'నికర సంపాదన',
    'request_payout': 'పేఅవుట్ అభ్యర్థించండి',
    'payout_amount': 'పేఅవుట్ మొత్తం',
    'payout_mode': 'పేఅవుట్ విధానం',
    'generate_qr': 'QR కోడ్ తయారు చేయండి',
    'share_via_whatsapp': 'WhatsAppలో షేర్ చేయండి',
    'recent_activity': 'ఇటీవలి కార్యకలాపం',
    'no_earnings': 'ఇంకా సంపాదన లేదు',
    'no_payouts': 'ఇంకా పేఅవుట్‌లు లేవు',

    // Categories
    'category_delivery': 'డెలివరీ',
    'category_salon': 'సెలూన్',
    'category_restaurant': 'రెస్టారెంట్',
    'category_hotel': 'హోటల్',
    'category_household': 'గృహ సేవ',
    'category_other': 'ఇతరాలు',

    // Settings
    'profile': 'ప్రొఫైల్',
    'language': 'భాష',
    'payout_preference': 'పేఅవుట్ ప్రాధాన్యత',
    'upi_address': 'UPI చిరునామా',
    'logout': 'లాగ్అవుట్',
    'save': 'సేవ్ చేయండి',
    'name': 'పేరు',
    'email': 'ఈమెయిల్',
    'phone': 'ఫోన్',

    // General
    'loading': 'లోడ్ అవుతోంది...',
    'error': 'ఏదో తప్పు జరిగింది',
    'retry': 'మళ్ళీ ప్రయత్నించండి',
    'cancel': 'రద్దు చేయండి',
    'confirm': 'నిర్ధారించండి',
    'success': 'విజయం',
  };

  // ---------------------------------------------------------------------------
  // Kannada (ಕನ್ನಡ)
  // ---------------------------------------------------------------------------
  static const Map<String, String> _kn = {
    // Auth
    'login_title': 'Fliqಗೆ ಸ್ವಾಗತ',
    'login_subtitle': 'ಪ್ರಾರಂಭಿಸಲು ನಿಮ್ಮ ಫೋನ್ ನಂಬರ್ ನಮೂದಿಸಿ',
    'enter_phone': 'ಫೋನ್ ನಂಬರ್',
    'send_otp': 'OTP ಕಳುಹಿಸಿ',
    'verify_otp': 'OTP ಪರಿಶೀಲಿಸಿ',
    'enter_otp': '6 ಅಂಕಿ ಕೋಡ್ ನಮೂದಿಸಿ, ಕಳುಹಿಸಲಾಗಿದೆ',
    'resend_otp': 'OTP ಮತ್ತೆ ಕಳುಹಿಸಿ',

    // Customer
    'scan_to_tip': 'ಟಿಪ್ ಕೊಡಲು ಸ್ಕ್ಯಾನ್ ಮಾಡಿ',
    'scan_instruction': 'ಕ್ಯಾಮೆರಾವನ್ನು QR ಕೋಡ್ ಮೇಲೆ ತೋರಿಸಿ',
    'tip_amount': 'ಟಿಪ್ ಮೊತ್ತ',
    'custom_amount': 'ಬೇರೆ ಮೊತ್ತ',
    'commission_free': 'ಶುಲ್ಕ ಇಲ್ಲ',
    'commission_rate': '5% ಶುಲ್ಕ',
    'add_rating': 'ಸೇವೆಗೆ ರೇಟಿಂಗ್ ಕೊಡಿ',
    'add_message': 'ಸಂದೇಶ ಬರೆಯಿರಿ (ಐಚ್ಛಿಕ)',
    'pay_button': 'ಪಾವತಿಸಿ',
    'payment_success': 'ಪಾವತಿ ಯಶಸ್ವಿ!',
    'sent_to': 'ಗೆ ಕಳುಹಿಸಲಾಗಿದೆ',
    'share_fliq': 'Fliq ಹಂಚಿಕೊಳ್ಳಿ',
    'back_to_home': 'ಹೋಮ್‌ಗೆ ಹಿಂತಿರುಗಿ',
    'view_history': 'ಇತಿಹಾಸ ನೋಡಿ',
    'tips_given': 'ಕೊಟ್ಟ ಟಿಪ್ಸ್',
    'total_amount': 'ಒಟ್ಟು',
    'recent_tips': 'ಇತ್ತೀಚಿನ ಟಿಪ್ಸ್',
    'browse_categories': 'ವರ್ಗಗಳನ್ನು ನೋಡಿ',
    'no_tips_yet': 'ಇನ್ನೂ ಟಿಪ್ಸ್ ಇಲ್ಲ',
    'search_providers': 'ಪ್ರೊವೈಡರ್ ಹುಡುಕಿ',
    'search_by_name': 'ಹೆಸರು ಅಥವಾ ಫೋನ್ ಮೂಲಕ ಹುಡುಕಿ',

    // Provider
    'dashboard': 'ಡ್ಯಾಶ್‌ಬೋರ್ಡ್',
    'my_qr_code': 'ನನ್ನ QR ಕೋಡ್',
    'earnings': 'ಗಳಿಕೆ',
    'payouts': 'ಪಾವತಿಗಳು',
    'settings': 'ಸೆಟ್ಟಿಂಗ್ಸ್',
    'wallet_balance': 'ವಾಲೆಟ್ ಬ್ಯಾಲೆನ್ಸ್',
    'today_earnings': 'ಇಂದು',
    'week_earnings': 'ಈ ವಾರ',
    'month_earnings': 'ಈ ತಿಂಗಳು',
    'total_earnings': 'ಒಟ್ಟು ಗಳಿಕೆ',
    'commission_paid': 'ಕಮಿಷನ್ ಪಾವತಿಸಿದ್ದು',
    'net_earnings': 'ನಿವ್ವಳ ಗಳಿಕೆ',
    'request_payout': 'ಪೇಔಟ್ ವಿನಂತಿ',
    'payout_amount': 'ಪೇಔಟ್ ಮೊತ್ತ',
    'payout_mode': 'ಪೇಔಟ್ ವಿಧಾನ',
    'generate_qr': 'QR ಕೋಡ್ ರಚಿಸಿ',
    'share_via_whatsapp': 'WhatsAppನಲ್ಲಿ ಹಂಚಿಕೊಳ್ಳಿ',
    'recent_activity': 'ಇತ್ತೀಚಿನ ಚಟುವಟಿಕೆ',
    'no_earnings': 'ಇನ್ನೂ ಗಳಿಕೆ ಇಲ್ಲ',
    'no_payouts': 'ಇನ್ನೂ ಪೇಔಟ್‌ಗಳಿಲ್ಲ',

    // Categories
    'category_delivery': 'ಡೆಲಿವರಿ',
    'category_salon': 'ಸಲೂನ್',
    'category_restaurant': 'ರೆಸ್ಟೋರೆಂಟ್',
    'category_hotel': 'ಹೋಟೆಲ್',
    'category_household': 'ಮನೆ ಕೆಲಸ',
    'category_other': 'ಇತರೆ',

    // Settings
    'profile': 'ಪ್ರೊಫೈಲ್',
    'language': 'ಭಾಷೆ',
    'payout_preference': 'ಪೇಔಟ್ ಆದ್ಯತೆ',
    'upi_address': 'UPI ವಿಳಾಸ',
    'logout': 'ಲಾಗ್ಔಟ್',
    'save': 'ಉಳಿಸಿ',
    'name': 'ಹೆಸರು',
    'email': 'ಇಮೇಲ್',
    'phone': 'ಫೋನ್',

    // General
    'loading': 'ಲೋಡ್ ಆಗುತ್ತಿದೆ...',
    'error': 'ಏನೋ ತಪ್ಪಾಗಿದೆ',
    'retry': 'ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ',
    'cancel': 'ರದ್ದು',
    'confirm': 'ಖಚಿತಪಡಿಸಿ',
    'success': 'ಯಶಸ್ಸು',
  };

  // ---------------------------------------------------------------------------
  // Marathi (मराठी)
  // ---------------------------------------------------------------------------
  static const Map<String, String> _mr = {
    // Auth
    'login_title': 'Fliq मध्ये आपले स्वागत आहे',
    'login_subtitle': 'सुरू करण्यासाठी तुमचा फोन नंबर टाका',
    'enter_phone': 'फोन नंबर',
    'send_otp': 'OTP पाठवा',
    'verify_otp': 'OTP तपासा',
    'enter_otp': '6 अंकी कोड टाका, पाठवलेला',
    'resend_otp': 'OTP पुन्हा पाठवा',

    // Customer
    'scan_to_tip': 'टिप देण्यासाठी स्कॅन करा',
    'scan_instruction': 'कॅमेरा QR कोडवर दाखवा',
    'tip_amount': 'टिप रक्कम',
    'custom_amount': 'इतर रक्कम',
    'commission_free': 'शुल्क नाही',
    'commission_rate': '5% शुल्क',
    'add_rating': 'सेवेला रेटिंग द्या',
    'add_message': 'संदेश लिहा (ऐच्छिक)',
    'pay_button': 'पैसे भरा',
    'payment_success': 'पेमेंट यशस्वी!',
    'sent_to': 'ला पाठवले',
    'share_fliq': 'Fliq शेअर करा',
    'back_to_home': 'होमवर परत जा',
    'view_history': 'इतिहास पहा',
    'tips_given': 'दिलेल्या टिप्स',
    'total_amount': 'एकूण',
    'recent_tips': 'अलीकडील टिप्स',
    'browse_categories': 'कॅटेगरी पहा',
    'no_tips_yet': 'अजून टिप्स नाहीत',
    'search_providers': 'प्रोव्हायडर शोधा',
    'search_by_name': 'नाव किंवा फोनने शोधा',

    // Provider
    'dashboard': 'डॅशबोर्ड',
    'my_qr_code': 'माझा QR कोड',
    'earnings': 'कमाई',
    'payouts': 'पेमेंट',
    'settings': 'सेटिंग्ज',
    'wallet_balance': 'वॉलेट शिल्लक',
    'today_earnings': 'आज',
    'week_earnings': 'या आठवड्यात',
    'month_earnings': 'या महिन्यात',
    'total_earnings': 'एकूण कमाई',
    'commission_paid': 'कमिशन दिले',
    'net_earnings': 'निव्वळ कमाई',
    'request_payout': 'पेआउट विनंती करा',
    'payout_amount': 'पेआउट रक्कम',
    'payout_mode': 'पेआउट पद्धत',
    'generate_qr': 'QR कोड तयार करा',
    'share_via_whatsapp': 'WhatsApp वर शेअर करा',
    'recent_activity': 'अलीकडील क्रियाकलाप',
    'no_earnings': 'अजून कमाई नाही',
    'no_payouts': 'अजून पेआउट नाहीत',

    // Categories
    'category_delivery': 'डिलिव्हरी',
    'category_salon': 'सलून',
    'category_restaurant': 'रेस्टॉरंट',
    'category_hotel': 'हॉटेल',
    'category_household': 'घरगुती सेवा',
    'category_other': 'इतर',

    // Settings
    'profile': 'प्रोफाइल',
    'language': 'भाषा',
    'payout_preference': 'पेआउट प्राधान्य',
    'upi_address': 'UPI पत्ता',
    'logout': 'लॉगआउट',
    'save': 'सेव्ह करा',
    'name': 'नाव',
    'email': 'ईमेल',
    'phone': 'फोन',

    // General
    'loading': 'लोड होत आहे...',
    'error': 'काहीतरी चूक झाली',
    'retry': 'पुन्हा प्रयत्न करा',
    'cancel': 'रद्द करा',
    'confirm': 'खात्री करा',
    'success': 'यशस्वी',
  };
}
