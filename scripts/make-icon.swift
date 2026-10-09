import AppKit

let root = CommandLine.arguments[1]
let folder = URL(fileURLWithPath: root).appendingPathComponent(".build/AppIcon.iconset")
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let size = points * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let unit = CGFloat(size) / 1024
        NSAffineTransform().concat()
        let transform = NSAffineTransform()
        transform.scale(by: unit)
        transform.concat()
        NSColor(calibratedRed: 0.10, green: 0.28, blue: 0.42, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 52, y: 52, width: 920, height: 920), xRadius: 204, yRadius: 204).fill()
        NSColor.white.withAlphaComponent(0.10).setStroke()
        for y in [CGFloat(320), 510, 700] {
            let grid = NSBezierPath()
            grid.move(to: NSPoint(x: 195, y: y)); grid.line(to: NSPoint(x: 832, y: y))
            grid.lineWidth = 5; grid.stroke()
        }
        let chart = NSBezierPath()
        chart.move(to: NSPoint(x: 202, y: 320))
        chart.line(to: NSPoint(x: 354, y: 500))
        chart.line(to: NSPoint(x: 484, y: 414))
        chart.line(to: NSPoint(x: 630, y: 650))
        chart.line(to: NSPoint(x: 822, y: 726))
        chart.lineWidth = 50; chart.lineCapStyle = .round; chart.lineJoinStyle = .round
        NSColor(calibratedRed: 0.53, green: 0.91, blue: 0.79, alpha: 1).setStroke(); chart.stroke()
        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(x: 792, y: 696, width: 60, height: 60)).fill()
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!.write(to: folder.appendingPathComponent("icon_\(points)x\(points)\(suffix).png"))
    }
}
