//
//  GuideRingHoldUITests.swift
//  Marlin DVR TVUITests
//
//  Pass 123's evidence harness, not a standing test: the Guide's held ring, forward and back, and the
//  footer's new wording (owner, 2026-09-24). It needs the physical Apple TV ("Home Theater") and the
//  owner's server, and it opens the Guide on whatever collection the owner last picked; it changes no
//  pick.
//
//  **It makes no server write.** Select is pressed once, on Home's Guide tile. In the Guide only Right and
//  Left are pressed — clicked or held, never Select, never a hold on Select — so no airing sheet, channel
//  menu or Player opens. The only non-GET traffic is the app's own launch ping.
//
//  **`launch()`, not `activate()`** (Pass 92): no console is attached, so the run is believed only once
//  its launch ping is in `GET /api/logs` at its time.
//
//  **A held ring here is `XCUIRemote.press(_:forDuration:)`**, one press-down and one press-up that far
//  apart (Pass 9: a synthesized hold drives the device's own press pipeline; Pass 123's diagnostic saw
//  the recognizer's began and ended 2.95 s apart for a 3 s one). **XCUITest on tvOS cannot swipe**
//  (Pass 108), so **a swipe right is code-traced only**, never driven.
//
//  What it runs, and what it leaves traced:
//    RUN     one click Right at a row's last cell steps the window exactly one slot (the new catcher's
//            path); one held Right, 4 s, steps it several slots inside the one press; the footer while
//            ahead reads "Menu snaps back to now · 24 hours per request"; Left along the row to the channel
//            cell with the window unmoved; one held Left, longer than the way back, brings the window to
//            the current half hour and stops there with focus still on that channel cell, not in the
//            rail; then one separate Left press reaches the rail with the ring on Guide.
//    TRACED  a swipe right and a swipe left; a hold that starts at now; a hold across a refetch or the
//            horizon; a hold on a row with no later cell; a second Left inside about half a second of a
//            hold's release, which the catcher still refuses.
//
//  Two methods, run one at a time. The run of record is the first, with `launch()`; the second drives a
//  process `devicectl … --console` already started, so the app's own `[guide]` and `[rail]` lines can be
//  read beside the harness's — it was written to diagnose a run in which the held Left reached now and
//  then the rail, and it was the console's timing that showed why (the pass's report).
//
//  Run (the record):
//    xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
//      -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates test \
//      -only-testing:"Marlin DVR TVUITests/GuideRingHoldUITests/testHeldRightStepsForwardHeldLeftStopsAtNowAndTheFooter"
//  Run (with the console; the app first, then the tests):
//    xcrun devicectl device process launch --device "Home Theater" --console --terminate-existing \
//      com.marlin1111.MarlinDVRTV &
//    xcodebuild … test -only-testing:"Marlin DVR TVUITests/GuideRingHoldUITests/testTheSameDriveWithTheConsoleAttached"
//
//  **Every query is a predicate, never an enumeration** (GuideRightEdgeUITests' header says why).
//

import XCTest

final class GuideRingHoldUITests: XCTestCase {
    private var app: XCUIApplication!
    private let remote = XCUIRemote.shared

    /// The header band ends above y 200 and the collapsed rail ends left of x 200 (Pass 72, Pass 76).
    private static let headerBottom: CGFloat = 200
    private static let contentLeft: CGFloat = 200
    /// The channel column runs from x≈236 to x≈536; a programme cell starts at x≈554.
    private static let channelColumnRight: CGFloat = 545
    /// 1920 − the 80 pt trailing margin: a row's last visible cell reaches here.
    private static let programmeAreaRight: CGFloat = 1840

    private static let footerAhead = "Menu snaps back to now · 24 hours per request"
    private static let footerAheadBefore = "Menu snaps back to now · forward only, 24 hours per request"
    private static let footerAtNow = "Starts at the current half hour · forward only"

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    // MARK: reading the device

