#!/usr/bin/env swift
// Renders the NoteNest app icon to a 1024x1024 PNG using AppKit/CoreGraphics.
// Usage: swift scripts/make-icon.swift <output-png-path>
import AppKit

let outPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon-1024.png"
let size = 512  // logical points; NSImage renders at 2x → 1024 px

let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()
let ctx = NSGraphicsContext.current!.cgContext

// Dark rounded-square background.
let rect = CGRect(x: 0, y: 0, width: size, height: size)
let bg = CGPath(roundedRect: rect.insetBy(dx: 24, dy: 24),
                cornerWidth: 96, cornerHeight: 96, transform: nil)
ctx.addPath(bg)
ctx.setFillColor(CGColor(red: 0.12, green: 0.13, blue: 0.16, alpha: 1))
ctx.fillPath()

// Three "note line" strokes (the last one shorter) in a soft blue.
ctx.setStrokeColor(CGColor(red: 0.55, green: 0.70, blue: 0.95, alpha: 1))
ctx.setLineWidth(22)
ctx.setLineCap(.round)
let ys = [332, 256, 180]            // top to bottom
for (i, y) in ys.enumerated() {
    let endX = (i == 2) ? size - 230 : size - 170
    ctx.move(to: CGPoint(x: 170, y: y))
    ctx.addLine(to: CGPoint(x: endX, y: y))
    ctx.strokePath()
}

img.unlockFocus()

guard let tiff = img.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    FileHandle.standardError.write("failed to render icon\n".data(using: .utf8)!)
    exit(1)
}
try! png.write(to: URL(fileURLWithPath: outPath))
print("wrote \(outPath)")
