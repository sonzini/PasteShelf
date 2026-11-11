#!/usr/bin/env swift
// Draws the PasteShelf app icon (1024×1024 PNG) with Core Graphics.
// Usage: swift scripts/make-icon.swift <output.png>

import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let ctx = NSGraphicsContext.current!.cgContext

func color(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}
func rounded(_ r: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

// macOS icon grid: 824×824 squircle centred on a 1024 canvas, with a soft drop shadow.
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = rounded(tile, 185)

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 28, color: color(0x000000, 0.35))
ctx.addPath(tilePath); ctx.setFillColor(color(0x000000)); ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(tilePath); ctx.clip()
let bg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: [color(0x6FA8FF), color(0x3D6BF2), color(0x2A3FB8)] as CFArray,
                    locations: [0, 0.55, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
let hl = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: [color(0xFFFFFF, 0.25), color(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(hl, startCenter: CGPoint(x: 380, y: 900), startRadius: 0,
                       endCenter: CGPoint(x: 380, y: 900), endRadius: 520, options: [])
ctx.restoreGState()

// Stacked cards behind the board ("a shelf of clips")
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 16, color: color(0x000000, 0.25))
ctx.addPath(rounded(CGRect(x: 322, y: 236, width: 420, height: 520), 48))
ctx.setFillColor(color(0xFFFFFF, 0.45)); ctx.fillPath()
ctx.addPath(rounded(CGRect(x: 302, y: 216, width: 420, height: 520), 48))
ctx.setFillColor(color(0xFFFFFF, 0.7)); ctx.fillPath()
// Main board
ctx.addPath(rounded(CGRect(x: 282, y: 196, width: 420, height: 540), 48))
ctx.setFillColor(color(0xFFFFFF)); ctx.fillPath()
ctx.restoreGState()

// Clip at the top
ctx.addPath(rounded(CGRect(x: 392, y: 690, width: 200, height: 96), 30))
ctx.setFillColor(color(0x1E2A66)); ctx.fillPath()
ctx.addPath(rounded(CGRect(x: 452, y: 740, width: 80, height: 26), 13))
ctx.setFillColor(color(0x6FA8FF)); ctx.fillPath()

// Text lines (history entries)
let lineColor = color(0xC9D4F2)
for (i, w) in [300.0, 240.0, 280.0, 200.0].enumerated() {
    let y = 590 - CGFloat(i) * 92
    ctx.addPath(rounded(CGRect(x: 332, y: y, width: w, height: 40), 20))
    ctx.setFillColor(i == 0 ? color(0x3D6BF2) : lineColor)
    ctx.fillPath()
}

// Favourite star badge
func star(center c: CGPoint, outer: CGFloat, inner: CGFloat) -> CGPath {
    let p = CGMutablePath()
    for i in 0..<10 {
        let r = i % 2 == 0 ? outer : inner
        let a = CGFloat(i) * .pi / 5 + .pi / 2
        let pt = CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a))
        i == 0 ? p.move(to: pt) : p.addLine(to: pt)
    }
    p.closeSubpath()
    return p
}
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 14, color: color(0x000000, 0.3))
ctx.setFillColor(color(0xFFC83D))
ctx.addPath(star(center: CGPoint(x: 700, y: 262), outer: 110, inner: 48)); ctx.fillPath()
ctx.restoreGState()

NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
