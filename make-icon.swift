// Renders the 1024px app icon PNG: swift make-icon.swift icon.png
import AppKit

let size: CGFloat = 1024
let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
    // macOS icon grid: 824pt body centered in a 1024 canvas.
    let body = NSRect(x: 100, y: 100, width: 824, height: 824)
    let bg = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)
    NSGradient(colors: [NSColor(red: 0.20, green: 0.45, blue: 0.95, alpha: 1),
                        NSColor(red: 0.45, green: 0.25, blue: 0.85, alpha: 1)])!
        .draw(in: bg, angle: -60)

    // Three tiled "windows": one tall on the left, two stacked on the right.
    let pad: CGFloat = 70, gap: CGFloat = 40
    let inner = body.insetBy(dx: pad, dy: pad)
    let half = (inner.width - gap) / 2
    let tiles = [
        NSRect(x: inner.minX, y: inner.minY, width: half, height: inner.height),
        NSRect(x: inner.minX + half + gap, y: inner.midY + gap / 2, width: half, height: (inner.height - gap) / 2),
        NSRect(x: inner.minX + half + gap, y: inner.minY, width: half, height: (inner.height - gap) / 2),
    ]
    for tile in tiles {
        NSColor.white.withAlphaComponent(0.92).setFill()
        NSBezierPath(roundedRect: tile, xRadius: 40, yRadius: 40).fill()
        // Title bar strip.
        let bar = NSRect(x: tile.minX, y: tile.maxY - 70, width: tile.width, height: 70)
        NSColor(white: 0, alpha: 0.12).setFill()
        let barPath = NSBezierPath(roundedRect: bar, xRadius: 40, yRadius: 40)
        barPath.append(NSBezierPath(rect: NSRect(x: bar.minX, y: bar.minY, width: bar.width, height: 35)))
        barPath.fill()
    }
    return true
}

let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
