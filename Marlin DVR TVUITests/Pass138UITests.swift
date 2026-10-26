//
//  Pass138UITests.swift
//  Marlin DVR TVUITests
//
//  Pass 138's evidence harness, not a standing test: the last-channel flip. Two live channels are played
//  from On Now, then a double-click on the clickpad centre — inside the first minute after tuning, where
//  the app does its own delayed pause — switches back to the first, and a second double-click returns to
//  the second; a single click still pauses and a second single click resumes; and after the app is quit
//  and launched again, a double-click still finds the channel watched before it. It needs the physical
//  Apple TV ("Home Theater") and the owner's server.
//
//  The channel playing is read from the item's title, "ch<number> <name>", which Apple's transport bar
//  keeps in the accessibility tree whether it is shown or hidden (Pass 110). **It makes no write beyond
//  the live sessions playing a channel opens and closes** — Select on Home's On Now tile and on two On Now
//  cards, and clicks in the Player. **`launch()`, not `activate()`** (Pass 92).
//
//  Two methods, run one at a time. The run of record is the first, with `launch()`. The second drives a
//  process `devicectl … --console` already started — neither `launch()` nor `activate()` — so the app's own
//  `[select]` and `[lastchannel]` lines show, for the owner's question about the first minute after
//  tuning, whether the first click's own delayed pause was still pending and cancelled, or had acted once.
//
//  Run (the record):
//    xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
//      -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates test \
//      -only-testing:"Marlin DVR TVUITests/Pass138UITests/testDoubleClickFlipsToThePreviousChannel"
//  Run (with the console; the app first, then the test):
//    xcrun devicectl device process launch --device "Home Theater" --console --terminate-existing \
//      com.marlin1111.MarlinDVRTV &
//    xcodebuild … test -only-testing:"Marlin DVR TVUITests/Pass138UITests/testTheFirstMinuteWithTheConsoleAttached"
//

import XCTest

final class Pass138UITests: XCTestCase {
    private var app: XCUIApplication!
    private let remote = XCUIRemote.shared

