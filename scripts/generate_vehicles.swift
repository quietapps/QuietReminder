#!/usr/bin/swift
import AppKit
import Foundation

// Usage: swift generate_vehicles.swift <output_xcassets_dir>
let xcassetsDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "\(FileManager.default.currentDirectoryPath)/QuietReminder/Assets.xcassets"

// MARK: - Helpers

func draw(width: CGFloat, height: CGFloat, block: () -> Void) -> NSImage {
    let img = NSImage(size: NSSize(width: width, height: height))
    img.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    block()
    img.unlockFocus()
    return img
}

func save(_ img: NSImage, imagesetName: String) {
    let dir = "\(xcassetsDir)/\(imagesetName).imageset"
    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

    // PNG
    if let tiff = img.tiffRepresentation,
       let rep = NSBitmapImageRep(data: tiff),
       let png = rep.representation(using: .png, properties: [:]) {
        try? png.write(to: URL(fileURLWithPath: "\(dir)/\(imagesetName).png"))
    }

    // Contents.json
    let json = """
    {
      "images" : [
        {
          "filename" : "\(imagesetName).png",
          "idiom" : "universal",
          "scale" : "1x"
        }
      ],
      "info" : {
        "author" : "xcode",
        "version" : 1
      }
    }
    """
    try? json.write(toFile: "\(dir)/Contents.json", atomically: true, encoding: .utf8)
    print("✓ \(imagesetName).imageset")
}

// MARK: - Rocket
// Horizontal, nose right, fins left, exhaust flame left.
// Orange/red palette to match the .rocket accentColor.

func makeRocket() -> NSImage {
    let W: CGFloat = 420, H: CGFloat = 270
    return draw(width: W, height: H) {

        let bodyColor   = NSColor(srgbRed: 0.82, green: 0.32, blue: 0.18, alpha: 1)
        let bodyLight   = NSColor(srgbRed: 0.96, green: 0.62, blue: 0.42, alpha: 1)
        let outline     = NSColor(srgbRed: 0.28, green: 0.10, blue: 0.04, alpha: 1)
        let winColor    = NSColor(srgbRed: 0.65, green: 0.88, blue: 0.98, alpha: 1)
        let flame1      = NSColor(srgbRed: 0.99, green: 0.80, blue: 0.10, alpha: 1)
        let flame2      = NSColor(srgbRed: 0.99, green: 0.45, blue: 0.05, alpha: 1)
        let finColor    = NSColor(srgbRed: 0.68, green: 0.22, blue: 0.10, alpha: 1)

        // --- Flame (behind body) ---
        let fl2 = NSBezierPath()
        fl2.move(to: NSPoint(x: 75, y: 135))
        fl2.curve(to: NSPoint(x: 8,  y: 135), controlPoint1: NSPoint(x: 44, y: 162), controlPoint2: NSPoint(x: 10, y: 162))
        fl2.curve(to: NSPoint(x: 75, y: 135), controlPoint1: NSPoint(x: 10, y: 108), controlPoint2: NSPoint(x: 44, y: 108))
        flame2.setFill(); fl2.fill()

        let fl1 = NSBezierPath()
        fl1.move(to: NSPoint(x: 78, y: 135))
        fl1.curve(to: NSPoint(x: 25, y: 135), controlPoint1: NSPoint(x: 52, y: 155), controlPoint2: NSPoint(x: 27, y: 153))
        fl1.curve(to: NSPoint(x: 78, y: 135), controlPoint1: NSPoint(x: 27, y: 117), controlPoint2: NSPoint(x: 52, y: 115))
        flame1.setFill(); fl1.fill()

        // --- Fins ---
        func fin(_ pts: [NSPoint], fill: NSColor) {
            let p = NSBezierPath()
            p.move(to: pts[0])
            pts.dropFirst().forEach { p.line(to: $0) }
            p.close()
            fill.setFill(); p.fill()
            outline.setStroke(); p.lineWidth = 4; p.stroke()
        }
        fin([NSPoint(x: 85, y: 150), NSPoint(x: 55, y: 215), NSPoint(x: 160, y: 150)], fill: finColor)
        fin([NSPoint(x: 85, y: 120), NSPoint(x: 55, y:  55), NSPoint(x: 160, y: 120)], fill: finColor)

        // --- Body ---
        let body = NSBezierPath()
        body.appendRoundedRect(NSRect(x: 75, y: 105, width: 255, height: 60), xRadius: 30, yRadius: 30)
        bodyColor.setFill(); body.fill()

        // highlight stripe
        let hi = NSBezierPath()
        hi.appendRoundedRect(NSRect(x: 115, y: 148, width: 160, height: 10), xRadius: 5, yRadius: 5)
        bodyLight.setFill(); hi.fill()

        // --- Nose ---
        let nose = NSBezierPath()
        nose.move(to: NSPoint(x: 318, y: 165))
        nose.curve(to: NSPoint(x: 395, y: 135), controlPoint1: NSPoint(x: 352, y: 167), controlPoint2: NSPoint(x: 395, y: 152))
        nose.curve(to: NSPoint(x: 318, y: 105), controlPoint1: NSPoint(x: 395, y: 118), controlPoint2: NSPoint(x: 352, y: 103))
        nose.close()
        bodyColor.setFill(); nose.fill()
        outline.setStroke(); nose.lineWidth = 4; nose.stroke()

        // body outline
        outline.setStroke(); body.lineWidth = 4; body.stroke()

        // --- Window ---
        let win = NSBezierPath(ovalIn: NSRect(x: 200, y: 115, width: 56, height: 40))
        winColor.setFill(); win.fill()
        outline.setStroke(); win.lineWidth = 3.5; win.stroke()

        // window shine
        let shine = NSBezierPath(ovalIn: NSRect(x: 210, y: 138, width: 16, height: 10))
        NSColor.white.withAlphaComponent(0.75).setFill(); shine.fill()

        // --- Rivets ---
        for x: CGFloat in [120, 155, 182] {
            let r = NSBezierPath(ovalIn: NSRect(x: x, y: 130, width: 7, height: 7))
            outline.setFill(); r.fill()
        }
    }
}

