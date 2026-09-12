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
/// On a dark theme the accents are already bright, and a bright wash over
/// near-black reads as fog rather than as the colour. So the lightness comes
/// from the appearance, not from the accent; only the hue survives either way.
func glowColor(_ c: CGColor, dark: Bool) -> CGColor {
    guard let ns = NSColor(cgColor: c)?.usingColorSpace(.sRGB) else { return c }
    var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    ns.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
    return dark
        ? NSColor(hue: h, saturation: min(max(s, 0.45), 0.75), brightness: 0.42, alpha: 1).cgColor
        : NSColor(hue: h, saturation: min(s, 0.30), brightness: max(b, 0.96), alpha: 1).cgColor
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
            accents: [CGColor], dark: Bool) -> CGImage {
    let w = CGFloat(width), h = CGFloat(height)
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: width, height: height,
                        bitsPerComponent: 8, bytesPerRow: 0, space: space,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

    ctx.setFillColor(base)
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))

    // Glows are placed off the diagonal so the centre of the screen -- where
    // windows sit -- stays the quietest part of the image.
    // A dark theme needs more of the glow to show at all: the same alpha that
    // tints an off-white base is invisible against near-black.
    let layout: [(CGFloat, CGFloat, CGFloat, CGFloat)] = dark ? [
        (0.14, 0.16, 0.62, 0.78),
        (0.86, 0.80, 0.58, 0.62),
        (0.62, 0.10, 0.46, 0.38),
        (0.30, 0.92, 0.42, 0.30),
    ] : [
        (0.14, 0.16, 0.62, 0.50),
        (0.86, 0.80, 0.58, 0.42),
        (0.62, 0.10, 0.46, 0.24),
        (0.30, 0.92, 0.42, 0.20),
    ]
    let glows = layout.enumerated().map { i, l in
        Glow(color: glowColor(accents[i % accents.count], dark: dark),
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

    return grain(ctx.makeImage()!, width: width, height: height)
}

/// Gradients this wide band badly -- worst on a light background, but visible
/// in a night sky too. A little monochrome noise breaks the bands up and is
/// invisible at arm's length.
func grain(_ image: CGImage, width: Int, height: Int) -> CGImage {
    let w = CGFloat(width), h = CGFloat(height)
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let noise = CIFilter(name: "CIRandomGenerator")!.outputImage!
    let mono = noise.applyingFilter("CIColorMatrix", parameters: [
        "inputRVector": CIVector(x: 0.06, y: 0, z: 0, w: 0),
        "inputGVector": CIVector(x: 0.06, y: 0, z: 0, w: 0),
        "inputBVector": CIVector(x: 0.06, y: 0, z: 0, w: 0),
        "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0.045),
    ]).cropped(to: CGRect(x: 0, y: 0, width: w, height: h))
    let composited = mono.composited(over: CIImage(cgImage: image))
    let ci = CIContext(options: [.workingColorSpace: space])
    return ci.createCGImage(composited, from: CGRect(x: 0, y: 0, width: w, height: h),
                            format: .RGBA8, colorSpace: space)!
}

// MARK: - The wallpaper store
//
// macOS 14 replaced the old desktop-picture defaults with a single store that
// holds both the desktop image and the screen saver ("Idle"), per display and
// per space:
//
//   ~/Library/Application Support/com.apple.wallpaper/Store/Index.plist
//
// There is no public API for the Idle half -- NSWorkspace only sets the
// desktop. So `link-idle` copies the Desktop node macOS itself just wrote over
// the Idle node, which means the schema is never hand-built: whatever the OS
// considers a valid choice is what gets written back.

let storeURL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Application Support/com.apple.wallpaper/Store/Index.plist")

func die(_ msg: String) -> Never {
    FileHandle.standardError.write("wallpaper: \(msg)\n".data(using: .utf8)!)
    exit(1)
}

func loadStore() -> NSMutableDictionary {
    guard let data = try? Data(contentsOf: storeURL),
          let obj = try? PropertyListSerialization.propertyList(
              from: data, options: [], format: nil),
          let dict = obj as? NSDictionary
    else { die("could not read \(storeURL.path)") }
    return deepCopy(dict)
}

/// A true deep mutable copy -- mutableCopy() is one level only.
func deepCopy(_ d: NSDictionary) -> NSMutableDictionary {
    guard let data = try? PropertyListSerialization.data(
              fromPropertyList: d, format: .binary, options: 0),
          let obj = try? PropertyListSerialization.propertyList(
              from: data, options: [.mutableContainersAndLeaves], format: nil),
          let copy = obj as? NSMutableDictionary
    else { die("could not copy the wallpaper store") }
    return copy
}

/// Visit every dictionary in the tree.
func visit(_ node: Any, _ body: (NSMutableDictionary) -> Void) {
    if let d = node as? NSMutableDictionary {
        body(d)
        for v in d.allValues { visit(v, body) }
    } else if let a = node as? NSArray {
        for v in a { visit(v, body) }
    }
}

/// provider + image path of a Desktop/Idle node, for reporting.
func describeChoice(_ node: Any?) -> (provider: String, path: String?) {
    guard let d = node as? NSDictionary,
          let choice = ((d["Content"] as? NSDictionary)?["Choices"] as? NSArray)?
              .firstObject as? NSDictionary
    else { return ("none", nil) }
    let provider = (choice["Provider"] as? String) ?? "unknown"
    var path: String? = nil
    if let cfg = choice["Configuration"] as? Data,
       let inner = try? PropertyListSerialization.propertyList(
           from: cfg, options: [], format: nil) as? NSDictionary,
       let url = (inner["url"] as? NSDictionary)?["relative"] as? String {
        path = URL(string: url)?.path ?? url
    }
    return (provider, path)
}


// MARK: - Composition: grid
//
// The other one. `glow` is a wash that stays out of the way; this is a picture,
// and a theme asks for it by name (WALLPAPER_STYLE=grid) rather than the
// renderer guessing from the colours.
//
// Sun, horizon, perspective grid. The horizon sits low so the busiest part of
// the image is below where windows are, and the grid is drawn as a wide dim
// pass under a narrow bright one -- one stroke reads as a hairline, two read
// as something glowing.
func renderGrid(width: Int, height: Int, base: CGColor, deep: CGColor,
                accents: [CGColor]) -> CGImage {
    let w = CGFloat(width), h = CGFloat(height)
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(data: nil, width: width, height: height,
                        bitsPerComponent: 8, bytesPerRow: 0, space: space,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

    // Colours in declared order: sun top, sun bottom, grid, sky.
    let sunTop = accents.count > 0 ? accents[0] : base
    let sunBot = accents.count > 1 ? accents[1] : sunTop
    let grid   = accents.count > 2 ? accents[2] : sunTop
    let sky    = accents.count > 3 ? accents[3] : sunBot

    let horizon = h * 0.38

    ctx.setFillColor(base)
    ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))

    // Sky: dark overhead, warming as it approaches the horizon.
    let skyGrad = CGGradient(colorsSpace: space,
                             colors: [withAlpha(base, 0),
                                      withAlpha(sky, 0.22),
                                      withAlpha(sunBot, 0.42)] as CFArray,
                             locations: [0, 0.62, 1])!
    ctx.drawLinearGradient(skyGrad, start: CGPoint(x: 0, y: h),
                           end: CGPoint(x: 0, y: horizon), options: [])

    // Stars, thinning out towards the horizon haze. Deterministic: a wallpaper
    // that reshuffles every render is a diff nobody wants.
    var seed: UInt64 = 0x5eed
    func rnd() -> CGFloat {
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        return CGFloat((seed >> 33) % 100_000) / 100_000
    }
    for _ in 0..<420 {
        let x = rnd() * w
        let y = horizon + rnd() * (h - horizon)
        let fade = (y - horizon) / (h - horizon)
        ctx.setFillColor(withAlpha(.white, 0.45 * fade * fade))
        let r = 1 + rnd() * 1.6
        ctx.fillEllipse(in: CGRect(x: x, y: y, width: r, height: r))
    }

    // The sun, sitting on the horizon with its lower half cut into bands.
    let sunR = w * 0.115
    let sunC = CGPoint(x: w * 0.5, y: horizon + sunR * 0.52)
    ctx.saveGState()
    // Clipped at the horizon as well as to the circle: the sun sits *on* the
    // line rather than hanging in front of the grid.
    ctx.clip(to: CGRect(x: 0, y: horizon, width: w, height: h - horizon))
    ctx.addEllipse(in: CGRect(x: sunC.x - sunR, y: sunC.y - sunR,
                              width: sunR * 2, height: sunR * 2))
    ctx.clip()
    let sunGrad = CGGradient(colorsSpace: space,
                             colors: [sunBot, sunTop] as CFArray,
                             locations: [0, 1])!
    ctx.drawLinearGradient(sunGrad, start: CGPoint(x: 0, y: sunC.y - sunR),
                           end: CGPoint(x: 0, y: sunC.y + sunR), options: [])
    // Bands: thicker and closer together further down, which is what makes it
    // read as a sun setting rather than a striped circle.
    var bandY = sunC.y + sunR * 0.06
    var bandH = sunR * 0.035
    while bandY > sunC.y - sunR {
        ctx.setFillColor(base)
        ctx.fill(CGRect(x: sunC.x - sunR, y: bandY, width: sunR * 2, height: bandH))
        bandY -= bandH * 2.25
        bandH *= 1.22
    }
    ctx.restoreGState()

    // Horizon: a bright line with a soft bloom over it.
    let bloom = CGGradient(colorsSpace: space,
                           colors: [withAlpha(sunBot, 0), withAlpha(sunBot, 0.5),
                                    withAlpha(sunBot, 0)] as CFArray,
                           locations: [0, 0.5, 1])!
    ctx.saveGState()
    ctx.clip(to: CGRect(x: 0, y: horizon - h * 0.05, width: w, height: h * 0.1))
    ctx.drawLinearGradient(bloom, start: CGPoint(x: 0, y: horizon - h * 0.05),
                           end: CGPoint(x: 0, y: horizon + h * 0.05), options: [])
    ctx.restoreGState()

    // The grid, below the horizon, converging on the sun.
    ctx.saveGState()
    ctx.clip(to: CGRect(x: 0, y: 0, width: w, height: horizon))
    let vanish = CGPoint(x: w * 0.5, y: horizon)

    func stroke(_ path: CGPath) {
        ctx.addPath(path); ctx.setStrokeColor(withAlpha(grid, 0.18))
        ctx.setLineWidth(w * 0.006); ctx.strokePath()
        ctx.addPath(path); ctx.setStrokeColor(withAlpha(grid, 0.85))
        ctx.setLineWidth(w * 0.0014); ctx.strokePath()
    }

    for i in -24...24 {
        let p = CGMutablePath()
        p.move(to: vanish)
        p.addLine(to: CGPoint(x: w * 0.5 + CGFloat(i) * w * 0.085, y: 0))
        stroke(p)
    }
    // Horizontal rungs: spacing grows towards the viewer, so the ground reads
    // as receding rather than as a ladder.
    var y = horizon, step = horizon * 0.012
    while y > 0 {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: w, y: y))
        stroke(p)
        y -= step
        step *= 1.42
    }
    ctx.restoreGState()

    // Corner falloff, the same idea as the wash's vignette.
    let centre = CGPoint(x: w * 0.5, y: h * 0.5)
    let vign = CGGradient(colorsSpace: space,
                          colors: [withAlpha(deep, 0), withAlpha(deep, 0.10),
                                   withAlpha(deep, 0.38)] as CFArray,
                          locations: [0, 0.6, 1])!
    ctx.drawRadialGradient(vign, startCenter: centre, startRadius: 0,
                           endCenter: centre, endRadius: max(w, h) * 0.72,
                           options: .drawsAfterEndLocation)

    return grain(ctx.makeImage()!, width: width, height: height)
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
           wallpaper propagate <desktop|both>
           wallpaper store
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
    guard args.count >= 8, ["light", "dark"].contains(args[4]),
          ["glow", "grid"].contains(args[5]) else { usage() }
    let dims = args[3].split(separator: "x").compactMap { Int($0) }
    guard dims.count == 2 else { usage() }
    let accents = args[8...].map(parseColor)
    let image = args[5] == "grid"
        ? renderGrid(width: dims[0], height: dims[1],
                     base: parseColor(args[6]), deep: parseColor(args[7]),
                     accents: accents)
        : render(width: dims[0], height: dims[1],
                 base: parseColor(args[6]), deep: parseColor(args[7]),
                 accents: accents, dark: args[4] == "dark")
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

