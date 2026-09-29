import AppKit
import ApplicationServices
import WindowLayoutCore

enum WindowManager {
    /// Visible standard windows of all regular, unhidden apps whose center lies in `display`,
    /// normalized to `visible`. Both rects in AX (top-left origin) coordinates.
    static func capture(display: CGRect, visible: CGRect) -> [SavedWindow] {
        var result: [SavedWindow] = []
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular && !app.isHidden {
            guard let bundleID = app.bundleIdentifier else { continue }
            for (index, window) in windows(of: pid(of: app)).enumerated() where isVisible(window) {
                guard let origin = point(window), let size = size(window) else { continue }
                let frame = CGRect(origin: origin, size: size)
                guard display.contains(CGPoint(x: frame.midX, y: frame.midY)) else { continue }
                let n = normalize(frame: frame, in: visible)
                result.append(SavedWindow(bundleID: bundleID, appName: app.localizedName ?? bundleID, title: title(window),
                                          index: index, x: n.x, y: n.y, width: n.width, height: n.height))
            }
        }
        return result
    }

    /// Moves windows onto `visible` (AX coordinates); returns the number moved and the names of apps that aren't running.
    static func apply(_ saved: [SavedWindow], in visible: CGRect) -> (moved: Int, notOpen: [String]) {
        var moved = 0
        var notOpen: [String] = []
        for entries in Dictionary(grouping: saved, by: \.bundleID).values {
            guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: entries[0].bundleID).first else {
                notOpen.append(entries[0].appName)
                continue
            }
            let wins = windows(of: pid(of: app))
            let titles = wins.map(title)
            for entry in entries {
                guard let i = match(saved: entry, titles: titles) else { continue }
                let frame = denormalize(entry, in: visible)
                var pos = frame.origin
                var size = frame.size
                guard let posValue = AXValueCreate(.cgPoint, &pos), let sizeValue = AXValueCreate(.cgSize, &size) else { continue }
                // Position, size, position again: the OS may clamp size/position when moving across displays.
                AXUIElementSetAttributeValue(wins[i], kAXPositionAttribute as CFString, posValue)
                AXUIElementSetAttributeValue(wins[i], kAXSizeAttribute as CFString, sizeValue)
                if AXUIElementSetAttributeValue(wins[i], kAXPositionAttribute as CFString, posValue) == .success { moved += 1 }
            }
        }
        return (moved, notOpen.sorted())
    }

    /// Some apps (e.g. Xcode's Device Hub on macOS 27) report pid -1 via NSRunningApplication;
    /// fall back to finding the process whose executable path matches.
    private static func pid(of app: NSRunningApplication) -> pid_t {
        if app.processIdentifier > 0 { return app.processIdentifier }
        guard let exe = app.executableURL?.resolvingSymlinksInPath().path else { return -1 }
        var pids = [pid_t](repeating: 0, count: 4096)
        let count = Int(proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size)))
        var buf = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        for pid in pids.prefix(max(count, 0)) where pid > 0 {
            if proc_pidpath(pid, &buf, UInt32(buf.count)) > 0, String(cString: buf) == exe { return pid }
        }
        return -1
    }

    private static func windows(of pid: pid_t) -> [AXUIElement] {
        let app = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success else { return [] }
        return value as? [AXUIElement] ?? []
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }

    /// Only normal, on-screen windows: skips minimized windows and non-standard ones (e.g. Finder's desktop).
    private static func isVisible(_ window: AXUIElement) -> Bool {
        let minimized = attribute(window, kAXMinimizedAttribute) as? Bool ?? false
        let subrole = attribute(window, kAXSubroleAttribute) as? String
        return !minimized && subrole == kAXStandardWindowSubrole
    }

    private static func title(_ window: AXUIElement) -> String {
        attribute(window, kAXTitleAttribute) as? String ?? ""
    }

    private static func point(_ window: AXUIElement) -> CGPoint? {
        guard let raw = attribute(window, kAXPositionAttribute), CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        var p = CGPoint.zero
        return AXValueGetValue(raw as! AXValue, .cgPoint, &p) ? p : nil
    }

    private static func size(_ window: AXUIElement) -> CGSize? {
        guard let raw = attribute(window, kAXSizeAttribute), CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        var s = CGSize.zero
        return AXValueGetValue(raw as! AXValue, .cgSize, &s) ? s : nil
    }
}
