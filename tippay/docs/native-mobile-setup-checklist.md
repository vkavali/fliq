# Native Mobile Setup Checklist

This checklist covers the remaining external setup required after the native Android and iOS code changes already in this repo.

## Push Notifications

### Android

1. Create or reuse the Firebase Android app for the package ID in `apps/android/app/build.gradle.kts`.
2. Download `google-services.json`.
3. Place it at `apps/android/app/google-services.json`.
4. Confirm the Firebase project has Cloud Messaging enabled.
5. Build and install the Android app on a physical device.
6. Sign in, grant notification permission, and confirm the backend receives a token via `POST /notifications/fcm-token`.

### iOS

1. Create or reuse the Firebase iOS app for the bundle ID in `apps/ios/project.yml`.
2. Download `GoogleService-Info.plist`.
3. Place it in `apps/ios/FliqIOS/Resources/GoogleService-Info.plist`.
4. Add Push Notifications and Background Modes capabilities to the Xcode target.
5. Enable `Remote notifications` under Background Modes.
6. Configure an Apple Team, provisioning profile, and APNs key/certificate for the bundle ID.
7. Build and install the iOS app on a physical device.
8. Sign in, allow notifications, and confirm the backend receives a token via `POST /notifications/fcm-token`.

### Backend

1. Set `FIREBASE_SERVICE_ACCOUNT_BASE64` for the backend environment.
2. Redeploy the backend with that value present.
3. Verify push send paths can resolve stored tokens from the `push-notifications` module.

## Real-Device QA

### Android

1. OTP sign-in for customer, provider, and business.
2. QR scan with a real camera.
3. Payment link resolution.
4. Razorpay checkout success and failure states.
5. Offline pending tip creation and retry.
6. Provider avatar upload.
7. Business CSV export/share flow.
8. Notification permission prompt and token registration.

### iOS

1. OTP sign-in for customer, provider, and business.
2. QR scan with a real camera.
3. Payment link resolution.
4. Razorpay checkout success and failure states.
5. Offline pending tip creation and retry.
6. Provider avatar upload.
7. Business CSV export/share flow.
8. Notification permission prompt, APNs registration, and FCM token registration.

## Remaining Product Decisions

1. Decide whether WhatsApp-specific business management stays web-first or gets native UI.
2. Decide whether current provider and business reporting cards are sufficient or need deeper backend analytics endpoints.
3. Keep Flutter in the repo only as a reference until native iOS and Android pass parity QA.