    private static let homeTiles = [["Guide", "On Now", "On Later"], ["Recordings", "Cameras", "Favorites"], ["Weather", "Radio", "Settings"]]

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        // The console drive joins the process `devicectl … --console` started; everything else launches.
        if name.contains("WithTheConsoleAttached") {
            log("joining the running app — no launch()")
        } else {
            app.launch()
            log("launched")
        }
    }

    // MARK: reading the device

    private func stamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: Date())
    }

    private func log(_ line: String) { print("[pass138 \(stamp())] \(line)") }

    private func shot(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    private func focusedLabel() -> String? {
        app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == YES")).allElementsBoundByIndex.first?.label
    }

    private func waitFor(_ timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            usleep(250_000)
        }
        return condition()
    }

    /// Only the Starting screen (6a) draws this.
    private var starting: Bool {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Press Menu to cancel'")).firstMatch.exists
    }

    /// The item's title, "ch2.1 WMAR-HD" — the channel the Player holds. The paused-live screen draws the
    /// title and the subtitle on one line, "ch8.1 WGAL-TV · WGAL News 8 at 7PM · until 7:30 PM" (found on
    /// this harness's first run), so a line carrying " · " is not the title.
    private func playingTitle() -> String? {
        app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^ch[0-9].*")).allElementsBoundByIndex
            .map(\.label).first { !$0.contains(" · ") }
    }

    /// The item's subtitle, "<programme> · until 7:00 PM", when the request carried what is on.
    private func playingSubtitle() -> String? {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", " · until ")).allElementsBoundByIndex.first?.label
    }

    /// The live title an On Now card's channel will play under: "2.1 · WMAR-HD, NEW, …" → "ch2.1 WMAR-HD".
    private func liveTitle(fromCard label: String?) -> String? {
        guard let first = label?.components(separatedBy: ", ").first else { return nil }
        let parts = first.components(separatedBy: " · ")
        return parts.count == 2 ? "ch\(parts[0]) \(parts[1])" : nil
    }

    /// The Player is past its Starting screen and holds `title`.
    private func waitPlaying(_ title: String, timeout: TimeInterval = 30) -> Bool {
        waitFor(timeout) { !starting && playingTitle() == title }
    }

    // MARK: driving

    private func tilePosition(of label: String?) -> (Int, Int)? {
        guard let label else { return nil }
        for (r, row) in Self.homeTiles.enumerated() {
            for (c, name) in row.enumerated() where label.hasPrefix("\(name), ") { return (r, c) }
        }
        return nil
    }

    private func focusTile(_ name: String) {
        for _ in 0..<12 {
            guard let here = tilePosition(of: focusedLabel()) else { remote.press(.up); usleep(800_000); continue }
            var target = (0, 0)
            for (r, row) in Self.homeTiles.enumerated() { if let c = row.firstIndex(of: name) { target = (r, c) } }
            if here == target { return }
            if here.0 < target.0 { remote.press(.down) }
            else if here.0 > target.0 { remote.press(.up) }
            else if here.1 < target.1 { remote.press(.right) }
            else { remote.press(.left) }
            usleep(800_000)
        }
        XCTFail("could not focus Home's \(name) tile; focus=\(focusedLabel() ?? "nothing")")
    }

    private func openOnNow() {
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Guide, ")).firstMatch.waitForExistence(timeout: 40), "Home did not appear")
        sleep(3)
        focusTile("On Now")
        remote.press(.select)
        XCTAssertTrue(app.staticTexts["On Now"].waitForExistence(timeout: 30), "On Now did not open")
        sleep(4)
    }

    /// Two centre clicks as close together as the remote allows; the gap between the two calls is logged.
    private func doubleClick(_ why: String) {
        let t0 = Date()
        remote.press(.select)
        let t1 = Date()
        remote.press(.select)
        log("\(why): double-click sent — the second call began \(Int(t1.timeIntervalSince(t0) * 1000)) ms after the first")
    }

    // MARK: the console drive

    /// One channel from On Now, then two double-clicks inside the first minute after tuning: the first as
    /// fast as the remote allows, which lands inside the 0.35 s grace of the app's own pause; the second with
    /// 130 ms added between the clicks, aiming past it. Only the first is asserted — the second's gap is the
    /// remote's to decide, and the console says which case it was.
    func testTheFirstMinuteWithTheConsoleAttached() {
        openOnNow()
        guard let title = liveTitle(fromCard: focusedLabel()) else { return XCTFail("could not read the first card's channel") }
        remote.press(.select)
        XCTAssertTrue(waitPlaying(title), "\(title) did not start; title=\(playingTitle() ?? "none")")
        log("PLAYING \(title)")
        sleep(3)
        doubleClick("on \(title), first minute, fast")
        let flipped = waitFor(30) { !starting && playingTitle() != nil && playingTitle() != title }
        let other = playingTitle() ?? "none"
        log("after the fast double-click: title \(other), paused screen \(app.staticTexts["Paused"].exists)")
        XCTAssertTrue(flipped, "the fast double-click did not switch channel; title=\(other)")
        XCTAssertFalse(app.staticTexts["Paused"].exists, "the flipped-to channel is paused")
        sleep(3)
        let t0 = Date()
        remote.press(.select)
        usleep(130_000)
        let t1 = Date()
        remote.press(.select)
        log("on \(other), first minute, slower: the second call began \(Int(t1.timeIntervalSince(t0) * 1000)) ms after the first")
        _ = waitFor(15) { !starting && playingTitle() == title }
        sleep(2)
        log("after the slower double-click: title \(playingTitle() ?? "none"), paused screen \(app.staticTexts["Paused"].exists)")
        remote.press(.menu)
        _ = app.staticTexts["On Now"].waitForExistence(timeout: 15)
    }

    // MARK: the run

    func testDoubleClickFlipsToThePreviousChannel() {
        openOnNow()

        // Channel A: the first On Now card.
        let titleA = liveTitle(fromCard: focusedLabel())
        log("ON NOW first card \(focusedLabel() ?? "nothing") → \(titleA ?? "?")")
        guard let titleA else { return XCTFail("could not read the first card's channel") }
        remote.press(.select)
        XCTAssertTrue(waitPlaying(titleA), "\(titleA) did not start; title=\(playingTitle() ?? "none")")
        log("PLAYING \(titleA)")
        sleep(4)
        remote.press(.menu)
        XCTAssertTrue(app.staticTexts["On Now"].waitForExistence(timeout: 15), "Menu did not leave the Player")
        sleep(3)

        // Channel B: the next card.
        remote.press(.right)
        sleep(1)
        let titleB = liveTitle(fromCard: focusedLabel())
        log("ON NOW second card \(focusedLabel() ?? "nothing") → \(titleB ?? "?")")
        guard let titleB, titleB != titleA else { return XCTFail("could not read a second, different channel") }
        remote.press(.select)
        XCTAssertTrue(waitPlaying(titleB), "\(titleB) did not start; title=\(playingTitle() ?? "none")")
        log("PLAYING \(titleB)")
        sleep(3)
        shot("01-playing-B")

        // A double-click inside the first minute after tuning B — the app's own delayed pause applies — goes to A.
        doubleClick("on \(titleB), first minute")
        let flippedToA = waitPlaying(titleA)
        log("after the double-click: title \(playingTitle() ?? "none"), subtitle \(playingSubtitle() ?? "none"), paused screen \(app.staticTexts["Paused"].exists)")
        shot("02-flipped-to-A")
        XCTAssertTrue(flippedToA, "the double-click did not switch to \(titleA); title=\(playingTitle() ?? "none")")
        XCTAssertFalse(app.staticTexts["Paused"].exists, "the flipped-to channel is paused")

        // Again, inside A's first minute: back to B.
        sleep(3)
        doubleClick("on \(titleA), first minute")
        let flippedToB = waitPlaying(titleB)
        log("after the second double-click: title \(playingTitle() ?? "none"), subtitle \(playingSubtitle() ?? "none"), paused screen \(app.staticTexts["Paused"].exists)")
        shot("03-flipped-back-to-B")
        XCTAssertTrue(flippedToB, "the second double-click did not switch back to \(titleB); title=\(playingTitle() ?? "none")")
        XCTAssertFalse(app.staticTexts["Paused"].exists, "the flipped-back channel is paused")

        // A single click still pauses, and a second single click — well apart — resumes, on the same channel.
        sleep(3)
        remote.press(.select)
        let paused = app.staticTexts["Paused"].waitForExistence(timeout: 5)
        log("single click: paused screen \(paused), title \(playingTitle() ?? "none")")
        shot("04-single-click-paused")
        XCTAssertTrue(paused, "a single click did not pause")
        XCTAssertEqual(playingTitle(), titleB, "a single click changed the channel")
        sleep(3)
        remote.press(.select)
        let resumed = waitFor(5) { !app.staticTexts["Paused"].exists }
        log("second single click: resumed \(resumed), title \(playingTitle() ?? "none")")
        XCTAssertTrue(resumed, "a second single click did not resume")
        XCTAssertEqual(playingTitle(), titleB, "a single click changed the channel")

        // Quit and launch again: the record survives (owner's A1).
        sleep(2)
        remote.press(.menu)
        XCTAssertTrue(app.staticTexts["On Now"].waitForExistence(timeout: 15), "Menu did not leave the Player")
        app.terminate()
        log("terminated; launching again")
        app.launch()
        openOnNow()
        let titleC = liveTitle(fromCard: focusedLabel())
        guard let titleC else { return XCTFail("could not read the first card's channel after the relaunch") }
        // Before the quit the current channel was B and the previous A. Playing C makes B previous —
        // unless C is B, which changes nothing and leaves A previous.
        let expected = titleC == titleB ? titleA : titleB
        log("AFTER RELAUNCH first card \(titleC); the previous channel should be \(expected)")
        remote.press(.select)
        XCTAssertTrue(waitPlaying(titleC), "\(titleC) did not start after the relaunch; title=\(playingTitle() ?? "none")")
        sleep(3)
        doubleClick("on \(titleC) after the relaunch")
        let flippedAfterRelaunch = waitPlaying(expected)
        log("after the relaunch double-click: title \(playingTitle() ?? "none"), subtitle \(playingSubtitle() ?? "none")")
        shot("05-after-relaunch-flipped")
        XCTAssertTrue(flippedAfterRelaunch, "after the relaunch the double-click did not switch to \(expected); title=\(playingTitle() ?? "none")")

        sleep(2)
        remote.press(.menu)
        _ = app.staticTexts["On Now"].waitForExistence(timeout: 15)
    }
}
