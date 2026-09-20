//
//  GuideLiveRedrawUITests.swift
//  Marlin DVR TVUITests
//
//  Pass 116's evidence harness. Not a standing test: it needs the physical Apple TV, the owner's live
//  server at 1.10.0 or later with its "History" collection as it stood on 2026-09-20 — ten Philo
//  channels, 6105 TLC the sixth and 6108 DIY the last — **and the owner himself at the server's admin
//  page**, because the thing under test is the Guide redrawing when *he* changes something, and this
//  project never writes to his channels or collections.
//
//  **It creates, changes or deletes nothing on the server.** Every request it drives is a GET — the
//  guide, the schedule, GET /api/collections and the GET /api/events stream — plus the
//  `POST /api/clients/{id}/ping` the app itself sends on every launch (`ClientSession.swift:62-81`).
//  It does leave this Apple TV's Guide on the "History" collection if it cannot put back the pick it
//  found, and says so.
//
//  Three methods, run one at a time:
//
//  * `testOwnerChangesAreDrawnWithoutLeavingTheGuide` — **`launch()`**. Opens the Guide on History,
//    puts focus on 6113 DISCOVERY-LIFE's programme cell, prints `P116 READY`, and then presses
//    nothing at all while it waits for two things to appear on the screen: 6105 reading "TLC LIVE"
//    (the owner renames the channel) and 6108 DIY's row gone (the owner takes it out of History).
//    At each it checks that focus, the window and the pick have not moved.
//  * `testReconnectReReadsBoth` — **`launch()`**, no owner needed. Opens the Guide, presses Home,
//    waits, comes back. What the stream did is read from the server's log afterwards: the server
//    writes a connection's `GET /api/events 200` line only when that connection ends
//    (main.go:176-181).
//  * `testPutBacksWithTheConsoleAttached` — **neither `launch()` nor `activate()`**: the app is
//    started beforehand by `xcrun devicectl device process launch --console --terminate-existing`,
//    which is the only way this project has to read the app's own `print` lines (Pass 38), and this
//    method drives the process that command started. It is a fresh process by construction and its
//    own launch ping is in the server's log, so Pass 92's trap — a harness photographing the build
//    that was already running — cannot apply. It waits for the owner's two put-backs the same way.
//
//  The one `activate()` in this file is in `comeBackFromHome()`, where it brings the process the
//  method already launched back to the foreground after a Home press. It launches nothing unless
//  tvOS killed the app meanwhile, and that would show as a second ping in the server's log.
//
//  The owner's wait is `P116_WAIT` seconds (default 1200), passed as `TEST_RUNNER_P116_WAIT`.
//
//  Run:
//    xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
//      -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates test \
//      -only-testing:"Marlin DVR TVUITests/GuideLiveRedrawUITests/<method>"
//

import XCTest

final class GuideLiveRedrawUITests: XCTestCase {
    private var app: XCUIApplication!
    private let remote = XCUIRemote.shared

    /// The header's band, as `GuideCollectionsUITests` measured it on Home Theater.
    static let headerBottom: CGFloat = 200

    private let guideLegend = "Recording or set to record"
    private let collection = "History"
    private let everyPick = ["All Channels", "Local", "History", "SY-FY"]
    /// The channel the owner renames, and what he renames it to.
    private let renamed = (number: "6105", was: "TLC", becomes: "TLC LIVE")
    /// The last member of History, which the owner takes out and puts back. Last, so that putting
    /// it back restores the collection's order exactly.
    private let removed = (number: "6108", name: "DIY")
    /// The row focus is parked on: the one above the row that goes.
    private let parked = (number: "6113", name: "DISCOVERY-LIFE")

