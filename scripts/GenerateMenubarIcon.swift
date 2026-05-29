#!/usr/bin/swift
// Generates menubar icon at 1x (22px), 2x (44px), 3x (66px) from source PNG

import Cocoa
import CoreGraphics

func savePNG(_ source: CGImage, to path: String, size: Int) {
    let ctx = CGContext(data: nil, width: size, height: size,
                        bitsPerComponent: 8, bytesPerRow: size * 4,
                        space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.draw(source, in: CGRect(x: 0, y: 0, width: size, height: size))
    let img = ctx.makeImage()!
    let url = URL(fileURLWithPath: path)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, img, nil)
    CGImageDestinationFinalize(dest)
    print("  wrote \(size)x\(size) → \(url.lastPathComponent)")
}

let src = "/Users/parth/Projects/Apps/QuietReminder/QuietReminder/Assets.xcassets/menubar.imageset/menubar_new.png"
let outDir = "/Users/parth/Projects/Apps/QuietReminder/QuietReminder/Assets.xcassets/menubar.imageset"

guard let img = NSImage(contentsOfFile: src),
      let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    print("ERROR: could not load \(src)"); exit(1)
}

print("Generating menubar icon sizes…")
savePNG(cg, to: "\(outDir)/menubar_22.png", size: 22)
savePNG(cg, to: "\(outDir)/menubar_44.png", size: 44)
savePNG(cg, to: "\(outDir)/menubar_66.png", size: 66)
print("Done.")
