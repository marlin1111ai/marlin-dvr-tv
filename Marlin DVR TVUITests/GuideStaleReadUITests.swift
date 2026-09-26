//
//  GuideStaleReadUITests.swift
//  Marlin DVR TVUITests
//
//  Pass 129's evidence harness, not a standing test: S11, a Guide read that finishes after the window or
//  the collection on screen has changed never fills the grid. It runs what Pass 119's report says a run can
//  prove — +12h twice then Menu, +12h twice then ↩ Now, each giving a filled grid at now; a collection pick
//  while ahead redrawing in place — and, because the same screen carries them, that Pass 122's Left
//  back-step and Pass 123's ring hold still work.
//
//  It needs the physical Apple TV ("Home Theater") and the owner's server. It runs on All Channels: if the
//  Guide opens on another collection it chooses All Channels first, and its pick test chooses "Local" and
//  puts "All Channels" back.
//
//  **Two methods, run one at a time.** The run of record is the first, with `launch()`, on the committed
//  code: a healthy server answers inside one round trip, so no press of XCUIRemote's can land inside a
//  read, and the run is the regression only. The second drove a process `devicectl … --console` started
//  with `MARLIN_PROBE_FETCH_DELAY` set — a disclosed diagnostic that held every read for that many
//  seconds, reverted before the commit — so a Menu could land inside the second +12h's read and the app's
//  own `[guide] read … discarded` line be seen beside the harness's. **It does not drive a pick and then
//  Menu inside the pick's read**: `pick()` puts focus back in the grid only after its read lands, and until
//  then focus sits in the rail, where Menu reaches the shell and the app goes Home — measured twice in
//  Pass 129, and recorded there as an open question; that discard stays traced.
//
//  **It makes no server write.** Select is pressed on Home's Guide tile, on the header's pills, on the
//  collections button and on two rows of its overlay — never on a programme cell, never a hold. Its only
//  non-GET traffic is the app's own launch ping.
//
//  Run (the record):
//    xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
//      -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates test \
//      -only-testing:"Marlin DVR TVUITests/GuideStaleReadUITests/testWindowAndCollectionMovesStillFillTheGrid"
//  Run (with the console and the delay; the diagnostic build first, then the tests):
//    xcrun devicectl device process launch --device "Home Theater" --console --terminate-existing \
//      -e '{"MARLIN_PROBE_FETCH_DELAY":"4"}' com.marlin1111.MarlinDVRTV &
//    xcodebuild … test -only-testing:"Marlin DVR TVUITests/GuideStaleReadUITests/testAReadThatLandsLateIsDiscarded"
//
//  **Every query is a predicate, never an enumeration** (GuideRightEdgeUITests' header says why).
//

import XCTest

final class GuideStaleReadUITests: XCTestCase {
    private var app: XCUIApplication!
    private let remote = XCUIRemote.shared

    private static let headerBottom: CGFloat = 200
    private static let contentLeft: CGFloat = 200
    private static let channelColumnRight: CGFloat = 545
    private static let programmeAreaRight: CGFloat = 1840

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

    private func log(_ line: String) { print("[pass129 \(stamp())] \(line)") }

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

    private func currentHalfHourPosition() -> Int {
        let c = Calendar.current.dateComponents([.month, .day, .hour, .minute], from: Date())
        return (((c.month ?? 1) - 1) * 31 + (c.day ?? 0)) * 1440 + (c.hour ?? 0) * 60 + ((c.minute ?? 0) / 30) * 30
    }

    private func stripFirstColumn() -> String? {
        guard let label = windowLabel(),
              let r = label.range(of: "[0-9]{1,2}:[0-9]{2}", options: .regularExpression) else { return nil }
        let clock = String(label[r])
        let e = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", clock)).firstMatch
        return e.exists ? e.label : nil
    }

