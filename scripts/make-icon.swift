import AppKit

// 生成 PieDrop 应用图标：圆角方底 + 三扇区紫环 + 白色中心
// 用法: swift scripts/make-icon.swift <iconset输出目录>

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Assets/AppIcon.iconset"

func polar(_ c: CGPoint, _ r: CGFloat, _ deg: CGFloat) -> NSPoint {
    let rad = deg * CGFloat.pi / 180
    return NSPoint(x: c.x + r * cos(rad), y: c.y + r * sin(rad))
}

func sector(_ c: CGPoint, _ ri: CGFloat, _ ro: CGFloat, _ a0: CGFloat, _ a1: CGFloat) -> NSBezierPath {
    let p = NSBezierPath()
    p.move(to: polar(c, ro, a0))
    p.appendArc(withCenter: c, radius: ro, startAngle: a0, endAngle: a1, clockwise: false)
    p.line(to: polar(c, ri, a1))
    p.appendArc(withCenter: c, radius: ri, startAngle: a1, endAngle: a0, clockwise: true)
    p.close()
    return p
}

let S: CGFloat = 1024
let image = NSImage(size: NSSize(width: S, height: S))
image.lockFocus()

// 圆角方底（macOS 图标栅格：四周留 ~10%）
let pad: CGFloat = 100
let side = S - pad * 2
let bg = NSBezierPath(roundedRect: NSRect(x: pad, y: pad, width: side, height: side),
                      xRadius: 185, yRadius: 185)
NSColor.white.setFill()
bg.fill()
NSGradient(colors: [NSColor(srgbRed: 0.99, green: 0.99, blue: 1.0, alpha: 1),
                    NSColor(srgbRed: 0.895, green: 0.895, blue: 0.925, alpha: 1)])?
    .draw(in: bg, angle: -90)
NSColor.black.withAlphaComponent(0.08).setStroke()
bg.lineWidth = 3
bg.stroke()

// 圆盘
let c = CGPoint(x: S / 2, y: S / 2)
let ro: CGFloat = 300, ri: CGFloat = 128, centerR: CGFloat = 92
let purple = NSColor(srgbRed: 0.545, green: 0.486, blue: 0.965, alpha: 1)

NSGraphicsContext.current?.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowOffset = NSSize(width: 0, height: -10)
shadow.shadowBlurRadius = 28
shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
shadow.set()

let step: CGFloat = 120, gap: CGFloat = 6
let alphas: [CGFloat] = [0.9, 0.52, 0.3]
for i in 0..<3 {
    let a0 = -90 + CGFloat(i) * step + gap / 2
    let a1 = a0 + step - gap
    let path = sector(c, ri, ro, a0, a1)
    purple.withAlphaComponent(alphas[i]).setFill()
    path.fill()
}

// 中心白圆 + 小灰点
let center = NSBezierPath(ovalIn: NSRect(x: c.x - centerR, y: c.y - centerR, width: centerR * 2, height: centerR * 2))
NSColor.white.setFill()
center.fill()
NSColor.black.withAlphaComponent(0.07).setStroke()
center.lineWidth = 3
center.stroke()
let dot = NSBezierPath(ovalIn: NSRect(x: c.x - 9, y: c.y - 9, width: 18, height: 18))
NSColor(srgbRed: 0.55, green: 0.55, blue: 0.58, alpha: 1).setFill()
dot.fill()
NSGraphicsContext.current?.restoreGraphicsState()

image.unlockFocus()

// 输出 iconset 全尺寸
let fm = FileManager.default
try? fm.createDirectory(atPath: outDir, withIntermediateDirectories: true)
let sizes: [(Int, String)] = [
    (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png"),
]
for (px, name) in sizes {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: px, height: px)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
    NSGraphicsContext.restoreGraphicsState()
    let data = rep.representation(using: .png, properties: [:])!
    try! data.write(to: URL(fileURLWithPath: outDir + "/" + name))
    print("wrote \(outDir)/\(name)")
}
