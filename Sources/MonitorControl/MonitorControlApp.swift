import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Check onboarding status
        let hasCompleted = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        
        if !hasCompleted {
            openOnboardingWindow()
        }
    }
    
    func openOnboardingWindow() {
        // Create a SwiftUI window programmatically for Onboarding
        let onboardingView = OnboardingView()
        let hostingController = NSHostingController(rootView: onboardingView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 450),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered, defer: false
        )
        window.center()
        window.setFrameAutosaveName("OnboardingWindow")
        window.contentViewController = hostingController
        window.title = "Welcome"
        window.identifier = NSUserInterfaceItemIdentifier("onboarding")
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

@main
struct MonitorControlApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var monitorManager = MonitorManager()
    @StateObject private var presetManager = PresetManager()

    var body: some Scene {
        MenuBarExtra("Monitor Control", systemImage: "display") {
            ControlView(manager: monitorManager, presetManager: presetManager)
        }
        .menuBarExtraStyle(.window) // Allows for a richer view (popover)
    }
}
