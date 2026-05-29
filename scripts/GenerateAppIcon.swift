#!/usr/bin/swift
// Generates QuietReminder app icon following Quiet Apps design system:
// - 1024×1024 transparent canvas, 9% safe-area padding
// - True n=5 superellipse squircle filled with Quiet Blue #1E88E5
// - White airplane artwork composited via screen blend (extracts white strokes from source)
// - Downscales to all required sizes

import Cocoa
import CoreGraphics

// MARK: - Squircle path (n=5 superellipse, matching QuietFinance GenerateIcon spec)

func squirclePath(in rect: CGRect, exponent: Double = 5.0) -> CGPath {
    let cx = rect.midX, cy = rect.midY
    let rx = rect.width / 2, ry = rect.height / 2
    let path = CGMutablePath()
    let steps = 600
    for i in 0...steps {
        let t = 2 * Double.pi * Double(i) / Double(steps)
        let cosT = cos(t), sinT = sin(t)
        let x = cx + CGFloat(pow(abs(cosT), 2.0 / exponent) * (cosT >= 0 ? 1 : -1)) * rx
        let y = cy + CGFloat(pow(abs(sinT), 2.0 / exponent) * (sinT >= 0 ? 1 : -1)) * ry
        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
        else       { path.addLine(to: CGPoint(x: x, y: y)) }
    }
    path.closeSubpath()
    return path
}

// MARK: - Render 1024×1024 master icon

func renderMaster(sourcePath: String) -> CGImage {
    let size = 1024
    let pad  = 0.09
    let inset = CGFloat(size) * CGFloat(pad)
    let artRect = CGRect(x: inset, y: inset,
                         width: CGFloat(size) - 2 * inset,
                         height: CGFloat(size) - 2 * inset)

    let ctx = CGContext(data: nil,
                        width: size, height: size,
                        bitsPerComponent: 8,
                        bytesPerRow: size * 4,
                        space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

    let squircle = squirclePath(in: artRect, exponent: 5.0)

    // Fill squircle with Quiet Blue #1E88E5
    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()
    ctx.setFillColor(CGColor(red: 0x1E/255.0, green: 0x88/255.0, blue: 0xE5/255.0, alpha: 1.0))
    ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
    ctx.restoreGState()

    // Load source and draw as-is — no blend mode, colors preserved exactly
    guard let src = NSImage(contentsOfFile: sourcePath),
          let srcCG = src.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        print("ERROR: could not load \(sourcePath)"); exit(1)
    }

    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()
    ctx.interpolationQuality = .high
    ctx.draw(srcCG, in: artRect)
    ctx.restoreGState()

    return ctx.makeImage()!
}

// MARK: - Downscale + save PNG

func savePNG(_ image: CGImage, to path: String, size: Int) {
    let ctx = CGContext(data: nil,
                        width: size, height: size,
                        bitsPerComponent: 8,
                        bytesPerRow: size * 4,
                        space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
    let scaled = ctx.makeImage()!

    let url  = URL(fileURLWithPath: path)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, scaled, nil)
    CGImageDestinationFinalize(dest)
    print("  wrote \(size)x\(size) → \(url.lastPathComponent)")
}

// MARK: - Main

let sourceImage = "/Users/parth/.claude/image-cache/e93de9db-25cb-457a-a378-ad673f31de18/15.png"
let outDir = "/Users/parth/Projects/Apps/QuietReminder/QuietReminder/Assets.xcassets/AppIcon.appiconset"

print("Generating QuietReminder app icon…")
let master = renderMaster(sourcePath: sourceImage)

let sizes: [(filename: String, px: Int)] = [
    ("icon_16.png",   16),
    ("icon_32.png",   32),
    ("icon_64.png",   64),
    ("icon_128.png",  128),
    ("icon_256.png",  256),
    ("icon_512.png",  512),
    ("icon_1024.png", 1024),
]

for (filename, px) in sizes {
    savePNG(master, to: "\(outDir)/\(filename)", size: px)
}

print("Done.")
