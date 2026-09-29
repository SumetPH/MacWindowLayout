import AppKit
import Carbon
import SwiftUI
import WindowLayoutCore

/// "Record" button that captures the next key combo locally, validates it with `hotKeyConflict` and stores it via AppState.
struct ShortcutRecorder: View {
    let state: AppState
    let preset: UUID
    let combo: HotKeyCombo?

    @State private var monitor: Any?
    @State private var error: String?

    private static let modifierMap: [(flag: NSEvent.ModifierFlags, carbon: Int, symbol: String)] = [
        (.control, controlKey, "⌃"), (.option, optionKey, "⌥"), (.shift, shiftKey, "⇧"), (.command, cmdKey, "⌘"),
    ]

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack {
                Text(monitor != nil ? "Press shortcut… (Esc cancels)" : combo?.display ?? "None")
                    .monospaced()
                Button(monitor != nil ? "Cancel" : "Record") { monitor != nil ? stop() : start() }
            }
            if let error {
                Text(error).foregroundStyle(.red).font(.caption)
            } else if let combo, state.failedHotKeys.contains(combo) {
                Text("Couldn’t register — in use by the system or another app").foregroundStyle(.red).font(.caption)
            }
        }
        .onDisappear(perform: stop)
    }

    private func start() {
        error = nil
        state.isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) { stop(); return nil }
            record(event)
            return nil
        }
    }

    private func stop() {
        guard let monitor else { return }
        NSEvent.removeMonitor(monitor)
        self.monitor = nil
        state.isRecording = false
    }

    private func record(_ event: NSEvent) {
        let mods = Self.modifierMap.filter { event.modifierFlags.contains($0.flag) }
        let key = event.characters(byApplyingModifiers: [])?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() ?? ""
        let candidate = HotKeyCombo(keyCode: UInt32(event.keyCode),
                                    modifiers: mods.reduce(0) { $0 | UInt32($1.carbon) },
                                    display: mods.map(\.symbol).joined() + (key.isEmpty ? "key \(event.keyCode)" : key))
        stop()
        error = hotKeyConflict(candidate, in: state.data, excludingPreset: preset)
        if error == nil { state.setHotKey(candidate, preset: preset) }
    }
}