// MARK: - UFO
// Disc + dome. Green palette for the .ufo accentColor.

func makeUFO() -> NSImage {
    let W: CGFloat = 420, H: CGFloat = 290
    return draw(width: W, height: H) {

        let discColor   = NSColor(srgbRed: 0.35, green: 0.72, blue: 0.38, alpha: 1)
        let discLight   = NSColor(srgbRed: 0.62, green: 0.90, blue: 0.60, alpha: 1)
        let outline     = NSColor(srgbRed: 0.10, green: 0.30, blue: 0.10, alpha: 1)
        let domeColor   = NSColor(srgbRed: 0.75, green: 0.96, blue: 0.78, alpha: 0.90)
        let domeOutline = NSColor(srgbRed: 0.20, green: 0.55, blue: 0.25, alpha: 1)
        let lightYellow = NSColor(srgbRed: 1.00, green: 0.94, blue: 0.20, alpha: 1)
        let beamColor   = NSColor(srgbRed: 0.70, green: 1.00, blue: 0.70, alpha: 0.22)

        // --- Beam ---
        let beam = NSBezierPath()
        beam.move(to: NSPoint(x: 162, y: 122))
        beam.line(to: NSPoint(x: 108, y: 32))
        beam.line(to: NSPoint(x: 312, y: 32))
        beam.line(to: NSPoint(x: 258, y: 122))
        beam.close()
        beamColor.setFill(); beam.fill()

        // --- Disc bottom shadow ---
        let shadow = NSBezierPath(ovalIn: NSRect(x: 72, y: 108, width: 276, height: 60))
        NSColor(srgbRed: 0.20, green: 0.50, blue: 0.22, alpha: 0.45).setFill()
        shadow.fill()

        // --- Disc ---
        let disc = NSBezierPath(ovalIn: NSRect(x: 60, y: 110, width: 300, height: 72))
        discColor.setFill(); disc.fill()

        // disc highlight
        let dhigh = NSBezierPath(ovalIn: NSRect(x: 120, y: 158, width: 120, height: 16))
        discLight.setFill(); dhigh.fill()

        // --- Dome ---
        let dome = NSBezierPath()
        dome.appendArc(withCenter: NSPoint(x: 210, y: 146), radius: 82,
                       startAngle: 0, endAngle: 180)
        dome.line(to: NSPoint(x: 128, y: 146))
        dome.close()
        domeColor.setFill(); dome.fill()
        domeOutline.setStroke(); dome.lineWidth = 4; dome.stroke()

        // dome shine arc
        let domeShine = NSBezierPath()
        domeShine.appendArc(withCenter: NSPoint(x: 210, y: 146), radius: 62,
                            startAngle: 40, endAngle: 140)
        NSColor.white.withAlphaComponent(0.55).setStroke()
        domeShine.lineWidth = 7; domeShine.lineCapStyle = .round; domeShine.stroke()

        // --- Disc outline ---
        outline.setStroke(); disc.lineWidth = 4; disc.stroke()

        // --- Lights ---
        let lightXs: [CGFloat] = [105, 150, 210, 270, 315]
        for x in lightXs {
            let y: CGFloat = x < 160 || x > 260 ? 138 : 122
            let l = NSBezierPath(ovalIn: NSRect(x: x - 9, y: y - 7, width: 18, height: 14))
            lightYellow.setFill(); l.fill()
            outline.setStroke(); l.lineWidth = 2.5; l.stroke()
        }
    }
}

