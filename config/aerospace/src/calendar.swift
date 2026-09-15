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
//   calendar next [--within <minutes>]   the next event, if one is close
//   calendar agenda [--json]             everything left today
//
// Output is tab-separated: <epoch start> <epoch end> <all-day> <calendar> <title>
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

// Today, from now until midnight. An event that started an hour ago and is
// still running is still what you are in, so the window starts at the top of
// today and the caller decides what "next" means.
let startOfDay = cal.startOfDay(for: now)
let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay)!
let predicate = store.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)

// Declined invitations are not your day.
let events = store.events(matching: predicate)
    .filter { ev in
        guard let me = ev.attendees?.first(where: { $0.isCurrentUser }) else { return true }
        return me.participantStatus != .declined
    }
    .sorted { ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast) }

func row(_ ev: EKEvent) -> String {
    let title = (ev.title ?? "(no title)").replacingOccurrences(of: "\t", with: " ")
    let name = (ev.calendar?.title ?? "").replacingOccurrences(of: "\t", with: " ")
    return [String(Int(ev.startDate.timeIntervalSince1970)),
            String(Int((ev.endDate ?? ev.startDate).timeIntervalSince1970)),
            ev.isAllDay ? "1" : "0", name, title].joined(separator: "\t")
}

switch cmd {
case "next":
    // How far ahead to care. Beyond this the bar says nothing rather than
    // showing you a meeting you cannot do anything about yet.
    let within = Double(flag("--within") ?? "") ?? 240
    let horizon = now.addingTimeInterval(within * 60)
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
