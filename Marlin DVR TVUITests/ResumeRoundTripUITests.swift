//
//  ResumeRoundTripUITests.swift
//  Marlin DVR TVUITests
//
//  Pass 125's evidence harness, not a standing test: the regression Pass 119's report says a run can
//  prove for S5 on a healthy server — **Resume lands on the saved position, and the saved position
//  survives leaving the Player.** S5's own path, "Try again" after a failed start, needs a failure the
//  remote cannot produce (the server down, or the Apple TV's network pulled — declined on 2026-09-16,
//  Pass 99), so it is code-traced only and this harness never goes near it.
//
//  It needs the physical Apple TV ("Home Theater"), the owner's server, and at least one recording with
//  an unfinished saved position on this Apple TV — a card on the Recordings screen's Continue watching
//  shelf. It prefers the standing subject, History's Greatest Mysteries (`5328bb632e76`), and takes
//  the first card otherwise.
//
//  **`launch()`, not `activate()`** (Pass 92): no console is attached, so the run is believed only once
//  its launch ping is in `GET /api/logs` at its time.
//
//  **It moves one saved position by the seconds it plays** — about twenty — and clears none: the
//  recording is never played to its end, and nothing is deleted, trashed, kept, scheduled or marked
//  watched. Select is pressed on Home's Recordings tile, on the card, on Resume, and twice inside the
//  Player to pause and play (Apple's own transport control; the app owns Select only while the
//  commercial prompt is up, which the harness waits out). Its only non-GET traffic is the app's own:
//  the launch ping and the one play session (POST, then DELETE on leaving).
//
//  **What it reads.** The saved position before, from the card's own "n min in" and show detail's
//  "Resume S4 E14 · n min in" (both `ResumeStore.label(for:)`); where playback is, from Apple's
//  transport-bar clock while paused (the app's own recording HUD went in Pass 110); and the saved
//  position after, from the same two labels once the Player has been left. If Resume had landed at 0,
//  the position saved on leaving would read "n s in" instead of the minutes it started with.
//
//  Run:
//    xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
//      -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates test \
//      -only-testing:"Marlin DVR TVUITests/ResumeRoundTripUITests"
//

import XCTest

final class ResumeRoundTripUITests: XCTestCase {
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
    /// The Pass 38 prompt. Nothing else in the app draws this string.
    private let promptText = "Skip the commercial break"
    /// The Player's Starting screen line for a recording (`PlayerModel.startingLine`).
    private let preparing = "Preparing the recording"
    /// The standing subject, preferred when it has a card.
    private let preferredShow = "History's Greatest Mysteries"

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

    private func log(_ line: String) { print("[pass125 \(stamp())] \(line)") }

