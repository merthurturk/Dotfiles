// Where every window actually is.
//
// AeroSpace reports which workspace a window is on, but not its frame, and the
// obvious substitutes all lie:
//
//   - AppleScript `bounds` reports a browser's parked position for any window
//     on a workspace you are not looking at. It cost three misdiagnoses here.
//   - System Events needs Automation permission per app and takes ~0.8s.
//   - A screenshot tells you nothing about a workspace that is not on screen.
//
// CGWindowListCopyWindowInfo needs no permission at all and sees every window,
// on screen or not. Usefully, the kCGWindowNumber it reports is the same id
// AeroSpace uses, so the two lists join on it without any title matching.
//
// Output is one tab-separated row per window:
//   <window-id> <x> <y> <width> <height> <app> <title>
//
// Note what this can and cannot tell you. A window on a *hidden* workspace has
// no meaningful frame: AeroSpace parks it off-screen at whatever size it last
// had. That is a fact worth being able to see, not a bug to paper over, so the
// numbers are reported as they are and the caller decides.

import CoreGraphics
import Foundation

let opts = CGWindowListOption.excludeDesktopElements
guard let list = CGWindowListCopyWindowInfo(opts, kCGNullWindowID) as? [[String: Any]] else {
    FileHandle.standardError.write(Data("geometry: could not read the window list\n".utf8))
    exit(1)
}

for w in list {
    // Layer 0 is the ordinary window layer. Everything else is menu bars,
    // panels, shadows and the rest of the furniture -- SketchyBar alone
    // accounts for a dozen rows.
    guard let layer = w[kCGWindowLayer as String] as? Int, layer == 0,
          let bounds = w[kCGWindowBounds as String] as? [String: Any],
          let x = bounds["X"] as? Double, let y = bounds["Y"] as? Double,
          let width = bounds["Width"] as? Double,
          let height = bounds["Height"] as? Double,
          let id = w[kCGWindowNumber as String] as? Int else { continue }

    // Tooltips, autofill popovers and the like. A real window is bigger than
    // this, and nothing that tiles is smaller.
    if width < 120 || height < 80 { continue }

    let app = (w[kCGWindowOwnerName as String] as? String ?? "?")
    let title = (w[kCGWindowName as String] as? String ?? "")
        .replacingOccurrences(of: "\t", with: " ")
    print("\(id)\t\(Int(x))\t\(Int(y))\t\(Int(width))\t\(Int(height))\t\(app)\t\(title)")
}
