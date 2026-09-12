import AppKit

// A small keyboard-driven chooser.
//
//   picker [file]          items from <file>, or from stdin when omitted
//   PICKER_PROMPT=...      placeholder text in the search field
//
// Each input line is "label" or "label<TAB>detail"; the detail is shown dimmed
// on the right and is searchable along with the label.
//
// Prints the chosen line's label to stdout and exits 0; exits 1 when cancelled.
// Styling follows the sketchybar bar: the active theme's palette, 16pt outer
// radius with concentric 8pt rows, Berkeley Mono text.

// MARK: - Palette
//
// Read from the same file the bar reads -- ~/.config/sketchybar/colors.sh is a
// symlink into the active theme -- so the picker cannot be on a different
// palette than the bar it appears over. It used to hold Catppuccin Latte's
// values as literals, which was fine until there was more than one theme.
//
// Parsing shell from Swift is narrow on purpose: `export NAME=0xaarrggbb`, plus
// `export NAME=$OTHER` because the roles are defined that way (WS_ACTIVE_BG is
// usually an accent by reference). Anything else is skipped, and every colour
// falls back to the Latte value it had before, so a malformed or missing file
// degrades to the old look rather than to a blank window.

func hex(_ v: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((v >> 16) & 0xff) / 255,
            green:   CGFloat((v >> 8) & 0xff) / 255,
            blue:    CGFloat(v & 0xff) / 255,
            alpha:   a)
}

let themePalette: [String: UInt32] = {
    let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/sketchybar/colors.sh")
    guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [:] }
    var out: [String: UInt32] = [:]
    for raw in text.split(separator: "\n") {
        guard raw.hasPrefix("export ") else { continue }
        let body = raw.dropFirst("export ".count)
        guard let eq = body.firstIndex(of: "=") else { continue }
        let key = String(body[body.startIndex..<eq]).trimmingCharacters(in: .whitespaces)
        var value = String(body[body.index(after: eq)...])
        if let comment = value.firstIndex(of: "#") { value = String(value[..<comment]) }
        value = value.trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("$") {
            // A role defined as another colour: colors.sh always defines the
            // target above the reference, so one pass is enough.
            if let v = out[String(value.dropFirst())] { out[key] = v }
        } else if value.hasPrefix("0x"), let v = UInt32(value.dropFirst(2), radix: 16) {
            out[key] = v & 0x00ff_ffff        // drop the alpha byte
        }
    }
    return out
}()

func themed(_ name: String, _ fallback: UInt32, alpha: CGFloat = 1) -> NSColor {
    hex(themePalette[name] ?? fallback, alpha)
}

let cBase    = themed("BASE",     0xeff1f5)
let cMantle  = themed("MANTLE",   0xe6e9ef)
let cText    = themed("TEXT",     0x4c4f69)
let cSubtext = themed("SUBTEXT",  0x6c6f85)
let cSurface = themed("SURFACE0", 0xccd0da)
let cOverlay = themed("OVERLAY0", 0x9ca0b0)
// The selected row uses the same pair as the bar's focused workspace pill, so
// "this is the one" is one colour wherever it appears -- pill, window outline,
// picker row.
let cAccent   = themed("WS_ACTIVE_BG", 0x1e66f5)
let cOnAccent = themed("WS_ACTIVE_FG", 0xeff1f5)

// Text font matches the bar and terminal. Berkeley Mono installs each weight as
// its own family, so it's selected by PostScript name; falls back to the system
// font since Berkeley Mono is commercial and can't ship in the repo.
func uiFont(_ size: CGFloat, bold: Bool = false) -> NSFont {
    let ps = bold ? "BerkeleyMono-BoldSemiCondensed" : "BerkeleyMono-SemiCondensed"
    return NSFont(name: ps, size: size)
        ?? .systemFont(ofSize: size, weight: bold ? .semibold : .regular)
}

// How much vertical room the header takes, measured from the wrapped text so a
// long plan doesn't overlap the field.
var headerOffset: CGFloat = 0

let OUTER_RADIUS: CGFloat = 16
let ROW_INSET: CGFloat    = 8
let ROW_RADIUS            = OUTER_RADIUS - ROW_INSET   // concentric
let ROW_H: CGFloat        = 36
let FIELD_H: CGFloat      = 50
let FOOTER_H: CGFloat     = 30
let WIDTH: CGFloat        = 540
let MAX_ROWS              = 8

let promptText = ProcessInfo.processInfo.environment["PICKER_PROMPT"] ?? "Select"

// PICKER_MODE=input turns the picker into a single text field -- same panel,
// same fonts, same theme -- so callers never have to fall back to a stock
// AppleScript dialog, which looks nothing like the rest of this setup.
let inputMode = ProcessInfo.processInfo.environment["PICKER_MODE"] == "input"

