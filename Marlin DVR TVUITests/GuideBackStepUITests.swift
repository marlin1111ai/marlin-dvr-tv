//
//  GuideBackStepUITests.swift
//  Marlin DVR TVUITests
//
//  Pass 122's evidence harness, not a standing test: item G, the Guide's Left back-step (owner,
//  2026-09-23: "go back as it did forward"). It needs the physical Apple TV ("Home Theater") and the
//  owner's server, and it moves the Guide ahead with Pass 77's own Right nudge before stepping back.
//
//  **It makes no server write.** Select is pressed once, on Home's Guide tile. In the Guide only Right,
//  Left and Menu are pressed — never Select, never a hold — so no airing sheet, channel menu or
//  Player opens. The only non-GET traffic is the app's own launch ping.
//
//  **`launch()`, not `activate()`** (Pass 92): no console is attached, so the run is believed only once
//  its launch ping is in `GET /api/logs` at its time.
//
//  **Every press here is a click.** XCUITest on tvOS presses remote buttons and cannot swipe (Pass 108),
//  so **a swipe left on a channel cell is code-traced only**, never driven.
//
//  What it runs, and what it leaves traced:
//    RUN     the Guide moved four slots ahead by Right at a row's last cell; Left along the row to its
//            channel cell with the window unmoved; then Left on that channel cell, once per press: the
//            header's window, the time strip's first column and the rows step back 30 minutes together
//            and focus stays on the same channel cell, down to the current half hour ("· now" drawn,
//            "↩ Now" gone); then one more Left, which reaches the rail with the ring on Guide.
//    TRACED  a back-step below the fetched range and its read; a half-hour boundary during back-steps;
//            Menu, ↩ Now and +12h after back-steps; a server notice during one; an overlay open; the
//            Player on top; a swipe; a fast presser.
//
//  Run:
//    xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
//      -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates test \
//      -only-testing:"Marlin DVR TVUITests/GuideBackStepUITests"
//
//  **Every query is a predicate, never an enumeration** (GuideRightEdgeUITests' header says why).
//

import XCTest

final class GuideBackStepUITests: XCTestCase {
    private var app: XCUIApplication!
    private let remote = XCUIRemote.shared

    /// The header band ends above y 200 and the collapsed rail ends left of x 200 (Pass 72, Pass 76).
    private static let headerBottom: CGFloat = 200
    private static let contentLeft: CGFloat = 200
    /// The channel column runs from x≈236 to x≈536; a programme cell starts at x≈554.
    private static let channelColumnRight: CGFloat = 545
    /// 1920 − the 80 pt trailing margin: a row's last visible cell reaches here.
    private static let programmeAreaRight: CGFloat = 1840

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        log("launched")
    }

    // MARK: reading the device

    private func stamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: Date())
    }

    private func log(_ line: String) { print("[pass122 \(stamp())] \(line)") }

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

    /// The header's window label — "Thu Sep 24 · 10:30 AM – 12:30 PM", or the midnight form with "→".
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

    /// The time strip's first column, found by the window's own start clock — "10:30 AM", or
    /// "10:00 AM · now" at the current half hour.
    private func stripFirstColumn() -> String? {
        guard let label = windowLabel(),
              let r = label.range(of: "[0-9]{1,2}:[0-9]{2}", options: .regularExpression) else { return nil }
        let clock = String(label[r])
        let e = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", clock)).firstMatch
        return e.exists ? e.label : nil
    }

    /// The header's "↩ Now · 10:14 AM" pill, drawn only while the window is ahead of now.
    private func nowPillDrawn() -> Bool {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "\u{21A9} Now")).firstMatch.exists
    }

    /// One line per stage: the header, the strip, the pill and focus together.
    private func stage(_ tag: String) -> String {
        "\(tag) window=\u{201C}\(windowLabel() ?? "NO LABEL")\u{201D} startMin=\(windowPosition().map(String.init) ?? "?") " +
        "strip=\u{201C}\(stripFirstColumn() ?? "?")\u{201D} nowPill=\(nowPillDrawn()) zone=\(zone()) focus=\(focusLine())"
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

    /// Pass 77's nudge: Right at the row's last cell until the window has moved `slots` slots.
    private func nudgeAhead(_ slots: Int, from start: Int) -> Int {
        var advanced = 0
        for _ in 0..<(slots * 5) {
            remote.press(.right)
            usleep(1_500_000)
            if let now = windowPosition() { advanced = (now - start) / 30 }
            if advanced >= slots { break }
        }
        return advanced
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

    func testLeftStepsBackOneSlotPerPressToNowThenTheRail() {
        openGuide()
        guard let atNow = windowPosition() else { return XCTFail("no window label at open") }
        log(stage("OPEN"))
        XCTAssertTrue(stripFirstColumn()?.hasSuffix("\u{00B7} now") == true, "the Guide did not open at now")
        XCTAssertFalse(nowPillDrawn(), "↩ Now is drawn at now")
        shot("01-guide-open-at-now")

        // Four slots ahead, by Pass 77's own Right.
        XCTAssertTrue(walkToLastCell(), "could not reach the row's last cell; focus=\(focusLine())")
        let ahead = nudgeAhead(4, from: atNow)
        log(stage("AHEAD \(ahead) slot(s)"))
        XCTAssertEqual(ahead, 4, "the window did not go four slots ahead")
        XCTAssertTrue(nowPillDrawn(), "↩ Now is not drawn while ahead")
        shot("02-four-slots-ahead")

        // To the row's channel cell; the window must not move on the way.
        let aheadStart = atNow + 4 * 30
        XCTAssertTrue(walkLeftToChannelCell(window: aheadStart), "could not reach the channel cell; focus=\(focusLine())")
        guard let channel = focusedLabel() else { return XCTFail("nothing focused on the channel cell") }
        log(stage("ON THE CHANNEL CELL"))
        shot("03-on-the-channel-cell-four-ahead")

        // G: each Left steps the window back one slot, focus staying on the same channel cell.
        var expected = aheadStart
        for press in 1...4 {
            remote.press(.left)
            sleep(3)
            expected -= 30
            log(stage("BACK-STEP LEFT #\(press)"))
            XCTAssertEqual(windowPosition(), expected, "Left #\(press) did not step the window back one slot")
            XCTAssertEqual(zone(), "grid:channel-cell", "Left #\(press) took focus out of the grid")
            XCTAssertEqual(focusedLabel(), channel, "Left #\(press) moved focus off the channel cell")
            XCTAssertNotNil(stripFirstColumn(), "the time strip's first column does not read the window's start")
            shot(String(format: "%02d-back-step-%d", 3 + press, press))
        }
        XCTAssertEqual(windowPosition(), atNow, "four Lefts did not bring the window back to now")
        XCTAssertTrue(stripFirstColumn()?.hasSuffix("\u{00B7} now") == true, "\"· now\" is not drawn back at now")
        XCTAssertFalse(nowPillDrawn(), "↩ Now is still drawn back at now")

        // At now, Left reaches the rail as it always has, with the ring on Guide.
        remote.press(.left)
        sleep(3)
        log(stage("ONE MORE LEFT AT NOW"))
        XCTAssertEqual(zone(), "rail", "Left at now did not reach the rail")
        XCTAssertEqual(focusedLabel(), "Guide", "the rail's ring is not on Guide")
        XCTAssertEqual(windowPosition(), atNow, "the window moved on the Left into the rail")
        shot("08-left-at-now-reaches-the-rail")
    }
}
