import SwiftUI

@main
struct FliqIOSApp: App {
    @UIApplicationDelegateAdaptor(FliqPushAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
    }
}