// Optional multi-line text shown above the field, e.g. a plan awaiting consent.
let headerText = ProcessInfo.processInfo.environment["PICKER_HEADER"] ?? ""

// An optional second action on the same row. When set, shift+return prints the
// same label but exits 2, so the caller can offer a variant -- "open here" vs
// "open in a new workspace" -- without doubling the number of rows.
let altHint = ProcessInfo.processInfo.environment["PICKER_ALT_HINT"] ?? ""

// MARK: - Frecency
//
// With PICKER_CONTEXT set, remember how often each label is chosen and float
// the common ones to the top. Keyed by context so the launcher's history and
// the Chrome profile history don't contaminate each other. Without it the
// picker is stateless, as before.

let historyURL: URL? = ProcessInfo.processInfo.environment["PICKER_CONTEXT"].map { ctx in
    let base = ProcessInfo.processInfo.environment["XDG_STATE_HOME"]
        .map { URL(fileURLWithPath: $0) }
        ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".local/state")
    let dir = base.appendingPathComponent("aerospace")
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent("picker-\(ctx).history")
}

// label -> (times chosen, last chosen)
var history: [String: (count: Int, last: Double)] = [:]
if let url = historyURL, let body = try? String(contentsOf: url, encoding: .utf8) {
    for line in body.components(separatedBy: "\n") {
        let f = line.components(separatedBy: "\t")
        if f.count == 3, let c = Int(f[0]), let t = Double(f[1]) {
            history[f[2]] = (c, t)
        }
    }
}

func recordChoice(_ label: String) {
    guard let url = historyURL else { return }
    let prev = history[label] ?? (0, 0)
    history[label] = (prev.count + 1, Date().timeIntervalSince1970)
    let body = history.map { "\($0.value.count)\t\($0.value.last)\t\($0.key)" }
                      .joined(separator: "\n")
    try? body.write(to: url, atomically: true, encoding: .utf8)
}

// Higher is better. Recency decays over a week so an old favourite yields to a
// current one without vanishing.
func frecency(_ label: String) -> Double {
    guard let h = history[label] else { return 0 }
    let ageDays = (Date().timeIntervalSince1970 - h.last) / 86_400
    return Double(h.count) * (1.0 / (1.0 + ageDays / 7.0))
}

headerOffset = measureHeader(headerText, width: WIDTH - 40)

// MARK: - Input

struct Item { let label: String; let detail: String }

var items: [Item] = []
func ingest(_ lines: [String]) {
    for raw in lines {
        let line = raw.trimmingCharacters(in: .whitespaces)
        if line.isEmpty { continue }
        let parts = raw.components(separatedBy: "\t")
        items.append(Item(label: parts[0].trimmingCharacters(in: .whitespaces),
                          detail: parts.count > 1
                              ? parts[1].trimmingCharacters(in: .whitespaces) : ""))
    }
}
if CommandLine.arguments.count > 1,
   let body = try? String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8) {
    ingest(body.components(separatedBy: "\n"))
} else {
    var lines: [String] = []
    while let l = readLine(strippingNewline: true) { lines.append(l) }
    ingest(lines)
}
if items.isEmpty && !inputMode { exit(1) }

func measureHeader(_ text: String, width: CGFloat) -> CGFloat {
    if text.isEmpty { return 0 }
    let f = NSFont(name: "BerkeleyMono-SemiCondensed", size: 12)
        ?? NSFont.systemFont(ofSize: 12)
    let box = (text as NSString).boundingRect(
        with: NSSize(width: width, height: .greatestFiniteMagnitude),
        options: [.usesLineFragmentOrigin, .usesFontLeading],
        attributes: [.font: f])
    return ceil(box.height) + 26
}

// MARK: - Fuzzy match (subsequence; lower score = tighter match)

func score(_ needle: String, _ hay: String) -> Int? {
    if needle.isEmpty { return 0 }
    let n = Array(needle.lowercased())
    let h = Array(hay.lowercased())
    var i = 0, total = 0, last = -1
    for (j, ch) in h.enumerated() {
        if i < n.count && ch == n[i] {
            total += last >= 0 ? j - last - 1 : j
            last = j
            i += 1
        }
    }
    return i == n.count ? total : nil
}

// MARK: - Views

final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class RowView: NSView {
    let label  = NSTextField(labelWithString: "")
    let detail = NSTextField(labelWithString: "")

    var selected = false {
        didSet {
            layer?.backgroundColor = selected ? cAccent.cgColor : NSColor.clear.cgColor
            label.textColor  = selected ? cOnAccent : cText
            detail.textColor = selected ? cOnAccent.withAlphaComponent(0.75) : cOverlay
        }
    }

    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = ROW_RADIUS

        label.font  = uiFont(14)
        detail.font = uiFont(12)
        detail.alignment = .right
        detail.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        detail.lineBreakMode = .byTruncatingMiddle

        for v in [label, detail] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
            v.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        }
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            detail.leadingAnchor.constraint(greaterThanOrEqualTo: label.trailingAnchor,
                                            constant: 12),
            detail.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
}

