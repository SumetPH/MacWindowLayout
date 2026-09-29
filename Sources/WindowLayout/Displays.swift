import AppKit

enum Displays {
    /// The screen under the mouse pointer, else the main screen.
    static func underMouse() -> NSScreen? {
        NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
    }

    /// Converts an AppKit rect (bottom-left origin) to AX global coordinates (top-left origin of the primary screen).
    static func axRect(_ rect: CGRect) -> CGRect {
        let primaryMaxY = NSScreen.screens.first?.frame.maxY ?? 0
        return CGRect(x: rect.minX, y: primaryMaxY - rect.maxY, width: rect.width, height: rect.height)
    }
}
