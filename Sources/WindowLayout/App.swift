import AppKit
import ApplicationServices
import SwiftUI
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    let state = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        promptForAccessibility()
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error { NSLog("WindowLayout notification auth failed: \(error)") }
        }
        state.registerHotKeys()
    }

    // Show banners even though the menu bar app counts as frontmost.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async
        -> UNNotificationPresentationOptions { [.banner, .sound] }
}

func notify(_ body: String) {
    let content = UNMutableNotificationContent()
    content.title = "Mac Window Layout"
    content.body = body
    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
    UNUserNotificationCenter.current().add(request) { error in
        if let error { NSLog("WindowLayout notify failed: \(error)") }
    }
}

func promptForAccessibility() {
    let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
    _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
}

struct MenuContent: View {
    let state: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if state.data.presets.isEmpty {
            Text("No presets yet")
        }
        ForEach(state.data.presets) { preset in
            Button("Apply \(preset.name)" + (preset.applyHotKey.map { "  \($0.display)" } ?? "")) { state.apply(preset.id) }
        }
        Divider()
        Button("Save New Preset…") { state.saveNewPreset() }
        Divider()
        Button("Settings…") {
            openWindow(id: "settings")
            NSApp.activate(ignoringOtherApps: true)
        }
        Divider()
        // Menu content is rebuilt each time the menu opens, so this reflects the current state.
        Text(AXIsProcessTrusted() ? "Accessibility: granted" : "Accessibility: NOT granted")
        Button("Request Accessibility Access…") { promptForAccessibility() }
        Divider()
        Button("Quit") { NSApp.terminate(nil) }
    }
}

@main
struct WindowLayoutApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Mac Window Layout", systemImage: "rectangle.3.group") {
            MenuContent(state: appDelegate.state)
        }
        Window("Mac Window Layout Settings", id: "settings") {
            SettingsView(state: appDelegate.state)
        }
        .windowResizability(.contentSize)
    }
}
