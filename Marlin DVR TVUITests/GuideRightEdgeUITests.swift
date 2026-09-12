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
