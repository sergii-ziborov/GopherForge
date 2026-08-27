#!/usr/bin/env swift

// Renders the GopherForge app icon.
//
// The mark is original artwork: an anvil struck by a spark, with two ears
// suggested by the anvil's horns. It deliberately does not reproduce the Go
// gopher, which is Renée French's design and not ours to ship.
//
// Generated rather than hand-drawn so the icon is reproducible from source and
// a colour change is a one-line diff instead of a binary swap.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let side = 1024
let output = CommandLine.arguments.count > 1
    ? URL(fileURLWithPath: CommandLine.arguments[1])
    : URL(fileURLWithPath: "GopherForgeIcon-1024.png")

guard let context = CGContext(
    data: nil,
    width: side,
    height: side,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("could not create the drawing context")
}

let size = CGFloat(side)

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
}

// Slate ground, warm at the bottom as if lit from the forge.
let slateTop = color(0.11, 0.14, 0.18)
let slateBottom = color(0.20, 0.15, 0.13)
let ember = color(0.85, 0.45, 0.16)
let emberBright = color(0.98, 0.70, 0.32)

let gradient = CGGradient(
    colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
    colors: [slateTop, slateBottom] as CFArray,
    locations: [0, 1]
)!
context.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: size),
    end: CGPoint(x: 0, y: 0),
    options: []
)

// The glow the anvil sits in.
let glow = CGGradient(
    colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
    colors: [color(0.85, 0.45, 0.16, 0.55), color(0.85, 0.45, 0.16, 0)] as CFArray,
    locations: [0, 1]
)!
context.drawRadialGradient(
    glow,
    startCenter: CGPoint(x: size / 2, y: size * 0.36),
    startRadius: 0,
    endCenter: CGPoint(x: size / 2, y: size * 0.36),
    endRadius: size * 0.42,
    options: []
)

// MARK: - Anvil

// Proportions are expressed as fractions of the canvas so the shape scales
// with the icon rather than being tuned to 1024 alone.
let anvil = CGMutablePath()
let baseY = size * 0.26
let bodyTopY = size * 0.52
let waistY = size * 0.38

anvil.move(to: CGPoint(x: size * 0.30, y: baseY))
anvil.addLine(to: CGPoint(x: size * 0.70, y: baseY))
anvil.addLine(to: CGPoint(x: size * 0.62, y: waistY))
anvil.addLine(to: CGPoint(x: size * 0.66, y: waistY))
anvil.addLine(to: CGPoint(x: size * 0.66, y: bodyTopY - size * 0.06))

// Right horn, drawn as an ear.
anvil.addCurve(
    to: CGPoint(x: size * 0.78, y: bodyTopY),
    control1: CGPoint(x: size * 0.72, y: bodyTopY - size * 0.05),
    control2: CGPoint(x: size * 0.78, y: bodyTopY - size * 0.03)
)
anvil.addCurve(
    to: CGPoint(x: size * 0.64, y: bodyTopY + size * 0.03),
    control1: CGPoint(x: size * 0.78, y: bodyTopY + size * 0.04),
    control2: CGPoint(x: size * 0.71, y: bodyTopY + size * 0.05)
)
anvil.addLine(to: CGPoint(x: size * 0.36, y: bodyTopY + size * 0.03))

// Left horn.
anvil.addCurve(
    to: CGPoint(x: size * 0.22, y: bodyTopY),
    control1: CGPoint(x: size * 0.29, y: bodyTopY + size * 0.05),
    control2: CGPoint(x: size * 0.22, y: bodyTopY + size * 0.04)
)
anvil.addCurve(
    to: CGPoint(x: size * 0.34, y: bodyTopY - size * 0.06),
    control1: CGPoint(x: size * 0.22, y: bodyTopY - size * 0.03),
    control2: CGPoint(x: size * 0.28, y: bodyTopY - size * 0.05)
)
anvil.addLine(to: CGPoint(x: size * 0.34, y: waistY))
anvil.addLine(to: CGPoint(x: size * 0.38, y: waistY))
anvil.closeSubpath()

context.addPath(anvil)
context.setFillColor(ember)
context.fillPath()

// MARK: - Spark

// A four-pointed spark above the anvil, offset so the icon is not symmetric
// and reads as a moment rather than a logo lockup.
let sparkCenter = CGPoint(x: size * 0.60, y: size * 0.70)
let sparkLong = size * 0.14
let sparkShort = size * 0.035

let spark = CGMutablePath()
spark.move(to: CGPoint(x: sparkCenter.x, y: sparkCenter.y + sparkLong))
spark.addQuadCurve(
    to: CGPoint(x: sparkCenter.x + sparkShort, y: sparkCenter.y),
    control: CGPoint(x: sparkCenter.x + sparkShort * 0.4, y: sparkCenter.y + sparkShort)
)
spark.addQuadCurve(
    to: CGPoint(x: sparkCenter.x + sparkLong * 0.72, y: sparkCenter.y),
    control: CGPoint(x: sparkCenter.x + sparkShort * 2, y: sparkCenter.y + sparkShort * 0.3)
)
spark.addQuadCurve(
    to: CGPoint(x: sparkCenter.x + sparkShort, y: sparkCenter.y),
    control: CGPoint(x: sparkCenter.x + sparkShort * 2, y: sparkCenter.y - sparkShort * 0.3)
)
spark.addQuadCurve(
    to: CGPoint(x: sparkCenter.x, y: sparkCenter.y - sparkLong),
    control: CGPoint(x: sparkCenter.x + sparkShort * 0.4, y: sparkCenter.y - sparkShort)
)
spark.addQuadCurve(
    to: CGPoint(x: sparkCenter.x - sparkShort, y: sparkCenter.y),
    control: CGPoint(x: sparkCenter.x - sparkShort * 0.4, y: sparkCenter.y - sparkShort)
)
spark.addQuadCurve(
    to: CGPoint(x: sparkCenter.x - sparkLong * 0.72, y: sparkCenter.y),
    control: CGPoint(x: sparkCenter.x - sparkShort * 2, y: sparkCenter.y - sparkShort * 0.3)
)
spark.addQuadCurve(
    to: CGPoint(x: sparkCenter.x - sparkShort, y: sparkCenter.y),
    control: CGPoint(x: sparkCenter.x - sparkShort * 2, y: sparkCenter.y + sparkShort * 0.3)
)
spark.addQuadCurve(
    to: CGPoint(x: sparkCenter.x, y: sparkCenter.y + sparkLong),
    control: CGPoint(x: sparkCenter.x - sparkShort * 0.4, y: sparkCenter.y + sparkShort)
)
spark.closeSubpath()

context.addPath(spark)
context.setFillColor(emberBright)
context.fillPath()

guard let image = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(
        output as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
      )
else {
    fatalError("could not encode the icon")
}

CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else {
    fatalError("could not write \(output.path)")
}

print("Wrote \(output.path)")
