// Reproducible original SortScape artwork. Run: swift Tools/GenerateIcon.swift
import AppKit
import ImageIO
import UniformTypeIdentifiers
let size = 1024
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
let dark = NSColor(srgbRed: 0.06, green: 0.22, blue: 0.24, alpha: 1)
let light = NSColor(srgbRed: 0.21, green: 0.47, blue: 0.40, alpha: 1)
let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [dark.cgColor, light.cgColor] as CFArray, locations: [0, 1])!
context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 1024, y: 1024), options: [])
func rounded(_ rect: CGRect, radius: CGFloat, color: NSColor) {
    context.setFillColor(color.cgColor)
    context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)); context.fillPath()
}
context.setFillColor(NSColor(srgbRed: 1, green: 0.83, blue: 0.46, alpha: 1).cgColor)
context.fillEllipse(in: CGRect(x: 704, y: 722, width: 145, height: 145))
let palette: [NSColor] = [NSColor(srgbRed: 0.98, green: 0.52, blue: 0.42, alpha: 1), NSColor(srgbRed: 0.56, green: 0.85, blue: 0.70, alpha: 1), NSColor(srgbRed: 1, green: 0.80, blue: 0.38, alpha: 1)]
for column in 0..<3 {
    let x = CGFloat(195 + column * 220), base = CGFloat(column == 1 ? 230 : 195)
    rounded(CGRect(x: x - 12, y: base - 17, width: 188, height: 515), radius: 49, color: .white.withAlphaComponent(0.17))
    for row in 0..<(column == 1 ? 4 : 3) {
        let y = base + CGFloat(row * 114)
        rounded(CGRect(x: x, y: y, width: 164, height: 99), radius: 27, color: palette[column])
        let text = ["◆", "✿", "✦"][column] as NSString
        text.draw(at: CGPoint(x: x + 51, y: y + 14), withAttributes: [.font: NSFont.systemFont(ofSize: 48, weight: .bold), .foregroundColor: dark])
    }
}
NSGraphicsContext.restoreGraphicsState()
let output = URL(fileURLWithPath: "Sources/SortScape/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, context.makeImage()!, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Unable to write icon") }
