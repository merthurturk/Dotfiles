// What's next, and what today looks like.
//
// Reads EventKit, which is the local store macOS Calendar syncs into -- so a
// Google account added under System Settings > Internet Accounts shows up here
// with no OAuth, no client secret in this repo, and no token to refresh. That
// is the whole reason for this route.
//
// Not AppleScript. `tell application "Calendar" to get every event whose start
// date ≥ ...` takes **five seconds** on this machine and is a well-known
// pathology; EventKit answers the same question in milliseconds off a local
// database.
//
//   calendar watch                       resident; publishes to state files
//   calendar next [--within <minutes>]   the next event, if one is close
//   calendar agenda                      everything today
//
// `watch` is how this is actually used. TCC attributes a permission to the
// process *responsible* for launching one, so the helper run by SketchyBar
// would be asking with SketchyBar's grant, and the same binary run from a
// terminal would be asking with the terminal's -- three identities, three
// grants, three different answers. A launchd agent is its own responsible
// process, so the grant belongs to this bundle and nothing else needs one.
// The bar and the launcher then read files and do no work at all.
//
// Output is tab-separated:
//   <epoch start> <epoch end> <all-day> <calendar> <title> <join url>
// `next` prints one row or nothing at all, which is what lets the bar chip say
// "draw nothing" without parsing anything.

import EventKit
import Foundation

let store = EKEventStore()

// Ask once, synchronously. Granting happens in System Settings > Privacy &
// Security > Calendars; this binary lives inside a .app bundle so it has a
// name there a person can recognise, rather than appearing as "calendar".
func authorised() -> Bool {
    // Already granted? Do not ask again. Asking is not harmless: a process
    // without its own bundle identity gets `false` back from
    // requestFullAccessToEvents even when authorizationStatus already says
    // fullAccess, and then refuses to do work it was perfectly entitled to do.
    let status = EKEventStore.authorizationStatus(for: .event)
    if #available(macOS 14.0, *) {
        if status == .fullAccess { return true }
    }
    if status.rawValue == 3 { return true }   // .authorized, pre-14 spelling

    let sem = DispatchSemaphore(value: 0)
    var ok = false
    if #available(macOS 14.0, *) {
        store.requestFullAccessToEvents { granted, _ in ok = granted; sem.signal() }
    } else {
        store.requestAccess(to: .event) { granted, _ in ok = granted; sem.signal() }
    }
    _ = sem.wait(timeout: .now() + 10)
    return ok
}

guard authorised() else {
    FileHandle.standardError.write(Data("calendar: no access to Calendars\n".utf8))
    exit(2)
}

let args = Array(CommandLine.arguments.dropFirst())
let cmd = args.first ?? "agenda"
let cal = Calendar.current
let now = Date()

func flag(_ name: String) -> String? {
    guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
    return args[i + 1]
}

// Today, midnight to midnight. An event that started an hour ago and is still
// running is still what you are in, so the window starts at the top of today
// and the caller decides what "next" means.
//
// Recomputed on each call rather than captured once: `watch` outlives a day.
@Sendable func todaysEvents() -> [EKEvent] {
    let today = Date()
    let startOfDay = cal.startOfDay(for: today)
    let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay)!
    let predicate = store.predicateForEvents(withStart: startOfDay, end: endOfDay,
                                             calendars: nil)
    // Declined invitations are not your day.
    return store.events(matching: predicate)
        .filter { ev in
            guard let me = ev.attendees?.first(where: { $0.isCurrentUser }) else { return true }
            return me.participantStatus != .declined
        }
        .sorted { ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast) }
}
let events = todaysEvents()

// The link you would actually click. Google and Zoom both bury it in the notes
// rather than the url field -- every event on this machine had `url` empty and
// "Join with Google Meet: https://meet.google.com/..." in the body -- so all
// three fields are searched, in the order most likely to be deliberate.
let joinPatterns = [
    #"https://meet\.google\.com/[a-z0-9-]+"#,
    #"https://[a-z0-9.-]*zoom\.us/j/[0-9]+(\?[^\s<>"]*)?"#,
    #"https://teams\.microsoft\.com/l/meetup-join/[^\s<>"]+"#,
    #"https://[a-z0-9.-]*webex\.com/[^\s<>"]+"#,
    #"https://meet\.jit\.si/[^\s<>"]+"#,
    #"https://[a-z0-9.-]*whereby\.com/[^\s<>"]+"#,
]

