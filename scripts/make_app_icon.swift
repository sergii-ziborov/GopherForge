#!/usr/bin/env swift

// Renders the GopherForge app icon.
//
// The mark is original artwork: our own gopher, drawn from circles, in the
// colours the Go project publishes for itself. It deliberately does not
// reproduce the Go gopher, which is Renée French's design and not ours to
// ship — different silhouette, different palette arrangement, different face.
// A mascot on the icon has to be one we can register as ours.
//
// Generated rather than hand-drawn so the icon is reproducible from source and
// a colour change is a one-line diff instead of a binary swap.
//
// Written without an alpha channel on purpose: App Store Connect rejects a
// transparent marketing icon at upload, long after the archive, with a message
// that does not name the file. scripts/check_app_icon.sh guards the same rule
// at build time.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let side = 1024
let output = CommandLine.arguments.count > 1
    ? URL(fileURLWithPath: CommandLine.arguments[1])
    : URL(fileURLWithPath: "GopherForgeIcon-1024.png")

let space = CGColorSpace(name: CGColorSpace.sRGB)!

guard let context = CGContext(
    data: nil,
    width: side,
    height: side,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: space,
    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
) else {
    fatalError("could not create the drawing context")
}

let size = CGFloat(side)

/// Fractions of the canvas rather than pixels, so the drawing scales with the
/// icon instead of being tuned to 1024 alone.
func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
    CGPoint(x: size * x, y: size * y)
}

func length(_ fraction: CGFloat) -> CGFloat { size * fraction }

func circle(_ centre: CGPoint, _ radius: CGFloat) -> CGRect {
    CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2)
}

// Go's published palette, plus the two darker values its own site uses where a
// bright fill would not carry.
func rgb(_ hex: UInt32) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: 1
    )
}

let gopherBlue = rgb(0x00ADD8)
let deepBlue = rgb(0x00566E)
let sky = rgb(0x5DC9E2)
let berry = rgb(0xCE3262)
let sun = rgb(0xFDDD00)
let ink = rgb(0x0E3648)
let cream = rgb(0xF6F4EE)

// MARK: - Ground

let ground = CGGradient(
    colorsSpace: space,
    colors: [gopherBlue, deepBlue] as CFArray,
    locations: [0, 1]
)!
context.drawLinearGradient(
    ground,
    start: point(0, 1),
    end: point(1, 0),
    options: []
)

// A soft light behind the head, so the mark sits on the square rather than
// floating over a flat field.
let halo = CGGradient(
    colorsSpace: space,
    colors: [
        CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.22),
        CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0),
    ] as CFArray,
    locations: [0, 1]
)!
context.drawRadialGradient(
    halo,
    startCenter: point(0.5, 0.52),
    startRadius: 0,
    endCenter: point(0.5, 0.52),
    endRadius: length(0.52),
    options: []
)

// MARK: - Ears

// Drawn before the head so the head overlaps them: an ear that is a separate
// circle stuck on the side reads as a sticker, and one the head grows out of
// reads as an animal.
//
// Small and set high. Large round ears on a round head is a bear, whatever
// else is on the face — the first draft of this icon was one.
for centre in [point(0.315, 0.715), point(0.685, 0.715)] {
    context.setFillColor(cream)
    context.fillEllipse(in: circle(centre, length(0.079)))
    context.setFillColor(sky)
    context.fillEllipse(in: circle(centre, length(0.037)))
}

// MARK: - Head

context.setFillColor(cream)
context.fillEllipse(
    in: CGRect(
        x: length(0.225),
        y: length(0.195),
        width: length(0.55),
        height: length(0.545)
    )
)

// MARK: - Eyes

// Big, wide-set and outlined. At 40 points on a home screen the eyes are the
// whole character; everything else is texture.
for centre in [point(0.378, 0.556), point(0.622, 0.556)] {
    context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
    context.fillEllipse(in: circle(centre, length(0.090)))

    context.setStrokeColor(ink)
    context.setLineWidth(length(0.013))
    context.strokeEllipse(in: circle(centre, length(0.090)))

    context.setFillColor(ink)
    context.fillEllipse(
        in: circle(CGPoint(x: centre.x, y: centre.y - length(0.008)), length(0.046))
    )

    context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.92))
    context.fillEllipse(
        in: circle(
            CGPoint(x: centre.x - length(0.016), y: centre.y + length(0.016)),
            length(0.017)
        )
    )
}

