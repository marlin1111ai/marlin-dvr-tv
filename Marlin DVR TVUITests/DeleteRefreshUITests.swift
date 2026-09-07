//
//  DeleteRefreshUITests.swift
//  Marlin DVR TVUITests
//
//  Pass 31's evidence harness, not a standing test. It runs on the physical Apple TV and drives
//  the real Siri Remote, because the defect is about what the owner sees when he backs out of
//  show detail with the remote in his hand.
//
//  It makes ONE server write — `PUT /api/library/recordings/{id} {"trash": true}` on the
//  recording the shelves are showing — which is the delete the owner authorised for this test.
//  Nothing is restored afterwards (owner, 2026-09-07), and Empty Trash is never sent.
//
//  The assertion is deliberately not "the card disappears". Delete moves a recording to the
//  trash rather than removing it, and Pass 8 Open Question 11 recorded that a show whose last
//  episode is trashed stays in the library index with 0 visible episodes until the trash period
//  expires. So what this proves is the defect itself: the shelves must no longer be showing the
//  library as it was BEFORE the delete, and what they show on the way back must be identical to
//  what a fresh entry into Recordings shows.
//

import XCTest

final class DeleteRefreshUITests: XCTestCase {
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
    /// Only in EpisodeActionsMenu.
    private let menuNote = "Delete sets the trash flag; the server removes the file when its trash period expires. Keep is shared with the other Apple TV."

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
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

    private func log(_ line: String) { print("[pass31 \(stamp())] \(line)") }

    /// Every string the screen is drawing, in screen order. The shelves' whole state — the
    /// header counts, the shelf labels, each card's title and episode count and its "n new"
    /// badge — is static text, so this is the snapshot the before/after comparison uses.
    private func screenText() -> [String] {
        app.staticTexts.allElementsBoundByIndex.map(\.label).filter { !$0.isEmpty }
    }

    private func focusedLabel() -> String {
        let buttons = app.buttons.matching(NSPredicate(format: "hasFocus == true")).allElementsBoundByIndex
        if let first = buttons.first { return first.label }
        let others = app.otherElements.matching(NSPredicate(format: "hasFocus == true")).allElementsBoundByIndex
        if let first = others.first { return "other:\(first.label)" }
        return "nothing"
    }

    // MARK: driving the remote

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

    func testDeletedRecordingLeavesTheShelvesWithoutLeavingTheScreen() {
        openFromHome("Recordings")
        waitForShelves("first entry")

        let before = screenText()
        shot("01-shelves-before-the-delete")
        log("shelves BEFORE: \(before)")
        XCTAssertTrue(before.contains { $0.hasSuffix(" episode") || $0.hasSuffix(" episodes") },
                      "no card on the shelves to delete from: \(before)")

        // Into show detail on the first card, which has focus by defaultFocus.
        remote.press(.select)
        XCTAssertTrue(app.staticTexts[detailNote].waitForExistence(timeout: 40), "show detail did not open")
        sleep(3)
        let detailBefore = screenText()
        shot("02-show-detail-before-the-delete")
        log("detail BEFORE: \(detailBefore)")

        // Focus opens on the left column (Resume / Play newest); Right crosses into the episodes.
        remote.press(.right)
        sleep(2)
        log("after Right, focus is \(focusedLabel())")

        // The hold that opens the episode menu.
        remote.press(.select, forDuration: 1.2)
        if !app.staticTexts[menuNote].waitForExistence(timeout: 8) {
            shot("xx-menu-did-not-open")
            return XCTFail("click-and-hold did not open the episode menu; on screen: \(screenText())")
        }
        sleep(1)

        // The menu opens on Keep; Down reaches Delete.
        remote.press(.down)
        sleep(1)
        shot("03-episode-menu-on-delete")
        log("menu focus is \(focusedLabel())")
        XCTAssertTrue(focusedLabel().contains("Delete") || focusedLabel().contains("trash"),
                      "Delete is not the focused row — it is \(focusedLabel())")

        // THE WRITE.
        log("sending Delete")
        remote.press(.select)
        XCTAssertTrue(app.staticTexts[detailNote].waitForExistence(timeout: 20), "the episode menu never closed")
        sleep(3)
        let detailAfter = screenText()
        shot("04-show-detail-after-the-delete")
        log("detail AFTER: \(detailAfter)")

        // Back out to the shelves — the step the owner reported as showing stale data.
        log("pressing Menu back to the shelves")
        remote.press(.menu)
        XCTAssertTrue(app.staticTexts[shelvesNote].waitForExistence(timeout: 20), "Menu did not return to the shelves")
        sleep(2)
        let afterBackOut = screenText()
        shot("05-shelves-after-backing-out")
        log("shelves AFTER BACKING OUT: \(afterBackOut)")

        // The defect, stated exactly: the shelves must not still be the library from before.
        XCTAssertNotEqual(afterBackOut, before,
                          "the shelves are unchanged after the delete — this is the Pass 31 defect: \(afterBackOut)")

        // Leave Recordings altogether and come back: the path that always worked. The shelves
        // reached by backing out must agree with it, or the refresh showed something else.
        log("leaving Recordings and re-entering")
        remote.press(.menu)
        XCTAssertTrue(app.staticTexts["Marlin"].waitForExistence(timeout: 30), "Menu did not return to Home")
        sleep(3)
        openFromHome("Recordings")
        waitForShelves("re-entry")
        let reEntered = screenText()
        shot("06-shelves-on-a-fresh-entry")
        log("shelves ON RE-ENTRY: \(reEntered)")

        XCTAssertEqual(afterBackOut.sorted(), reEntered.sorted(),
                       "backing out and re-entering disagree — backing out gave \(afterBackOut), re-entry gave \(reEntered)")
    }
}