// MARK: - Paper Plane
// Classic delta-wing paper airplane. Blue/white palette for .paper accentColor.

func makePaper() -> NSImage {
    let W: CGFloat = 420, H: CGFloat = 260
    return draw(width: W, height: H) {

        let topWing     = NSColor(srgbRed: 0.93, green: 0.96, blue: 1.00, alpha: 1)
        let botWing     = NSColor(srgbRed: 0.74, green: 0.86, blue: 0.98, alpha: 1)
        let foldColor   = NSColor(srgbRed: 0.55, green: 0.74, blue: 0.95, alpha: 1)
        let outline     = NSColor(srgbRed: 0.22, green: 0.38, blue: 0.60, alpha: 1)
        let shadow      = NSColor(srgbRed: 0.62, green: 0.78, blue: 0.96, alpha: 1)

        // nose x=390, tail x=65, center spine y=130
        let nose  = NSPoint(x: 390, y: 130)
        let tailT = NSPoint(x: 65, y: 220)  // rear top corner
        let tailB = NSPoint(x: 65, y: 40)   // rear bottom corner
        let spine = NSPoint(x: 200, y: 130) // center fold join

        // --- Lower wing (shadow side, drawn first) ---
        let lower = NSBezierPath()
        lower.move(to: nose)
        lower.line(to: spine)
        lower.line(to: tailB)
        lower.close()
        botWing.setFill(); lower.fill()

        // --- Upper wing ---
        let upper = NSBezierPath()
        upper.move(to: nose)
        upper.line(to: spine)
        upper.line(to: tailT)
        upper.close()
        topWing.setFill(); upper.fill()

        // --- Outlines ---
        outline.setStroke()

        let fullOutline = NSBezierPath()
        fullOutline.move(to: nose)
        fullOutline.line(to: tailT)
        fullOutline.line(to: tailB)
        fullOutline.close()
        fullOutline.lineWidth = 4; fullOutline.stroke()

        // Center fold line
        let fold = NSBezierPath()
        fold.move(to: nose)
        fold.line(to: tailT)
        foldColor.setStroke(); fold.lineWidth = 2.5; fold.stroke()

        // Spine crease (bottom half)
        let crease = NSBezierPath()
        crease.move(to: spine)
        crease.line(to: tailT)
        shadow.setStroke(); crease.lineWidth = 2; crease.stroke()

        // --- Cockpit dot ---
        let dot = NSBezierPath(ovalIn: NSRect(x: 348, y: 123, width: 14, height: 14))
        foldColor.setFill(); dot.fill()
        outline.setStroke(); dot.lineWidth = 2; dot.stroke()
    }
}

// MARK: - Run

let xcassets = xcassetsDir
print("Writing to: \(xcassets)\n")
save(makeRocket(), imagesetName: "rocket")
save(makeUFO(),    imagesetName: "ufo")
save(makePaper(),  imagesetName: "paper")
print("\nDone.")
