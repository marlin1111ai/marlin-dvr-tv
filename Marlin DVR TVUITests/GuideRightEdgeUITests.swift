//
//  GuideRightEdgeUITests.swift
//  Marlin DVR TVUITests
//
//  Pass 76's evidence harness, not a standing test. It exists to answer the first open question of
//  `reports/2026-09-12-pass75-guide-scroll-recon.md`: **what does a Right press do at the right-hand
//  edge of a Guide row, and does the app ever see it?** Pass 75 §2.3 established that no device run
//  in `reports/` had ever pressed Right inside a Guide row at all, so even the baseline — that Right
//  walks a row cell by cell — was untested.
//
//  It needs the physical Apple TV and the real Siri Remote. **It makes no server write**: it never
//  opens the airing sheet, never records, never touches a collection, and never presses Select on a
//  programme cell (which would start playback). Its only non-GET traffic is the app's own launch
//  ping, and it does not even cause that, because it uses `activate()`.
//
//  **`activate()`, never `launch()`** — the `CommercialSkipUITests` pattern, for the same reason
//  (COLD-START, Pass 38): XCUITest does not forward the app's `print` output, so the app is started
//  separately with `xcrun devicectl device process launch --console --terminate-existing` and this
//  harness joins the running process instead of replacing it. A `launch()` here would kill that
//  process and take the `[probe]` lines with it.
//
//  **Every query is a predicate, never an enumeration.** The Guide realises all 91 channel rows at
//  once and `app.buttons.count` reads 375 unfiltered, so a full accessibility walk resolves 585+
//  elements at roughly 0.8 s each — two Pass 72 harness runs were killed at t = 1317 s and t = 908 s
//  before the queries were rewritten. Do not reintroduce one.
//
//  Run (the app first, with its console attached, then the tests):
//    xcrun devicectl device process launch --device "Home Theater" --console --terminate-existing \
//      com.marlin1111.MarlinDVRTV &
//    xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
//      -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates test \
//      -only-testing:"Marlin DVR TVUITests/GuideRightEdgeUITests"
//

import XCTest

final class GuideRightEdgeUITests: XCTestCase {
    private var app: XCUIApplication!
    private let remote = XCUIRemote.shared

    /// Drawn by the Guide's legend whatever the grid holds — the marker that the screen is up.
    private let guideLegend = "Recording or set to record"

