// Slice transparent sprite cells into individual universal Xcode image sets.
// swift Tools/ImportIslandAtlas.swift ATLAS.png Sources/SortScape/Assets.xcassets
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count == 3,
      let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: args[1]) as CFURL, nil),
      let atlas = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    fatalError("Expected atlas PNG and asset catalog path")
}
let names = ["Pathways", "Trees", "FlowerGarden", "Bridge",
             "Picnic", "Fountain", "Windmill", "Dock"]
for (index, name) in names.enumerated() {
    let w = atlas.width / 4, h = atlas.height / 2
    let rect = CGRect(x: index % 4 * w, y: index / 4 * h, width: w, height: h)
    guard let cell = atlas.cropping(to: rect),
          let rgba = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                               bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                               bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
          let data = rgba.data else { fatalError("Could not read \(name)") }
    rgba.draw(cell, in: CGRect(x: 0, y: 0, width: w, height: h))
    let bytes = data.assumingMemoryBound(to: UInt8.self)
    var x0 = w, y0 = h, x1 = -1, y1 = -1
    for y in 0..<h {
        for x in 0..<w where bytes[(y * w + x) * 4 + 3] >= 16 {
            x0 = min(x0, x); x1 = max(x1, x); y0 = min(y0, y); y1 = max(y1, y)
        }
    }
    guard x1 >= x0, y1 >= y0 else { fatalError("Empty sprite: \(name)") }
    let left = max(0, x0 - 4), top = max(0, y0 - 4)
    let right = min(w, x1 + 5), bottom = min(h, y1 + 5)
    guard let sprite = cell.cropping(to: CGRect(x: left, y: top, width: right - left, height: bottom - top)) else {
        fatalError("Invalid sprite bounds: \(name)")
    }
    let folder = URL(fileURLWithPath: args[2]).appendingPathComponent("Island\(name).imageset")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    guard let output = CGImageDestinationCreateWithURL(folder.appendingPathComponent("Art.png") as CFURL,
                                                      UTType.png.identifier as CFString, 1, nil) else {
        fatalError("Could not create image: \(name)")
    }
    CGImageDestinationAddImage(output, sprite, nil)
    guard CGImageDestinationFinalize(output) else { fatalError("Could not write \(name)") }
    try Data(#"{"images":[{"filename":"Art.png","idiom":"universal"}],"info":{"author":"xcode","version":1}}"#.utf8)
        .write(to: folder.appendingPathComponent("Contents.json"), options: .atomic)
    print("\(name): \(sprite.width) × \(sprite.height)")
}
