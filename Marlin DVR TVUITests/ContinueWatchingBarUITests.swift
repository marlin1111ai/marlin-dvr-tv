//
//  ContinueWatchingBarUITests.swift
//  Marlin DVR TVUITests
//
//  Pass 92's evidence harness, not a standing test. Like Pass 91's it needs the physical Apple TV
//  ("Home Theater") and the real Siri Remote: the bars it photographs are drawn from that Apple
//  TV's own `ResumeStore`, which exists nowhere else.
//
//  **It makes no server write of any kind.** The only non-GET traffic is the app's own launch
//  ping (`ClientSession.swift`). Nothing is played, deleted, trashed, kept or scheduled.
//
//  **`launch()`, not `activate()` — and that is deliberate.** Pass 38 introduced `activate()` so
//  that a separately started process with a console attached is joined rather than replaced, and
//  Passes 86 and 91 copied it. **It photographed a stale build here**: `activate()` resumed the
//  Pass 91 process that was still running on the television from the previous session, so the
//  first two runs of this harness photographed a card with no bar while the new build sat
//  installed and unlaunched. The server's own log is what caught it — the app pings on every
//  launch (`ClientSession.swift:8-9`) and there was **no ping at all** during those two runs,
//  where each Pass 91 run had one. This harness attaches no console, so it uses `launch()`, which
//  terminates any running instance and starts the build that was just installed.
//
//    92a  the Continue watching shelf with no card focused — every bar at its resting 252 pt width
//    92b  one card focused — the same bar on the grown 296 pt card
//
//  **How the unfocused state is reached, and why it is the rail.** Pressing **Down** into the
//  shelf below was tried first and measured: the vertical `ScrollView` scrolls 570 pt to bring
//  that shelf into view, which carries the Continue watching heading to y = −410 and its cards to
//  y = −324 — off the top of the television. So the shot is taken with focus in the **rail**,
//  which leaves the vertical scroll alone. The rail expands to 372 pt while it holds focus
//  (`RailView.swift:67`) and the content narrows with it; that is the owner's own swipe-left
//  state, and the card rects logged below record exactly what it costs.
//
//  **A card's frame is the evidence the screenshots are measured against.** The harness logs each
//  card's rect, so the fill widths read off the photographs can be turned back into fractions
//  without assuming the card is the size the source says it is.
//

import XCTest

final class ContinueWatchingBarUITests: XCTestCase {
    private var app: XCUIApplication!
    private let remote = XCUIRemote.shared

    /// Home tile order, frame 2a — three rows of three (Destination.homeTiles).
    private static let homeTiles = ["Guide", "On Now", "On Later",
                                    "Recordings", "Cameras", "Favorites",
                                    "Weather", "Radio", "Settings"]
    /// Only on the Recordings shelves.
    private let shelvesNote = "Watched and keep flags are shared with the other Apple TV"
    private let continueLabel = "Continue watching"

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launch()
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

    private func log(_ line: String) { print("[pass92 \(stamp())] \(line)") }

    private func screenText() -> [String] {
        app.staticTexts.allElementsBoundByIndex.map(\.label).filter { !$0.isEmpty }
    }

    /// A Continue watching card is the only button whose label carries a saved position.
    private func continueCards() -> [XCUIElement] {
        app.buttons.matching(NSPredicate(format: "label CONTAINS ' min in' OR label CONTAINS ' s in'"))
            .allElementsBoundByIndex
    }

    private func rects(_ elements: [XCUIElement]) -> String {
        elements.map { e in
            let f = e.frame
            return "“\(e.label)” (\(f.origin.x), \(f.origin.y), \(f.width), \(f.height))"
        }.joined(separator: "  |  ")
    }

    private func focusedLabel() -> String {
        let buttons = app.buttons.matching(NSPredicate(format: "hasFocus == true")).allElementsBoundByIndex
        if let first = buttons.first { return first.label }
        let others = app.otherElements.matching(NSPredicate(format: "hasFocus == true")).allElementsBoundByIndex
        if let first = others.first { return "other:\(first.label)" }
        return "nothing"
    }

    /// Where the shelf's heading sits, so a screenshot can be shown to include it.
    private func headingFrame() -> CGRect {
        app.staticTexts[continueLabel].frame
    }

    // MARK: driving the remote

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

    // MARK: the pass's question

    func testTheProgressBarDrawsOnContinueWatchingCardsFocusedAndNot() {
        openFromHome("Recordings")
        XCTAssertTrue(app.staticTexts[shelvesNote].waitForExistence(timeout: 40), "the Recordings shelves did not appear")
        sleep(3)

        XCTAssertTrue(screenText().contains(continueLabel), "no \"\(continueLabel)\" shelf: \(screenText())")
        let cards = continueCards()
        log("cards on entry: \(rects(cards))")
        log("focus on entry: \(focusedLabel())")
        XCTAssertFalse(cards.isEmpty, "the Continue watching shelf has no cards to photograph")

        // 92a — the resting shelf, with focus parked in the rail (see the header).
        remote.press(.left)
        sleep(2)
        let resting = continueCards()
        let heading = headingFrame()
        log("after Left, focus is \(focusedLabel())")
        log("heading frame: \(heading)")
        log("cards at rest: \(rects(resting))")
        shot("92a-continue-watching-shelf-unfocused")
        XCTAssertFalse(focusedLabel().contains(" min in") || focusedLabel().contains(" s in"),
                       "Left did not leave the Continue watching shelf — focus is \(focusedLabel())")
        XCTAssertTrue(heading.maxY > 0 && heading.minY < 1080,
                      "the Continue watching heading scrolled off screen: \(heading)")
        XCTAssertFalse(resting.isEmpty, "the Continue watching cards left the screen: \(screenText())")

        // 92b — one card focused, on the grown 296 pt box.
        remote.press(.right)
        sleep(2)
        let focusedCards = continueCards()
        log("after Right, focus is \(focusedLabel())")
        log("cards with one focused: \(rects(focusedCards))")
        shot("92b-continue-watching-card-focused")
        XCTAssertTrue(focusedLabel().contains(" min in") || focusedLabel().contains(" s in"),
                      "Right did not return to a Continue watching card — focus is \(focusedLabel())")
    }
}
