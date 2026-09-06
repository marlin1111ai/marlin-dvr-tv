//
//  ManageDVRUITests.swift
//  Marlin DVR TVUITests
//
//  Pass 10's evidence harness. It drives the Simulator through the new management area with
//  `XCUIRemote`, asserts on the text the app actually draws, and attaches a screenshot at
//  each step. It exists because it does not need the Mac's keyboard focus — the Pass 9 way of
//  driving the Simulator with synthetic key presses is unreliable while someone else is using
//  the machine — and because an assertion on the server's own strings is better evidence than
//  a picture alone.
//
//  It performs exactly one write: the Cancel on the Record Now booking created for the test
//  (step 4b). It never presses Restore or Empty Trash — the trash holds a real recording of
//  the owner's (step 4c).
//

import XCTest

final class ManageDVRUITests: XCTestCase {
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

    /// Home → Recordings → the Manage DVR row.
    private func openManageDVR() {
        XCTAssertTrue(app.staticTexts["Marlin"].waitForExistence(timeout: 30), "Home did not appear")
        remote.press(.down)          // row 2 of the tile grid
        sleep(1)
        remote.press(.select)        // Recordings
        XCTAssertTrue(app.staticTexts["Manage DVR"].waitForExistence(timeout: 30), "Recordings did not appear")
        sleep(3)
        remote.press(.up)            // focus lands on a poster card; the Manage row is above it
        sleep(2)
        remote.press(.select)
        XCTAssertTrue(app.staticTexts["Storage"].waitForExistence(timeout: 20), "Manage DVR did not open")
        sleep(3)
    }

    /// After the pass's cleanup: the hub's three counts are the server's, and the scheduled
    /// row reads "N scheduled" (it said "2 scheduleds" before this pass fixed it).
    func testManageHubCountsAfterCleanup() {
        openManageDVR()
        shot("40-hub-after-cleanup")
        let labels = app.staticTexts.allElementsBoundByIndex.map(\.label)
        XCTAssertTrue(labels.contains { $0.hasSuffix(" scheduled") && !$0.contains("scheduleds") },
                      "the scheduled count reads wrong; saw: \(labels)")
        XCTAssertTrue(labels.contains("1 pass") || labels.contains { $0.hasSuffix(" passes") },
                      "no pass count; saw: \(labels)")
        XCTAssertTrue(labels.contains { $0.hasSuffix("in trash") || $0 == "empty" },
                      "no trash count; saw: \(labels)")
    }

    func testManageDVR() {
        openManageDVR()

        // ---- step 2a and 3: the storage line and the three counts
        shot("10-manage-hub")
        XCTAssertTrue(app.staticTexts["Scheduled Recordings"].exists)
        XCTAssertTrue(app.staticTexts["Your Passes"].exists)
        XCTAssertTrue(app.staticTexts["Trash"].exists)
        // The storage line is the server's own formatted text.
        let storage = app.staticTexts.allElementsBoundByIndex.map(\.label)
        XCTAssertTrue(storage.contains { $0.contains("used ·") && $0.contains("free of") },
                      "no storage summary on screen; saw: \(storage)")
        XCTAssertTrue(storage.contains { $0.contains("available on the recordings volume") },
                      "no disk label on screen; saw: \(storage)")

        // ---- step 2b: scheduled recordings
        remote.press(.select)        // Scheduled Recordings
        XCTAssertTrue(app.staticTexts["Infomercials @ 4PM"].waitForExistence(timeout: 20),
                      "the test booking is not listed")
        sleep(2)
        shot("11-scheduled-list")
        XCTAssertTrue(app.staticTexts["Hazardous History With Henry Winkler"].exists,
                      "the owner's pass airing is not listed")

        // The first row is the earliest airing — the test booking at 4:00 PM.
        remote.press(.select)
        XCTAssertTrue(app.staticTexts["Cancel recording"].waitForExistence(timeout: 10),
                      "the airing detail did not open")
        sleep(2)
        shot("12-scheduled-detail")
        XCTAssertTrue(app.staticTexts["One-off Record Now"].exists,
                      "this should be the manual booking")
        XCTAssertFalse(app.staticTexts["Manage pass"].exists,
                       "Manage pass must be hidden for a Record Now job")

        // Cancel: arms first, then confirms.
        remote.press(.select)
        XCTAssertTrue(app.staticTexts["Cancel recording — click again to confirm"].waitForExistence(timeout: 10),
                      "Cancel did not arm")
        sleep(1)
        shot("13-cancel-armed")
        remote.press(.select)
        XCTAssertTrue(app.staticTexts["Booking removed. That airing is free to record again."].waitForExistence(timeout: 20),
                      "the cancel did not report a removed booking")
        sleep(2)
        shot("14-cancelled")
        XCTAssertFalse(app.staticTexts["Infomercials @ 4PM"].exists,
                       "the cancelled booking is still listed")

        // ---- step 2c: passes
        remote.press(.menu)          // back to the hub
        XCTAssertTrue(app.staticTexts["Storage"].waitForExistence(timeout: 10))
        sleep(2)
        remote.press(.down)          // Your Passes
        sleep(1)
        remote.press(.select)
        XCTAssertTrue(app.staticTexts["Fugitives Caught on Tape"].waitForExistence(timeout: 20),
                      "the test pass is not listed")
        sleep(2)
        shot("20-passes-list")
        XCTAssertTrue(app.staticTexts["Hazardous History With Henry Winkler"].exists,
                      "the owner's pass is not listed")

        // Open the second row — the test pass — and check the editor, including Pause.
        remote.press(.down)
        sleep(1)
        remote.press(.select)
        XCTAssertTrue(app.staticTexts["SERIES PASS"].waitForExistence(timeout: 10),
                      "the pass editor did not open")
        sleep(2)
        shot("21-pass-editor")
        XCTAssertTrue(app.staticTexts["Pause"].exists, "Pause/Resume is missing from the editor")
        XCTAssertTrue(app.staticTexts["Delete this pass"].exists)
        remote.press(.menu)          // out of the editor, writing nothing
        sleep(2)

        // ---- step 2d: trash, read only
        remote.press(.menu)          // back to the hub
        XCTAssertTrue(app.staticTexts["Storage"].waitForExistence(timeout: 10))
        sleep(2)
        remote.press(.down)
        sleep(1)
        remote.press(.down)          // Trash
        sleep(1)
        remote.press(.select)
        XCTAssertTrue(app.staticTexts["The Aging Brain"].waitForExistence(timeout: 25),
                      "the owner's trashed recording is not listed")
        sleep(2)
        shot("30-trash-list")
        // A single-Text button is exposed as a button, not a static text.
        XCTAssertTrue(app.buttons["Empty Trash"].exists || app.staticTexts["Empty Trash"].exists,
                      "Empty Trash is missing")
        XCTAssertTrue(app.staticTexts["Restore"].exists || app.buttons["Restore"].exists,
                      "the row's Restore action is missing")
        // Nothing is pressed here: the trash holds a recording of the owner's.

        remote.press(.menu)
        sleep(1)
    }
}
