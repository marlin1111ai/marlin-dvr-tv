//
//  TrashRestoreUITests.swift
//  Marlin DVR TVUITests
//
//  Pass 33's evidence harness, not a standing test. It runs on the physical Apple TV
//  ("Home Theater") and drives the real Siri Remote.
//
//  It makes exactly TWO server writes, both `PUT /api/library/recordings/{id} {"trash": false}`
//  — the two Restores the owner asked to be proven (steps 3 and 4).
//
//  The subjects are the two recordings Pass 32 left behind and disclosed in its §C — a 7.66 MB
//  Midday Maryland fragment its test created, and a 275.92 MB episode of The View its aborted
//  run booked by accident. The owner wants neither and authorised trashing and restoring these
//  two ids and no others (2026-09-07). They were put in the trash from this Mac before the run;
//  this harness only reads the list and restores them.
//
//  The owner's own four trashed recordings, which this pass was written for, were permanently
//  deleted at 20:51:50 by an Empty Trash from his web-UI session (report §0). They were the
//  pre-1.6.0 form — file still in its show folder — and no such entry can be made any more, so
//  what this proves is the 1.6.0 form only: a file the server has moved to DVR/Trash/.
//
//  Empty Trash is never pressed. Every Select on this screen is guarded by an assertion that
//  focus is on the row being restored, so a stray press cannot reach that button.
//
//  PERFORMANCE, learned in Pass 32: never call `app.staticTexts.allElementsBoundByIndex` on
//  this device — one such call took five minutes on the Guide. Every read below is an exact
//  label or a scoped predicate, and every wait is bounded.
//

import XCTest

final class TrashRestoreUITests: XCTestCase {
    private var app: XCUIApplication!
    private let remote = XCUIRemote.shared

    /// The rail, top to bottom (RailManageUITests, Pass 10B).
    private static let rail = ["Home", "Favorites", "On Now", "Guide", "On Later",
                               "Recordings", "Cameras", "Weather", "Radio", "Manage DVR"]

    /// The trash as `GET /api/library/trash` listed it at 21:09 on 2026-09-07, newest first.
    private static let trashed = ["The View",              // 275.92 MB, has a season and episode
                                  "Midday Maryland"]       // 7.66 MB, no title, no season/episode

    /// Only on the Recordings shelves.
    private let shelvesNote = "Watched and keep flags are shared with the other Apple TV"

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

    private func log(_ line: String) { print("[pass33 \(stamp())] \(line)") }

    private func exists(_ label: String) -> Bool { app.staticTexts[label].firstMatch.exists }

