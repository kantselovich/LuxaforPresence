import SwiftUI

@main
struct LuxaforPresenceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            // This is where preferences would go if it were a full SwiftUI app.
            // Since we are using AppKit for the preferences panel, we can leave this empty.
            EmptyView()
        }
    }
}