final class Picker: NSObject, NSTextFieldDelegate, NSWindowDelegate {
    let panel: KeyPanel
    let field = NSTextField()
    let stack = NSStackView()
    let empty = NSTextField(labelWithString: "No matches")
    var shown: [Item] = items.enumerated()
        .sorted { a, b in
            let fa = frecency(a.element.label), fb = frecency(b.element.label)
            return fa == fb ? a.offset < b.offset : fa > fb
        }
        .map { $0.element }
    var sel = 0
    var rows: [RowView] = []
    var everBecameKey = false

    override init() {
        panel = KeyPanel(contentRect: NSRect(x: 0, y: 0, width: WIDTH, height: 200),
                         styleMask: [.borderless],
                         backing: .buffered, defer: false)
        super.init()

        panel.becomesKeyOnlyIfNeeded = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .popUpMenu
        panel.hasShadow = true
        panel.delegate = self
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let bg = NSView()
        bg.wantsLayer = true
        bg.layer?.backgroundColor = cBase.cgColor
        bg.layer?.cornerRadius = OUTER_RADIUS
        bg.layer?.borderWidth = 1
        bg.layer?.borderColor = cSurface.cgColor
        panel.contentView = bg

        // --- optional header ---
        let header = NSTextField(wrappingLabelWithString: headerText)
        header.font = uiFont(12)
        header.textColor = cSubtext
        header.isSelectable = false
        header.isHidden = headerText.isEmpty

        // --- search row ---
        let glyph = NSImageView()
        glyph.image = NSImage(systemSymbolName: inputMode ? "sparkles" : "magnifyingglass",
                              accessibilityDescription: nil)
        glyph.contentTintColor = cOverlay
        glyph.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 15,
                                                                weight: .medium)

        field.placeholderString = promptText
        field.font = uiFont(17)
        field.textColor = cText
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.delegate = self
        field.cell?.usesSingleLineMode = true

        let rule = NSView()
        rule.wantsLayer = true
        rule.layer?.backgroundColor = cSurface.cgColor

        stack.orientation = .vertical
        stack.spacing = 2
        stack.alignment = .centerX

        empty.font = uiFont(13)
        empty.textColor = cOverlay
        empty.isHidden = true

        // --- footer ---
        let footerBar = NSView()
        footerBar.wantsLayer = true
        footerBar.layer?.backgroundColor = cMantle.cgColor
        let hint = NSTextField(labelWithString: "↑↓ navigate    ↵ select    esc cancel")
        hint.font = uiFont(11)
        hint.textColor = cOverlay
        if inputMode {
            hint.stringValue = "↵ submit    esc cancel"
        } else if !altHint.isEmpty {
            hint.stringValue = "↵ select    ⇧↵ \(altHint)    esc cancel"
        }

        for v in [header, glyph, field, rule, stack, empty, footerBar, hint] {
            v.translatesAutoresizingMaskIntoConstraints = false
        }
        [header, glyph, field, rule, stack, empty, footerBar].forEach { bg.addSubview($0) }
        footerBar.addSubview(hint)

        NSLayoutConstraint.activate([
            // Centre the field vertically in its band -- an NSTextField draws
            // its text at the top of its frame, so filling the band leaves the
            // placeholder floating above centre.
            header.topAnchor.constraint(equalTo: bg.topAnchor, constant: 16),
            header.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 20),
            header.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -20),