    private func nowPillDrawn() -> Bool {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "\u{21A9} Now")).firstMatch.exists
    }

    /// The programme cells drawn: buttons below the header and right of the channel column. A count,
    /// through a predicate on the frame-free label is not possible, so this counts by position — the
    /// grid's cells are the only buttons there. Enumerating buttons on All Channels' 202 rows is slow
    /// (GuideRightEdgeUITests' header), so this samples: it stops at 12.
    private func programmeCellsDrawn(limit: Int = 12) -> Int {
        var n = 0
        for b in app.buttons.allElementsBoundByIndex.prefix(80) {
            let r = b.frame
            if r.minY >= Self.headerBottom && r.minX > Self.channelColumnRight && r.width > 20 { n += 1 }
            if n >= limit { break }
        }
        return n
    }

    /// The channel cells drawn, by their ", <number>" label ending: at most `limit`.
    private func channelCellsDrawn(limit: Int = 12) -> Int {
        var n = 0
        for b in app.buttons.matching(NSPredicate(format: "label MATCHES %@", ".*, [0-9.]+$")).allElementsBoundByIndex.prefix(limit + 1) {
            if b.frame.minY >= Self.headerBottom && b.frame.minX < Self.channelColumnRight { n += 1 }
            if n > limit { break }
        }
        return n
    }

    private func channelCell(_ number: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", ", \(number)")).firstMatch
    }

    private func collectionsButton() -> XCUIElement? {
        for label in ["All Channels", "Local", "History", "SY-FY", "News/Weather", "Test"] {
            let e = app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
            if e.exists && e.frame.minY < Self.headerBottom { return e }
        }
        return nil
    }

    private func stage(_ tag: String) -> String {
        "\(tag) window=\u{201C}\(windowLabel() ?? "NO LABEL")\u{201D} startMin=\(windowPosition().map(String.init) ?? "?") " +
        "strip=\u{201C}\(stripFirstColumn() ?? "?")\u{201D} nowPill=\(nowPillDrawn()) collection=\u{201C}\(collectionsButton()?.label ?? "?")\u{201D} " +
        "cells=\(programmeCellsDrawn()) zone=\(zone()) focus=\(focusLine())"
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

    private func rect(_ r: CGRect) -> String { "(\(Int(r.minX)),\(Int(r.minY)) \(Int(r.width))x\(Int(r.height)))" }

    /// Put focus in the header: Up out of the grid, stepping Left when Up finds nothing above
    /// (GuideRightEdgeUITests.intoTheHeader, Pass 77).
    @discardableResult
    private func intoTheHeader() -> Bool {
        for _ in 0..<16 {
            guard let f = focusedElements().first else { break }
            if f.frame.minX < Self.contentLeft { remote.press(.right); usleep(1_100_000); continue }
            if f.frame.minY < Self.headerBottom { return true }
            let before = f.label + rect(f.frame)
            remote.press(.up); usleep(1_100_000)
            let after = focusedElements().first.map { $0.label + rect($0.frame) }
            if after == before { remote.press(.left); usleep(1_100_000) }
        }
        return (focusedElements().first?.frame.minY ?? 9999) < Self.headerBottom
    }

    /// The header's rightmost pill — +12h whenever it is drawn.
    private func toHeaderRightEnd() -> String? {
        guard intoTheHeader() else { return nil }
        var last = focusedElements().first?.label
        for _ in 0..<5 {
            remote.press(.right); usleep(1_000_000)
            guard let f = focusedElements().first, f.frame.minY < Self.headerBottom else { break }
            if f.label == last { break }
            last = f.label
        }
        return last
    }

    /// Press +12h and wait `settle` seconds: 5 on a healthy server; 1 when a read must still be in flight.
    private func pressPlus12h(settle: UInt32 = 5) -> Bool {
        guard let label = toHeaderRightEnd(), label.contains("+12h") else {
            log("the header's right end is not +12h; focus=\(focusLine())"); return false
        }
        remote.press(.select); sleep(settle)
        log("pressed +12h · window=\u{201C}\(windowLabel() ?? "?")\u{201D}")
        return true
    }

    /// Press ↩ Now: one Left from +12h when both are drawn.
    private func pressNow() -> Bool {
        guard let label = toHeaderRightEnd() else { return false }
        if !label.contains("Now") {
            remote.press(.left); usleep(1_100_000)
            guard let f = focusedElements().first, f.frame.minY < Self.headerBottom, f.label.contains("Now") else {
                log("could not reach ↩ Now; focus=\(focusLine())"); return false
            }
        }
        remote.press(.select); sleep(5)
        log("pressed ↩ Now · window=\u{201C}\(windowLabel() ?? "?")\u{201D}")
        return true
    }

    /// Open the collections overlay and choose `name`; wait `settle` seconds after the pick.
    private func chooseCollection(_ name: String, settle: UInt32 = 6) -> Bool {
        for _ in 0..<8 {
            if let b = collectionsButton(), focusedElements().contains(where: { $0.label == b.label && $0.frame.minY < Self.headerBottom }) { break }
            if let f = focusedElements().first, f.frame.minY >= Self.headerBottom { remote.press(.up) } else { remote.press(.left) }
            usleep(1_200_000)
        }
        guard let b = collectionsButton(),
              focusedElements().contains(where: { $0.label == b.label && $0.frame.minY < Self.headerBottom }) else {
            log("could not focus the collections button; focus=\(focusLine())"); return false
        }
        remote.press(.select)
        guard app.staticTexts["Show in the Guide"].waitForExistence(timeout: 20) else { log("the overlay did not open"); return false }
        sleep(3)
        for _ in 0...8 {
            if focusedElements().contains(where: { $0.label.contains(name) }) {
                remote.press(.select); sleep(settle)
                // A short settle means a press must follow inside the read: no query here, because a
                // snapshot of 202 rows holds the app's main thread while focus is still being handed
                // from the closing overlay to the grid, and a Menu in that gap reaches the shell instead.
                if settle >= 4 {
                    log("chose \u{201C}\(name)\u{201D} · button now \u{201C}\(collectionsButton()?.label ?? "?")\u{201D}")
                } else {
                    log("chose \u{201C}\(name)\u{201D}")
                }
                return true
            }
            remote.press(name == "All Channels" ? .up : .down)
            usleep(1_000_000)
        }
        log("could not reach the \u{201C}\(name)\u{201D} row"); return false
    }

    /// Left along the row to its channel cell, the window read after every press.
    private func walkLeftToChannelCell(window: Int) -> Bool {
        for _ in 0..<12 {
            if zone() == "grid:channel-cell" { return true }
            guard zone() == "grid:programme-cell" else { return false }
            remote.press(.left)
            usleep(1_500_000)
            XCTAssertEqual(windowPosition(), window, "a Left along the row moved the window")
        }
        return zone() == "grid:channel-cell"
    }

    private func intoTheGrid() {
        for _ in 0..<6 {
            if zone().hasPrefix("grid") { return }
            remote.press(.down); usleep(1_100_000)
        }
    }

    // MARK: the run of record — the regression on a healthy server

    func testWindowAndCollectionMovesStillFillTheGrid() {
        app.launch()
        log("launched")
        openGuide()
        log(stage("OPEN") + " clockHalfHour=\(currentHalfHourPosition())")
        XCTAssertTrue(stripFirstColumn()?.hasSuffix("\u{00B7} now") == true, "the Guide did not open at now")
        XCTAssertGreaterThan(programmeCellsDrawn(), 0, "no programme cells at open")
        if collectionsButton()?.label != "All Channels" {
            log("the Guide opened on \u{201C}\(collectionsButton()?.label ?? "?")\u{201D} — choosing All Channels first")
            XCTAssertTrue(chooseCollection("All Channels"), "could not choose All Channels at the start")
            intoTheGrid()
        }
        guard let atNow = windowPosition() else { return XCTFail("no window label at open") }
        XCTAssertEqual(collectionsButton()?.label, "All Channels", "not on All Channels at the start")
        let allChannelsRows = channelCellsDrawn()
        shot("01-open-at-now")

        // +12h twice, then Menu: the window at now, the grid filled.
        XCTAssertTrue(pressPlus12h(), "could not press +12h (1)")
        XCTAssertTrue(pressPlus12h(), "could not press +12h (2)")
        log(stage("PLUS 24H"))
        XCTAssertEqual(windowPosition(), atNow + 1440, "two +12h did not move the window 24 h")
        XCTAssertGreaterThan(programmeCellsDrawn(), 0, "no programme cells 24 h ahead")
        shot("02-plus-24h")
        remote.press(.menu); sleep(5)
        log(stage("MENU"))
        XCTAssertEqual(windowPosition(), currentHalfHourPosition(), "Menu did not snap the window to now")
        XCTAssertTrue(stripFirstColumn()?.hasSuffix("\u{00B7} now") == true, "\"· now\" is not drawn after Menu")
        XCTAssertFalse(nowPillDrawn(), "↩ Now is drawn at now after Menu")
        XCTAssertGreaterThan(programmeCellsDrawn(), 0, "the grid is empty after Menu")
        shot("03-menu-back-at-now")

        // +12h twice, then ↩ Now: the same.
        XCTAssertTrue(pressPlus12h(), "could not press +12h (3)")
        XCTAssertTrue(pressPlus12h(), "could not press +12h (4)")
        XCTAssertEqual(windowPosition(), currentHalfHourPosition() + 1440, "two +12h did not move the window 24 h (again)")
        XCTAssertTrue(pressNow(), "could not press ↩ Now")
        log(stage("NOW PILL"))
        XCTAssertEqual(windowPosition(), currentHalfHourPosition(), "↩ Now did not snap the window to now")
        XCTAssertTrue(stripFirstColumn()?.hasSuffix("\u{00B7} now") == true, "\"· now\" is not drawn after ↩ Now")
        XCTAssertGreaterThan(programmeCellsDrawn(), 0, "the grid is empty after ↩ Now")
        shot("04-now-pill-back-at-now")

        // Pass 123's ring hold and Pass 122's back-step, from now: hold Right, one Left click, hold Left.
        intoTheGrid()
        let before = windowPosition() ?? 0
        remote.press(.right, forDuration: 3.0)
        sleep(3)
        let ahead = ((windowPosition() ?? 0) - before) / 30
        log(stage("HELD RIGHT 3 s -> \(ahead) slot(s)"))
        XCTAssertGreaterThanOrEqual(ahead, 2, "a 3 s held Right moved the window \(ahead) slot(s)")
        XCTAssertGreaterThan(programmeCellsDrawn(), 0, "the grid is empty after the held Right")
        let aheadStart = windowPosition() ?? 0
        XCTAssertTrue(walkLeftToChannelCell(window: aheadStart), "could not reach the channel cell; focus=\(focusLine())")
        guard let channel = focusedLabel() else { return XCTFail("nothing focused on the channel cell") }
        remote.press(.left); sleep(3)
        log(stage("ONE LEFT CLICK ON THE CHANNEL CELL"))
        XCTAssertEqual(windowPosition(), aheadStart - 30, "the Left click did not step the window back one slot")
        XCTAssertEqual(focusedLabel(), channel, "the back-step moved focus off the channel cell")
        shot("05-back-step")
        let slotsLeft = ((windowPosition() ?? 0) - currentHalfHourPosition()) / 30
        remote.press(.left, forDuration: Double(slotsLeft) * 0.75 + 4.0)
        sleep(3)
        let nowAfterHold = currentHalfHourPosition()
        log(stage("HELD LEFT") + " clockHalfHour=\(nowAfterHold)")
        XCTAssertEqual(windowPosition(), nowAfterHold, "the held Left did not bring the window back to the current half hour")
        XCTAssertEqual(zone(), "grid:channel-cell", "the held Left carried focus out of the grid")
        XCTAssertGreaterThan(programmeCellsDrawn(), 0, "the grid is empty after the held Left")
        shot("06-held-left-at-now")

        // A pick while ahead redraws in place: +12h, choose Local, the window unmoved and the rows Local's;
        // then All Channels back, the window still unmoved.
        XCTAssertTrue(pressPlus12h(), "could not press +12h (5)")
        let pickWindow = windowPosition()
        XCTAssertTrue(chooseCollection("Local"), "could not choose Local")
        log(stage("LOCAL WHILE AHEAD") + " channelCells=\(channelCellsDrawn())")
        XCTAssertEqual(collectionsButton()?.label, "Local", "the button does not read Local")
        XCTAssertEqual(windowPosition(), pickWindow, "the pick moved the window")
        // Local's members are the owner's and change — eleven rows on 2026-09-25 where Pass 77 knew five, and
        // WBFF45, then a non-member, is one now — so the test assumes no member but its first: WMAR-HD drawn,
        // and fewer channel rows than All Channels draws.
        XCTAssertTrue(channelCell("2.1").exists, "WMAR-HD 2.1 is not drawn under Local")
        XCTAssertLessThan(channelCellsDrawn(), allChannelsRows, "Local draws no fewer channel rows (\(channelCellsDrawn())) than All Channels (\(allChannelsRows))")
        XCTAssertGreaterThan(programmeCellsDrawn(), 0, "the grid is empty under Local")
        shot("07-local-while-ahead")
        XCTAssertTrue(chooseCollection("All Channels"), "could not put All Channels back")
        log(stage("ALL CHANNELS BACK") + " channelCells=\(channelCellsDrawn())")
        XCTAssertEqual(collectionsButton()?.label, "All Channels", "the button does not read All Channels")
        XCTAssertEqual(windowPosition(), pickWindow, "putting All Channels back moved the window")
        XCTAssertEqual(channelCellsDrawn(), allChannelsRows, "All Channels does not draw the rows it drew at the start")
        shot("08-all-channels-back")

        // Leave the Guide at now.
        remote.press(.menu); sleep(4)
        log(stage("MENU AT THE END"))
        XCTAssertEqual(windowPosition(), currentHalfHourPosition(), "Menu did not snap the window to now at the end")
        XCTAssertGreaterThan(programmeCellsDrawn(), 0, "the grid is empty at the end")
        log("RESULT +12h twice → Menu and → ↩ Now filled at now; hold Right \(ahead) slots, one back-step, held Left to now; Local while ahead in place; All Channels back")
    }

    // MARK: the discard branch, against the console-launched process with the delay

    /// Against a process `devicectl … --console` started with `MARLIN_PROBE_FETCH_DELAY` (the disclosed
    /// diagnostic, reverted before the commit): +12h, +12h and Menu inside the held read. The app's own
    /// `[guide] read … discarded` line is the evidence; the harness reads what is left on screen. (A pick
    /// and then Menu inside the pick's read cannot be driven — see the header.)
    func testAReadThatLandsLateIsDiscarded() {
        continueAfterFailure = true
        log("ATTACHING to the process devicectl launched — no launch(), no activate()")
        openGuide()
        log(stage("OPEN"))
        if collectionsButton()?.label != "All Channels" {
            XCTAssertTrue(chooseCollection("All Channels"), "could not choose All Channels at the start")
            intoTheGrid()
        }
        guard let atNow = windowPosition() else { return XCTFail("no window label at open") }

        // REVIEW.md's case: the second +12h starts a read; Menu lands before it does.
        XCTAssertTrue(pressPlus12h(settle: 1), "could not press +12h (1)")
        XCTAssertTrue(pressPlus12h(settle: 1), "could not press +12h (2)")
        remote.press(.menu)
        log("Menu pressed about 1 s after the second +12h — inside the held read")
        sleep(8)
        log(stage("MENU INSIDE THE READ"))
        XCTAssertEqual(windowPosition(), currentHalfHourPosition(), "the window is not at now after Menu")
        XCTAssertTrue(stripFirstColumn()?.hasSuffix("\u{00B7} now") == true, "\"· now\" is not drawn")
        XCTAssertFalse(nowPillDrawn(), "↩ Now is drawn at now")
        XCTAssertGreaterThan(programmeCellsDrawn(), 0, "the grid is empty after the late read landed")
        shot("stale-01-menu-inside-the-read")
        _ = atNow
    }
}
