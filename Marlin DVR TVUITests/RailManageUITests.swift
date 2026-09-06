//
//  RailManageUITests.swift
//  Marlin DVR TVUITests
//
//  Pass 10B step 4. Manage DVR moved out of the Recordings screen and into the rail, so this
//  checks the three things that move asks for: the row is gone from Recordings, the rail's
//  bottom entry opens the same screen, and focus still walks the rail from top to bottom.
//
//  It is driven with XCUIRemote rather than synthetic key presses because the Mac's keyboard
//  focus was being taken by other applications during Pass 10, which made that unreliable.
//  It makes no server write.
//

import XCTest

final class RailManageUITests: XCTestCase {
    private var app: XCUIApplication!
    private let remote = XCUIRemote.shared

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testManageDVRLivesInTheRailAndNotOnRecordings() {
        XCTAssertTrue(app.staticTexts["Marlin"].waitForExistence(timeout: 30), "Home did not appear")

        // ---- step 3: the Home grid is the design's nine tiles, with no Manage DVR among them
        shot("10-home-unchanged")
        XCTAssertFalse(app.staticTexts["Manage DVR"].exists,
                       "Manage DVR must not be a Home tile")

        // ---- step 1: Recordings no longer carries the row
        remote.press(.down)
        sleep(1)
        remote.press(.select)
        XCTAssertTrue(app.staticTexts["Recordings"].waitForExistence(timeout: 30), "Recordings did not open")
        sleep(3)
        shot("11-recordings-without-the-row")
        XCTAssertFalse(app.staticTexts["Manage DVR"].exists,
                       "the Manage DVR row is still on Recordings")
        XCTAssertFalse(app.staticTexts["Scheduled recordings, series passes, trash and storage"].exists,
                       "the old row's subtitle is still on Recordings")

        // ---- step 2: it is the bottom entry of the rail
        remote.press(.left)          // into the rail; it expands and shows its labels
        sleep(2)
        shot("12-rail-expanded")
        XCTAssertTrue(app.buttons["Manage DVR"].waitForExistence(timeout: 10),
                      "Manage DVR is not in the rail")

        // Entering the rail lands on the entry nearest the content, not on the current
        // screen's — pre-existing behaviour — so walk to the top first and work from there.
        var guardRail = 0
        while !app.buttons["Home"].hasFocus && guardRail < 14 {
            remote.press(.up)
            sleep(1)
            guardRail += 1
        }
        XCTAssertTrue(app.buttons["Home"].hasFocus, "could not walk up the rail to Home")

        // Down through every entry in order; the last one is Manage DVR.
        for label in ["Favorites", "On Now", "Guide", "On Later", "Recordings", "Cameras", "Weather", "Radio", "Manage DVR"] {
            remote.press(.down)
            sleep(1)
            XCTAssertTrue(app.buttons[label].hasFocus, "walking down the rail stopped at \(label)")
        }
        remote.press(.select)
        XCTAssertTrue(app.staticTexts["Storage"].waitForExistence(timeout: 25),
                      "the rail entry did not open Manage DVR")
        sleep(3)
        shot("13-manage-from-the-rail")
        XCTAssertTrue(app.staticTexts["Scheduled Recordings"].exists)
        XCTAssertTrue(app.staticTexts["Your Passes"].exists)
        XCTAssertTrue(app.staticTexts["Trash"].exists)

        // ---- step 4: and back up again from the bottom, from inside Manage DVR
        remote.press(.left)
        sleep(2)
        var back = 0
        while !app.buttons["Home"].hasFocus && back < 14 {
            remote.press(.up)
            sleep(1)
            back += 1
        }
        XCTAssertTrue(app.buttons["Home"].hasFocus, "could not walk back up the rail from Manage DVR")
        shot("14-rail-top")
    }
}
