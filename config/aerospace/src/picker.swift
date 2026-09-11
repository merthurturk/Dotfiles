import AppKit

// A small keyboard-driven chooser.
//
//   picker [file]          items from <file>, or from stdin when omitted
//   PICKER_PROMPT=...      placeholder text in the search field
//
// Prints the chosen line to stdout and exits 0; exits 1 when cancelled.
// Styling follows the sketchybar bar: Catppuccin Latte, 16pt outer radius with
// concentric 8pt rows.

// MARK: - Palette (Catppuccin Latte)

func hex(_ v: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((v >> 16) & 0xff) / 255,
            green:   CGFloat((v >> 8) & 0xff) / 255,
            blue:    CGFloat(v & 0xff) / 255,
            alpha:   a)
}
let cBase     = hex(0xeff1f5)
let cText     = hex(0x4c4f69)
let cSubtext  = hex(0x6c6f85)
let cSurface  = hex(0xccd0da)
let cBlue     = hex(0x1e66f5)
let cOverlay  = hex(0x9ca0b0)

let OUTER_RADIUS: CGFloat = 16
let ROW_INSET: CGFloat    = 8
let ROW_RADIUS            = OUTER_RADIUS - ROW_INSET   // concentric
let ROW_H: CGFloat        = 34
let FIELD_H: CGFloat      = 52
let WIDTH: CGFloat        = 520
let MAX_ROWS              = 8

// MARK: - Input

var items: [String] = []
if CommandLine.arguments.count > 1,
   let body = try? String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8) {
    items = body.components(separatedBy: "\n")
} else {
    while let line = readLine(strippingNewline: true) { items.append(line) }
}
items = items.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
if items.isEmpty { exit(1) }

let promptText = ProcessInfo.processInfo.environment["PICKER_PROMPT"] ?? "Select"

// MARK: - Fuzzy match (subsequence; lower score = tighter match)

func score(_ needle: String, _ hay: String) -> Int? {
    if needle.isEmpty { return 0 }
    let n = Array(needle.lowercased())
    let h = Array(hay.lowercased())
    var i = 0, total = 0, last = -1
    for (j, ch) in h.enumerated() {
        if i < n.count && ch == n[i] {
            if last >= 0 { total += j - last - 1 }
            else { total += j }          // prefer matches near the start
            last = j
            i += 1
        }
    }
    return i == n.count ? total : nil
}

// MARK: - Window

final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

final class RowView: NSView {
    let label = NSTextField(labelWithString: "")
    var selected = false {
        didSet {
            layer?.backgroundColor = selected ? cBlue.cgColor : NSColor.clear.cgColor
            label.textColor = selected ? cBase : cText
        }
    }
    init() {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = ROW_RADIUS
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -14),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }
}

final class Picker: NSObject, NSTextFieldDelegate, NSWindowDelegate {
    let panel: KeyPanel
    let field = NSTextField()
    let stack = NSStackView()
    var shown: [String] = items
    var sel = 0
    var rows: [RowView] = []
    var everBecameKey = false

    override init() {
        let h = FIELD_H + CGFloat(min(items.count, MAX_ROWS)) * ROW_H + ROW_INSET
        panel = KeyPanel(contentRect: NSRect(x: 0, y: 0, width: WIDTH, height: h),
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
        bg.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = bg

        field.placeholderString = promptText
        field.font = .systemFont(ofSize: 18, weight: .regular)
        field.textColor = cText
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.delegate = self
        field.translatesAutoresizingMaskIntoConstraints = false
        bg.addSubview(field)

        let rule = NSView()
        rule.wantsLayer = true
        rule.layer?.backgroundColor = cSurface.cgColor
        rule.translatesAutoresizingMaskIntoConstraints = false
        bg.addSubview(rule)

        stack.orientation = .vertical
        stack.spacing = 0
        stack.edgeInsets = NSEdgeInsets(top: 0, left: ROW_INSET, bottom: 0, right: ROW_INSET)
        stack.translatesAutoresizingMaskIntoConstraints = false
        bg.addSubview(stack)

        NSLayoutConstraint.activate([
            field.topAnchor.constraint(equalTo: bg.topAnchor),
            field.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 20),
            field.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -20),
            field.heightAnchor.constraint(equalToConstant: FIELD_H),

            rule.topAnchor.constraint(equalTo: field.bottomAnchor),
            rule.leadingAnchor.constraint(equalTo: bg.leadingAnchor),
            rule.trailingAnchor.constraint(equalTo: bg.trailingAnchor),
            rule.heightAnchor.constraint(equalToConstant: 1),

            stack.topAnchor.constraint(equalTo: rule.bottomAnchor, constant: ROW_INSET / 2),
            stack.leadingAnchor.constraint(equalTo: bg.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: bg.trailingAnchor),
        ])

        rebuild()

        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
            guard let self else { return e }
            switch e.keyCode {
            case 125: self.move(1);  return nil          // down
            case 126: self.move(-1); return nil          // up
            case 36, 76: self.accept(); return nil       // return / enter
            case 53: self.cancel(); return nil           // esc
            default: return e
            }
        }
    }

    func rebuild() {
        rows.forEach { $0.removeFromSuperview() }
        rows = []
        for (i, s) in shown.prefix(MAX_ROWS).enumerated() {
            let r = RowView()
            r.label.stringValue = s
            r.selected = (i == sel)
            r.heightAnchor.constraint(equalToConstant: ROW_H).isActive = true
            stack.addArrangedSubview(r)
            r.widthAnchor.constraint(equalTo: stack.widthAnchor,
                                     constant: -2 * ROW_INSET).isActive = true
            rows.append(r)
        }
        resize()
    }

    func resize() {
        let h = FIELD_H + CGFloat(max(rows.count, 1)) * ROW_H + ROW_INSET
        guard let screen = NSScreen.main else { return }
        let v = screen.visibleFrame
        let frame = NSRect(x: v.midX - WIDTH / 2,
                           y: v.midY - h / 2 + v.height * 0.12,
                           width: WIDTH, height: h)
        panel.setFrame(frame, display: true)
    }

    func highlight() { for (i, r) in rows.enumerated() { r.selected = (i == sel) } }

    func move(_ d: Int) {
        guard !rows.isEmpty else { return }
        sel = max(0, min(rows.count - 1, sel + d))
        highlight()
    }

    func controlTextDidChange(_ obj: Notification) {
        let q = field.stringValue
        if q.isEmpty {
            shown = items
        } else {
            shown = items.compactMap { s in score(q, s).map { ($0, s) } }
                         .sorted { $0.0 < $1.0 }
                         .map { $0.1 }
        }
        sel = 0
        rebuild()
    }

    func accept() {
        guard sel < shown.count else { cancel(); return }
        FileHandle.standardOutput.write((shown[sel] + "\n").data(using: .utf8)!)
        NSApp.terminate(nil)
        exit(0)
    }

    func cancel() { exit(1) }
    func windowDidBecomeKey(_ n: Notification) { everBecameKey = true }
    func windowDidResignKey(_ n: Notification) { if everBecameKey { cancel() } }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(field)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let picker = Picker()
app.activate(ignoringOtherApps: true)
picker.show()
app.run()