@Sendable func joinURL(_ ev: EKEvent) -> String {
    let haystack = [ev.url?.absoluteString, ev.location, ev.notes]
        .compactMap { $0 }.joined(separator: "\n")
    guard !haystack.isEmpty else { return "" }
    for pattern in joinPatterns {
        guard let re = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
        else { continue }
        let range = NSRange(haystack.startIndex..., in: haystack)
        if let m = re.firstMatch(in: haystack, range: range),
           let r = Range(m.range, in: haystack) {
            return String(haystack[r])
        }
    }
    return ""
}

@Sendable func row(_ ev: EKEvent) -> String {
    let title = (ev.title ?? "(no title)").replacingOccurrences(of: "\t", with: " ")
    let name = (ev.calendar?.title ?? "").replacingOccurrences(of: "\t", with: " ")
    return [String(Int(ev.startDate.timeIntervalSince1970)),
            String(Int((ev.endDate ?? ev.startDate).timeIntervalSince1970)),
            ev.isAllDay ? "1" : "0", name, title, joinURL(ev)].joined(separator: "\t")
}

// Where `watch` publishes. The bar reads the first of these on a timer and
// forks nothing; `dot calendar agenda` reads the second.
let stateDir = (ProcessInfo.processInfo.environment["XDG_STATE_HOME"]
                ?? NSHomeDirectory() + "/.local/state") + "/aerospace"

@Sendable func publish(_ name: String, _ text: String) {
    try? FileManager.default.createDirectory(atPath: stateDir,
                                             withIntermediateDirectories: true)
    let path = stateDir + "/" + name
    let tmp = path + ".tmp"
    // Through a rename, so a reader never sees half a file.
    try? text.write(toFile: tmp, atomically: false, encoding: .utf8)
    _ = try? FileManager.default.replaceItemAt(URL(fileURLWithPath: path),
                                               withItemAt: URL(fileURLWithPath: tmp))
}

@Sendable func snapshot() {
    let evs = todaysEvents()
    publish("agenda.tsv", evs.map(row).joined(separator: "\n") + (evs.isEmpty ? "" : "\n"))
    // The rest of today, not a few hours of it. "What is next" at 06:30 is the
    // 13:00 meeting; the chip already shows a clock time rather than a
    // countdown once something is more than an hour away, so a distant event
    // reads as "13:00 · Work Session" and takes no more room than "25m".
    let now = Date()
    let horizon = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now))!
    let current = evs.first { !$0.isAllDay && $0.startDate <= now && ($0.endDate ?? now) > now }
    let upcoming = evs.first { !$0.isAllDay && $0.startDate > now && $0.startDate <= horizon }
    publish("next-event.tsv", (current ?? upcoming).map { row($0) + "\n" } ?? "")
}

switch cmd {
case "watch":
    snapshot()
    // EventKit says when something changed, so an edit in Calendar shows up
    // immediately rather than on the next tick. The timer is the backstop:
    // events become "now" with the passage of time, which fires no
    // notification at all.
    NotificationCenter.default.addObserver(forName: .EKEventStoreChanged,
                                           object: store, queue: .main) { _ in snapshot() }
    Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in snapshot() }
    RunLoop.main.run()
case "next":
    // Defaults to the rest of today; --within narrows it.
    let horizon = flag("--within").flatMap(Double.init).map { now.addingTimeInterval($0 * 60) }
        ?? cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now))!
    // Something you are in the middle of beats something that has not started.
    let current = events.first { !$0.isAllDay && $0.startDate <= now && ($0.endDate ?? now) > now }
    let upcoming = events.first { !$0.isAllDay && $0.startDate > now && $0.startDate <= horizon }
    if let ev = current ?? upcoming { print(row(ev)) }
case "agenda":
    for ev in events { print(row(ev)) }
default:
    FileHandle.standardError.write(Data("usage: calendar [next|agenda]\n".utf8))
    exit(1)
}
