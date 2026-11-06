import AppKit
import SwiftUI

@main struct MyApp: App {
    init() {
        NSWindow.allowsAutomaticWindowTabbing = true
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView()
                .tint(.orange)
        }
        .commands {
            BabybelCommands()
        }
    }
}
