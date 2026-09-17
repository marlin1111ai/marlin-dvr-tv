//
//  ShowDetailSeriesPassUITests.swift
//  Marlin DVR TVUITests
//
//  Pass 103's evidence harness, not a standing test. It needs the physical Apple TV
//  ("Home Theater") and the real Siri Remote, and it needs the owner's own library: a show the
//  server holds **no** pass for and a show it holds one for. Both were read before the run —
//  `Hitler's DNA` (`pass: ""`) and `The Food That Built America` (`pass: "The Food That Built
//  America"`) — from `GET /api/library/shows/{id}`, the read the screen itself makes.
//
//  **It makes no server write of any kind, and that is the point of how it is written.** The only
//  non-GET traffic is the app's own launch ping (`ClientSession.swift:8-9`). In particular:
//   · **"Record the series" is never pressed.** It is `POST /api/passes`, which creates a pass and
//     queues recordings on the owner's DVR. The harness photographs the button and walks away;
//     the press is his to make (Pass 102 §5/A1 — "A pass created for evidence should be one he
//     wants").
//   · **Nothing inside the editor is pressed.** Every `MenuRow` in `EditSeriesPassScreen` writes
//     `PUT /api/passes/{id}` on a single click, and the editor opens with focus on the first of
//     them ("Record", `EditSeriesPassScreen.swift:135-139`). The harness opens the editor, reads
//     it, photographs it and leaves by **Menu** — never Select. So "leaving it saves and deletes
//     nothing" is established by never having sent anything, which is stronger than checking
//     afterwards that nothing changed.
//
//  **`launch()`, not `activate()`.** Pass 92 proved that `activate()` can photograph the previous
//  build: it resumes the process already running on the television while the new build sits
//  installed and unlaunched, and every assertion can pass against the old screen. The proof is the
//  server's log — the app pings on every launch and there was no ping at all in those runs. This
//  harness attaches no console, so it uses `launch()`, and the run is only believed once the ping
//  is found in `GET /api/logs` at the run's timestamp.
//
//    103a  show detail for a show with no pass — the button reads "Record the series"
//    103b  show detail for a show with a pass — it reads "Edit series pass", with the gold
//          "◆ Series pass · n recordings scheduled · new episodes" line under the buttons
//    103c  the editor, opened from that button — the same EditSeriesPassScreen the Guide opens
//    103d  back on show detail after Menu, the button still "Edit series pass" and the pass intact
//

import XCTest

final class ShowDetailSeriesPassUITests: XCTestCase {
    private var app: XCUIApplication!
    private let remote = XCUIRemote.shared

    /// Home tile order, frame 2a (Destination.homeTiles).
    private static let homeTiles = ["Guide", "On Now", "On Later",
                                    "Recordings", "Cameras", "Favorites",
                                    "Weather", "Radio", "Settings"]

    private let shelvesNote = "Watched and keep flags are shared with the other Apple TV"
    private let detailNote = "Click and hold an episode for Keep and Delete"
    /// Only the editor draws this, so it is how the harness knows the editor is up.
    private let editorNote = "A click steps each setting to its next value and saves it on the server. Nothing already recorded is touched."

    /// The two shows, and what the server says about each. Read before the run, not guessed.
    private let showWithoutPass = "Hitler's DNA"
    private let showWithPass = "The Food That Built America"

    private let recordLabel = "Record the series"
    private let editLabel = "Edit series pass"

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

    private func log(_ line: String) { print("[pass103 \(stamp())] \(line)") }

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

