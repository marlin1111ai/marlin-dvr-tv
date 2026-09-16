//
//  ContinueWatchingUITests.swift
//  Marlin DVR TVUITests
//
//  Pass 91's evidence harness, not a standing test. It runs on the physical Apple TV
//  ("Home Theater") and drives the real Siri Remote, because the shelf it photographs is built
//  from `ResumeStore` — which lives in that Apple TV's own `UserDefaults` and exists nowhere
//  else. A simulator has no saved positions and would draw no shelf at all.
//
//  **It makes no server write of any kind.** The only non-GET traffic is the app's own launch
//  ping (`ClientSession.swift`). Nothing is played, deleted, trashed, kept or scheduled, so the
//  device is left exactly as it was found — the saved positions included.
//
//  **`activate()`, never `launch()`** — Pass 38's pattern, kept since: if the app was started
//  separately with a console attached, `activate()` joins that process instead of replacing it.
//
//  What it proves, and what only the photographs can show:
//
//    91a  the Recordings screen: "Continue watching" in the first shelf's place with its cards,
//         and no "Recently Watched" shelf anywhere on the screen
//    91b  show detail for the first of those cards, reached by selecting it
//
//  The card's own second line is `ResumeStore`'s value rendered — "S4 E14 · 24 min in" is
//  `ResumeStore.label(for:)` on the entry the shelf selected — so reading the card's label is
//  reading the store, which a test process cannot open directly.
//

import XCTest

final class ContinueWatchingUITests: XCTestCase {
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

    private let continueLabel = "Continue watching"
    private let serverWatchedLabel = "Recently Watched"

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.activate()
        goHome()
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

    private func log(_ line: String) { print("[pass91 \(stamp())] \(line)") }

    /// Every string the screen is drawing, in screen order. The shelves' whole state — the header
    /// counts, each shelf's heading, each card's title and its second line — is static text.
    private func screenText() -> [String] {
        app.staticTexts.allElementsBoundByIndex.map(\.label).filter { !$0.isEmpty }
    }

    /// Every button the screen is drawing. On the shelves those are the cards; in show detail
    /// they are Resume / Play newest / Series pass and the episode rows. **A button's own text is
    /// not a `staticText`**, so the Resume line — which is a `Button` — is only readable here and
    /// never through `screenText()`; the first run of this harness asserted on the wrong one of
    /// the two and failed while the screen was correct (Pass 91 §4).
    ///
    /// Enumerating is cheap on both screens; the rule about never enumerating a realised grid is
    /// about the Guide, not about three shelves.
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

    // MARK: driving the remote

    private func goHome() {
        for _ in 0..<7 {
            if app.staticTexts["Marlin"].waitForExistence(timeout: 8) { sleep(2); return }
            remote.press(.menu)
            sleep(3)
        }
    }

    /// Walk the 3x3 Home grid to a named tile and select it.
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
        XCTAssertTrue(focusedLabel() == tile || focusedLabel().hasPrefix("\(tile), "),
                      "walking Home did not reach \(tile) — focus is \(focusedLabel())")
        remote.press(.select)
    }

    private func waitForShelves(_ tag: String) {
        XCTAssertTrue(app.staticTexts[shelvesNote].waitForExistence(timeout: 40), "the Recordings shelves did not appear (\(tag))")
        sleep(3)
    }

    // MARK: the pass's question

    func testContinueWatchingReplacesTheServersRecentlyWatchedShelf() {
        openFromHome("Recordings")
        waitForShelves("first entry")

        let text = screenText()
        log("shelves: \(text)")
        log("cards: \(buttonLabels())")
        log("focus: \(focusedLabel())")
        shot("91a-recordings-continue-watching")

        // 1. The shelf is drawn, and the server's is not.
        XCTAssertTrue(text.contains(continueLabel), "no \"\(continueLabel)\" heading on the shelves: \(text)")
        XCTAssertFalse(text.contains(serverWatchedLabel), "the server's \"\(serverWatchedLabel)\" shelf is still drawn: \(text)")

        // 2. It is in the first shelf's place — above both of the server's.
        let here = text.firstIndex(of: continueLabel)
        for below in ["Recently Updated", "Recently Added"] {
            guard let there = text.firstIndex(of: below) else { continue }
            XCTAssertTrue(here! < there, "\"\(continueLabel)\" is not above \"\(below)\": \(text)")
        }

        // 3. It has cards, and each one's second line is the store's own "n min in".
        let positions = text.filter { $0.hasSuffix(" min in") || $0.hasSuffix(" s in") }
        log("saved positions on the shelf: \(positions)")
        XCTAssertFalse(positions.isEmpty,
                       "\"\(continueLabel)\" is drawn with no card carrying a position — either this "
                       + "Apple TV has no unfinished saved position, or the shelf drew empty: \(text)")

        // 4. Focus opens on the first of them, because the shelf is now the first shelf.
        XCTAssertTrue(focusedLabel().contains(" min in") || focusedLabel().contains(" s in"),
                      "focus did not open on a Continue watching card — it is \(focusedLabel())")

        // 5. Selecting it opens show detail, whose Resume line reads the same store.
        log("selecting \(focusedLabel())")
        remote.press(.select)
        XCTAssertTrue(app.staticTexts[detailNote].waitForExistence(timeout: 40), "show detail did not open")
        sleep(3)
        let detail = screenText()
        let detailButtons = buttonLabels()
        log("show detail: \(detail)")
        log("show detail buttons: \(detailButtons)")
        shot("91b-show-detail-for-the-first-card")
        // The card's second line and this line are the same `ResumeStore` entry rendered by the
        // same `ResumeStore.label(for:)`, one on the shelf and one in frame 5d.
        XCTAssertTrue(detailButtons.contains { $0.hasPrefix("Resume ") },
                      "show detail for a Continue watching card has no Resume line: \(detailButtons)")

        // 6. Back out: the shelves are still the shelves, and nothing was written.
        remote.press(.menu)
        XCTAssertTrue(app.staticTexts[shelvesNote].waitForExistence(timeout: 20), "Menu did not return to the shelves")
        sleep(2)
        log("back on the shelves, focus is \(focusedLabel())")
    }
}
