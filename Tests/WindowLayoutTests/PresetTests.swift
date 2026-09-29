import Carbon.HIToolbox
import Foundation
import WindowLayoutCore
import XCTest

final class PresetTests: XCTestCase {
    private let ctrlOptCmd = UInt32(controlKey | optionKey | cmdKey)
    private lazy var work = Preset(name: "Work", applyHotKey: HotKeyCombo(keyCode: 18, modifiers: ctrlOptCmd, display: "⌃⌥⌘1"))
    private let home = Preset(name: "Home")

    private var data: AppData { AppData(presets: [work, home]) }

    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("presets.json")
    }

    private func saved(_ n: (x: Double, y: Double, width: Double, height: Double)) -> SavedWindow {
        SavedWindow(bundleID: "com.example", appName: "Example", title: "T", index: 0, x: n.x, y: n.y, width: n.width, height: n.height)
    }

    // MARK: normalize / denormalize

    func testNormalizeRoundTrip() {
        // Secondary display left of and above the primary (negative AX origin), below a 25pt menu bar.
        let visible = CGRect(x: -1920, y: -1055, width: 1920, height: 1055)
        let frame = CGRect(x: -1440, y: -800, width: 960, height: 527.5)
        let n = normalize(frame: frame, in: visible)
        XCTAssertEqual(n.x, 0.25, accuracy: 1e-9)
        XCTAssertEqual(n.width, 0.5, accuracy: 1e-9)
        XCTAssertEqual(n.height, 0.5, accuracy: 1e-9)
        XCTAssertEqual(denormalize(saved(n), in: visible), frame)
    }

    func testDenormalizeMapsOntoDifferentDisplay() {
        let laptop = CGRect(x: 0, y: 25, width: 1512, height: 920)
        let external = CGRect(x: 1512, y: -300, width: 2560, height: 1400)
        // Left half of the laptop's visible area.
        let n = normalize(frame: CGRect(x: 0, y: 25, width: 756, height: 920), in: laptop)
        XCTAssertEqual(denormalize(saved(n), in: external), CGRect(x: 1512, y: -300, width: 1280, height: 1400))
    }

    // MARK: hotKeyConflict

    func testConflictWithOtherPreset() {
        XCTAssertNotNil(hotKeyConflict(work.applyHotKey!, in: data, excludingPreset: home.id))
    }

    func testSamePresetAllowed() {
        XCTAssertNil(hotKeyConflict(work.applyHotKey!, in: data, excludingPreset: work.id))
    }

    func testRequiresControlOptionOrCommand() {
        let none = HotKeyCombo(keyCode: 18, modifiers: 0, display: "1")
        let shiftOnly = HotKeyCombo(keyCode: 18, modifiers: UInt32(shiftKey), display: "⇧1")
        XCTAssertNotNil(hotKeyConflict(none, in: data, excludingPreset: nil))
        XCTAssertNotNil(hotKeyConflict(shiftOnly, in: data, excludingPreset: nil))
        XCTAssertNil(hotKeyConflict(HotKeyCombo(keyCode: 19, modifiers: ctrlOptCmd, display: "⌃⌥⌘2"), in: data, excludingPreset: nil))
    }

    // MARK: LayoutStore

    func testAppDataJSONRoundTrip() throws {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        var withWindows = work
        withWindows.windows = [saved((0.1, 0.2, 0.3, 0.4))]
        let original = AppData(presets: [withWindows, home])
        try LayoutStore.save(original, to: url)
        XCTAssertEqual(try LayoutStore.load(from: url), original)
    }

    func testEmptyWhenFileMissing() throws {
        XCTAssertEqual(try LayoutStore.load(from: tempURL()).presets, [])
    }
}