case "propagate":
    // Copy the desktop choice macOS just wrote over every other entry in the
    // store: the other displays (including ones not currently attached, which
    // the public API cannot reach and which would otherwise keep serving a
    // stale image when they come back), and -- with "both" -- the screen
    // saver, which has no public API at all.
    //
    // Nothing here is hand-built. Whatever shape the OS considers a valid
    // choice is the shape that gets written back.
    guard args.count == 3, ["desktop", "both"].contains(args[2]) else { usage() }
    let both = args[2] == "both"
    let root = loadStore()
    guard let canonical = root.value(forKeyPath: "SystemDefault.Desktop") as? NSDictionary
    else { die("the store has no SystemDefault.Desktop to copy from") }
    var patched = 0
    visit(root) { node in
        if node["Desktop"] != nil {
            node["Desktop"] = deepCopy(canonical); patched += 1
        }
        if both, node["Idle"] != nil {
            node["Idle"] = deepCopy(canonical); patched += 1
            // A node holding both halves must say they are set independently,
            // or the OS goes on serving them as a linked pair.
            if node["Type"] != nil && node["Desktop"] != nil {
                node["Type"] = "individual"
            }
        }
    }
    guard patched > 0 else { die("no entries found in the store") }
    guard let out = try? PropertyListSerialization.data(
            fromPropertyList: root, format: .binary, options: 0)
    else { die("could not serialise the store") }
    do { try out.write(to: storeURL) }
    catch { die(error.localizedDescription) }
    print("patched \(patched)")

case "store":
    // What the world actually contains -- the caller verifies against this,
    // never against an exit code.
    let root = loadStore()
    var rows: [String] = []
    func report(_ label: String, _ node: NSMutableDictionary) {
        for half in ["Desktop", "Idle"] where node[half] != nil {
            let c = describeChoice(node[half])
            rows.append("\(label)\t\(half)\t\(c.provider)\t\(c.path ?? "-")")
        }
    }
    for key in ["SystemDefault", "AllSpacesAndDisplays"] {
        if let n = root[key] as? NSMutableDictionary { report(key, n) }
    }
    if let displays = root["Displays"] as? NSMutableDictionary {
        for (k, v) in displays {
            if let n = v as? NSMutableDictionary { report("Display:\(k)", n) }
        }
    }
    print(rows.joined(separator: "\n"))

default:
    usage()
}
