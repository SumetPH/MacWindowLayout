import ServiceManagement
import SwiftUI
import WindowLayoutCore

struct SettingsView: View {
    let state: AppState

    var body: some View {
        Form {
            GeneralSection()
            if state.data.presets.isEmpty {
                Text("No presets yet — use “Save New Preset…” in the menu bar.").foregroundStyle(.secondary)
            }
            ForEach(state.data.presets) { preset in
                PresetSection(state: state, preset: preset)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 480, minHeight: 360)
    }
}

private struct GeneralSection: View {
    @AppStorage(showMenuBarIconKey) private var showMenuBarIcon = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Section("General") {
            Toggle("Launch at login", isOn: Binding(get: { launchAtLogin }, set: setLaunchAtLogin))
            Toggle("Show menu bar icon", isOn: $showMenuBarIcon)
            if !showMenuBarIcon {
                Text("Open the app again (e.g. from Finder) to bring the icon back.").foregroundStyle(.secondary)
            }
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("WindowLayout launch at login failed: \(error)")
            notify("Couldn't change launch at login: \(error.localizedDescription)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}

private struct PresetSection: View {
    let state: AppState
    let preset: Preset

    var body: some View {
        Section(preset.name) {
            TextField("Name", text: Binding(get: { preset.name }, set: { state.rename(preset.id, to: $0) }))
            LabeledContent("Apps") {
                Text(preset.windows.isEmpty ? "None" : appNames(preset).joined(separator: ", "))
                    .foregroundStyle(.secondary)
            }
            LabeledContent("Apply shortcut") {
                HStack(alignment: .top) {
                    ShortcutRecorder(state: state, preset: preset.id, combo: preset.applyHotKey)
                    Button("Clear") { state.setHotKey(nil, preset: preset.id) }
                        .disabled(preset.applyHotKey == nil)
                }
            }
            HStack {
                Button("Update from Current Windows") { state.updateFromCurrentWindows(preset.id) }
                    .help("Replaces this preset with the windows on the display under the mouse")
                Spacer()
                Button("Delete", role: .destructive) { state.deletePreset(preset.id) }
            }
        }
    }
}