    private func shot(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    private func screenText() -> [String] {
        app.staticTexts.allElementsBoundByIndex.map(\.label).filter { !$0.isEmpty }
    }

    /// The cards and the action buttons are `Button`s, so their text is here and never in
    /// `screenText()` (ContinueWatchingUITests' header, Pass 91 §4).
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

    /// "S4 E14 · 24 min in" → 24; "… · 40 s in" → 0. Nil when the label carries no position.
    private static func minutesIn(_ label: String) -> Int? {
        if let r = label.range(of: "([0-9]+) min in", options: .regularExpression) {
            return Int(label[r].split(separator: " ")[0])
        }
        if label.range(of: "[0-9]+ s in", options: .regularExpression) != nil { return 0 }
        return nil
    }

    /// Apple's own transport-bar clock — "24:31" and the like — which is on screen while paused.
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

    /// The Continue watching cards, in shelf order: every button whose label carries a position.
    private func continueCards() -> [String] {
        buttonLabels().filter { Self.minutesIn($0) != nil }
    }

    /// Right along the first shelf until the named card has focus.
    private func focusCard(_ label: String) -> Bool {
        for _ in 0..<12 {
            if focusedLabel() == label { return true }
            remote.press(.right)
            usleep(700_000)
        }
        return focusedLabel() == label
    }

    private func resumeLabel() -> String? { buttonLabels().first { $0.hasPrefix("Resume ") } }

    // MARK: the run

    func testResumeLandsOnTheSavedPositionAndItSurvivesLeavingThePlayer() {
        openFromHome("Recordings")
        waitForShelves("before")
        let cards = continueCards()
        log("Continue watching cards: \(cards)")
        XCTAssertFalse(cards.isEmpty, "no Continue watching card — this Apple TV has no unfinished saved position to resume")
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
        XCTAssertEqual(Self.minutesIn(resumeBefore), minutesBefore, "the Resume line and the card disagree about the saved position")
        XCTAssertTrue(focusedLabel().hasPrefix("Resume "), "show detail did not focus Resume — focus is \(focusedLabel())")
        shot("02-show-detail-before")

        // Resume: the same press the owner makes. A finished recording starts at once since 1.9.1 (the
        // server serves the .mp4 beside it, no remux), so the Starting screen is gone before a query can
        // see it, and show detail's own text still exists in the tree under the Player's cover — run 1 of
        // this harness failed on both of those with the app playing (its session is in the server's log).
        // The proof that the Player is up is Apple's transport clock, read on a pause below.
        remote.press(.select)
        log("Resume pressed")
        var waited = 0
        while app.staticTexts[preparing].exists && waited < 90 { sleep(1); waited += 1 }
        if waited > 0 { log("\u{201C}\(preparing)\u{201D} was up for about \(waited) s") }
        sleep(12)
        XCTAssertFalse(app.buttons["Try again"].exists, "the Player shows a failure card: \(screenText())")

        // Pause on Apple's transport, read its clock, play on.
        waitForPromptToClear("before the pause")
        remote.press(.select)
        sleep(4)
        let landed = transportClock()
        log("paused: transport clock=\(landed.map { String(format: "%.0f s", $0) } ?? "unreadable") · text=\(screenText())")
        shot("03-paused-after-resume")
        XCTAssertNotNil(landed, "no transport clock on screen after the pause — the Player is not up, or Select did not pause it")
        if let landed {
            XCTAssertGreaterThanOrEqual(landed, Double(minutesBefore) * 60 - 5, "Resume landed at \(landed) s, before the saved \(minutesBefore) min")
            XCTAssertLessThan(landed, Double(minutesBefore + 1) * 60 + 60, "Resume landed at \(landed) s, well past the saved \(minutesBefore) min")
        }
        remote.press(.select)
        sleep(3)

        // Leave the Player: Menu → dismiss → `stop()` saves the position.
        remote.press(.menu)
        XCTAssertTrue(app.staticTexts[detailNote].waitForExistence(timeout: 30), "show detail did not come back after Menu")
        sleep(3)
        guard let resumeAfter = resumeLabel() else { return XCTFail("the Resume line is gone after leaving the Player; buttons: \(buttonLabels())") }
        let minutesAfter = Self.minutesIn(resumeAfter) ?? -1
        log("show detail after: \u{201C}\(resumeAfter)\u{201D} — \(minutesAfter) min in")
        XCTAssertTrue(minutesAfter == minutesBefore || minutesAfter == minutesBefore + 1,
                      "the position after leaving reads \(minutesAfter) min, from \(minutesBefore) min before")
        shot("04-show-detail-after")

        // And the shelf agrees.
        remote.press(.menu)
        waitForShelves("after")
        let cardsAfter = continueCards()
        log("Continue watching cards after: \(cardsAfter)")
        let showName = card.components(separatedBy: ",").first ?? card
        let cardAfter = cardsAfter.first { $0.hasPrefix(showName) }
        XCTAssertNotNil(cardAfter, "the subject's card is gone from Continue watching: \(cardsAfter)")
        XCTAssertEqual(cardAfter.flatMap(Self.minutesIn), minutesAfter, "the card and the Resume line disagree after")
        shot("05-continue-watching-after")
        log("RESULT resumed at \(landed.map { String(format: "%.0f s", $0) } ?? "an unread position"); saved position \(minutesBefore) → \(minutesAfter) min in")
    }
}
