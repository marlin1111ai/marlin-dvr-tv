//
//  Pass140UITests.swift
//  Marlin DVR TVUITests
//
//  Pass 140's evidence harness, not a standing test: what the Player's item carries as Now Playing text on
//  a live channel and on a recording. Joined to a process `devicectl … --console` started — neither
//  `launch()` nor `activate()` (Pass 116) — so the app's `[nowplaying]` lines (the text published, the
//  picture fetched, the Now Playing centre's read-back) land on the console beside this log. It plays On
//  Now's first card for 75 s (past the 60 s window Apple's pause needs — Pass 7C), presses Play/Pause so
//  Apple's transport bar draws the item's title and subtitle, keeps a screenshot and every static text on
//  screen, resumes and leaves; then the Recordings shelves' first card, the same way. It makes no write
//  beyond the sessions playing opens and closes, and a resume position the recording saves as always.
//
//  Status at the Pass 140 commit: written, NOT RUN — the owner was using Home Theater at the time; the live
//  publish, the picture, a channel change and the 11:00 PM airing change were read from the console instead.
//
//  Run (the app first, then this):
//    xcrun devicectl device process launch --device "Home Theater" --console --terminate-existing com.marlin1111.MarlinDVRTV &
//    xcodebuild test-without-building -xctestrun "build/dd-device/Build/Products/Marlin DVR TV_Marlin DVR TV_appletvos27.0-arm64.xctestrun" \
//      -destination 'platform=tvOS,name=Home Theater' -only-testing:"Marlin DVR TVUITests/Pass140UITests/testLiveThenRecording"
//

import XCTest

final class Pass140UITests: XCTestCase {
    private var app: XCUIApplication!
    private let remote = XCUIRemote.shared

    private static let homeTiles = ["Guide", "On Now", "On Later",
                                    "Recordings", "Cameras", "Favorites",
                                    "Weather", "Radio", "Settings"]
    private let shelvesNote = "Watched and keep flags are shared with the other Apple TV"
    private let detailNote = "Click and hold an episode for Keep and Delete"

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        log("joining the running app — no launch()")
    }

    // MARK: reading the device

    private func stamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: Date())
    }

    private func log(_ line: String) { print("[pass140 \(stamp())] \(line)") }

    private func shot(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    private func focusedLabel() -> String {
        app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == YES")).allElementsBoundByIndex.first?.label ?? ""
    }

    private func screenText() -> [String] {
        app.staticTexts.allElementsBoundByIndex.map(\.label).filter { !$0.isEmpty }
    }

    private func logTexts(_ when: String) {
        log("TEXTS \(when): " + screenText().map { "\"\($0)\"" }.joined(separator: ", "))
    }

    /// Only the Starting screen (6a) draws this.
    private var starting: Bool {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Press Menu to cancel'")).firstMatch.exists
    }

    private func waitFor(_ seconds: Int, _ condition: () -> Bool) -> Bool {
        for _ in 0..<(seconds * 2) {
            if condition() { return true }
            usleep(500_000)
        }
        return condition()
    }

    /// Playback has started once the Starting screen has come and gone.
    private func waitForPlayback(_ what: String) -> Bool {
        sleep(2)
        let gone = waitFor(120) { !starting }
        log("\(what): Starting screen gone \(gone)")
        return gone
    }

    // MARK: driving

    private func goHome() {
        for _ in 0..<7 {
            if app.staticTexts["Marlin"].waitForExistence(timeout: 8) { sleep(2); return }
            remote.press(.menu)
            sleep(3)
        }
    }

    private func openFromHome(_ tile: String) {
        XCTAssertTrue(app.staticTexts["Marlin"].waitForExistence(timeout: 60), "Home did not appear")
        sleep(3)
        guard let target = Self.homeTiles.firstIndex(of: tile) else { return XCTFail("no such tile: \(tile)") }
        guard let here = Self.homeTiles.firstIndex(where: { focusedLabel() == $0 || focusedLabel().hasPrefix("\($0), ") }) else {
            return XCTFail("Home focus is not on a tile — it is \(focusedLabel())")
        }
        log("Home focus is \(Self.homeTiles[here]); walking to \(tile)")
        let dRow = target / 3 - here / 3, dCol = target % 3 - here % 3
        for _ in 0..<abs(dRow) { remote.press(dRow > 0 ? .down : .up); usleep(700_000) }
        for _ in 0..<abs(dCol) { remote.press(dCol > 0 ? .right : .left); usleep(700_000) }
        remote.press(.select)
    }

    /// Pause, read, resume: Apple's transport bar draws the item's title and subtitle while paused.
    private func pauseReadResume(_ what: String) {
        logTexts("\(what), playing")
        remote.press(.playPause)
        sleep(3)
        shot("\(what) paused")
        logTexts("\(what), paused")
        remote.press(.playPause)
        sleep(2)
        logTexts("\(what), resumed")
    }

    // MARK: the pass's evidence

    func testLiveThenRecording() {
        // ---- live: On Now's first card ----
        openFromHome("On Now")
        XCTAssertTrue(app.staticTexts["On Now"].waitForExistence(timeout: 30), "On Now did not open")
        sleep(4)
        log("On Now first card: \"\(focusedLabel())\"")
        remote.press(.select)
        XCTAssertTrue(waitForPlayback("live"), "the live channel never started")
        log("live playing — waiting 75 s for the window Apple's pause needs")
        sleep(75)
        pauseReadResume("live")
        remote.press(.menu)
        sleep(3)
        goHome()

        // ---- recording: the Recordings shelves' first card ----
        openFromHome("Recordings")
        XCTAssertTrue(app.staticTexts[shelvesNote].waitForExistence(timeout: 40), "the Recordings shelves did not appear")
        sleep(3)
        log("Recordings first card: \"\(focusedLabel())\"")
        remote.press(.select)
        let detail = app.staticTexts[detailNote].waitForExistence(timeout: 40)
        if detail {
            sleep(3)
            log("show detail control: \"\(focusedLabel())\"")
            remote.press(.select)
        } else {
            // A Continue-watching card opens the resume sheet instead; its focused control plays.
            log("no show detail — focus is \"\(focusedLabel())\"; pressing it")
            remote.press(.select)
        }
        XCTAssertTrue(waitForPlayback("recording"), "the recording never started")
        sleep(12)
        pauseReadResume("recording")
        remote.press(.menu)
        sleep(3)
        goHome()
        log("done")
    }
}
