//
//  CommercialSkipUITests.swift
//  Marlin DVR TVUITests
//
//  Pass 38's evidence harness, not a standing test. It runs on the physical Apple TV and
//  drives the real Siri Remote, because every claim this pass makes is about what happens
//  on screen while a recording plays.
//
//  It sends no PUT, POST or DELETE of its own. It does play recordings, so the server sees
//  the ordinary consequences of playback: play sessions, resume positions, and `watched:true`
//  on any recording that is allowed to reach its end.
//
//  **`activate()`, never `launch()`.** The app is started separately with
//  `xcrun devicectl device process launch --console`, which is the only way this project has
//  ever captured the app's own `print` output from the device (Pass 22 §3). A `launch()` here
//  would kill that process and take the console with it; `activate()` brings the running one
//  to the front and leaves it attached, so the `[commercials] …` lines land in the console log
//  beside the screenshots these tests take.
//

import XCTest

final class CommercialSkipUITests: XCTestCase {
    private var app: XCUIApplication!
    private let remote = XCUIRemote.shared

    /// Home tile order, frame 2a — three rows of three (Destination.homeTiles).
    private static let homeTiles = ["Guide", "On Now", "On Later",
                                    "Recordings", "Cameras", "Favorites",
                                    "Weather", "Radio", "Settings"]
    /// Only on the Recordings shelves.
    private let shelvesNote = "Watched and keep flags are shared with the other Apple TV"
    /// Only in show detail.
    private let detailNote = "Click and hold an episode for Keep and Delete"
    /// The prompt this pass built. Nothing else in the app draws this string.
    private let promptText = "Skip the commercial break"

