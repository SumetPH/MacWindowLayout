import AppKit
import Observation
import WindowLayoutCore

/// Owns the persisted `AppData`, saves it on every change and keeps global hotkeys in sync with it.
@Observable
final class AppState {
    private(set) var data: AppData {
        didSet {
            persist()
            if shortcutsChanged(from: oldValue) { registerHotKeys() }
        }
    }

    /// Shortcuts that RegisterEventHotKey rejected (taken by the system or another app).
    private(set) var failedHotKeys: Set<HotKeyCombo> = []

    /// While a shortcut recorder is active, global hotkeys are off so existing combos reach the recorder.
    var isRecording = false {
        didSet { registerHotKeys() }
    }

    @ObservationIgnored private var hotKeys: [HotKey] = []
    @ObservationIgnored private let url: URL

    init(url: URL = LayoutStore.fileURL) {
        self.url = url
        do {
            data = try LayoutStore.load(from: url)
        } catch {
            // Keep the unreadable file around instead of overwriting it on the next change.
            let backup = url.appendingPathExtension("corrupt")
            NSLog("WindowLayout load failed: \(error); moving it to \(backup.path)")
            try? FileManager.default.removeItem(at: backup)
            do { try FileManager.default.moveItem(at: url, to: backup) } catch { NSLog("WindowLayout backup failed: \(error)") }
            data = AppData()
        }
    }

    // MARK: Actions

    /// Captures the display under the mouse, then asks for a name.
    func saveNewPreset() {
        guard let windows = captureUnderMouse() else { return }
        let fallback = "Preset \(data.presets.count + 1)"
        guard let name = askPresetName(default: fallback) else { return }
        let preset = Preset(name: name.isEmpty ? fallback : name, windows: windows)
        data.presets.append(preset)
        notifySaved(preset)
    }

    func updateFromCurrentWindows(_ id: UUID) {
        guard let windows = captureUnderMouse() else { return }
        updatePreset(id) { $0.windows = windows }
        if let preset = data.presets.first(where: { $0.id == id }) { notifySaved(preset) }
    }

    /// Lays the preset out on the display under the mouse.
    func apply(_ id: UUID) {
        guard let preset = data.presets.first(where: { $0.id == id }) else { return }
        guard let screen = Displays.underMouse() else { return notify("No display found") }
        let result = WindowManager.apply(preset.windows, in: Displays.axRect(screen.visibleFrame))
        let skipped = result.notOpen.isEmpty ? "" : " — not open: \(result.notOpen.joined(separator: ", "))"
        notify("Applied '\(preset.name)': \(result.moved) windows\(skipped)")
    }

    // MARK: Editing

    func deletePreset(_ id: UUID) {
        data.presets.removeAll { $0.id == id }
    }

    func rename(_ id: UUID, to name: String) {
        updatePreset(id) { $0.name = name }
    }

    /// `nil` clears the preset's apply shortcut.
    func setHotKey(_ combo: HotKeyCombo?, preset: UUID) {
        updatePreset(preset) { $0.applyHotKey = combo }
    }

    // MARK: Private

    private func captureUnderMouse() -> [SavedWindow]? {
        guard let screen = Displays.underMouse() else {
            notify("No display found")
            return nil
        }
        return WindowManager.capture(display: Displays.axRect(screen.frame), visible: Displays.axRect(screen.visibleFrame))
    }

    private func notifySaved(_ preset: Preset) {
        notify("Saved '\(preset.name)': \(preset.windows.count) windows (\(appNames(preset).joined(separator: ", ")))")
    }

    private func updatePreset(_ id: UUID, _ change: (inout Preset) -> Void) {
        guard let i = data.presets.firstIndex(where: { $0.id == id }) else { return }
        change(&data.presets[i])
    }

    private func persist() {
        do { try LayoutStore.save(data, to: url) } catch { NSLog("WindowLayout save failed: \(error)") }
    }

    private func shortcutsChanged(from old: AppData) -> Bool {
        old.presets.map(\.id) != data.presets.map(\.id) || old.presets.map(\.applyHotKey) != data.presets.map(\.applyHotKey)
    }

    func registerHotKeys() {
        hotKeys = [] // deinit unregisters the old ones before we re-register
        guard !isRecording else { return }
        let registered = data.presets.compactMap { preset in
            preset.applyHotKey.map { combo in
                (combo, HotKey(keyCode: combo.keyCode, modifiers: combo.modifiers) { [weak self] in self?.apply(preset.id) })
            }
        }
        hotKeys = registered.compactMap(\.1)
        failedHotKeys = Set(registered.filter { $0.1 == nil }.map(\.0))
    }
}

/// Unique app names in first-seen order.
func appNames(_ preset: Preset) -> [String] {
    var seen = Set<String>()
    return preset.windows.map(\.appName).filter { seen.insert($0).inserted }
}

/// Modal name prompt; nil if cancelled. Returns the trimmed text (possibly empty).
private func askPresetName(default name: String) -> String? {
    NSApp.activate(ignoringOtherApps: true) // LSUIElement apps aren't frontmost otherwise
    let alert = NSAlert()
    alert.messageText = "Save New Preset"
    alert.informativeText = "Windows on the display under the mouse were captured."
    let field = NSTextField(string: name)
    field.frame = CGRect(x: 0, y: 0, width: 240, height: 24)
    alert.accessoryView = field
    alert.addButton(withTitle: "Save")
    alert.addButton(withTitle: "Cancel")
    alert.window.initialFirstResponder = field
    guard alert.runModal() == .alertFirstButtonReturn else { return nil }
    return field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
}