// MARK: - Muzzle, nose and teeth

// A muzzle patch, then the nose on it, then the teeth hanging off the nose.
// Drawn as one stack on purpose: the first draft had the teeth floating below
// a gap and the whole thing read as a light switch.
context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
context.fillEllipse(
    in: CGRect(
        x: size * 0.5 - length(0.175),
        y: length(0.245),
        width: length(0.35),
        height: length(0.215)
    )
)

// Whiskers as dots rather than lines: three a side, which is what says rodent
// at a size where a hairline would disappear.
context.setFillColor(ink)
for side in [CGFloat(-1), 1] {
    for (dx, dy) in [(0.128, 0.048), (0.152, 0.012), (0.128, -0.024)] {
        context.fillEllipse(
            in: circle(
                CGPoint(x: size * 0.5 + side * length(dx), y: length(0.355 + dy)),
                length(0.0095)
            )
        )
    }
}

let noseCentre = point(0.5, 0.412)
let nose = CGMutablePath()
nose.move(to: CGPoint(x: noseCentre.x - length(0.046), y: noseCentre.y + length(0.018)))
nose.addQuadCurve(
    to: CGPoint(x: noseCentre.x + length(0.046), y: noseCentre.y + length(0.018)),
    control: CGPoint(x: noseCentre.x, y: noseCentre.y + length(0.050))
)
nose.addQuadCurve(
    to: CGPoint(x: noseCentre.x, y: noseCentre.y - length(0.036)),
    control: CGPoint(x: noseCentre.x + length(0.044), y: noseCentre.y - length(0.020))
)
nose.addQuadCurve(
    to: CGPoint(x: noseCentre.x - length(0.046), y: noseCentre.y + length(0.018)),
    control: CGPoint(x: noseCentre.x - length(0.044), y: noseCentre.y - length(0.020))
)
nose.closeSubpath()
context.addPath(nose)
context.setFillColor(berry)
context.fillPath()

// Two front teeth, which is the one feature that says rodent without a tail.
// Their top edge sits under the nose rather than below a gap.
let teeth = CGRect(
    x: size * 0.5 - length(0.068),
    y: length(0.272),
    width: length(0.136),
    height: length(0.098)
)
let toothPath = CGPath(
    roundedRect: teeth,
    cornerWidth: length(0.026),
    cornerHeight: length(0.026),
    transform: nil
)
context.addPath(toothPath)
context.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
context.fillPath()
context.addPath(toothPath)
context.setStrokeColor(ink)
context.setLineWidth(length(0.009))
context.strokePath()

context.setStrokeColor(ink)
context.setLineWidth(length(0.010))
context.move(to: CGPoint(x: teeth.midX, y: teeth.minY + length(0.010)))
context.addLine(to: CGPoint(x: teeth.midX, y: teeth.maxY - length(0.012)))
context.strokePath()

// MARK: - Spark

// The forge half of the name, in Go's yellow: a four-pointed spark, off centre
// so the icon reads as a moment rather than a symmetrical logo lockup.
let sparkCentre = point(0.175, 0.845)
let long = length(0.090)
let short = length(0.022)

let spark = CGMutablePath()
spark.move(to: CGPoint(x: sparkCentre.x, y: sparkCentre.y + long))
spark.addQuadCurve(
    to: CGPoint(x: sparkCentre.x + long, y: sparkCentre.y),
    control: CGPoint(x: sparkCentre.x + short, y: sparkCentre.y + short)
)
spark.addQuadCurve(
    to: CGPoint(x: sparkCentre.x, y: sparkCentre.y - long),
    control: CGPoint(x: sparkCentre.x + short, y: sparkCentre.y - short)
)
spark.addQuadCurve(
    to: CGPoint(x: sparkCentre.x - long, y: sparkCentre.y),
    control: CGPoint(x: sparkCentre.x - short, y: sparkCentre.y - short)
)
spark.addQuadCurve(
    to: CGPoint(x: sparkCentre.x, y: sparkCentre.y + long),
    control: CGPoint(x: sparkCentre.x - short, y: sparkCentre.y + short)
)
spark.closeSubpath()

context.addPath(spark)
context.setFillColor(sun)
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