    /// The recording the contract's own §10.2 example is taken from, and the one in the
    /// owner's library with real detected breaks.
    private static let showWithBreaks = "History's Greatest Mysteries"
    private static let episodeWithBreaks = "Cooper"
    /// The other episode of the same show, whose answer is `state: "unknown"` — the ordinary
    /// case for most of the library, and the one that must behave exactly as it did before
    /// this pass.
    private static let episodeWithoutBreaks = "Osama"

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.activate()
        goHome()
    }

    /// Menu back to Home from wherever the previous test left the app.
    private func goHome() {
        for _ in 0..<7 {
            if app.staticTexts["Marlin"].waitForExistence(timeout: 10) { sleep(2); return }
            remote.press(.menu)
            sleep(3)
        }
    }

    // MARK: reading the device

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func stamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: Date())
    }

    private func log(_ line: String) { print("[pass38 \(stamp())] \(line)") }

    private func screenText() -> [String] {
        app.staticTexts.allElementsBoundByIndex.map(\.label).filter { !$0.isEmpty }
    }

    private func focusedLabel() -> String {
        let buttons = app.buttons.matching(NSPredicate(format: "hasFocus == true")).allElementsBoundByIndex
        if let first = buttons.first { return first.label }
        let others = app.otherElements.matching(NSPredicate(format: "hasFocus == true")).allElementsBoundByIndex
        if let first = others.first { return "other:\(first.label)" }
        let any = app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true")).allElementsBoundByIndex
        if let first = any.first { return "any:\(first.elementType.rawValue):\(first.label)" }
        return "nothing"
    }

    /// Apple's own transport-bar clock — "02:56" and the like — which the arrow presses below
    /// keep on screen. An app-independent reading of where playback is.
    private func transportClock() -> [String] {
        screenText().filter { $0.range(of: "^[0-9]{1,2}:[0-9]{2}(:[0-9]{2})?$", options: .regularExpression) != nil }
    }

    private var promptOnScreen: Bool { app.staticTexts[promptText].exists }

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
        remote.press(.select)
    }

    private func waitForShelves(_ tag: String) {
        XCTAssertTrue(app.staticTexts[shelvesNote].waitForExistence(timeout: 40),
                      "the Recordings shelves did not appear (\(tag))")
        sleep(3)
    }

    /// Walk the whole shelf grid — every row, left edge to right edge — to the named show
    /// and open it. The shelves reorder themselves as recordings are played (Recently
    /// Updated is exactly that), so nothing here assumes a fixed position.
    private func openShow(_ needle: String) -> Bool {
        var seen: [String] = []
        for row in 0..<4 {
            for _ in 0..<8 { remote.press(.left); usleep(450_000) }
            for _ in 0..<9 {
                let here = focusedLabel()
                if !seen.contains(here) { seen.append(here) }
                if here.contains(needle) {
                    log("row \(row): focus is \"\(here)\" — opening it")
                    remote.press(.select)
                    guard app.staticTexts[detailNote].waitForExistence(timeout: 40) else {
                        log("show detail did not open"); return false
                    }
                    sleep(3)
                    return true
                }
                remote.press(.right)
                usleep(600_000)
            }
            remote.press(.down)
            usleep(900_000)
        }
        log("no shelf card matched \"\(needle)\". Focus visited: \(seen)")
        return false
    }

    /// From show detail: cross into the episode list and play the row whose label carries
    /// `needle`. `nil` plays whatever the left column offers (Resume, else Play newest).
    private func playEpisode(_ needle: String?) -> Bool {
        guard let needle else {
            log("playing the left column: \(focusedLabel())")
            remote.press(.select)
            sleep(16)
            return true
        }
        remote.press(.right)
        usleep(900_000)
        var seen: [String] = []
        // Crossing in from the left column lands wherever the focus engine puts it, which is
        // not always the first row — so walk down, then back up past the start.
        for (step, direction) in (Array(repeating: XCUIRemote.Button.down, count: 4) + Array(repeating: .up, count: 8)).enumerated() {
            let here = focusedLabel()
            if !seen.contains(here) { seen.append(here) }
            if here.contains(needle) {
                log("episode row \(step) is the one: \(here)")
                remote.press(.select)
                sleep(12)
                return true
            }
            remote.press(direction)
            usleep(900_000)
        }
        log("no episode row matched \"\(needle)\". Focus visited: \(seen)")
        return false
    }

    /// Apple's own forward skip, repeated, until the prompt appears. Nothing else moves
    /// playback, so this is also the proof that the arrows are untouched by this pass.
    @discardableResult
    private func skipForwardUntilPrompt(limit: Int) -> Int {
        var presses = 0
        while presses < limit {
            if promptOnScreen { return presses }
            remote.press(.right)
            presses += 1
            usleep(1_200_000)
            if promptOnScreen { return presses }
            if presses % 4 == 0 {
                for _ in 0..<3 { if promptOnScreen { return presses }; sleep(1) }
            }
        }
        return presses
    }

    private func leavePlayer() {
        remote.press(.menu)
        sleep(4)
        if app.staticTexts[detailNote].exists { remote.press(.menu); sleep(3) }
    }

    // MARK: 1 — the prompt appears at a real break, and Select skips past it

    func testPromptAppearsAndSelectSkips() {
        openFromHome("Recordings")
        waitForShelves("skip test")
        XCTAssertTrue(openShow(Self.showWithBreaks), "could not open \(Self.showWithBreaks)")
        XCTAssertTrue(playEpisode(Self.episodeWithBreaks), "could not play the episode")
        shot("01-playing")
        log("playing: \(screenText())")

        let presses = skipForwardUntilPrompt(limit: 40)
        XCTAssertTrue(promptOnScreen, "no prompt after \(presses) forward skips; on screen: \(screenText())")
        shot("02-the-prompt-at-a-real-break")
        log("PROMPT after \(presses) forward skips — clock \(transportClock()), screen \(screenText())")

        // THE PRESS.
        remote.press(.select)
        sleep(1)
        shot("03-immediately-after-select")
        XCTAssertFalse(promptOnScreen, "the prompt is still up after Select")
        sleep(3)
        shot("04-after-the-skip")
        log("after Select — clock \(transportClock()), screen \(screenText())")
        leavePlayer()
    }

    // MARK: 2 — pressing nothing plays the commercial normally

    func testPromptTimesOutAndTheBreakPlays() {
        openFromHome("Recordings")
        waitForShelves("timeout test")
        XCTAssertTrue(openShow(Self.showWithBreaks), "could not open \(Self.showWithBreaks)")
        XCTAssertTrue(playEpisode(Self.episodeWithBreaks), "could not play the episode")

        let presses = skipForwardUntilPrompt(limit: 40)
        XCTAssertTrue(promptOnScreen, "no prompt after \(presses) forward skips")
        shot("05-prompt-before-the-timeout")
        log("prompt up at clock \(transportClock()); pressing nothing for 9 s")

        sleep(9)
        XCTAssertFalse(promptOnScreen, "the prompt is still up 9 s after it appeared")
        shot("06-prompt-gone-commercial-playing")
        log("after 9 s of pressing nothing — clock \(transportClock()), screen \(screenText())")

        // It must not come back for the same break.
        sleep(8)
        XCTAssertFalse(promptOnScreen, "the prompt came back for a break it had already offered")
        shot("07-still-no-prompt")
        log("8 s later, still no prompt — clock \(transportClock())")
        leavePlayer()
    }

    // MARK: 3 — Select outside the prompt is Apple's, and frame stepping is unchanged

    func testSelectOutsideThePromptIsApples() {
        openFromHome("Recordings")
        waitForShelves("select test")
        XCTAssertTrue(openShow(Self.showWithBreaks), "could not open \(Self.showWithBreaks)")
        XCTAssertTrue(playEpisode(Self.episodeWithBreaks), "could not play the episode")
        XCTAssertFalse(promptOnScreen, "a prompt is up at the start — this test needs none")

        shot("08-before-select-no-prompt")
        log("Select #1 with no prompt on screen — clock \(transportClock())")
        remote.press(.select)
        sleep(4)
        shot("09-select-with-no-prompt")
        log("after Select #1 — clock \(transportClock())")

        // Pass 28/29 must be exactly what it was: left/right clicks while paused step one
        // frame, and Apple does not bank a 10-second skip for each.
        for _ in 0..<10 { remote.press(.right); usleep(600_000) }
        sleep(2)
        shot("10-ten-frame-steps")
        log("after 10 right clicks while paused — clock \(transportClock())")

        remote.press(.select)
        sleep(4)
        shot("11-select-again")
        log("after Select #2 — clock \(transportClock())")
        leavePlayer()
    }

    // MARK: 4 — a recording with no segments behaves exactly as it does today

    func testARecordingWithNoSegmentsIsUnchanged() {
        openFromHome("Recordings")
        waitForShelves("no-segments test")
        XCTAssertTrue(openShow(Self.showWithBreaks), "could not open \(Self.showWithBreaks)")
        XCTAssertTrue(playEpisode(Self.episodeWithoutBreaks), "could not play the recording")
        shot("12-no-segments-playing")
        XCTAssertFalse(promptOnScreen, "a prompt appeared on a recording with no segments")
        log("no-segments recording: \(screenText())")

        for n in 1...20 {
            remote.press(.right)
            usleep(900_000)
            XCTAssertFalse(promptOnScreen, "a prompt appeared after \(n) skips on a recording with no segments")
            if n % 5 == 0 { for _ in 0..<3 { XCTAssertFalse(promptOnScreen); sleep(1) } }
        }
        sleep(5)
        shot("13-no-segments-after-20-skips")
        XCTAssertFalse(promptOnScreen, "a prompt appeared on a recording with no segments")
        log("20 forward skips, no prompt at any point — clock \(transportClock())")
        leavePlayer()
    }

    // MARK: 5 — a pause takes the prompt down and gives Select back (step 6)

    func testPauseDismissesThePrompt() {
        openFromHome("Recordings")
        waitForShelves("pause test")
        XCTAssertTrue(openShow(Self.showWithBreaks), "could not open \(Self.showWithBreaks)")
        XCTAssertTrue(playEpisode(Self.episodeWithBreaks), "could not play the episode")

        let presses = skipForwardUntilPrompt(limit: 40)
        XCTAssertTrue(promptOnScreen, "no prompt after \(presses) forward skips")
        shot("14-prompt-before-the-pause")
        log("prompt up; pressing Play/Pause — not Select")

        remote.press(.playPause)
        sleep(2)
        XCTAssertFalse(promptOnScreen, "the prompt survived a pause")
        shot("15-paused-prompt-gone")
        log("paused, prompt gone — clock \(transportClock())")

        remote.press(.playPause)
        sleep(3)
        shot("16-resumed")
        leavePlayer()
    }

    // MARK: 6 — a break already offered is never offered again (step 4)

    func testASkippedBreakIsNotOfferedAgain() {
        openFromHome("Recordings")
        waitForShelves("re-offer test")
        XCTAssertTrue(openShow(Self.showWithBreaks), "could not open \(Self.showWithBreaks)")
        XCTAssertTrue(playEpisode(Self.episodeWithBreaks), "could not play the episode")

        let presses = skipForwardUntilPrompt(limit: 40)
        XCTAssertTrue(promptOnScreen, "no prompt after \(presses) forward skips")
        log("prompt up; skipping the break")
        remote.press(.select)
        sleep(2)
        XCTAssertFalse(promptOnScreen, "the prompt is still up after Select")
        shot("17-skipped")

        // Back into the same break with Apple's own backward skip.
        for _ in 0..<8 { remote.press(.left); usleep(900_000) }
        log("seeked backwards into the break just skipped — clock \(transportClock())")
        for n in 1...20 {
            XCTAssertFalse(promptOnScreen, "the break was offered again \(n) s after seeking back into it")
            sleep(1)
        }
        shot("18-no-second-offer")
        log("20 s inside the break already skipped, no second prompt — clock \(transportClock())")
        leavePlayer()
    }


    // MARK: harness housekeeping, not a claim about the app

    /// Runs the subject recording out to its end, which is the only thing that clears its
    /// resume position (`ResumeStore.clear`, PlayerModel end-of-playback). Every test above
    /// leaves a resume further into the recording than the last, so this is how the suite is
    /// put back to the start. It asserts nothing.
    func testZResetTheSubjectRecordingsResume() {
        openFromHome("Recordings")
        waitForShelves("reset")
        XCTAssertTrue(openShow(Self.showWithBreaks), "could not open \(Self.showWithBreaks)")
        XCTAssertTrue(playEpisode(Self.episodeWithBreaks), "could not play the episode")
        for _ in 0..<220 { remote.press(.right); usleep(320_000) }
        sleep(4)
        log("reset run finished — \(screenText().prefix(4))")
        leavePlayer()
    }
}