    /// The header band. Measured on Home Theater in Pass 72: the title draws at y 60-122 and the
    /// pills at y 79-123, while the grid's first row starts at y 238 — so 200 separates them.
    private static let headerBottom: CGFloat = 200
    /// The content area starts at x≈236; the collapsed rail is to the left of it.
    private static let contentLeft: CGFloat = 200
    /// The channel column is 300 pt wide from x≈236, so a programme cell starts at x≈554.
    private static let channelColumnRight: CGFloat = 545
    /// The programme area is 1920 − 236 − 80 − 300 − 18 = 1286 pt wide, so a cell wider than this
    /// fills the whole 2-hour window.
    private static let fullWindowWidth: CGFloat = 1200

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.activate()
        goHome()
    }

    // MARK: reading the device

    private func shot(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    private func stamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: Date())
    }

    private func log(_ line: String) { print("[pass76 \(stamp())] \(line)") }

    /// Predicate only — see the file header.
    private func focusedElements() -> [XCUIElement] {
        app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == YES")).allElementsBoundByIndex
    }

    private func rect(_ f: CGRect) -> String {
        "(\(Int(f.minX)),\(Int(f.minY)) \(Int(f.width))x\(Int(f.height)))"
    }

    /// One line describing everything focused, with frames — the per-press record the pass asks for.
    private func focusLine() -> String {
        let focused = focusedElements()
        if focused.isEmpty { return "NOTHING FOCUSED" }
        return focused.map { "\($0.elementType.rawValue):\u{201C}\($0.label)\u{201D} \(rect($0.frame))" }
            .joined(separator: " | ")
    }

    /// The single focused element that is a programme cell or channel cell in the grid, if any.
    private func focusedInGrid() -> XCUIElement? {
        focusedElements().first { $0.frame.minY >= Self.headerBottom && $0.frame.minX > Self.contentLeft }
    }

    private func focusedFrame() -> CGRect? { focusedElements().first?.frame }

    /// Where focus is, in words — so "Right at the edge went to the +12h pill" is a reading and not
    /// an interpretation.
    private func focusZone() -> String {
        let focused = focusedElements()
        guard let f = focused.first else { return "nowhere" }
        let r = f.frame
        if r.minX < Self.contentLeft { return "rail" }
        if r.minY < Self.headerBottom {
            if f.label.contains("+12h") { return "header:+12h" }
            if f.label.contains("Now") { return "header:↩Now" }
            return "header:\u{201C}\(f.label)\u{201D}"
        }
        if r.minX < Self.channelColumnRight { return "grid:channel-cell" }
        return "grid:programme-cell"
    }

    // MARK: driving the remote

    /// Menu back to Home from wherever a previous test left the app.
    private func goHome() {
        for _ in 0..<7 {
            if app.staticTexts["Marlin"].waitForExistence(timeout: 10) { sleep(2); return }
            remote.press(.menu)
            sleep(3)
        }
    }

    /// Home's first tile is the Guide (`Destination.homeTiles`), so one Select opens it, and the
    /// Guide's own `.task` puts focus on the first programme cell.
    private func openGuide() {
        XCTAssertTrue(app.staticTexts["Marlin"].waitForExistence(timeout: 40), "Home did not appear")
        sleep(3)
        remote.press(.select)
        XCTAssertTrue(app.staticTexts[guideLegend].waitForExistence(timeout: 40), "the Guide did not open")
        sleep(6)   // the fetch, then focusSoon's 80 ms, with room to spare
    }

    /// One press, then the reading. The sleep is generous on purpose: a focus move that is going to
    /// happen has happened well inside 1.5 s, and the app's own `[probe]` line for the press is
    /// emitted 250 ms after it.
    @discardableResult
    private func press(_ button: XCUIRemote.Button, _ tag: String, _ index: Int) -> String {
        let before = focusLine()
        remote.press(button)
        usleep(1_500_000)
        let after = focusLine()
        let moved = before != after
        log("\(tag) press #\(index) \(button == .right ? "RIGHT" : "\(button)") " +
            "zone=\(focusZone()) moved=\(moved)")
        log("\(tag)   before: \(before)")
        log("\(tag)   after : \(after)")
        return after
    }

    // MARK: 1 — Right along the first row, and three presses past its last cell

    func testRightAlongTheFirstRowAndThreePressesPastTheEdge() {
        openGuide()
        shot("01-guide-open-first-cell-focused")
        log("OPEN zone=\(focusZone())")
        log("OPEN focus: \(focusLine())")

        guard let opening = focusedInGrid() else {
            shot("01x-nothing-focused-in-the-grid")
            return XCTFail("the Guide opened with nothing focused in the grid; focus=\(focusLine())")
        }
        log("OPEN the Guide focused \u{201C}\(opening.label)\u{201D} \(rect(opening.frame))")
        XCTAssertTrue(opening.frame.minX > Self.channelColumnRight,
                      "the Guide did not open on a programme cell; focus=\(focusLine())")

        // Walk right until a press changes nothing. That press is the edge, and its index is how
        // many cells of this row were visible.
        var readings: [String] = [focusLine()]
        var zones: [String] = [focusZone()]
        var edgeAt: Int?
        for i in 1...14 {
            let after = press(.right, "WALK", i)
            zones.append(focusZone())
            if after == readings.last {
                edgeAt = i
                log("WALK press #\(i) changed nothing — this is the edge")
                break
            }
            readings.append(after)
        }
        shot("02-at-the-last-visible-cell")

        guard let edge = edgeAt else {
            log("WALK focus was still moving after 14 Right presses — this row has more than 14 cells, or Right is doing something else")
            shot("02x-still-moving-after-14")
            return XCTFail("never reached a press that changed nothing in 14 Right presses; readings=\(readings.count)")
        }

        log("RESULT cells walked before the edge: \(edge - 1) (presses 1…\(edge - 1) each moved focus)")
        log("RESULT zones in order: \(zones.joined(separator: " -> "))")

        // Three more presses at the edge. This is the pass's subject.
        for i in 1...3 {
            press(.right, "EDGE", i)
        }
        shot("03-three-presses-past-the-edge")
        log("EDGE after three more Right presses: zone=\(focusZone()) focus=\(focusLine())")

        // And the negative control: Left from the edge must move, which proves the remote and the
        // focus engine were both alive for the three presses above.
        press(.left, "CONTROL", 1)
        shot("04-left-from-the-edge-moves")
        log("CONTROL Left from the edge: zone=\(focusZone())")
    }

    // MARK: 1b — the same walk on a row of 30-minute cells

    /// Test 1 is the row the brief names — the **first** row — and on the morning this ran that row
    /// held only two cells, so "Right walks a row cell by cell" rested on a single moving press.
    /// This repeats the walk one row down, where the cells are 315 pt (30 minutes) rather than
    /// 637 pt, so the same claim is carried by more than one moving press and the edge is reached
    /// from a four-cell row — which is the shape the owner's goal is actually about.
    func testRightAlongARowOfHalfHourCells() {
        openGuide()
        guard focusedInGrid() != nil else {
            return XCTFail("the Guide opened with nothing focused in the grid; focus=\(focusLine())")
        }

        // One row down, then back to that row's leftmost cell: Left to the channel cell, Right once.
        remote.press(.down)
        usleep(1_200_000)
        log("ROW1 after Down: \(focusLine())")
        for _ in 0..<3 {
            guard let f = focusedFrame(), f.minX > Self.channelColumnRight else { break }
            remote.press(.left)
            usleep(1_200_000)
        }
        log("ROW1 at the channel cell: \(focusLine())")
        remote.press(.right)
        usleep(1_500_000)
        guard let first = focusedInGrid(), first.frame.minX > Self.channelColumnRight else {
            shot("07x-could-not-reach-the-first-cell-of-row-1")
            return XCTFail("could not get back to row 1's first programme cell; focus=\(focusLine())")
        }
        log("ROW1 first cell: \u{201C}\(first.label)\u{201D} \(rect(first.frame))")
        shot("07-row-1-first-cell")

        var readings = [focusLine()]
        var moved = 0
        var edgeAt: Int?
        for i in 1...10 {
            let after = press(.right, "ROW1WALK", i)
            if after == readings.last {
                edgeAt = i
                log("ROW1WALK press #\(i) changed nothing — this is the edge after \(moved) moving press(es)")
                break
            }
            moved += 1
            readings.append(after)
        }
        shot("08-row-1-at-the-edge")
        XCTAssertNotNil(edgeAt, "row 1 never stopped moving in 10 Right presses")
        log("ROW1 RESULT \(moved) moving Right press(es), then the edge; zone=\(focusZone())")

        // Two more at the edge, then the control.
        press(.right, "ROW1EDGE", 1)
        press(.right, "ROW1EDGE", 2)
        log("ROW1EDGE after two more: zone=\(focusZone()) focus=\(focusLine())")
        press(.left, "ROW1CONTROL", 1)
        shot("09-row-1-left-from-the-edge")
    }

    // MARK: 2 — Right on a cell that already fills the whole window

    func testRightOnACellThatFillsTheWindow() {
        openGuide()
        log("OPEN focus: \(focusLine())")
        guard focusedInGrid() != nil else {
            return XCTFail("the Guide opened with nothing focused in the grid; focus=\(focusLine())")
        }

        // Down moves to the cell in the next row that overlaps horizontally, so one press a row is
        // enough to survey widths. A cell wider than 1200 pt fills the 1286 pt programme area.
        var widest: (label: String, frame: CGRect)?
        var found: (label: String, frame: CGRect)?
        for row in 0..<20 {
            guard let cell = focusedInGrid(), cell.frame.minX > Self.channelColumnRight else {
                log("SURVEY row \(row): focus is not on a programme cell (\(focusZone())) — stopping the walk")
                break
            }
            let f = cell.frame
            log("SURVEY row \(row): \u{201C}\(cell.label)\u{201D} \(rect(f))")
            if widest == nil || f.width > widest!.frame.width { widest = (cell.label, f) }
            if f.width > Self.fullWindowWidth {
                found = (cell.label, f)
                log("SURVEY row \(row) fills the window: width \(Int(f.width)) pt > \(Int(Self.fullWindowWidth))")
                break
            }
            remote.press(.down)
            usleep(1_200_000)
        }

        if found == nil {
            log("SURVEY no row in the first 20 had a single cell filling the window; widest was " +
                "\u{201C}\(widest?.label ?? "-")\u{201D} at \(widest.map { Int($0.frame.width) } ?? 0) pt")
            shot("05x-no-full-window-cell-found")
        } else {
            shot("05-a-cell-that-fills-the-window")
        }

        // Press Right wherever the survey stopped. If `found` is non-nil this is the pass's second
        // case — a first cell that is also the last cell. If it is nil, it is still a Right press on
        // the widest cell available, and the reading is reported as that rather than as the case
        // asked for.
        log("FULL before: zone=\(focusZone()) focus=\(focusLine())")
        for i in 1...3 {
            press(.right, "FULL", i)
        }
        shot("06-right-on-a-full-window-cell")
        log("FULL after three Right presses: zone=\(focusZone()) focus=\(focusLine())")

        press(.left, "FULLCONTROL", 1)
        log("FULLCONTROL Left from it: zone=\(focusZone())")
    }
}
