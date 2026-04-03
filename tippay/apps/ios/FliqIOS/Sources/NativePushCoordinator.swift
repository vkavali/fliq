import FirebaseCore
import FirebaseMessaging
import Foundation
import UIKit
import UserNotifications

@MainActor
final class NativePushCoordinator: NSObject, ObservableObject {
    static let shared = NativePushCoordinator()

    private let client = PushNotificationsClient()
    private let sessionStore = AuthSessionStore()

    private override init() {
        super.init()
    }

    func configureIfPossible() {
        guard Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil else {
            return
        }
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
    }

    func syncTokenIfPossible(session: AuthSession) async {
        guard FirebaseApp.app() != nil else {
            return
        }

        let authorization = await requestAuthorizationIfNeeded()
        guard authorization else {
            return
        }

        UIApplication.shared.registerForRemoteNotifications()

        if let token = Messaging.messaging().fcmToken, !token.isEmpty {
            try? await client.registerToken(accessToken: session.accessToken, token: token)
            return
        }

        let token = await fetchFcmToken()
        if let token, !token.isEmpty {
            try? await client.registerToken(accessToken: session.accessToken, token: token)
        }
    }

    func removeTokenIfPossible(accessToken: String?) async {
        guard let accessToken, !accessToken.isEmpty else {
            return
        }

        try? await client.removeToken(accessToken: accessToken)
        guard FirebaseApp.app() != nil else {
            return
        }
        await deleteFcmToken()
    }

    func handleAPNsToken(_ token: Data) {
        guard FirebaseApp.app() != nil else {
            return
        }
        Messaging.messaging().apnsToken = token
    }

    func handleRegistrationToken(_ token: String?) {
        guard let token, !token.isEmpty, FirebaseApp.app() != nil else {
            return
        }

        Task {
            let session = sessionStore.load()
            guard let session else { return }
            try? await client.registerToken(accessToken: session.accessToken, token: token)
        }
    }

    private func requestAuthorizationIfNeeded() async -> Bool {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    continuation.resume(returning: true)
                case .denied:
                    continuation.resume(returning: false)
                case .notDetermined:
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                        continuation.resume(returning: granted)
                    }
                @unknown default:
                    continuation.resume(returning: false)
                }
            }
        }
    }

    private func fetchFcmToken() async -> String? {
        await withCheckedContinuation { continuation in
            Messaging.messaging().token { token, _ in
                continuation.resume(returning: token)
            }
        }
    }

    private func deleteFcmToken() async {
        await withCheckedContinuation { continuation in
            Messaging.messaging().deleteToken { _ in
                continuation.resume()
            }
        }
    }
}

extension NativePushCoordinator: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        Task { @MainActor in
            handleRegistrationToken(fcmToken)
        }
    }
}

extension NativePushCoordinator: UNUserNotificationCenterDelegate {}

final class FliqPushAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        NativePushCoordinator.shared.configureIfPossible()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in
            NativePushCoordinator.shared.handleAPNsToken(deviceToken)
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Device registration failures are expected until APNs entitlements are configured.
    }
}
