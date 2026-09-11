// Renders a wallpaper from a theme's palette, and sets it as the desktop image.
//
// The colours are data -- they come from themes/<name>/colors.sh, so a new
// theme gets a wallpaper without anyone drawing one. The composition below is
// code: a light wash of accent glows over the bar's own background colour,
// deliberately low-contrast so window edges stay the most legible thing on
// screen.
//
// Built by install.sh:
//   swiftc -O -o config/aerospace/bin/wallpaper \
//          config/aerospace/src/wallpaper.swift -framework AppKit

import AppKit

// MARK: - Colour

/// "0xffeff1f5" or "eff1f5" -> CGColor. colors.sh writes the former.
func parseColor(_ s: String) -> CGColor {
    var hex = s.lowercased()
    if hex.hasPrefix("0x") { hex.removeFirst(2) }
    if hex.hasPrefix("#")  { hex.removeFirst() }
    if hex.count == 8 { hex.removeFirst(2) }   // drop the alpha byte
    let v = UInt32(hex, radix: 16) ?? 0
    return CGColor(srgbRed: CGFloat((v >> 16) & 0xff) / 255,
                   green:   CGFloat((v >> 8)  & 0xff) / 255,
                   blue:    CGFloat( v        & 0xff) / 255,
                   alpha: 1)
}

func withAlpha(_ c: CGColor, _ a: CGFloat) -> CGColor {
    c.copy(alpha: a) ?? c
}

/// An accent, lightened to a pastel of the same hue.
///
/// Accents in these palettes are darkened for legibility on a light bar --
/// Rose Pine Dawn's pine is #286983. Washed over a cream background at low
/// alpha, a colour that dark reads as grey, not as pine: the hue survives but
/// the lightness drags everything towards mud. Taking the hue and discarding
/// the accent's own lightness keeps each theme's character at wallpaper scale.
func pastel(_ c: CGColor) -> CGColor {
    guard let ns = NSColor(cgColor: c)?.usingColorSpace(.sRGB) else { return c }
    var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    ns.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
    return NSColor(hue: h, saturation: min(s, 0.30), brightness: max(b, 0.96),
                   alpha: 1).cgColor
}

// MARK: - Composition

/// One accent glow: a radial gradient fading to fully transparent.
struct Glow {
    let color: CGColor
    let x: CGFloat, y: CGFloat      // centre, as a fraction of the canvas
    let radius: CGFloat             // as a fraction of the canvas width
    let alpha: CGFloat
}

func render(width: Int, height: Int, base: CGColor, deep: CGColor,
            accents: [CGColor]) -> CGImage {
    let w = CGFloat(width), h = CGFloat(height)
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: width, height: height,
                        bitsPerComponent: 8, bytesPerRow: 0, space: space,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

    ctx.setFillColor(base)
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))

    // Glows are placed off the diagonal so the centre of the screen -- where
    // windows sit -- stays the quietest part of the image.
    let layout: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
        (0.14, 0.16, 0.62, 0.50),
        (0.86, 0.80, 0.58, 0.42),
        (0.62, 0.10, 0.46, 0.24),
        (0.30, 0.92, 0.42, 0.20),
    ]
    let glows = layout.enumerated().map { i, l in
        Glow(color: pastel(accents[i % accents.count]),
             x: l.0, y: l.1, radius: l.2, alpha: l.3)
    }

    for g in glows {
        let c = CGPoint(x: g.x * w, y: g.y * h)
        let r = g.radius * w
        // Three stops, not two: a linear falloff reads as a hard-edged disc.
        let grad = CGGradient(colorsSpace: space,
                              colors: [withAlpha(g.color, g.alpha),
                                       withAlpha(g.color, g.alpha * 0.35),
                                       withAlpha(g.color, 0)] as CFArray,
                              locations: [0, 0.45, 1])!
        ctx.drawRadialGradient(grad, startCenter: c, startRadius: 0,
                               endCenter: c, endRadius: r,
                               options: .drawsAfterEndLocation)
    }

    // Vignette: pulls the corners down towards the darkest surface colour so
    // the image has a centre without adding a visible shape.
    let centre = CGPoint(x: w * 0.5, y: h * 0.5)
    let vignette = CGGradient(colorsSpace: space,
                              colors: [withAlpha(deep, 0),
                                       withAlpha(deep, 0.03),
                                       withAlpha(deep, 0.14)] as CFArray,
                              locations: [0, 0.7, 1])!
    ctx.drawRadialGradient(vignette, startCenter: centre, startRadius: 0,
                           endCenter: centre, endRadius: max(w, h) * 0.72,
                           options: .drawsAfterEndLocation)

    let flat = ctx.makeImage()!

    // Grain. Gradients this wide band badly on a light background; a little
    // monochrome noise breaks the bands up and is invisible at arm's length.
    let noise = CIFilter(name: "CIRandomGenerator")!.outputImage!
    let mono = noise.applyingFilter("CIColorMatrix", parameters: [
        "inputRVector": CIVector(x: 0.06, y: 0, z: 0, w: 0),
        "inputGVector": CIVector(x: 0.06, y: 0, z: 0, w: 0),
        "inputBVector": CIVector(x: 0.06, y: 0, z: 0, w: 0),
        "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0.045),
    ]).cropped(to: CGRect(x: 0, y: 0, width: w, height: h))

    let composited = mono.composited(over: CIImage(cgImage: flat))
    let ci = CIContext(options: [.workingColorSpace: space])
    return ci.createCGImage(composited, from: CGRect(x: 0, y: 0, width: w, height: h),
                            format: .RGBA8, colorSpace: space)!
}