    /// XCUITest refuses a string identifier over 128 characters, and two of this screen's lines
    /// are longer than that, so anything long is matched on a prefix instead.
    private func staticText(startingWith prefix: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    /// The first static text matching a predicate, or nil. Scoped and short-circuited.
    private func text(matching format: String, _ args: CVarArg...) -> String? {
        let element = app.staticTexts.matching(NSPredicate(format: format,
                                                           arguments: getVaList(args))).firstMatch
        return element.exists ? element.label : nil
    }

    private func focusedLabel() -> String {
        let button = app.buttons.matching(NSPredicate(format: "hasFocus == true")).firstMatch
        return button.exists ? button.label : "nothing"
    }

    // MARK: driving the remote

    /// Home is the design's tile launcher and carries no rail (variant 2a), so the rail can only
    /// be reached from a screen. Open Recordings — the second tile, one Down from the Guide the
    /// grid starts on — and step left into the rail from there.
    private func enterRailFromHome() {
        XCTAssertTrue(app.staticTexts["Marlin"].waitForExistence(timeout: 60), "Home did not appear")
        sleep(3)
        remote.press(.down)
        usleep(900_000)
        XCTAssertTrue(focusedLabel().hasPrefix("Recordings"), "Home focus is \(focusedLabel()), not Recordings")
        remote.press(.select)
        XCTAssertTrue(app.staticTexts[shelvesNote].waitForExistence(timeout: 40), "Recordings did not open")
        sleep(3)
        remote.press(.left)
        sleep(2)
    }

    /// From inside the rail: walk to the top, then down to `entry`, and select it.
    private func openFromRail(_ entry: String) {
        var up = 0
        while !app.buttons["Home"].hasFocus && up < 14 {
            remote.press(.up)
            usleep(800_000)
            up += 1
        }
        XCTAssertTrue(app.buttons["Home"].hasFocus, "could not walk up the rail — focus is \(focusedLabel())")
        guard let target = Self.rail.firstIndex(of: entry) else { return XCTFail("no such rail entry: \(entry)") }
        for _ in 0 ..< target {
            remote.press(.down)
            usleep(800_000)
        }
        XCTAssertTrue(app.buttons[entry].hasFocus, "walking the rail stopped at \(focusedLabel())")
        remote.press(.select)
    }

    /// Manage DVR hub → the Trash list.
    private func openTrash() {
        XCTAssertTrue(app.staticTexts["Storage"].waitForExistence(timeout: 40), "Manage DVR did not open")
        sleep(3)
        shot("10-manage-hub")
        // Focus lands on Scheduled Recordings; Trash is two rows below it.
        remote.press(.down); usleep(800_000)
        remote.press(.down); usleep(800_000)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "hasFocus == true AND label BEGINSWITH 'Trash'")).firstMatch.exists,
                      "the Trash row did not take focus — focus is \(focusedLabel())")
        remote.press(.select)
        XCTAssertTrue(staticText(startingWith: "A restored recording goes straight back into its show.").waitForExistence(timeout: 30),
                      "the Trash list did not open")
        sleep(3)
    }

    /// Presses Restore on whatever row has focus and waits for the confirmation line.
    private func restoreFocusedRow(_ show: String, shotName: String) {
        log("restoring \(show); focus is \(focusedLabel())")
        XCTAssertTrue(focusedLabel().contains(show),
                      "focus is not on \(show) — it is \(focusedLabel())")
        remote.press(.select)
        let confirmation = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@", "Restored \(show)")).firstMatch
        XCTAssertTrue(confirmation.waitForExistence(timeout: 60),
                      "no confirmation line for \(show); screen says \(text(matching: "label CONTAINS 'trash'") ?? "-")")
        log("restored: \(confirmation.label)")
        sleep(3)
        shot(shotName)
        XCTAssertFalse(app.staticTexts[show].exists,
                       "\(show) is still listed in the trash after Restore")
    }

    // MARK: the pass

    func testTrashListsEveryTrashedRecordingAndRestoreWorks() {
        // ---- step 2: the list, read from GET /api/library/trash
        enterRailFromHome()
        openFromRail("Manage DVR")
        openTrash()
        shot("11-trash-list")

        for show in Self.trashed {
            XCTAssertTrue(exists(show), "\(show) is not in the Trash list")
        }
        log("both trashed recordings are listed")

        // The header carries the count and what the trash is holding on disk — neither of which
        // the show-by-show list could say.
        let subtitle = text(matching: "label BEGINSWITH '2 recordings · '")
        XCTAssertNotNil(subtitle, "the Trash header does not show 2 recordings and a size")
        log("header: \(subtitle ?? "-")")

        // The two rows exercise both halves of the row's own text. The View has a season and an
        // episode; Midday Maryland has neither and no episode title, so its middle line is
        // absent by design and must not render as a stray "S0 E0".
        XCTAssertNotNil(text(matching: "label BEGINSWITH 'S29 E205 · '"),
                        "The View's row is missing its season/episode/title line")
        XCTAssertNil(text(matching: "label CONTAINS 'S0 E0'"),
                     "a row with no season or episode drew one anyway")
        XCTAssertNotNil(text(matching: "label BEGINSWITH 'Aired ' AND label CONTAINS 'Trashed today at '"),
                        "no row is showing both its aired date and when it was trashed")

        // ---- step 3: restore the first, and step 4's repeat: restore the second
        restoreFocusedRow(Self.trashed[0], shotName: "12-after-restoring-the-view")
        XCTAssertTrue(exists(Self.trashed[1]), "\(Self.trashed[1]) went missing from the list")
        XCTAssertNotNil(text(matching: "label BEGINSWITH '1 recording · '"),
                        "the Trash header did not fall to 1 recording")
        sleep(2)
        restoreFocusedRow(Self.trashed[1], shotName: "13-after-restoring-midday-maryland")

        // ---- the empty state, on the device, from an empty {"count":0,"recordings":[]}
        XCTAssertTrue(staticText(startingWith: "The trash is empty.").waitForExistence(timeout: 20),
                      "the empty trash does not say it is empty")
        XCTAssertNil(text(matching: "label CONTAINS 'could not be read'"),
                     "an empty trash was reported as a failed read")
        sleep(2)
        shot("14-trash-empty")

        // ---- the hub agrees
        remote.press(.menu)
        XCTAssertTrue(app.staticTexts["Storage"].waitForExistence(timeout: 20), "did not get back to the hub")
        sleep(3)
        shot("15-hub-after-the-restores")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Trash, empty'")).firstMatch.exists,
                      "the hub's Trash row does not read empty")

        // ---- step 3: both are back in the library and on the Recordings shelves
        remote.press(.left)
        sleep(2)
        openFromRail("Recordings")
        XCTAssertTrue(app.staticTexts[shelvesNote].waitForExistence(timeout: 40), "the shelves did not appear")
        sleep(4)
        shot("16-recordings-shelves-after-the-restores")

        for show in Self.trashed {
            XCTAssertTrue(exists(show), "\(show) is not on the Recordings shelves after being restored")
        }
        log("both restored shows are on the shelves")
    }
}
