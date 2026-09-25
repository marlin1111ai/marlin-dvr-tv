//
//  FrameStepReadyUITests.swift
//  Marlin DVR TVUITests
//
//  Pass 127's evidence harness, not a standing test: S6, a frame-step click does nothing until the
//  recording's item is ready and no resume seek is still in flight. It runs what Pass 119's report
//  says a run can prove — a burst of paused clicks the moment Resume starts, and after that: no
//  crash, Resume on the saved position, and each Left or Right click still one frame.
//
//  It needs the physical Apple TV ("Home Theater"), the owner's server, and a recording with an
//  unfinished saved position on this Apple TV — a card on the Recordings screen's Continue watching
//  shelf. It prefers *The Proof Is Out There*, whose recording has no detected breaks (commercial
//  detection has failed since 2026-09-08, Pass 94), so the skip prompt can never take a Select; the
//  standing subject's saved spot sits inside its first break now. It takes the first card otherwise.
//
//  **Two methods, run one at a time.** The run of record is the first, with `launch()`; the second
//  drives a process `devicectl … --console` already started — neither `launch()` nor `activate()` —
//  so the app's own `[framestep]` and `[resume]` lines can be read beside the harness's: the exact
//  size of each step, the frame rate, and whether any click of the burst was declined.
//
//  **What it reads.** The saved position before and after, from the card's "n min in" and show
//  detail's "Resume … · n min in" — the app's own store, rendered. **It does not read Apple's
//  transport-bar clock**: a pause that lands before the item is ready leaves the bar's scrub head at
//  0:00, and there it stays through the resume seek and every frame step (measured in this pass's
//  first drive, where the head read 0:00 with the picture at 14:58). For the same reason it never
//  presses Select to play on after the burst — that Select seeks to the head, and the first drive lost
//  the saved position that way — it leaves from the paused state with Menu, which saves the app's own
//  position. The per-click step and the frame rate are the console's to say.
//
//  **It moves one saved position by a few frames** and clears none: the recording is never played to
//  its end, and nothing is deleted, trashed, kept, scheduled or marked watched. Its only non-GET
//  traffic is the app's own: the launch ping and one play session (POST, then DELETE on leaving).
//
//  **A third method puts the subject's position back.** The first drive, before the harness stopped
//  pressing Select to play on, left *The Proof Is Out There* S6 E16's position at the top of the
//  recording, where it had read "14 min in". `testPutTheSubjectsPositionBack` plays that episode from
//  the top and walks forward with Apple's own 10 s skip to about fifteen minutes, then leaves.
//
//  Run (the record):
//    xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
//      -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates test \
//      -only-testing:"Marlin DVR TVUITests/FrameStepReadyUITests/testBurstThenResumeLandsAndClicksStepOneFrame"
//  Run (with the console; the app first, then the tests):
//    xcrun devicectl device process launch --device "Home Theater" --console --terminate-existing \
//      com.marlin1111.MarlinDVRTV &
//    xcodebuild … test -only-testing:"Marlin DVR TVUITests/FrameStepReadyUITests/testTheSameDriveWithTheConsoleAttached"
//  Run (the restore, once, after the first drive):
//    xcodebuild … test -only-testing:"Marlin DVR TVUITests/FrameStepReadyUITests/testPutTheSubjectsPositionBack"
//

import XCTest

final class FrameStepReadyUITests: XCTestCase {
    private var app: XCUIApplication!
    private let remote = XCUIRemote.shared

    private static let homeTiles = ["Guide", "On Now", "On Later",
                                    "Recordings", "Cameras", "Favorites",
                                    "Weather", "Radio", "Settings"]
    private let shelvesNote = "Watched and keep flags are shared with the other Apple TV"
    private let detailNote = "Click and hold an episode for Keep and Delete"
    private let promptText = "Skip the commercial break"
    private let preferredShow = "The Proof Is Out There"
    private static let clicks = 60

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

    private func log(_ line: String) { print("[pass127 \(stamp())] \(line)") }

