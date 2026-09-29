import Carbon.HIToolbox
import Foundation

/// One window of a preset. `x`, `y`, `width`, `height` are fractions (0…1) of the display's visible frame.
public struct SavedWindow: Codable, Equatable {
    public let bundleID: String
    public let appName: String
    public let title: String
    public let index: Int
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(bundleID: String, appName: String, title: String, index: Int,
                x: Double, y: Double, width: Double, height: Double) {
        self.bundleID = bundleID
        self.appName = appName
        self.title = title
        self.index = index
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// Index of the window matching `saved`: equal title first, else saved index if in bounds, else nil.
public func match(saved: SavedWindow, titles: [String]) -> Int? {
    if let i = titles.firstIndex(of: saved.title) { return i }
    return titles.indices.contains(saved.index) ? saved.index : nil
}

/// `frame` as fractions of `visible`. Both rects in the same (AX, top-left origin) coordinate space.
public func normalize(frame: CGRect, in visible: CGRect) -> (x: Double, y: Double, width: Double, height: Double) {
    ((frame.minX - visible.minX) / visible.width, (frame.minY - visible.minY) / visible.height,
     frame.width / visible.width, frame.height / visible.height)
}

/// Inverse of `normalize`: the saved window's frame on a display whose visible frame is `visible`.
public func denormalize(_ saved: SavedWindow, in visible: CGRect) -> CGRect {
    CGRect(x: visible.minX + saved.x * visible.width, y: visible.minY + saved.y * visible.height,
           width: saved.width * visible.width, height: saved.height * visible.height)
}

public struct HotKeyCombo: Codable, Hashable {
    public let keyCode: UInt32
    /// Carbon modifier flags (controlKey, optionKey, shiftKey, cmdKey).
    public let modifiers: UInt32
    /// Human-readable form, e.g. "⌃⌥⌘1".
    public let display: String

    public init(keyCode: UInt32, modifiers: UInt32, display: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.display = display
    }

    static let controlOptionCommand = UInt32(controlKey | optionKey | cmdKey)

    /// Same physical key combination (ignores `display`).
    func triggers(like other: HotKeyCombo?) -> Bool {
        other.map { $0.keyCode == keyCode && $0.modifiers == modifiers } ?? false
    }
}

public struct Preset: Codable, Identifiable, Equatable {
    public let id: UUID
    public var name: String
    public var applyHotKey: HotKeyCombo?
    public var windows: [SavedWindow]

    public init(id: UUID = UUID(), name: String, applyHotKey: HotKeyCombo? = nil, windows: [SavedWindow] = []) {
        self.id = id
        self.name = name
        self.applyHotKey = applyHotKey
        self.windows = windows
    }
}

public struct AppData: Codable, Equatable {
    public var presets: [Preset]

    public init(presets: [Preset] = []) {
        self.presets = presets
    }
}

/// Human-readable reason `combo` can't be used, or nil if it's free.
public func hotKeyConflict(_ combo: HotKeyCombo, in data: AppData, excludingPreset: UUID?) -> String? {
    if combo.modifiers & HotKeyCombo.controlOptionCommand == 0 { return "Shortcut needs at least one of ⌃ ⌥ ⌘" }
    let other = data.presets.first { $0.id != excludingPreset && combo.triggers(like: $0.applyHotKey) }
    return other.map { "\(combo.display) is already used by “\($0.name)”" }
}

public enum LayoutStore {
    public static var fileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/WindowLayout/presets.json")
    }

    /// Returns no presets when the file doesn't exist yet; throws if it exists but can't be read.
    public static func load(from url: URL = fileURL) throws -> AppData {
        guard FileManager.default.fileExists(atPath: url.path) else { return AppData() }
        return try JSONDecoder().decode(AppData.self, from: Data(contentsOf: url))
    }

    public static func save(_ data: AppData, to url: URL = fileURL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(data).write(to: url, options: .atomic)
    }
}