// MARK: - Commands

func writePNG(_ image: CGImage, to path: String) {
    let rep = NSBitmapImageRep(cgImage: image)
    rep.size = NSSize(width: image.width, height: image.height)
    guard let data = rep.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write("wallpaper: could not encode PNG\n".data(using: .utf8)!)
        exit(1)
    }
    do { try data.write(to: URL(fileURLWithPath: path)) }
    catch {
        FileHandle.standardError.write("wallpaper: \(error.localizedDescription)\n".data(using: .utf8)!)
        exit(1)
    }
}

let args = CommandLine.arguments
func usage() -> Never {
    FileHandle.standardError.write("""
    usage: wallpaper render <out.png> <WxH> <base> <deep> <accent>...
           wallpaper set <image.png>
           wallpaper size

    """.data(using: .utf8)!)
    exit(2)
}

guard args.count >= 2 else { usage() }

switch args[1] {

case "size":
    // Pixel dimensions of the largest screen, so the render is never upscaled.
    var best = (w: 2560, h: 1440)
    for s in NSScreen.screens {
        let scale = s.backingScaleFactor
        let px = (w: Int(s.frame.width * scale), h: Int(s.frame.height * scale))
        if px.w * px.h > best.w * best.h { best = px }
    }
    print("\(best.w)x\(best.h)")

case "render":
    guard args.count >= 6 else { usage() }
    let dims = args[3].split(separator: "x").compactMap { Int($0) }
    guard dims.count == 2 else { usage() }
    let image = render(width: dims[0], height: dims[1],
                       base: parseColor(args[4]), deep: parseColor(args[5]),
                       accents: args[6...].map(parseColor))
    writePNG(image, to: args[2])
    print("\(dims[0])x\(dims[1])")

case "set":
    guard args.count == 3 else { usage() }
    let url = URL(fileURLWithPath: args[2]).standardizedFileURL
    guard FileManager.default.fileExists(atPath: url.path) else {
        FileHandle.standardError.write("wallpaper: no such file: \(url.path)\n".data(using: .utf8)!)
        exit(1)
    }
    // Every screen: setDesktopImageURL is per-NSScreen, and it reports success
    // whether or not anything changed -- the caller verifies against the
    // wallpaper store, not this exit code.
    for screen in NSScreen.screens {
        do { try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [:]) }
        catch {
            FileHandle.standardError.write("wallpaper: \(error.localizedDescription)\n".data(using: .utf8)!)
            exit(1)
        }
    }
    print(url.path)

default:
    usage()
}