    private var ownerWait: TimeInterval {
        ProcessInfo.processInfo.environment["P116_WAIT"].flatMap(TimeInterval.init) ?? 1200
    }

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
    }

    // MARK: evidence helpers

    private func stamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: Date())
    }

    private func log(_ line: String) { print("P116 \(stamp()) \(line)") }

    private func shot(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
        log("SHOT \(name)")
    }

    /// Every query in this file is a predicate, never an enumeration (`GuideCollectionsUITests`).
    private func focusedElements() -> [XCUIElement] {
        app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == YES")).allElementsBoundByIndex
    }

    private func focusLabels() -> [String] {
        focusedElements().map { "\($0.elementType.rawValue):\($0.label)" }
    }

    /// A channel cell's accessibility label ends in its number — "TLC, 6105"; see `reads`.
    private func channelCell(_ number: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", ", \(number)")).firstMatch
    }

    /// Whether a channel cell reads exactly this name. The label is "TLC, 6105" for a channel drawn
    /// with its logo and "TL, TLC, 6105" for one drawn with the initials tile (measured in this
    /// pass's first run, which expected the second form of a channel that has a logo).
    private func reads(_ number: String, _ name: String) -> Bool {
        let label = channelCell(number).label
        return label == "\(name), \(number)" || label.hasSuffix(", \(name), \(number)")
    }

    private func collectionsButtonLabel() -> String {
        for label in everyPick {
            let element = app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
            if element.exists && element.frame.minY < Self.headerBottom { return label }
        }
        return "ABSENT"
    }

    /// "Sun Sep 20 · 12:30 AM – 2:30 AM" — the spaced en dash is unique to it in the header.
    private func windowLabel() -> String {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", " \u{2013} "))
            .allElementsBoundByIndex.first { $0.frame.minY < Self.headerBottom && $0.frame.minX > 200 }?.label ?? "ABSENT"
    }

    private struct Standing: Equatable, CustomStringConvertible {
        let focus: [String]
        let window: String
        let pick: String
        var description: String { "focus=\(focus) window=\(window) pick=\(pick)" }
    }

    private func standing() -> Standing {
        Standing(focus: focusLabels(), window: windowLabel(), pick: collectionsButtonLabel())
    }

    /// The half hour the wall clock is in. A roll across a boundary moves the window by design
    /// (Pass 79), so a standing that differs is only a failure inside one half hour.
    private func halfHour() -> Int { Int(Date().timeIntervalSince1970 / 1800) }

    // MARK: navigation

    /// Home's first tile is the Guide, so one Select opens it.
    private func openGuide() {
        XCTAssertTrue(app.staticTexts["Marlin"].waitForExistence(timeout: 60), "Home did not appear")
        sleep(3)
        remote.press(.select)
        XCTAssertTrue(app.staticTexts[guideLegend].waitForExistence(timeout: 60), "the Guide did not open")
        sleep(6)
    }

    private func focusIsOnTheCollectionsButton() -> Bool {
        focusedElements().contains { everyPick.contains($0.label) && $0.frame.minY < Self.headerBottom }
    }

    private func focusIsInTheHeader() -> Bool {
        focusedElements().contains { $0.frame.minY < Self.headerBottom && $0.frame.minX > 200 }
    }

    private func reachTheCollectionsButton() -> Bool {
        for _ in 0..<14 {
            if focusIsInTheHeader() { break }
            remote.press(.up); sleep(1)
        }
        for _ in 0..<6 {
            if focusIsOnTheCollectionsButton() { return true }
            remote.press(.left); sleep(1)
            if focusedElements().contains(where: { $0.frame.minX < 200 }) {   // overshot into the rail
                remote.press(.right); sleep(2)
                break
            }
        }
        return focusIsOnTheCollectionsButton()
    }

    /// Open the drop-down and choose a row: to the top of the list, then down to it.
    private func pick(_ title: String) {
        XCTAssertTrue(reachTheCollectionsButton(), "could not put focus on the collections button; focus=\(focusLabels())")
        remote.press(.select)
        XCTAssertTrue(app.staticTexts["Show in the Guide"].waitForExistence(timeout: 20), "the overlay did not open")
        sleep(4)
        for _ in 0..<5 { remote.press(.up); usleep(600_000) }
        for step in 0...6 {
            if focusLabels().contains(where: { $0.contains(title) }) {
                log("PICK \u{201C}\(title)\u{201D} has focus after \(step) Down press(es)")
                remote.press(.select)
                sleep(6)
                XCTAssertEqual(collectionsButtonLabel(), title, "the pick did not take")
                return
            }
            remote.press(.down); sleep(1)
        }
        XCTFail("could not reach the \u{201C}\(title)\u{201D} row; focus=\(focusLabels())")
    }

    /// Focus on the parked row's programme cell, with the rows below it scrolled into view: down to
    /// the bottom of the grid, then up to the parked row if the last row is still the one that goes.
    private func parkFocus() {
        for _ in 0..<11 { remote.press(.down); usleep(700_000) }
        sleep(1)
        if channelCell(removed.number).exists { remote.press(.up); sleep(2) }
        let row = channelCell(parked.number)
        XCTAssertTrue(row.exists, "\(parked.name) is not in the grid")
        let focus = focusedElements()
        log("PARK focus=\(focusLabels()) parkedRowY=\(row.frame.midY)")
        XCTAssertTrue(focus.contains { abs($0.frame.midY - row.frame.midY) < 12 && $0.frame.minX > row.frame.maxX },
                      "focus is not on a programme cell of \(parked.name)'s row")
    }

    /// Wait, **pressing nothing**, until every named condition has been seen once. Each is
    /// photographed and checked the first time it is true.
    private func waitForTheOwner(_ conditions: [(name: String, shot: String, seen: () -> Bool)], before: Standing) {
        let startedIn = halfHour()
        var pending = conditions
        let deadline = Date().addingTimeInterval(ownerWait)
        var lastNote = Date()
        while !pending.isEmpty && Date() < deadline {
            for (index, condition) in pending.enumerated().reversed() where condition.seen() {
                log("SEEN \(condition.name)")
                usleep(1_500_000)   // let the redraw's own focus settle be over before it is judged
                shot(condition.shot)
                let after = standing()
                log("STANDING after \(condition.name): \(after)")
                XCTAssertTrue(app.staticTexts[guideLegend].exists, "the Guide is no longer on screen after \(condition.name)")
                if halfHour() == startedIn {
                    XCTAssertEqual(after, before, "focus, the window or the pick moved with \(condition.name)")
                } else {
                    log("NOTE a half-hour boundary passed during the wait; the window rolls by design, so the standing is recorded and not asserted")
                    XCTAssertEqual(after.pick, before.pick, "the pick moved with \(condition.name)")
                }
                pending.remove(at: index)
            }
            if Date().timeIntervalSince(lastNote) > 60 {
                log("WAITING for \(pending.map(\.name))")
                lastNote = Date()
            }
            usleep(500_000)
        }
        for condition in pending {
            XCTFail("never seen within \(Int(ownerWait)) s: \(condition.name)")
        }
    }

    /// Home, a wait, and back. `activate()` here foregrounds the process this method is already
    /// driving; see the header.
    private func comeBackFromHome(after seconds: UInt32) {
        log("HOME pressed")
        remote.press(.home)
        sleep(seconds)
        log("RETURN")
        app.activate()
        XCTAssertTrue(app.staticTexts[guideLegend].waitForExistence(timeout: 30), "the Guide is not on screen after coming back")
        sleep(12)
    }

    private func putThePickBack(_ found: String) {
        guard found != collectionsButtonLabel(), everyPick.contains(found) else { return }
        pick(found)
        log("RESTORED the pick to \u{201C}\(found)\u{201D}")
    }

    // MARK: 1 — the owner's two changes, with launch()

    func testOwnerChangesAreDrawnWithoutLeavingTheGuide() {
        app.launch()
        log("LAUNCHED with launch()")
        openGuide()
        let found = collectionsButtonLabel()
        log("FOUND the pick at \u{201C}\(found)\u{201D}")
        if found != collection { pick(collection) }
        parkFocus()

        XCTAssertTrue(reads(renamed.number, renamed.was), "\(renamed.number) does not read \(renamed.was) before the change: \(channelCell(renamed.number).label)")
        XCTAssertTrue(channelCell(removed.number).exists, "\(removed.name) is not in \(collection) before the change")
        let before = standing()
        log("STANDING before: \(before)")
        log("BEFORE \(renamed.number)=\u{201C}\(channelCell(renamed.number).label)\u{201D} \(removed.number) exists=\(channelCell(removed.number).exists)")
        shot("116a-before-history-focus-on-discovery-life")
        log("READY — the owner renames \(renamed.number) to \(renamed.becomes) and takes \(removed.number) \(removed.name) out of \(collection); no remote press from here on")

        waitForTheOwner([
            (name: "\(renamed.number) reads \(renamed.becomes)", shot: "116b-after-the-rename", seen: { [self] in
                reads(renamed.number, renamed.becomes)
            }),
            (name: "\(removed.number) \(removed.name) has left \(collection)", shot: "116c-after-the-removal", seen: { [self] in
                !channelCell(removed.number).exists
            }),
        ], before: before)

        log("AFTER \(renamed.number)=\u{201C}\(channelCell(renamed.number).label)\u{201D} \(removed.number) exists=\(channelCell(removed.number).exists)")
        putThePickBack(found)
    }

    // MARK: 2 — the reconnect, with launch()

    func testReconnectReReadsBoth() {
        app.launch()
        log("LAUNCHED with launch()")
        openGuide()
        let before = standing()
        log("STANDING before Home: \(before)")
        shot("116d-before-home")
        sleep(20)   // at least one keep-alive on the first connection
        comeBackFromHome(after: 75)
        let after = standing()
        log("STANDING after coming back: \(after)")
        shot("116e-back-from-home")
        XCTAssertEqual(after.pick, before.pick, "the pick moved across the trip to Home")
        sleep(50)   // long enough for an idle timer of 45 s to have fired if the stream came back dead
        log("DONE")
    }

    // MARK: 2b — the same trip to Home, against the process devicectl started with its console attached

    /// `testReconnectReReadsBoth` found that under a test session a trip to Home does not end the
    /// stream — perhaps because a process XCUITest launched is never suspended. This is the same
    /// trip with the app launched by `devicectl … --console`, outside any test session, so that the
    /// app's own `[events]` lines say what the stream did. No owner needed.
    func testTripToHomeWithTheConsoleAttached() {
        log("ATTACHING to the process devicectl launched — no launch(), no activate()")
        openGuide()
        let before = standing()
        log("STANDING before Home: \(before)")
        sleep(20)
        comeBackFromHome(after: UInt32(ProcessInfo.processInfo.environment["P116_AWAY"].flatMap(UInt32.init) ?? 75))
        log("STANDING after coming back: \(standing())")
        shot("116j-back-from-home-console-attached")
        sleep(50)
        putThePickBack(ProcessInfo.processInfo.environment["P116_RESTORE_PICK"] ?? before.pick)
        log("DONE")
    }

    // MARK: 3 — the put-backs, against the process devicectl started with its console attached

    func testPutBacksWithTheConsoleAttached() {
        log("ATTACHING to the process devicectl launched — no launch(), no activate()")
        openGuide()
        let found = collectionsButtonLabel()
        log("FOUND the pick at \u{201C}\(found)\u{201D}")
        if found != collection { pick(collection) }
        parkFocus()

        let before = standing()
        log("STANDING before: \(before)")
        log("BEFORE \(renamed.number)=\u{201C}\(channelCell(renamed.number).label)\u{201D} \(removed.number) exists=\(channelCell(removed.number).exists)")
        shot("116f-before-the-put-backs")
        log("READY — the owner renames \(renamed.number) back to \(renamed.was) and puts \(removed.number) \(removed.name) back in \(collection); no remote press from here on")

        waitForTheOwner([
            (name: "\(renamed.number) reads \(renamed.was) again", shot: "116g-after-the-name-is-back", seen: { [self] in
                reads(renamed.number, renamed.was)
            }),
            (name: "\(removed.number) \(removed.name) is back in \(collection)", shot: "116h-after-diy-is-back", seen: { [self] in
                channelCell(removed.number).exists
            }),
        ], before: before)

        log("AFTER \(renamed.number)=\u{201C}\(channelCell(renamed.number).label)\u{201D} \(removed.number) exists=\(channelCell(removed.number).exists)")
        comeBackFromHome(after: 75)
        shot("116i-back-from-home-console-leg")
        sleep(10)
        putThePickBack(found)
        log("DONE")
    }
}