    /// The gold footer line, whose text carries the server's own `countLabel` and `recordMode`.
    private func passFooterLine() -> String? {
        screenText().first { $0.hasPrefix("◆ Series pass · ") }
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

    private func waitForShelves(_ tag: String) {
        XCTAssertTrue(app.staticTexts[shelvesNote].waitForExistence(timeout: 40),
                      "the Recordings shelves did not appear (\(tag))")
        sleep(3)
    }

    /// Walks the shelves to the card for one show and opens it. The shelves are Continue watching
    /// (this Apple TV's own), then the server's Recently Updated and Recently Added, each its own
    /// horizontal row: Right walks a row and Down crosses to the next.
    ///
    /// **It walks each row and comes back to the left edge before going down, and that is
    /// measured, not tidiness.** The first version went Right to the end of a row before pressing
    /// Down and hung there: Continue watching holds 5 cards on this Apple TV and the two server
    /// shelves hold 4, each row keeps its own horizontal scroll offset, so from the 5th card there
    /// is **no focusable card below** and tvOS refuses the Down. The run of 20:57 logged it exactly
    /// — `step 3` … `step 17` all report the same focus, "History's Greatest Mysteries, S7 E20 ·
    /// 1 min in", the last Continue card, through four Downs and ten Rights. So the walk counts its
    /// own Rights and undoes them with the same number of Lefts before each Down, which keeps every
    /// Down in the left-hand column where all three rows have a card. It never presses Left from
    /// the first card, because that crosses into the rail (Pass 25's `railRestore`).
    ///
    /// A press that does not move focus is reported as such, so a stuck walk says where it stuck
    /// instead of spending its whole budget.
    private func openShow(_ title: String) {
        log("looking for a card for \"\(title)\"; focus is \(focusedLabel())")
        for row in 0..<3 {
            var rights = 0
            while true {
                let here = focusedLabel()
                if here.contains(title) {
                    log("found it on row \(row) at \(rights) right(s): \(here)")
                    remote.press(.select)
                    XCTAssertTrue(app.staticTexts[detailNote].waitForExistence(timeout: 40),
                                  "show detail did not open for \"\(title)\"")
                    sleep(3)
                    return
                }
                if rights == 6 { break }
                remote.press(.right)
                usleep(800_000)
                let next = focusedLabel()
                log("row \(row), right \(rights + 1): focus is \(next)")
                if next == here { break }   // the right-hand end of this row
                rights += 1
            }
            // Back to the left-hand column, one Left per Right, then down to the next row.
            for _ in 0..<rights { remote.press(.left); usleep(600_000) }
            log("row \(row): back at \(focusedLabel()) after \(rights) left(s)")
            if row == 2 { break }
            let before = focusedLabel()
            remote.press(.down)
            usleep(900_000)
            log("row \(row) → \(row + 1): focus is \(focusedLabel())")
            if focusedLabel() == before {
                XCTFail("Down did not leave row \(row) from the left-hand column — focus is \(before)")
                return
            }
        }
        XCTFail("no card for \"\(title)\" was reachable on the shelves: \(buttonLabels())")
    }

    /// Walks frame 5d's button block to the series control. The block is [Resume …] above
    /// [Play newest][the series button], so Down reaches the row of two and Right crosses it.
    @discardableResult
    private func focusSeriesButton(_ label: String) -> Bool {
        for _ in 0..<4 {
            let now = focusedLabel()
            if now == label { return true }
            if now == "Play newest" { remote.press(.right) } else { remote.press(.down) }
            usleep(800_000)
            log("walking to \"\(label)\": focus is \(focusedLabel())")
        }
        return focusedLabel() == label
    }

    // MARK: the pass's question

    func testTheSeriesButtonFollowsTheShowsPassAndOpensTheEditor() {
        openFromHome("Recordings")
        waitForShelves("on entry")
        log("shelf cards: \(buttonLabels())")

        // 1. A show the server holds no pass for: "Record the series", and it is NOT pressed.
        openShow(showWithoutPass)
        var labels = buttonLabels()
        log("\"\(showWithoutPass)\" buttons: \(labels)")
        log("\"\(showWithoutPass)\" footer: \(passFooterLine() ?? "none")")
        shot("103a-no-pass-record-the-series")
        XCTAssertTrue(labels.contains(recordLabel),
                      "\"\(showWithoutPass)\" has no pass, so the button should read \"\(recordLabel)\": \(labels)")
        XCTAssertFalse(labels.contains(editLabel),
                       "\"\(showWithoutPass)\" has no pass, so \"\(editLabel)\" should not be drawn: \(labels)")
        XCTAssertFalse(labels.contains("Series pass"),
                       "the Pass 8 inert label is still on screen: \(labels)")
        XCTAssertNil(passFooterLine(),
                     "a show with no pass should carry no ◆ Series pass line: \(screenText())")

        // Back to the shelves. Nothing was pressed on that screen.
        remote.press(.menu)
        waitForShelves("after \(showWithoutPass)")

        // 2. A show the server holds a pass for: "Edit series pass" and the gold footer.
        openShow(showWithPass)
        labels = buttonLabels()
        let footer = passFooterLine()
        log("\"\(showWithPass)\" buttons: \(labels)")
        log("\"\(showWithPass)\" footer: \(footer ?? "none")")
        shot("103b-has-pass-edit-series-pass")
        XCTAssertTrue(labels.contains(editLabel),
                      "\"\(showWithPass)\" has a pass, so the button should read \"\(editLabel)\": \(labels)")
        XCTAssertFalse(labels.contains(recordLabel),
                       "\"\(showWithPass)\" has a pass, so \"\(recordLabel)\" should not be drawn: \(labels)")
        XCTAssertNotNil(footer,
                        "the pass footer the sheet draws is missing: \(screenText())")

        // 3. Pressing it opens the editor — the same screen the Guide's "Edit series pass" opens.
        XCTAssertTrue(focusSeriesButton(editLabel),
                      "could not put focus on \"\(editLabel)\" — focus is \(focusedLabel())")
        remote.press(.select)
        XCTAssertTrue(app.staticTexts[editorNote].waitForExistence(timeout: 30),
                      "the editor did not open: \(screenText())")
        sleep(2)
        let editorText = screenText()
        log("editor text: \(editorText)")
        log("editor focus: \(focusedLabel())")
        shot("103c-editor-open")
        XCTAssertTrue(editorText.contains("SERIES PASS"),
                      "the editor's own heading is missing: \(editorText)")
        XCTAssertTrue(editorText.contains(showWithPass),
                      "the editor is not showing this show's pass: \(editorText)")
        for row in ["Record", "Start early", "Stop late", "Keep", "Delete this pass"] {
            XCTAssertTrue(editorText.contains(row), "the editor has no \"\(row)\" row: \(editorText)")
        }

        // 4. Menu leaves it. Nothing was pressed inside, so nothing was saved and nothing deleted;
        //    the button and the footer must read exactly what they did before it opened.
        remote.press(.menu)
        XCTAssertTrue(app.staticTexts[detailNote].waitForExistence(timeout: 30),
                      "Menu did not return to show detail: \(screenText())")
        sleep(2)
        let after = buttonLabels()
        let footerAfter = passFooterLine()
        log("after Menu, buttons: \(after)")
        log("after Menu, footer: \(footerAfter ?? "none")")
        log("after Menu, focus: \(focusedLabel())")
        shot("103d-back-on-show-detail")
        XCTAssertFalse(screenText().contains(editorNote), "the editor is still up: \(screenText())")
        XCTAssertTrue(after.contains(editLabel),
                      "the pass is gone or the button changed after simply opening and closing the editor: \(after)")
        XCTAssertEqual(footerAfter, footer,
                       "the pass footer changed although nothing in the editor was pressed")
        XCTAssertFalse(screenText().contains("Series pass deleted."),
                       "a delete message appeared and nothing was pressed to cause one")
    }
}