    private func stamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: Date())
    }

    private func log(_ line: String) { print("[pass123 \(stamp())] \(line)") }

    private func shot(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    private func focusedElements() -> [XCUIElement] {
        app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == YES")).allElementsBoundByIndex
    }

    private func focusLine() -> String {
        let focused = focusedElements()
        if focused.isEmpty { return "NOTHING FOCUSED" }
        return focused.map { f in
            "\(f.elementType.rawValue):\u{201C}\(f.label)\u{201D} (\(Int(f.frame.minX)),\(Int(f.frame.minY)) \(Int(f.frame.width))x\(Int(f.frame.height)))"
        }.joined(separator: " | ")
    }

    private func focusedLabel() -> String? { focusedElements().first?.label }

    private func zone() -> String {
        guard let f = focusedElements().first else { return "nowhere" }
        let r = f.frame
        if r.minX < Self.contentLeft { return "rail" }
        if r.minY < Self.headerBottom { return "header" }
        if r.minX < Self.channelColumnRight { return "grid:channel-cell" }
        return "grid:programme-cell"
    }

    /// The header's window label — "Fri Sep 25 · 5:30 – 7:30 PM", or the midnight form with "→".
    private func windowLabel() -> String? {
        for needle in [" \u{2013} ", " \u{2192} "] {
            let e = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", needle)).firstMatch
            if e.exists { return e.label }
        }
        return nil
    }

    /// The window's own start as an absolute minute count (GuideRightEdgeUITests.windowPosition, Pass 77).
    private func windowPosition() -> Int? {
        guard let label = windowLabel() else { return nil }
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        guard let dateR = label.range(of: "[A-Z][a-z]{2} [0-9]{1,2}", options: .regularExpression) else { return nil }
        let date = String(label[dateR]).split(separator: " ")
        guard date.count == 2, let month = months.firstIndex(of: String(date[0])), let day = Int(date[1]) else { return nil }
        guard let clockR = label.range(of: "[0-9]{1,2}:[0-9]{2}", options: .regularExpression) else { return nil }
        let hm = String(label[clockR]).split(separator: ":")
        guard hm.count == 2, var h = Int(hm[0]), let m = Int(hm[1]) else { return nil }
        let tail = label[clockR.upperBound...]
        let meridiem: String
        if tail.hasPrefix(" AM") { meridiem = "AM" }
        else if tail.hasPrefix(" PM") { meridiem = "PM" }
        else if let r = tail.range(of: "(AM|PM)", options: .regularExpression) { meridiem = String(tail[r]) }
        else { return nil }
        if h == 12 { h = 0 }
        if meridiem == "PM" { h += 12 }
        return ((month * 31) + day) * 1440 + h * 60 + m
    }

    /// The current half hour, in `windowPosition()`'s own units, from this Mac's clock — the Apple TV
    /// keeps the same time. Run 1 of this harness compared the end of a held Left against the half hour
    /// the Guide *opened* at, and the wall clock had crossed 5:30 PM in between: the window had stopped
    /// at the new current half hour, exactly as built, and the assertion was the stale one.
    private func currentHalfHourPosition() -> Int {
        let c = Calendar.current.dateComponents([.month, .day, .hour, .minute], from: Date())
        return (((c.month ?? 1) - 1) * 31 + (c.day ?? 0)) * 1440 + (c.hour ?? 0) * 60 + ((c.minute ?? 0) / 30) * 30
    }

    /// The time strip's first column, found by the window's own start clock — "5:30 PM", or
    /// "5:00 PM · now" at the current half hour.
    private func stripFirstColumn() -> String? {
        guard let label = windowLabel(),
              let r = label.range(of: "[0-9]{1,2}:[0-9]{2}", options: .regularExpression) else { return nil }
        let clock = String(label[r])
        let e = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", clock)).firstMatch
        return e.exists ? e.label : nil
    }

    /// The header's "↩ Now · 5:14 PM" pill, drawn only while the window is ahead of now.
    private func nowPillDrawn() -> Bool {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "\u{21A9} Now")).firstMatch.exists
    }

    /// The legend's right-hand sentence, whichever of the two it is.
    private func footerLine() -> String? {
        for needle in ["Menu snaps back", "Starts at the current"] {
            let e = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", needle)).firstMatch
            if e.exists { return e.label }
        }
        return nil
    }

    /// One line per stage: the header, the strip, the pill, the footer and focus together.
    private func stage(_ tag: String) -> String {
        "\(tag) window=\u{201C}\(windowLabel() ?? "NO LABEL")\u{201D} startMin=\(windowPosition().map(String.init) ?? "?") " +
        "strip=\u{201C}\(stripFirstColumn() ?? "?")\u{201D} nowPill=\(nowPillDrawn()) footer=\u{201C}\(footerLine() ?? "?")\u{201D} zone=\(zone()) focus=\(focusLine())"
    }

    // MARK: driving the remote

    private var homeGuideTile: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Guide, ")).firstMatch
    }

    private func openGuide() {
        XCTAssertTrue(homeGuideTile.waitForExistence(timeout: 40), "Home did not appear")
        sleep(3)
        for _ in 0..<5 {
            if focusedLabel()?.hasPrefix("Guide, ") == true { break }
            remote.press(.up); usleep(800_000)
            if focusedLabel()?.hasPrefix("Guide, ") == true { break }
            remote.press(.left); usleep(800_000)
        }
        XCTAssertTrue(focusedLabel()?.hasPrefix("Guide, ") == true, "could not focus Home's Guide tile; focus=\(focusLine())")
        remote.press(.select)
        XCTAssertTrue(app.staticTexts["Recording or set to record"].waitForExistence(timeout: 40), "the Guide did not open")
        sleep(6)
    }

    /// Right along the row to its last visible cell, never pressing Right on that cell.
    private func walkToLastCell() -> Bool {
        for _ in 0...14 {
            guard let f = focusedElements().first, f.frame.minX > Self.channelColumnRight,
                  f.frame.minY >= Self.headerBottom else { return false }
            if f.frame.maxX >= Self.programmeAreaRight - 12 { return true }
            remote.press(.right)
            usleep(1_500_000)
        }
        return false
    }

    /// Left along the row to its channel cell — never a Left on the channel cell itself — with the
    /// window read after every press, because none of these presses may move it.
    private func walkLeftToChannelCell(window: Int) -> Bool {
        for i in 0..<12 {
            if zone() == "grid:channel-cell" { return true }
            guard zone() == "grid:programme-cell" else { return false }
            remote.press(.left)
            usleep(1_500_000)
            let w = windowPosition()
            log("walk left #\(i + 1): startMin=\(w.map(String.init) ?? "?") zone=\(zone()) focus=\(focusLine())")
            XCTAssertEqual(w, window, "a Left along the row moved the window")
        }
        return zone() == "grid:channel-cell"
    }

    // MARK: the run

    /// The run of record: `launch()`, so the launch ping in `GET /api/logs` dates it.
    func testHeldRightStepsForwardHeldLeftStopsAtNowAndTheFooter() {
        app.launch()
        log("launched")
        heldRing()
    }

    /// The same drive against a process `devicectl … --console` already started — neither `launch()`
    /// nor `activate()` — so the app's own `[guide]` and `[rail]` lines can be read beside the harness's.
    /// It was written to diagnose a run in which the held Left reached now and then the rail (the report).
    func testTheSameDriveWithTheConsoleAttached() {
        continueAfterFailure = true
        log("ATTACHING to the process devicectl launched — no launch(), no activate()")
        heldRing()
    }

    private func heldRing() {
        openGuide()
        guard let atNow = windowPosition() else { return XCTFail("no window label at open") }
        log(stage("OPEN") + " clockHalfHour=\(currentHalfHourPosition())")
        XCTAssertEqual(atNow, currentHalfHourPosition(), "the Guide did not open at this clock's current half hour")
        XCTAssertTrue(stripFirstColumn()?.hasSuffix("\u{00B7} now") == true, "the Guide did not open at now")
        XCTAssertFalse(nowPillDrawn(), "↩ Now is drawn at now")
        XCTAssertEqual(footerLine(), Self.footerAtNow, "the at-now footer sentence changed")
        shot("01-guide-open-at-now")

        // A click Right at the row's last cell: exactly one slot, now through the forward catcher.
        XCTAssertTrue(walkToLastCell(), "could not reach the row's last cell; focus=\(focusLine())")
        log(stage("AT THE EDGE"))
        guard let beforeClick = windowPosition() else { return XCTFail("no window label before the click") }
        remote.press(.right)
        sleep(3)
        log(stage("ONE CLICK RIGHT AT THE EDGE"))
        XCTAssertEqual(windowPosition(), beforeClick + 30, "one click at the edge did not move the window exactly one slot")
        XCTAssertEqual(zone(), "grid:programme-cell", "the click took focus out of the grid")
        shot("02-one-click-right-at-the-edge")

        // Item b: one held Right — one press-down, one press-up, 4 s apart — steps the window several slots.
        guard let beforeHold = windowPosition() else { return XCTFail("no window label before the hold") }
        log("HOLD RIGHT 4 s: press-down")
        remote.press(.right, forDuration: 4.0)
        log("HOLD RIGHT 4 s: press-up")
        sleep(3)
        guard let afterHold = windowPosition() else { return XCTFail("no window label after the hold") }
        let slotsHeld = (afterHold - beforeHold) / 30
        log(stage("HELD RIGHT 4 s -> \(slotsHeld) slot(s) in the one press"))
        XCTAssertGreaterThanOrEqual(slotsHeld, 3, "a 4 s held Right stepped the window \(slotsHeld) slot(s); expected several")
        XCTAssertTrue(nowPillDrawn(), "↩ Now is not drawn while ahead")
        XCTAssertEqual(zone(), "grid:programme-cell", "the held Right took focus out of the grid")
        shot("03-after-a-4s-held-right")

        // Item d: the footer while ahead.
        XCTAssertEqual(footerLine(), Self.footerAhead, "the footer while ahead does not read the new sentence")
        XCTAssertFalse(app.staticTexts[Self.footerAheadBefore].exists, "the old footer sentence is still drawn")
        shot("04-footer-while-ahead")

        // Left along the row to its channel cell; the window must not move on the way.
        XCTAssertTrue(walkLeftToChannelCell(window: afterHold), "could not reach the channel cell; focus=\(focusLine())")
        guard let channel = focusedLabel() else { return XCTFail("nothing focused on the channel cell") }
        let slotsAhead = (afterHold - currentHalfHourPosition()) / 30
        log(stage("ON THE CHANNEL CELL, \(slotsAhead) SLOT(S) AHEAD") + " clockHalfHour=\(currentHalfHourPosition())")
        shot("05-on-the-channel-cell-ahead")

        // Item c: one held Left, longer than the way back needs, so it is still down after the window
        // has reached now. It must stop there, on the channel cell, and not carry on into the rail.
        let holdLeft = Double(slotsAhead) * 0.6 + 4.0
        log("HOLD LEFT \(holdLeft) s: press-down")
        remote.press(.left, forDuration: holdLeft)
        log("HOLD LEFT \(holdLeft) s: press-up")
        sleep(3)
        let nowAfterHold = currentHalfHourPosition()
        log(stage("HELD LEFT \(holdLeft) s") + " clockHalfHour=\(nowAfterHold)")
        XCTAssertEqual(windowPosition(), nowAfterHold, "the held Left did not bring the window back to the current half hour")
        XCTAssertEqual(zone(), "grid:channel-cell", "the held Left carried focus out of the grid")
        XCTAssertEqual(focusedLabel(), channel, "the held Left moved focus off the channel cell")
        XCTAssertTrue(stripFirstColumn()?.hasSuffix("\u{00B7} now") == true, "\"· now\" is not drawn back at now")
        XCTAssertFalse(nowPillDrawn(), "↩ Now is still drawn back at now")
        XCTAssertEqual(footerLine(), Self.footerAtNow, "the at-now footer sentence is not back")
        shot("06-held-left-stopped-at-now-in-the-grid")

        // Owner's answer 1a: a separate Left press after that reaches the rail, ring on Guide.
        remote.press(.left)
        sleep(3)
        log(stage("ONE SEPARATE LEFT AT NOW"))
        XCTAssertEqual(zone(), "rail", "the separate Left at now did not reach the rail")
        XCTAssertEqual(focusedLabel(), "Guide", "the rail's ring is not on Guide")
        XCTAssertEqual(windowPosition(), nowAfterHold, "the window moved on the Left into the rail")
        shot("07-a-separate-left-reaches-the-rail")
    }
}