            glyph.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 18),
            glyph.centerYAnchor.constraint(equalTo: bg.topAnchor,
                                           constant: headerOffset + FIELD_H / 2),
            glyph.widthAnchor.constraint(equalToConstant: 18),

            field.leadingAnchor.constraint(equalTo: glyph.trailingAnchor, constant: 10),
            field.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -18),
            field.centerYAnchor.constraint(equalTo: glyph.centerYAnchor),

            rule.topAnchor.constraint(equalTo: bg.topAnchor, constant: headerOffset + FIELD_H),
            rule.leadingAnchor.constraint(equalTo: bg.leadingAnchor),
            rule.trailingAnchor.constraint(equalTo: bg.trailingAnchor),
            rule.heightAnchor.constraint(equalToConstant: 1),

            stack.topAnchor.constraint(equalTo: rule.bottomAnchor, constant: ROW_INSET),
            stack.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: ROW_INSET),
            stack.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -ROW_INSET),

            empty.centerXAnchor.constraint(equalTo: bg.centerXAnchor),
            empty.topAnchor.constraint(equalTo: rule.bottomAnchor, constant: 18),

            footerBar.leadingAnchor.constraint(equalTo: bg.leadingAnchor),
            footerBar.trailingAnchor.constraint(equalTo: bg.trailingAnchor),
            footerBar.bottomAnchor.constraint(equalTo: bg.bottomAnchor),
            footerBar.heightAnchor.constraint(equalToConstant: FOOTER_H),
            hint.centerYAnchor.constraint(equalTo: footerBar.centerYAnchor),
            hint.leadingAnchor.constraint(equalTo: footerBar.leadingAnchor, constant: 18),
        ])

        rebuild()

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            guard let self else { return e }
            switch e.keyCode {
            case 125: self.move(1);  return nil          // down
            case 126: self.move(-1); return nil          // up
            case 36, 76:                                  // return / enter
                self.accept(alt: !altHint.isEmpty && e.modifierFlags.contains(.shift))
                return nil
            case 53: self.cancel(); return nil           // esc
            default: return e
            }
        }
    }

    func rebuild() {
        rows.forEach { stack.removeArrangedSubview($0); $0.removeFromSuperview() }
        rows = []
        if inputMode { empty.isHidden = true; resize(); return }
        for (i, item) in shown.prefix(MAX_ROWS).enumerated() {
            let r = RowView()
            r.label.stringValue = item.label
            r.detail.stringValue = item.detail
            r.selected = (i == sel)
            stack.addArrangedSubview(r)
            r.heightAnchor.constraint(equalToConstant: ROW_H).isActive = true
            r.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
            rows.append(r)
        }
        empty.isHidden = !rows.isEmpty
        resize()
    }

    func resize() {
        let listH: CGFloat
        if inputMode {
            listH = 0
        } else {
            listH = rows.isEmpty ? 52
                                 : CGFloat(rows.count) * ROW_H
                                   + CGFloat(max(rows.count - 1, 0)) * 2
        }
        let h = headerOffset + FIELD_H + 1 + (inputMode ? 0 : ROW_INSET)
                + listH + (inputMode ? 8 : ROW_INSET) + FOOTER_H
        guard let screen = NSScreen.main else { return }
        let v = screen.visibleFrame
        panel.setFrame(NSRect(x: v.midX - WIDTH / 2,
                              y: v.midY - h / 2 + v.height * 0.12,
                              width: WIDTH, height: h),
                       display: true)
    }

    func highlight() { for (i, r) in rows.enumerated() { r.selected = (i == sel) } }

    func move(_ d: Int) {
        guard !rows.isEmpty else { return }
        sel = max(0, min(rows.count - 1, sel + d))
        highlight()
    }

    func controlTextDidChange(_ obj: Notification) {
        if inputMode { return }
        let q = field.stringValue
        if q.isEmpty {
            // No query: most-used first, original order for anything unused.
            shown = items.enumerated()
                .sorted { a, b in
                    let fa = frecency(a.element.label), fb = frecency(b.element.label)
                    return fa == fb ? a.offset < b.offset : fa > fb
                }
                .map { $0.element }
        } else {
            // Match quality leads; frecency only breaks ties.
            shown = items
                .compactMap { it -> (Int, Item)? in
                    let hay = it.detail.isEmpty ? it.label : "\(it.label) \(it.detail)"
                    return score(q, hay).map { ($0, it) }
                }
                .sorted { a, b in
                    a.0 == b.0 ? frecency(a.1.label) > frecency(b.1.label) : a.0 < b.0
                }
                .map { $0.1 }
        }
        sel = 0
        rebuild()
    }

    func accept(alt: Bool = false) {
        if inputMode {
            let typed = field.stringValue.trimmingCharacters(in: .whitespaces)
            if typed.isEmpty { cancel(); return }
            FileHandle.standardOutput.write((typed + "\n").data(using: .utf8)!)
            exit(0)
        }
        guard sel < shown.count, !rows.isEmpty else { cancel(); return }
        recordChoice(shown[sel].label)
        FileHandle.standardOutput.write((shown[sel].label + "\n").data(using: .utf8)!)
        // 2 distinguishes the alternate action from the normal one; the label
        // is identical either way, so callers branch on the status.
        exit(alt ? 2 : 0)
    }

    func cancel() { exit(1) }
    func windowDidBecomeKey(_ n: Notification) { everBecameKey = true }
    func windowDidResignKey(_ n: Notification) { if everBecameKey { cancel() } }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(field)
        // The caret defaults to the system accent colour; tie it to the theme.
        (field.currentEditor() as? NSTextView)?.insertionPointColor = cAccent
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let picker = Picker()
app.activate(ignoringOtherApps: true)
picker.show()
app.run()