    private func shot(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    private func screenText() -> [String] {
        app.staticTexts.allElementsBoundByIndex.map(\.label).filter { !$0.isEmpty }
    }

    private func buttonLabels() -> [String] {
        app.buttons.allElementsBoundByIndex.map(\.label).filter { !$0.isEmpty }
    }

    private func focusedLabel() -> String {
        let buttons = app.buttons.matching(NSPredicate(format: "hasFocus == true")).allElementsBoundByIndex
        if let first = buttons.first { return first.label }
        let others = app.otherElements.matching(NSPredicate(format: "hasFocus == true")).allElementsBoundByIndex
        if let first = others.first { return "other:\(first.label)" }
        return "nothing"
    }

    private static func minutesIn(_ label: String) -> Int? {
        if let r = label.range(of: "([0-9]+) min in", options: .regularExpression) {
            return Int(label[r].split(separator: " ")[0])
        }
        if label.range(of: "[0-9]+ s in", options: .regularExpression) != nil { return 0 }
        return nil
    }

    /// Apple's own transport-bar clock — "14:31" and the like — on screen while paused.
    private func transportClock() -> Double? {
        for text in screenText() where text.range(of: "^[0-9]{1,2}:[0-9]{2}(:[0-9]{2})?$", options: .regularExpression) != nil {
            if let s = Self.seconds(text) { return s }
        }
        return nil
    }

    private static func seconds(_ clock: String) -> Double? {
        let bits = clock.split(separator: ":").map(String.init)
        guard bits.count == 2 || bits.count == 3, bits.allSatisfy({ Int($0) != nil }) else { return nil }
        let n = bits.compactMap { Double($0) }
        return bits.count == 2 ? n[0] * 60 + n[1] : n[0] * 3600 + n[1] * 60 + n[2]
    }

    private var promptOnScreen: Bool { app.staticTexts[promptText].exists }

    private func waitForPromptToClear(_ why: String) {
        guard promptOnScreen else { return }
        log("the skip prompt is up (\(why)) — waiting it out rather than pressing Select")
        for _ in 0..<10 {
            sleep(1)
            if !promptOnScreen { return }
        }
    }

    private static func clock(_ s: Double?) -> String { s.map { String(format: "%.0f s", $0) } ?? "unreadable" }

    // MARK: driving the remote

    private func openFromHome(_ tile: String) {
        XCTAssertTrue(app.staticTexts["Marlin"].waitForExistence(timeout: 60), "Home did not appear")
        sleep(3)
        guard let target = Self.homeTiles.firstIndex(of: tile) else { return XCTFail("no such tile: \(tile)") }
        guard let here = Self.homeTiles.firstIndex(where: { focusedLabel() == $0 || focusedLabel().hasPrefix("\($0), ") }) else {
            return XCTFail("Home focus is not on a tile — it is \(focusedLabel())")
        }
        let dRow = target / 3 - here / 3, dCol = target % 3 - here % 3
        for _ in 0..<abs(dRow) { remote.press(dRow > 0 ? .down : .up); usleep(700_000) }
        for _ in 0..<abs(dCol) { remote.press(dCol > 0 ? .right : .left); usleep(700_000) }
        XCTAssertTrue(focusedLabel() == tile || focusedLabel().hasPrefix("\(tile), "),
                      "walking Home did not reach \(tile) — focus is \(focusedLabel())")
        remote.press(.select)
    }

    private func waitForShelves(_ tag: String) {
        XCTAssertTrue(app.staticTexts[shelvesNote].waitForExistence(timeout: 40), "the Recordings shelves did not appear (\(tag))")
        sleep(3)
    }

    private func continueCards() -> [String] {
        buttonLabels().filter { Self.minutesIn($0) != nil }
    }

    private func focusCard(_ label: String) -> Bool {
        for _ in 0..<12 {
            if focusedLabel() == label { return true }
            remote.press(.right)
            usleep(700_000)
        }
        return focusedLabel() == label
    }

    private func resumeLabel() -> String? { buttonLabels().first { $0.hasPrefix("Resume ") } }

    /// The Player is up when Apple's transport bar draws the item's metadata line — the request's
    /// subtitle, "S6 E16 · … · 9001 HISTORY" — which nothing else in the app draws.
    private func playerUp() -> Bool {
        screenText().contains { $0.contains(" · ") && $0.range(of: "^S[0-9]+ E[0-9]+ · ", options: .regularExpression) != nil }
    }

    /// To the episode row whose label starts with `prefix`. Focus opens on the left column (Resume /
    /// Play newest) and Right crosses into the episodes (DeleteRefreshUITests, Pass 31) — since Pass 103
    /// by way of "Edit series pass", the button beside Play newest, so Right is pressed until an episode
    /// row has focus; Down then walks them, newest first.
    private func focusEpisodeRow(_ prefix: String) -> Bool {
        for _ in 0..<3 where focusedLabel().range(of: "^S[0-9]+ E[0-9]+", options: .regularExpression) == nil {
            remote.press(.right)
            usleep(800_000)
        }
        for _ in 0..<10 {
            if focusedLabel().hasPrefix(prefix) { return true }
            remote.press(.down)
            usleep(700_000)
        }
        return focusedLabel().hasPrefix(prefix)
    }

    // MARK: the run

    /// The run of record: `launch()`, so the launch ping in `GET /api/logs` dates it.
    func testBurstThenResumeLandsAndClicksStepOneFrame() {
        app.launch()
        log("launched")
        drive()
    }

    /// The same drive against a process `devicectl … --console` already started — neither `launch()`
    /// nor `activate()` — so the app's own lines can be read beside the harness's.
    func testTheSameDriveWithTheConsoleAttached() {
        continueAfterFailure = true
        log("ATTACHING to the process devicectl launched — no launch(), no activate()")
        drive()
    }

    private func drive() {
        openFromHome("Recordings")
        waitForShelves("before")
        let cards = continueCards()
        log("Continue watching cards: \(cards)")
        XCTAssertFalse(cards.isEmpty, "no Continue watching card — nothing to resume")
        guard let card = cards.first(where: { $0.contains(preferredShow) }) ?? cards.first,
              let minutesBefore = Self.minutesIn(card) else { return XCTFail("no card with a position") }
        log("subject: \u{201C}\(card)\u{201D} — \(minutesBefore) min in before")
        shot("01-continue-watching-before")

        XCTAssertTrue(focusCard(card), "could not focus the card; focus is \(focusedLabel())")
        remote.press(.select)
        XCTAssertTrue(app.staticTexts[detailNote].waitForExistence(timeout: 40), "show detail did not open")
        sleep(3)
        guard let resumeBefore = resumeLabel() else { return XCTFail("show detail draws no Resume line; buttons: \(buttonLabels())") }
        log("show detail before: \u{201C}\(resumeBefore)\u{201D} · focus=\(focusedLabel())")
        XCTAssertTrue(focusedLabel().hasPrefix("Resume "), "show detail did not focus Resume — focus is \(focusedLabel())")
        shot("02-show-detail-before")

        // S6's window: Resume, then inside the first second or two a pause and a burst of Right clicks.
        // The session lands about 0.4 s after the press on the sidecar route, the item is ready
        // 0.45–0.79 s after attach and the resume seek is in flight 0.19–0.32 s after that (Pass 96),
        // so a pause at +0.9 s and clicks from about +1.1 s straddle both. Which clicks fell inside is
        // the console's to say; the harness's claim is what is left afterwards.
        remote.press(.select)
        log("Resume pressed")
        usleep(900_000)
        remote.press(.select)
        log("Select (pause) sent at about +0.9 s")
        for _ in 0..<6 { remote.press(.right); usleep(120_000) }
        log("six Right clicks sent, about +1.1 s to +2.0 s")
        sleep(4)
        XCTAssertTrue(app.state == .runningForeground, "the app is not in the foreground after the burst: \(app.state.rawValue)")
        XCTAssertTrue(playerUp(), "the Player is not up after the burst; text=\(screenText())")
        XCTAssertFalse(app.buttons["Try again"].exists, "the Player shows a failure card: \(screenText())")
        log("after the burst: the app is up and the Player is drawn · the bar's scrub head reads \(Self.clock(transportClock())) (the head, not the app's position — see the header) · text=\(screenText())")
        shot("03-paused-after-the-burst")

        // Sixty Right clicks, then sixty Left, one frame each: the console shows the size of each.
        for _ in 0..<Self.clicks { remote.press(.right); usleep(150_000) }
        sleep(2)
        XCTAssertTrue(app.state == .runningForeground && playerUp(), "the app or the Player is gone after \(Self.clicks) Right clicks")
        log("\(Self.clicks) Right clicks sent; the app and the Player are still up")
        shot("04-after-60-right-clicks")
        for _ in 0..<Self.clicks { remote.press(.left); usleep(150_000) }
        sleep(2)
        XCTAssertTrue(app.state == .runningForeground && playerUp(), "the app or the Player is gone after \(Self.clicks) Left clicks")
        log("\(Self.clicks) Left clicks sent; the app and the Player are still up")
        shot("05-after-60-left-clicks")

        // Leave from the paused state: Menu → dismiss → `stop()` saves the app's own position. (Not a
        // Select to play on — that seeks to the transport bar's scrub head, which a pause before the item
        // was ready left at 0:00; the first drive lost the saved position that way.)
        remote.press(.menu)
        XCTAssertTrue(app.staticTexts[detailNote].waitForExistence(timeout: 30), "show detail did not come back after Menu")
        sleep(3)
        guard let resumeAfter = resumeLabel() else { return XCTFail("the Resume line is gone after leaving the Player; buttons: \(buttonLabels())") }
        let minutesAfter = Self.minutesIn(resumeAfter) ?? -1
        log("show detail after: \u{201C}\(resumeAfter)\u{201D} — \(minutesAfter) min in")
        XCTAssertEqual(minutesAfter, minutesBefore, "the position after leaving reads \(minutesAfter) min, from \(minutesBefore) min before — a resume that had landed at the top would read seconds")
        shot("06-show-detail-after")
        log("RESULT no crash; \(Self.clicks * 2 + 6) clicks sent — which of them fell inside the not-ready window is the console's to say; saved \(minutesBefore) → \(minutesAfter) min in")
    }

    // MARK: putting the subject's position back

    /// After the first drive (see the header): play *The Proof Is Out There* S6 E16 from where the drive
    /// left it, the top, and walk forward with Apple's own 10 s skip to about fifteen minutes, then
    /// leave, so the store holds a position near the "14 min in" it read before.
    func testPutTheSubjectsPositionBack() {
        app.launch()
        log("launched (restore)")
        openFromHome("Recordings")
        waitForShelves("restore")
        log("Continue watching cards: \(continueCards())")
        // The show's own card is gone from Continue watching; reach it through its shelf card instead,
        // walking the shelves the way ResumeRewindUITests.openShow does (Pass 96): to the row's start
        // first, then Right along it reading labels, then Down — never Down from the rail.
        var opened = false
        var seen: [String] = []
        for row in 0..<4 {
            for _ in 0..<8 { remote.press(.left); usleep(420_000) }
            for _ in 0..<9 {
                let here = focusedLabel()
                if !seen.contains(here) { seen.append(here) }
                // A shelf card's label leads with its badge — "4 new, The Proof Is Out There, 4 episodes".
                if here.contains(preferredShow) {
                    log("row \(row): focus is \u{201C}\(here)\u{201D} — opening it")
                    remote.press(.select)
                    opened = app.staticTexts[detailNote].waitForExistence(timeout: 40)
                    break
                }
                remote.press(.right)
                usleep(600_000)
            }
            if opened { break }
            remote.press(.down)
            usleep(900_000)
        }
        XCTAssertTrue(opened, "could not open \(preferredShow); focus visited \(seen)")
        sleep(3)
        log("show detail: Resume line = \(resumeLabel() ?? "none") · buttons=\(buttonLabels().prefix(4))")
        XCTAssertTrue(focusEpisodeRow("S6 E16"), "could not focus the S6 E16 row; focus is \(focusedLabel())")
        remote.press(.select)
        log("S6 E16 row selected — playing from its stored position")
        sleep(10)
        XCTAssertTrue(playerUp(), "the Player is not up; text=\(screenText())")
        // Apple's own skip is +10 s a click while playing; the app never owns the arrow then.
        for _ in 0..<88 { remote.press(.right); usleep(340_000) }
        sleep(4)
        remote.press(.menu)
        XCTAssertTrue(app.staticTexts[detailNote].waitForExistence(timeout: 30), "show detail did not come back after Menu")
        sleep(3)
        let after = resumeLabel()
        log("show detail after the restore: \u{201C}\(after ?? "none")\u{201D}")
        XCTAssertNotNil(after, "no Resume line after the restore")
        let minutes = after.flatMap(Self.minutesIn) ?? -1
        XCTAssertTrue(minutes == 14 || minutes == 15, "the restore left the position at \(minutes) min, not about fifteen")
        shot("restore-show-detail-after")
    }
}
