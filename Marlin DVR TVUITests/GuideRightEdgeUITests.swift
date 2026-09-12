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
//  Pass 79 extends it again, with five checks for "the Guide keeps up with the clock". Those tests
//  **wait out real half-hour boundaries** — there is no way to fake one from outside the app — so
//  each takes up to about 35 minutes and only one boundary can be spent on one state. Run them one
//  at a time, with `-only-testing` down to the method.
//
//  **What has and has not been run, so nobody reads an unrun test as a green one** (Pass 79 §4):
//    testTheWindowRollsWithTheClockAtNow      RUN, passed — the real 14:30 and 13:30 boundaries
//    testTheRollHoldsTheCollection            RUN, passed — the real 14:00 boundary, "Local" selected
//    testTheClockStopsWhenTheGuideDoes        RUN, passed — four Guide visits, beat counts matched
//    testAScrolledWindowDoesNotRoll…          RUN PARTWAY — killed ~18 min before its boundary; it
//                                             measured the ↩ Now pill tracking the clock for ten
//                                             minutes on a window that did not move, and no more
//    testTheGuideIsAtTheTrueHalfHour…         NEVER RUN — written, compiles, never executed
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

    /// Home's own Guide tile. A Home tile's label is "<name>, <sub-line>" (Pass 20), and nothing on
    /// any other screen draws one — unlike `"Marlin"`, which is Home's greeting **and** the rail's
    /// wordmark, so waiting for that mistakes an expanded rail for Home.
    private var homeGuideTile: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Guide, ")).firstMatch
    }

    /// Menu back to Home from wherever a previous test left the app. Menu on a scrolled Guide snaps
    /// the window back to now before it leaves, so this can take two presses from there.
    private func goHome() {
        for _ in 0..<8 {
            if homeGuideTile.waitForExistence(timeout: 8) { sleep(2); return }
            remote.press(.menu)
            sleep(3)
        }
        log("goHome: never reached Home; focus=\(focusLine())")
    }

    /// Home's first tile is the Guide (`Destination.homeTiles`), so one Select opens it, and the
    /// Guide's own `.task` puts focus on the first programme cell.
    private func openGuide() {
        XCTAssertTrue(homeGuideTile.waitForExistence(timeout: 40), "Home did not appear")
        sleep(3)
        // Home opens with the Guide tile focused (`HomeView.defaultFocus`), but come back to it if a
        // previous test left focus elsewhere — selecting the Guide rail entry while already on the
        // Guide changes nothing, because `ScreenShell`'s `.id(current)` only rebuilds on a change.
        for _ in 0..<5 {
            if focusedElements().first?.label.hasPrefix("Guide, ") == true { break }
            remote.press(.up); usleep(800_000)
            if focusedElements().first?.label.hasPrefix("Guide, ") == true { break }
            remote.press(.left); usleep(800_000)
        }
        XCTAssertTrue(focusedElements().first?.label.hasPrefix("Guide, ") == true,
                      "could not focus Home's Guide tile; focus=\(focusLine())")
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

    // MARK: Pass 77 — the window, the strip and the collection while scrolled

    /// The header's window label — "Sat Sep 12 · 8:30 – 10:30 AM", or the midnight-crossing form
    /// "Sat Sep 12 · 11:30 PM → Sun Sep 13 · 1:30 AM". The spaced en dash and the arrow are unique
    /// to it: the time strip's own labels carry neither, so this stays a predicate.
    private func windowLabel() -> String? {
        for needle in [" \u{2013} ", " \u{2192} "] {
            let e = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", needle)).firstMatch
            if e.exists { return e.label }
        }
        return nil
    }

    /// The first clock in the window label — the window's own start, which is also what the time
    /// strip's first column must read.
    private func windowStartClock() -> String? {
        guard let label = windowLabel() else { return nil }
        guard let r = label.range(of: "[0-9]{1,2}:[0-9]{2}", options: .regularExpression) else { return nil }
        return String(label[r])
    }

    /// The window's start as an absolute, **monotonic** minute count, so a 30-minute step can be
    /// asserted and slots counted across midnight. Minutes past midnight alone cannot: the first
    /// attempt at this test counted 42 slots where the app had advanced 90, because the clock wrapped
    /// at midnight. The date in the label is what fixes it.
    ///
    /// The label is `"Sat Sep 12 · 9:00 – 11:00 AM"`, or `"Sat Sep 12 · 11:30 PM → Sun Sep 13 ·
    /// 1:30 AM"` when the window crosses midnight; either way the first date and the first clock are
    /// the window's own start. `TimeFormat.timeRange` omits the start's meridiem when both ends share
    /// it, so it is taken from the text right after the clock when it is there and from the end
    /// otherwise.
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

    /// Put focus in the header. Up out of the grid; never Left, because Left from the header's
    /// leftmost pill leaves for the rail and coming back lands in the grid, not the header — which is
    /// how the first two attempts at this helper failed.
    @discardableResult
    private func intoTheHeader(_ tag: String) -> Bool {
        for _ in 0..<16 {
            guard let f = focusedElements().first else { break }
            if f.frame.minX < Self.contentLeft {          // in the rail: cross into the content first
                remote.press(.right); usleep(1_100_000); continue
            }
            if f.frame.minY < Self.headerBottom { return true }
            let before = f.label + rect(f.frame)
            remote.press(.up); usleep(1_100_000)
            let after = focusedElements().first.map { $0.label + rect($0.frame) }
            if after == before {
                // Up did nothing: the header's focusable items are the collections button at the left
                // and the pills at the right, so a cell whose x falls between them has no candidate
                // above it and the focus engine refuses. This is the app's existing header geometry,
                // not Pass 77's — `WeatherScreen.swift:109-113` records the same thing for its Radar
                // button. Step left and try again.
                remote.press(.left); usleep(1_100_000)
            }
        }
        let ok = (focusedElements().first?.frame.minY ?? 9999) < Self.headerBottom
        if !ok { log("\(tag) never reached the header; focus=\(focusLine())") }
        return ok
    }

    /// The header's rightmost focusable pill. The header holds, left to right, the collections button,
    /// then `↩ Now` when the window is ahead of now, then `+12h` while there are listings — so walking
    /// Right until focus stops moving lands on `+12h` whenever it is drawn.
    @discardableResult
    private func toHeaderRightEnd(_ tag: String) -> String? {
        guard intoTheHeader(tag) else { return nil }
        var last = focusedElements().first?.label
        for _ in 0..<5 {
            remote.press(.right); usleep(1_000_000)
            guard let f = focusedElements().first, f.frame.minY < Self.headerBottom else { break }
            if f.label == last { break }
            last = f.label
        }
        log("\(tag) header right end is \u{201C}\(last ?? "?")\u{201D}")
        return last
    }

    /// The header's `+12h` pill: the right-hand end of the header.
    private func pressPlus12h(_ tag: String) -> Bool {
        guard let label = toHeaderRightEnd(tag), label.contains("+12h") else {
            log("\(tag) the header's right end is not +12h; focus=\(focusLine())")
            return false
        }
        remote.press(.select); sleep(5)
        log("\(tag) pressed +12h · window=\u{201C}\(windowLabel() ?? "?")\u{201D}")
        return true
    }

    /// The `↩ Now` pill: one Left from `+12h` when both are drawn, which they are whenever the window
    /// is ahead of now and there are listings left.
    private func pressNow(_ tag: String) -> Bool {
        guard let label = toHeaderRightEnd(tag) else { return false }
        if label.contains("Now") {
            remote.press(.select); sleep(5)
            log("\(tag) pressed \u{201C}\(label)\u{201D}")
            return true
        }
        remote.press(.left); usleep(1_100_000)
        guard let f = focusedElements().first, f.frame.minY < Self.headerBottom, f.label.contains("Now") else {
            log("\(tag) could not reach ↩ Now; focus=\(focusLine())")
            return false
        }
        remote.press(.select); sleep(5)
        log("\(tag) pressed \u{201C}\(f.label)\u{201D}")
        return true
    }

    /// Everything focused, as "type:label" — the short form, for the overlay walk.
    private func focusLabels() -> [String] {
        focusedElements().map { "\($0.elementType.rawValue):\($0.label)" }
    }

    /// The rail is the left edge of the screen; the content area starts at x≈236.
    private func focusIsInTheRail() -> Bool {
        focusedElements().contains { $0.frame.minX < Self.contentLeft }
    }

    /// The right-hand edge of the programme area: 1920 − 80 pt trailing margin. A cell clipped by the
    /// window is drawn flush to it with no inset (Pass 75 §2.1), so the row's last visible cell is the
    /// one whose `maxX` reaches here.
    private static let programmeAreaRight: CGFloat = 1840
    private static let flushSlack: CGFloat = 12

    /// The time strip's first column must read the window's own start. Asserted by exact prefix, and
    /// its frame printed, so "the strip moved with the rows" is a reading and not an impression.
    @discardableResult
    private func stripFirstColumn(_ tag: String) -> String? {
        guard let clock = windowStartClock() else {
            log("\(tag) STRIP no window label to read")
            return nil
        }
        let e = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", clock)).firstMatch
        guard e.exists else {
            log("\(tag) STRIP no strip label beginning \u{201C}\(clock)\u{201D}")
            return nil
        }
        log("\(tag) STRIP first column \u{201C}\(e.label)\u{201D} \(rect(e.frame))")
        return e.label
    }

    /// One line tying the window, the strip and the focus together — the per-press record.
    private func windowLine(_ tag: String) -> String {
        let w = windowLabel() ?? "NO LABEL"
        return "\(tag) window=\u{201C}\(w)\u{201D} startMin=\(windowPosition().map(String.init) ?? "?") focus=\(focusLine())"
    }

    /// Back into the grid from the header or the rail, on to a programme cell.
    private func intoTheGrid(_ tag: String) {
        for _ in 0..<8 {
            if let f = focusedElements().first {
                if f.frame.minX < Self.contentLeft {     // in the rail: cross back first
                    remote.press(.right); usleep(1_200_000); continue
                }
                if f.frame.minY >= Self.headerBottom, f.frame.minX > Self.channelColumnRight { return }
            }
            remote.press(.down)
            usleep(1_200_000)
        }
        log("\(tag) could not get back on to a programme cell; focus=\(focusLine())")
    }

    /// Walk Right to the row's last visible cell **without pressing Right on it** — which matters now,
    /// because a Right press there moves the window. The last cell is identified by geometry, not by
    /// "the press changed nothing": since Pass 77 that test is meaningless, because the edge press
    /// changes the window instead of the focus.
    @discardableResult
    private func walkToLastCell(_ tag: String, limit: Int = 14) -> Bool {
        for i in 0...limit {
            var frame = focusedInGrid()?.frame
            if frame == nil {                            // one retry: the tree can be mid-settle
                usleep(1_200_000)
                frame = focusedInGrid()?.frame
            }
            guard let f = frame else {
                log("\(tag) nothing focused in the grid; focus=\(focusLine())")
                return false
            }
            if f.maxX >= Self.programmeAreaRight - Self.flushSlack {
                log("\(tag) on the row's last visible cell after \(i) press(es): \(focusLine())")
                return true
            }
            remote.press(.right)
            usleep(1_500_000)
        }
        log("\(tag) never reached a cell flush with the window edge; focus=\(focusLine())")
        return false
    }

    /// One Right press, classified by what it actually did: moved the window on by a slot, or was
    /// taken by the focus engine to move along the row. This is the unit of evidence for Pass 77.
    private enum PressOutcome: String { case nudged, focusMoved, nothing }

    private func pressRightAndClassify(_ tag: String, _ index: Int) -> PressOutcome {
        let beforeWindow = windowPosition()
        let beforeFocus = focusLine()
        remote.press(.right)
        usleep(2_000_000)            // the 150 ms settle, the nudge, and focusSoon's 80 ms
        let afterWindow = windowPosition()
        let afterFocus = focusLine()
        let outcome: PressOutcome
        if let b = beforeWindow, let a = afterWindow, a != b { outcome = .nudged }
        else if afterFocus != beforeFocus { outcome = .focusMoved }
        else { outcome = .nothing }
        let step = (beforeWindow != nil && afterWindow != nil) ? (afterWindow! - beforeWindow!) : -1
        log("\(tag) press #\(index) -> \(outcome.rawValue) windowStep=\(step)min " +
            "window=\u{201C}\(windowLabel() ?? "?")\u{201D}")
        log("\(tag)   focus before: \(beforeFocus)")
        log("\(tag)   focus after : \(afterFocus)")
        return outcome
    }

    /// Press Right at a brisk cadence until the window has advanced `slots` slots, or the press cap
    /// is reached. Used by the bulk tests, where the reading that matters is the end state.
    @discardableResult
    private func nudge(slots: Int, cap: Int, _ tag: String) -> (slots: Int, presses: Int) {
        guard let start = windowPosition() else {
            log("\(tag) no window label to start from")
            return (0, 0)
        }
        var presses = 0
        var advanced = 0
        while advanced < slots && presses < cap {
            remote.press(.right)
            presses += 1
            usleep(1_100_000)
            if let now = windowPosition() { advanced = (now - start) / 30 }
            if presses % 12 == 0 {
                log("\(tag) \(presses) presses -> \(advanced) slots · window=\u{201C}\(windowLabel() ?? "?")\u{201D}")
            }
        }
        log("\(tag) DONE \(advanced) slot(s) in \(presses) press(es) · window=\u{201C}\(windowLabel() ?? "?")\u{201D}")
        return (advanced, presses)
    }

    /// The collections button, and the overlay, reduced to what Pass 77 needs.
    private func collectionsButton() -> XCUIElement? {
        for label in ["All Channels", "Local", "Test"] {
            let e = app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
            if e.exists && e.frame.minY < Self.headerBottom { return e }
        }
        return nil
    }

    private func chooseCollection(_ name: String, _ tag: String) -> Bool {
        for _ in 0..<8 {
            if let b = collectionsButton(), focusedElements().contains(where: { $0.label == b.label && $0.frame.minY < Self.headerBottom }) { break }
            if let f = focusedElements().first, f.frame.minY >= Self.headerBottom { remote.press(.up) } else { remote.press(.left) }
            usleep(1_200_000)
        }
        guard let b = collectionsButton(),
              focusedElements().contains(where: { $0.label == b.label && $0.frame.minY < Self.headerBottom }) else {
            log("\(tag) could not focus the collections button; focus=\(focusLine())")
            return false
        }
        remote.press(.select)
        guard app.staticTexts["Show in the Guide"].waitForExistence(timeout: 20) else {
            log("\(tag) the overlay did not open")
            return false
        }
        sleep(4)
        for _ in 0...8 {
            if focusLabels().contains(where: { $0.contains(name) }) {
                remote.press(.select)
                sleep(6)
                log("\(tag) chose \u{201C}\(name)\u{201D} · button now \u{201C}\(collectionsButton()?.label ?? "?")\u{201D}")
                return true
            }
            remote.press(name == "All Channels" ? .up : .down)
            usleep(1_000_000)
        }
        log("\(tag) could not reach the \u{201C}\(name)\u{201D} row")
        return false
    }

    /// The five members of the owner's "Local" collection in the server's order (Pass 72).
    private let localRows = [("WMAR-HD", "2.1"), ("WGAL-TV", "8.1"), ("WBAL-DT", "11.1"), ("WJZ-TV", "13.1"), ("ESPN", "50007")]
    private let notInLocal = [("WBFF45", "45.1"), ("CWWNUV", "54.1")]

    private func channelCell(_ number: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", ", \(number)")).firstMatch
    }

    private func localRowOrder() -> [String] {
        localRows.map { (name: $0.0, element: channelCell($0.1)) }
            .filter { $0.element.exists }
            .sorted { $0.element.frame.minY < $1.element.frame.minY }
            .map(\.name)
    }

    // MARK: (a) — three nudges, the strip moving with them, 30 minutes each

    func testNudgeMovesTheWindowAndSettlesFocus() {
        openGuide()
        log(windowLine("OPEN"))
        stripFirstColumn("OPEN")
        shot("20-before-any-nudge")

        guard let startMin = windowPosition() else {
            return XCTFail("could not read the window label; focus=\(focusLine())")
        }
        XCTAssertTrue(focusedInGrid() != nil, "the Guide opened with nothing focused in the grid")
        XCTAssertTrue(walkToLastCell("WALK"), "could not reach the row's last visible cell")
        log(windowLine("ATEDGE"))
        XCTAssertEqual(windowPosition(), startMin,
                       "walking to the last cell moved the window — it must not")

        // Press Right until three nudges have happened, classifying every press. Three nudges is what
        // VERIFY (a) asks to see; how many presses they take is the reading, not the target.
        var minutes = [startMin]
        var outcomes: [PressOutcome] = []
        var nudges = 0
        for i in 1...10 {
            let outcome = pressRightAndClassify("EDGE", i)
            outcomes.append(outcome)
            if outcome == .nudged {
                nudges += 1
                if let w = windowPosition() { minutes.append(w) }
                stripFirstColumn("NUDGE#\(nudges)")
                shot("2\(nudges)-after-nudge-\(nudges)")
            }
            if nudges == 3 { break }
        }

        log("EDGE outcomes in order: \(outcomes.map(\.rawValue).joined(separator: " -> "))")
        log("EDGE window start minutes at each nudge: \(minutes)")
        XCTAssertEqual(nudges, 3, "expected three nudges inside ten presses; outcomes=\(outcomes)")
        for i in 1..<minutes.count {
            let step = minutes[i] - minutes[i - 1]
            XCTAssertEqual(step, 30, "nudge \(i) moved the window \(step) minutes, not 30")
        }
        // The thing Pass 77 has to report: three nudges cost more than three presses whenever the slot
        // a nudge reveals puts a new cell to the right of the focused programme.
        log("RESULT \(nudges) nudges in \(outcomes.count) presses " +
            "(\(outcomes.filter { $0 == .focusMoved }.count) press(es) were taken by the focus engine)")
        XCTAssertFalse(outcomes.contains(.nothing),
                       "a press at the edge did nothing at all — neither the window nor focus moved")
    }

    // MARK: (b) — the two focus outcomes the owner's rule names

    /// Step 2: focus stays on the same programme while that programme is still in the window, and goes
    /// to the leftmost cell its row still has when the programme has left it. Both are driven here from
    /// one run, by nudging until each has been seen.
    func testFocusAfterANudgeBothCases() {
        openGuide()
        XCTAssertTrue(walkToLastCell("B-WALK"), "could not reach the row's last visible cell")

        var heldSeen = false
        var leftSeen = false
        for i in 1...24 {
            guard let before = focusedInGrid() else { break }
            let beforeID = before.label
            let beforeFrame = before.frame
            let outcome = pressRightAndClassify("B", i)
            guard outcome == .nudged else { continue }
            guard let after = focusedInGrid() else {
                XCTFail("nothing focused in the grid after a nudge; focus=\(focusLine())")
                break
            }
            // Same programme: the accessibility label is the programme title, and the frame has shifted
            // left by one slot's width. Different programme: focus was re-placed.
            if after.label == beforeID && after.frame.minX < beforeFrame.minX {
                if !heldSeen {
                    heldSeen = true
                    log("B CASE 1 focus stayed on the same programme \u{201C}\(after.label)\u{201D}: " +
                        "\(rect(beforeFrame)) -> \(rect(after.frame))")
                    shot("30-focus-stayed-on-the-same-programme")
                }
            } else if after.label != beforeID {
                if !leftSeen {
                    leftSeen = true
                    log("B CASE 2 \u{201C}\(beforeID)\u{201D} left the window; focus is now " +
                        "\u{201C}\(after.label)\u{201D} \(rect(after.frame)) — leftmost column x=\(Int(after.frame.minX))")
                    shot("31-focus-moved-to-the-leftmost-cell")
                }
            }
            if heldSeen && leftSeen { break }
        }

        log("B RESULT focus-held seen=\(heldSeen), programme-left-the-window seen=\(leftSeen)")
        XCTAssertTrue(heldSeen, "never saw focus stay on the same programme across a nudge")
        XCTAssertTrue(leftSeen, "never saw focus re-placed after a programme left the window")
    }

    // MARK: (c) — 48 slots, one refetch, strip and rows still aligned

    func testFortyEightSlotsAndTheSingleRefetch() {
        openGuide()
        log(windowLine("C-OPEN"))
        stripFirstColumn("C-OPEN")
        shot("40-before-48-slots")
        XCTAssertTrue(walkToLastCell("C-WALK"), "could not reach the row's last visible cell")

        // 48 *slots*, not 48 presses: the window moves a slot per nudge, and a press the focus engine
        // takes moves focus instead. The press count is reported rather than assumed.
        let (slots, presses) = nudge(slots: 48, cap: 160, "C")
        shot("41-after-48-slots")
        log(windowLine("C-END"))
        stripFirstColumn("C-END")
        log("C RESULT \(slots) slots in \(presses) presses")
        XCTAssertEqual(slots, 48, "the window did not advance 48 slots (got \(slots) in \(presses) presses)")

        // Still a real, focusable cell, and the strip still agrees with the window.
        XCTAssertNotNil(focusedInGrid(), "nothing is focused in the grid after 48 slots; focus=\(focusLine())")
        XCTAssertNotNil(stripFirstColumn("C-ALIGN"), "the time strip does not show the window's start")
        XCTAssertNotNil(windowLabel(), "no window label after 48 slots")
        log("C focus at the end: \(focusLine())")
    }

    // MARK: (d) — +12h, then a nudge, then ↩ Now

    func testPlus12hThenANudgeThenNow() {
        openGuide()
        let atNow = windowLabel()
        log(windowLine("D-OPEN"))

        XCTAssertTrue(pressPlus12h("D"), "could not press +12h")
        log(windowLine("D-PLUS12"))
        shot("50-after-plus-12h")
        let after12 = windowPosition()
        XCTAssertNotEqual(windowLabel(), atNow, "+12h did not move the window")

        intoTheGrid("D")
        XCTAssertTrue(walkToLastCell("D-WALK"), "could not reach the last cell after +12h")
        var nudged = false
        for i in 1...8 where !nudged {
            if pressRightAndClassify("D", i) == .nudged { nudged = true }
        }
        log(windowLine("D-NUDGED"))
        shot("51-after-a-nudge-following-plus-12h")
        XCTAssertTrue(nudged, "could not nudge after +12h")
        if let a = after12, let b = windowPosition() {
            XCTAssertEqual(b - a, 30, "the nudge after +12h did not move 30 minutes")
        }

        // ↩ Now, from a window that is 12 h and one slot ahead.
        XCTAssertTrue(pressNow("D-NOW"), "could not press ↩ Now")
        log(windowLine("D-NOW"))
        shot("52-back-at-now")
        XCTAssertEqual(windowLabel(), atNow, "↩ Now did not return the window to where it opened")
        log("D RESULT +12h -> nudge -> ↩ Now all correct")
    }

    // MARK: (e) — about two days ahead, then Menu

    func testTwoDaysAheadThenMenuSnapsBack() {
        openGuide()
        let atNow = windowLabel()
        log(windowLine("E-OPEN"))

        // +12h four times is 48 h; the nudges then put the window on a 30-minute offset, which is the
        // state this case is really about. Composition disclosed: the limit and the snap-back do not
        // care how the window got there.
        for i in 1...4 {
            XCTAssertTrue(pressPlus12h("E\(i)"), "could not press +12h (\(i))")
            log("E after +12h #\(i): window=\u{201C}\(windowLabel() ?? "?")\u{201D}")
            intoTheGrid("E\(i)")
        }
        XCTAssertTrue(walkToLastCell("E-WALK"), "could not reach the last cell two days out")
        let (slots, presses) = nudge(slots: 4, cap: 20, "E")
        log("E \(slots) slot(s) in \(presses) press(es) two days out")
        log(windowLine("E-FAR"))
        shot("60-about-two-days-ahead")
        XCTAssertNotEqual(windowLabel(), atNow, "the window never left now")

        remote.press(.menu)
        sleep(6)
        log(windowLine("E-MENU"))
        shot("61-after-menu")
        XCTAssertEqual(windowLabel(), atNow, "Menu did not snap the window back to now")
        XCTAssertTrue(app.staticTexts[guideLegend].exists, "Menu left the Guide instead of snapping back")
        log("E RESULT Menu from ~2 days ahead snapped back to now and stayed on the Guide")
    }

    // MARK: (f) — the Local collection, scrolled four slots

    func testCollectionHoldsWhileScrolled() {
        openGuide()
        guard chooseCollection("Local", "F") else { return XCTFail("could not choose Local") }
        let before = localRowOrder()
        log("F filtered rows: \(before)")
        shot("70-local-before-scrolling")
        XCTAssertEqual(before, localRows.map(\.0), "Local's five rows are missing or out of order")

        intoTheGrid("F")
        XCTAssertTrue(walkToLastCell("F-WALK"), "could not reach the last cell while filtered")
        let (slots, presses) = nudge(slots: 4, cap: 24, "F")
        log("F \(slots) slot(s) in \(presses) press(es)")
        log(windowLine("F-SCROLLED"))
        shot("71-local-after-four-slots")
        XCTAssertEqual(slots, 4, "the window did not advance four slots while filtered")

        let after = localRowOrder()
        log("F filtered rows after scrolling: \(after)")
        XCTAssertEqual(after, before, "the collection's row order changed while scrolling")
        XCTAssertEqual(collectionsButton()?.label, "Local", "the button stopped reading Local")
        for (name, number) in notInLocal {
            XCTAssertFalse(channelCell(number).exists, "\(name) is drawn in a filtered grid after scrolling")
        }

        // Leave the device on All Channels.
        _ = chooseCollection("All Channels", "F-reset")
    }

    // MARK: (g) — scrolled, then out to the rail and back

    func testScrollThenRailRoundTrip() {
        openGuide()
        let atNow = windowLabel()
        XCTAssertTrue(walkToLastCell("G-WALK"), "could not reach the last cell")
        let (slots, _) = nudge(slots: 4, cap: 24, "G")
        log(windowLine("G-SCROLLED"))
        shot("80-scrolled-before-the-rail-trip")
        XCTAssertEqual(slots, 4, "the window did not advance four slots")

        // Out to the rail, down to Radio, open it, back up to the Guide, back in.
        for press in 1...4 {
            if focusIsInTheRail() { break }
            remote.press(.left); sleep(2)
            log("G left \(press) -> \(focusZone())")
        }
        XCTAssertTrue(focusIsInTheRail(), "could not reach the rail; focus=\(focusLine())")
        for _ in 0..<5 { remote.press(.down); usleep(700_000) }
        sleep(1)
        remote.press(.select); sleep(8)
        shot("81-radio")
        for press in 1...4 {
            if focusIsInTheRail() { break }
            remote.press(.left); sleep(2)
            log("G back-left \(press) -> \(focusZone())")
        }
        for _ in 0..<5 { remote.press(.up); usleep(700_000) }
        sleep(1)
        remote.press(.select)
        XCTAssertTrue(app.staticTexts[guideLegend].waitForExistence(timeout: 40), "the Guide did not come back")
        sleep(6)
        log(windowLine("G-BACK"))
        shot("82-back-on-the-guide")
        XCTAssertEqual(windowLabel(), atNow, "the Guide did not come back at now after a rail trip")
        log("G RESULT a rail trip returns the window to now, as today")
    }

    // MARK: (h) — held Right

    /// Step 4: does tvOS auto-repeat the move command while Right is held, and at what rate? The rate
    /// is read as slots advanced over a known hold, which needs no per-event timestamps.
    func testHeldRight() {
        openGuide()
        XCTAssertTrue(walkToLastCell("H-WALK"), "could not reach the row's last visible cell")
        log(windowLine("H-BEFORE"))
        shot("90-before-the-hold")

        for seconds in [2.0, 4.0] {
            guard let before = windowPosition() else { return XCTFail("no window label") }
            remote.press(.right, forDuration: seconds)
            sleep(4)
            guard let after = windowPosition() else { return XCTFail("no window label after the hold") }
            let slots = (after - before) / 30
            log("H held Right for \(seconds) s -> \(slots) slot(s) · window=\u{201C}\(windowLabel() ?? "?")\u{201D}")
            log("H   rate: \(slots == 0 ? "no repeat observed" : String(format: "%.2f slots/s, one step every %.0f ms", Double(slots) / seconds, seconds * 1000 / Double(slots)))")
            shot("91-after-holding-right-\(Int(seconds))s")
        }
        log("H focus at the end: \(focusLine())")
        XCTAssertNotNil(focusedInGrid(), "nothing focused in the grid after the holds")
    }

    // MARK: step 5 — the footer, the Now marker and the midnight accent at an offset window

    /// Step 5: the footer sentence, the strip's "· now" marker and the midnight column all read from
    /// `windowStart` already, so none of them was changed. This proves each is still right once the
    /// window sits on a 30-minute offset rather than on the current half hour.
    func testFooterNowMarkerAndMidnightAtAnOffsetWindow() {
        openGuide()
        let atNowFooter = "Starts at the current half hour · forward only"
        let aheadFooter = "Menu snaps back to now · forward only, 24 hours per request"
        XCTAssertTrue(app.staticTexts[atNowFooter].exists, "the at-now footer is not drawn on opening")
        let openStrip = stripFirstColumn("S5-OPEN")
        XCTAssertTrue(openStrip?.contains("· now") == true,
                      "the strip's first column does not carry the now marker at now: \(openStrip ?? "nil")")
        shot("110-at-now-footer-and-now-marker")

        // One slot off now.
        XCTAssertTrue(walkToLastCell("S5-WALK"), "could not reach the last cell")
        var nudged = false
        for i in 1...8 where !nudged {
            if pressRightAndClassify("S5", i) == .nudged { nudged = true }
        }
        XCTAssertTrue(nudged, "could not nudge one slot")
        log(windowLine("S5-OFFSET"))
        shot("111-offset-by-one-slot")

        XCTAssertTrue(app.staticTexts[aheadFooter].exists,
                      "the ahead-of-now footer is not drawn at a 30-minute offset")
        XCTAssertFalse(app.staticTexts[atNowFooter].exists,
                       "the at-now footer is still drawn at a 30-minute offset")
        let offStrip = stripFirstColumn("S5-OFFSET")
        XCTAssertNotNil(offStrip, "no strip first column at an offset window")
        XCTAssertFalse(offStrip?.contains("· now") == true,
                       "the now marker is still on the strip at an offset window: \(offStrip ?? "nil")")
        // ↩ Now is drawn, +12h still is, and the collections button is untouched.
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Now")).firstMatch.exists,
                      "↩ Now is not drawn at an offset window")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "+12h")).firstMatch.exists,
                      "+12h is not drawn at an offset window")
        log("S5 footer, now marker, ↩ Now and +12h all correct at a 30-minute offset")

        // Now take the window across midnight and read the named column.
        XCTAssertTrue(pressPlus12h("S5-12h"), "could not press +12h")
        intoTheGrid("S5")
        var crossed = windowLabel()?.contains("\u{2192}") == true
        for i in 1...14 where !crossed {
            XCTAssertTrue(walkToLastCell("S5-W\(i)"), "lost the row edge while walking to midnight")
            _ = pressRightAndClassify("S5-MID", i)
            crossed = windowLabel()?.contains("\u{2192}") == true
        }
        log(windowLine("S5-MIDNIGHT"))
        shot("112-window-crossing-midnight")
        XCTAssertTrue(crossed, "could not get the window to cross midnight; window=\(windowLabel() ?? "?")")

        // `slotLabel` names the day on the midnight column — "Sun · 12:00 AM" (dc:321-327).
        let named = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "· 12:00 AM")).firstMatch
        XCTAssertTrue(named.exists, "the midnight column is not named; window=\(windowLabel() ?? "?")")
        log("S5 midnight column \u{201C}\(named.label)\u{201D} \(rect(named.frame))")
        log("S5 RESULT footer, now marker, pills and the midnight column all correct off the half hour")
    }

    // MARK: (i) — the last slot that has a listing, and a further Right

    /// Step 3's limit, driven to its edge. `+12h` is used to cross the fortnight of listings quickly;
    /// the limit does not care how the window got there, and 27 presses is sized from
    /// `GET /api/guide/stats` read before the run (`coverageUntil`) so the window lands **inside** the
    /// last listed day rather than past it.
    func testTheWindowStopsAtTheLastListedSlot() {
        openGuide()
        log(windowLine("I-OPEN"))

        var jumps = 0
        for i in 1...27 {
            guard pressPlus12h("I\(i)") else { break }
            jumps += 1
            intoTheGrid("I\(i)")
            guard focusedInGrid() != nil else {
                log("I after +12h #\(i) the grid has no focusable cell — overshot the listings; stopping here")
                break
            }
            if i % 6 == 0 { log("I +12h #\(i): window=\u{201C}\(windowLabel() ?? "?")\u{201D} focus=\(focusZone())") }
        }
        log("I \(jumps) × +12h · window=\u{201C}\(windowLabel() ?? "?")\u{201D}")
        shot("100-near-the-end-of-the-listings")

        guard focusedInGrid() != nil else {
            log("I STOPPED: no focusable cell near the horizon, so a Right press cannot reach the grid " +
                "handler and the limit cannot be exercised by press from here.")
            return XCTFail("could not position on a programme cell near the end of the listings")
        }
        XCTAssertTrue(walkToLastCell("I-WALK"), "could not reach the last cell near the horizon")

        // Nudge until three consecutive presses change neither the window nor the focus.
        var lastWindow = windowPosition()
        var dead = 0
        var nudges = 0
        for i in 1...80 {
            let outcome = pressRightAndClassify("I", i)
            if outcome == .nudged { nudges += 1; dead = 0; lastWindow = windowPosition() }
            else if outcome == .nothing { dead += 1 } else { dead = 0 }
            if dead >= 3 { break }
        }
        log("I \(nudges) nudge(s), then \(dead) consecutive press(es) that did nothing")
        log(windowLine("I-LIMIT"))
        shot("101-at-the-last-listed-slot")

        XCTAssertGreaterThanOrEqual(dead, 3,
                                    "never reached a slot where a further Right did nothing (nudges=\(nudges))")
        // And the screen is still usable there: a real cell has focus and the strip still agrees.
        XCTAssertNotNil(focusedInGrid(), "nothing focused in the grid at the limit; focus=\(focusLine())")
        XCTAssertNotNil(stripFirstColumn("I-LIMIT"), "the strip does not show the window start at the limit")
        XCTAssertEqual(windowPosition(), lastWindow, "the window moved after the limit was reached")
        log("I RESULT the window stops at the last slot that has a listing; further Right presses do nothing")
    }

    // MARK: Pass 79 — the Guide keeps up with the clock

    /// The two footer sentences, which are how `isAtNow` reads from outside the app.
    private static let atNowFooterText = "Starts at the current half hour · forward only"
    private static let aheadFooterText = "Menu snaps back to now · forward only, 24 hours per request"

    /// The time strip's column labels, left to right, read by **geometry and shape** rather than by
    /// matching the header's date range — so that "the strip moved with the window" is two
    /// independent readings and not one. A strip label is a clock, optionally with a weekday in
    /// front of it on the midnight column and "· now" behind it on the first, and it sits at y≈157:
    /// below the header pills (y≈79) and above the first row (y≈228). This stays a predicate query,
    /// per the file header — `↩ Now · 10:47 AM` matches the shape but is excluded by the band.
    private func stripColumns() -> [String] {
        let pattern = "(^|.* · )[0-9]{1,2}:[0-9]{2} (AM|PM)( · now)?$"
        return app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", pattern))
            .allElementsBoundByIndex
            .filter { $0.frame.minY >= 130 && $0.frame.minY < Self.headerBottom }
            .sorted { $0.frame.minX < $1.frame.minX }
            .map(\.label)
    }

    /// The `↩ Now · 10:47 AM` pill, or nil when the window is at now and it is not drawn.
    private func nowPillLabel() -> String? {
        let e = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "↩ Now")).firstMatch
        return e.exists ? e.label : nil
    }

    private func footerState() -> String {
        if app.staticTexts[Self.atNowFooterText].exists { return "at-now" }
        if app.staticTexts[Self.aheadFooterText].exists { return "ahead" }
        return "neither"
    }

    /// Everything this pass is about in one line: the header's date range, the strip read
    /// independently of it, which footer sentence is drawn, and the ↩ Now pill's own clock.
    private func clockLine(_ tag: String) -> String {
        "\(tag) window=\u{201C}\(windowLabel() ?? "?")\u{201D} strip=\(stripColumns()) " +
        "footer=\(footerState()) nowPill=\(nowPillLabel().map { "\u{201C}\($0)\u{201D}" } ?? "absent")"
    }

    private func secondsToNextHalfHour() -> TimeInterval {
        1800 - Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 1800)
    }

    /// The Mac's own current half hour in the same monotonic minute space `windowPosition()` reads
    /// the device's window label into, so "the window is at the current half hour" is an equality.
    private func currentHalfHourPosition() -> Int {
        let truncated = Date(timeIntervalSince1970: (Date().timeIntervalSince1970 / 1800).rounded(.down) * 1800)
        let c = Calendar.current.dateComponents([.month, .day, .hour, .minute], from: truncated)
        return (((c.month! - 1) * 31) + c.day!) * 1440 + c.hour! * 60 + c.minute!
    }

    /// Wait until there is at least `lead` seconds of room before the next half-hour boundary, so a
    /// test's own set-up presses cannot straddle the boundary it is about to measure. Called first,
    /// before anything is opened.
    private func waitForRoom(_ tag: String, lead: TimeInterval) {
        let room = secondsToNextHalfHour()
        guard room < lead else {
            log("\(tag) ROOM \(Int(room)) s before the next half hour — enough, starting now")
            return
        }
        let sleepFor = room + 20
        log("\(tag) ROOM only \(Int(room)) s before the next half hour — sitting out \(Int(sleepFor)) s so the set-up cannot straddle it")
        Thread.sleep(forTimeInterval: sleepFor)
    }

    /// Wait out one real half-hour boundary **with the app left exactly as it is** — no press, no
    /// activation, nothing but reading. It samples every 30 s, which puts the moment the window
    /// moves on the record and keeps the Mac's wireless test connection from sitting idle (Pass 15:
    /// that link is what drops, not the app).
    private func waitOutABoundary(_ tag: String, slack: TimeInterval = 40) {
        let deadline = Date().addingTimeInterval(secondsToNextHalfHour() + slack)
        log("\(tag) WAIT \(Int(secondsToNextHalfHour())) s to the boundary, then \(Int(slack)) s of slack")
        var beat = 0
        while Date() < deadline {
            Thread.sleep(forTimeInterval: min(30, max(1, deadline.timeIntervalSinceNow)))
            beat += 1
            log(clockLine("\(tag) t-\(Int(max(0, deadline.timeIntervalSinceNow)))s"))
        }
        log("\(tag) waited out the boundary in \(beat) sample(s)")
    }

    // MARK: (a) — at now, left alone through a real half-hour boundary

    func testTheWindowRollsWithTheClockAtNow() {
        waitForRoom("A", lead: 200)
        openGuide()
        log(windowLine("A-OPEN"))
        log(clockLine("A-OPEN"))
        shot("120-at-now-before-the-boundary")

        guard let before = windowPosition() else { return XCTFail("no window label; focus=\(focusLine())") }
        XCTAssertEqual(before, currentHalfHourPosition(), "the Guide did not open at the current half hour")
        XCTAssertEqual(footerState(), "at-now", "the at-now footer is not drawn on opening")
        XCTAssertNil(nowPillLabel(), "↩ Now is drawn on a window that is at now")
        let stripBefore = stripColumns()
        XCTAssertTrue(stripBefore.first?.contains("· now") == true,
                      "the strip's first column does not carry the now marker: \(stripBefore)")
        guard let heldCell = focusedInGrid() else { return XCTFail("nothing focused in the grid") }
        let heldLabel = heldCell.label
        let heldFrame = heldCell.frame
        log("A held cell before the boundary: \u{201C}\(heldLabel)\u{201D} \(rect(heldFrame))")

        waitOutABoundary("A")

        log(windowLine("A-AFTER"))
        log(clockLine("A-AFTER"))
        shot("121-at-now-after-the-boundary")

        guard let after = windowPosition() else { return XCTFail("no window label after the boundary") }
        log("A RESULT window \(before) -> \(after) minutes (\(after - before) min), current half hour is \(currentHalfHourPosition())")
        XCTAssertEqual(after - before, 30, "the window did not advance one half hour across the boundary")
        XCTAssertEqual(after, currentHalfHourPosition(), "the window is not at the new current half hour")

        // The strip moved with it, read independently of the header's date range, and still carries
        // the now marker — the window is at now again.
        let stripAfter = stripColumns()
        log("A strip \(stripBefore) -> \(stripAfter)")
        XCTAssertNotEqual(stripAfter, stripBefore, "the time strip did not move with the window")
        XCTAssertTrue(stripAfter.first?.contains("· now") == true,
                      "the strip's first column lost the now marker: \(stripAfter)")
        XCTAssertNotNil(stripFirstColumn("A-AFTER"),
                        "the strip's first column does not agree with the header's date range")
        XCTAssertEqual(footerState(), "at-now", "the footer stopped saying the window is at now")
        XCTAssertNil(nowPillLabel(), "↩ Now is drawn on a window the roll has kept at now")

        // Focus, by the owner's rule, and the proof that every row moved with the strip: a cell that
        // keeps focus keeps its label and its box slides one slot to the left.
        guard let held = focusedInGrid() else {
            return XCTFail("nothing focused in the grid after the roll; focus=\(focusLine())")
        }
        if held.label == heldLabel {
            log("A FOCUS stayed on \u{201C}\(heldLabel)\u{201D}: \(rect(heldFrame)) -> \(rect(held.frame))")
            // Never rightward. It moves *left* by one slot only when the programme starts inside the
            // window; one that began before the window is clipped to it and drawn flush at x=554 in
            // the old window and the new one alike (Pass 75 §2.1), so its box does not move at all.
            // The reading is logged either way; the strip above is what proves the window moved.
            XCTAssertLessThanOrEqual(held.frame.minX, heldFrame.minX,
                                     "the focused programme's cell moved right across the roll")
        } else {
            log("A FOCUS \u{201C}\(heldLabel)\u{201D} left the window; focus is now \u{201C}\(held.label)\u{201D} \(rect(held.frame))")
        }
    }

    // MARK: (b) — the same roll with the owner's "Local" collection selected

    func testTheRollHoldsTheCollection() {
        waitForRoom("B79", lead: 330)
        openGuide()
        guard chooseCollection("Local", "B79") else { return XCTFail("could not choose Local") }
        let rowsBefore = localRowOrder()
        log("B79 filtered rows: \(rowsBefore)")
        XCTAssertEqual(rowsBefore, localRows.map(\.0), "Local's five rows are missing or out of order")
        intoTheGrid("B79")
        log(windowLine("B79-OPEN"))
        log(clockLine("B79-OPEN"))
        shot("130-local-before-the-boundary")

        guard let before = windowPosition() else { return XCTFail("no window label") }
        XCTAssertEqual(before, currentHalfHourPosition(), "the filtered Guide is not at the current half hour")
        let stripBefore = stripColumns()

        waitOutABoundary("B79")

        log(windowLine("B79-AFTER"))
        log(clockLine("B79-AFTER"))
        shot("131-local-after-the-boundary")

        guard let after = windowPosition() else { return XCTFail("no window label after the boundary") }
        log("B79 RESULT window \(before) -> \(after) minutes (\(after - before) min)")
        XCTAssertEqual(after - before, 30, "the filtered window did not advance one half hour")
        XCTAssertEqual(after, currentHalfHourPosition(), "the filtered window is not at the new current half hour")
        XCTAssertNotEqual(stripColumns(), stripBefore, "the time strip did not move with the filtered window")
        XCTAssertTrue(stripColumns().first?.contains("· now") == true, "the now marker left the strip")

        let rowsAfter = localRowOrder()
        log("B79 filtered rows after the roll: \(rowsAfter)")
        XCTAssertEqual(rowsAfter, rowsBefore, "the collection's rows changed across the roll")
        XCTAssertEqual(collectionsButton()?.label, "Local", "the button stopped reading Local")
        for (name, number) in notInLocal {
            XCTAssertFalse(channelCell(number).exists, "\(name) is drawn in the filtered grid after the roll")
        }
        log("B79 focus after the roll: \(focusLine())")
        XCTAssertNotNil(focusedInGrid(), "nothing focused in the filtered grid after the roll")

        _ = chooseCollection("All Channels", "B79-reset")
    }

    // MARK: (c) — a window scrolled two slots ahead does not roll, and ↩ Now tracks the clock

    func testAScrolledWindowDoesNotRollAndTheNowPillTracksTheClock() {
        waitForRoom("C79", lead: 420)
        openGuide()
        guard let atNow = windowPosition() else { return XCTFail("no window label") }
        XCTAssertTrue(walkToLastCell("C79-WALK"), "could not reach the row's last visible cell")
        let (slots, presses) = nudge(slots: 2, cap: 12, "C79")
        log("C79 \(slots) slot(s) in \(presses) press(es)")
        XCTAssertEqual(slots, 2, "could not scroll the window two slots ahead")

        log(windowLine("C79-AHEAD"))
        log(clockLine("C79-AHEAD"))
        shot("140-two-slots-ahead-before-the-boundary")

        guard let before = windowPosition() else { return XCTFail("no window label while ahead") }
        XCTAssertEqual(before - atNow, 60, "the window is not two slots ahead of now")
        XCTAssertEqual(footerState(), "ahead", "the ahead-of-now footer is not drawn on a scrolled window")
        guard let pillBefore = nowPillLabel() else { return XCTFail("↩ Now is not drawn on a scrolled window") }
        log("C79 ↩ Now before the boundary: \u{201C}\(pillBefore)\u{201D}")
        let stripBefore = stripColumns()
        XCTAssertFalse(stripBefore.first?.contains("· now") == true,
                       "the now marker is on the strip of a scrolled window: \(stripBefore)")

        // Sample the pill through the wait: this is where "within a half hour, the Now marker tracks
        // the clock" is measured, minute by minute, on a window that must not move.
        var pillReadings: [String] = [pillBefore]
        let deadline = Date().addingTimeInterval(secondsToNextHalfHour() + 40)
        log("C79 WAIT \(Int(secondsToNextHalfHour())) s to the boundary, sampling every 30 s")
        while Date() < deadline {
            Thread.sleep(forTimeInterval: min(30, max(1, deadline.timeIntervalSinceNow)))
            log(clockLine("C79 t-\(Int(max(0, deadline.timeIntervalSinceNow)))s"))
            if let p = nowPillLabel(), p != pillReadings.last { pillReadings.append(p) }
        }

        log(windowLine("C79-AFTER"))
        log(clockLine("C79-AFTER"))
        shot("141-two-slots-ahead-after-the-boundary")
        log("C79 ↩ Now readings in order: \(pillReadings)")

        guard let after = windowPosition() else { return XCTFail("no window label after the boundary") }
        XCTAssertEqual(after, before, "the window moved across the boundary — a scrolled window must not roll")
        XCTAssertEqual(footerState(), "ahead", "the footer stopped saying the window is ahead of now")
        XCTAssertNotNil(nowPillLabel(), "↩ Now stopped being drawn on a window still ahead of now")
        XCTAssertEqual(after - currentHalfHourPosition(), 30,
                       "the window should be one slot ahead of the new current half hour")
        XCTAssertFalse(stripColumns().first?.contains("· now") == true,
                       "the now marker appeared on the strip of a scrolled window")
        XCTAssertGreaterThan(pillReadings.count, 1,
                             "the ↩ Now pill's clock never changed while the clock passed: \(pillReadings)")
        log("C79 RESULT the window stayed at \(after) while the clock passed; ↩ Now advanced \(pillReadings.count - 1) time(s)")

        remote.press(.menu)   // leave the device at now
        sleep(5)
    }

    // MARK: (d) — the app backgrounded across a boundary, then the Guide read again

    func testTheGuideIsAtTheTrueHalfHourAfterBackgrounding() {
        waitForRoom("D79", lead: 240)
        openGuide()
        log(windowLine("D79-OPEN"))
        guard let before = windowPosition() else { return XCTFail("no window label") }
        XCTAssertEqual(before, currentHalfHourPosition(), "the Guide did not open at the current half hour")
        shot("150-before-backgrounding")

        log("D79 pressing Home to background the app")
        remote.press(.home)
        sleep(8)
        // 1 = notRunning, 2 = runningBackgroundSuspended, 3 = runningBackground, 4 = foreground.
        log("D79 app state after Home: \(app.state.rawValue)")
        XCTAssertNotEqual(app.state, .runningForeground, "the app is still in the foreground after Home")
        log("D79 backgrounded; waiting out the boundary with the app not in the foreground")

        let deadline = Date().addingTimeInterval(secondsToNextHalfHour() + 40)
        while Date() < deadline {
            Thread.sleep(forTimeInterval: min(30, max(1, deadline.timeIntervalSinceNow)))
            log("D79 t-\(Int(max(0, deadline.timeIntervalSinceNow)))s (backgrounded)")
        }

        log("D79 activating the app again; state before = \(app.state.rawValue)")
        app.activate()
        sleep(10)
        // Two outcomes are possible and this pass reports which one happened rather than assuming:
        // tvOS may have kept the app suspended with the Guide still on screen, or it may have
        // evicted it, in which case activating relaunches it cold on to Home.
        let cameBackOnTheGuide = app.staticTexts[guideLegend].waitForExistence(timeout: 25)
        log("D79 came back with the Guide still on screen: \(cameBackOnTheGuide) (state \(app.state.rawValue))")
        if cameBackOnTheGuide {
            log(windowLine("D79-RESUMED"))
            log(clockLine("D79-RESUMED"))
            shot("151-resumed-immediately")
            // The beat is aligned to the minute, so read again after one has certainly passed.
            Thread.sleep(forTimeInterval: 70)
            log(windowLine("D79-RESUMED+70s"))
            log(clockLine("D79-RESUMED+70s"))
            shot("152-resumed-after-a-minute")
        } else {
            log("D79 the app did not come back on the Guide — tvOS relaunched it rather than resuming it")
            shot("151x-relaunched-rather-than-resumed")
            goHome()
            openGuide()
            log(windowLine("D79-RELAUNCHED"))
            log(clockLine("D79-RELAUNCHED"))
            shot("152x-guide-opened-after-a-relaunch")
        }

        guard let resumed = windowPosition() else { return XCTFail("no window label after resuming") }
        log("D79 RESULT window \(before) -> \(resumed); current half hour is \(currentHalfHourPosition())")
        XCTAssertEqual(resumed, currentHalfHourPosition(),
                       "the Guide is on a stale half hour after the app sat backgrounded across a boundary")
        XCTAssertEqual(footerState(), "at-now", "the footer does not say the window is at now after resuming")
        XCTAssertNotNil(focusedInGrid(), "nothing focused in the grid after resuming; focus=\(focusLine())")

        // And the cold path the step names: leave the Guide and open it again.
        goHome()
        openGuide()
        log(windowLine("D79-REOPENED"))
        shot("153-guide-reopened")
        XCTAssertEqual(windowPosition(), currentHalfHourPosition(),
                       "reopening the Guide did not land on the true current half hour")
        log("D79 RESULT the reopened Guide is at the current half hour")
    }

    // MARK: (e) — the clock stops with the screen, and no beat outlives it

    /// The app prints `[guide] clock stopped after N beat(s)` when the `.task` loop ends, which is
    /// the evidence this item asks for. It needs the app's console — see the file header — so this
    /// test drives the remote and the console is read beside it.
    func testTheClockStopsWhenTheGuideDoes() {
        openGuide()
        log("E79 the Guide is open; sitting on it for 3 minutes so the clock beats")
        log(clockLine("E79-OPEN"))
        Thread.sleep(forTimeInterval: 185)
        log(clockLine("E79-AFTER-3-MIN"))
        shot("160-three-minutes-on-the-guide")

        // Out to the rail and into Radio: `ScreenShell`'s `.id(current)` destroys the Guide here.
        for press in 1...4 {
            if focusIsInTheRail() { break }
            remote.press(.left); sleep(2)
            log("E79 left \(press) -> \(focusZone())")
        }
        XCTAssertTrue(focusIsInTheRail(), "could not reach the rail; focus=\(focusLine())")
        for _ in 0..<5 { remote.press(.down); usleep(700_000) }
        sleep(1)
        remote.press(.select); sleep(8)
        shot("161-radio")
        log("E79 on Radio — the console must now carry \u{201C}[guide] clock stopped after N beat(s)\u{201D}")

        // Three more minutes away from the Guide. If a beat had outlived the screen it would keep
        // printing, and a second Guide would later report a beat count that includes them.
        Thread.sleep(forTimeInterval: 185)
        log("E79 three minutes away from the Guide")

        // Back to the Guide, sit for two minutes, then leave again: the second stop line reports the
        // second clock's own beats, and nothing else.
        for _ in 1...4 {
            if focusIsInTheRail() { break }
            remote.press(.left); sleep(2)
        }
        for _ in 0..<5 { remote.press(.up); usleep(700_000) }
        sleep(1)
        remote.press(.select)
        XCTAssertTrue(app.staticTexts[guideLegend].waitForExistence(timeout: 40), "the Guide did not come back")
        sleep(6)
        log(clockLine("E79-SECOND-VISIT"))
        Thread.sleep(forTimeInterval: 125)
        remote.press(.menu); sleep(6)
        log("E79 left the Guide a second time; zone=\(focusZone())")
        shot("162-left-the-guide-again")
        log("E79 RESULT two clocks started and two stopped — read the console for the two stop lines")
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
