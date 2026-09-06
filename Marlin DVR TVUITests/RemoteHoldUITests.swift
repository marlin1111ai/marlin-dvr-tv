//
//  RemoteHoldUITests.swift
//  Marlin DVR TVUITests
//
//  The evidence harness for Pass 9 step 1: does click-and-hold work on a real Siri Remote?
//
//  Pass 8 shipped a hold built on a SwiftUI ButtonStyle's `isPressed`; it worked on the
//  Simulator and did nothing on the owner's remote, and there was no way to tell the two
//  apart from this Mac. `XCUIRemote.press(.select, forDuration:)` closes that gap: run on a
//  paired Apple TV it drives the device's own press pipeline, so a pass here is a statement
//  about the hardware, not about the Simulator.
//
//  The test holds Select on a **channel cell** in the Guide's left column. A plain click
//  there does nothing (Pass 9 step 7), so the channel menu appearing can only mean the hold
//  was recognised — and nothing is played and nothing is written to the server either way.
//  It matches on text the app already draws, so the app itself needs no test affordance.
//

import XCTest

final class RemoteHoldUITests: XCTestCase {
    /// Only in the channel menu (ChannelActionsMenu).
    private let channelMenuNote = "Favorites are the server's own list: the web UI and the other Apple TV see this too."
    /// Only in the Guide's legend.
    private let guideLegend = "Recording or set to record"

    override func setUp() {
        continueAfterFailure = false
    }

    func testClickAndHoldOnAChannelCellOpensTheChannelMenu() {
        let app = XCUIApplication()
        app.launch()
        let remote = XCUIRemote.shared

        // Home: the Guide tile has focus on launch.
        XCTAssertTrue(app.staticTexts["Marlin"].waitForExistence(timeout: 30), "Home did not appear")
        remote.press(.select)

        // The Guide focuses its first programme cell once the grid has loaded.
        XCTAssertTrue(app.staticTexts[guideLegend].waitForExistence(timeout: 40), "the Guide did not load")
        sleep(4)

        // Left from the first programme cell is that row's channel cell.
        remote.press(.left)
        sleep(2)

        // The hold under test.
        remote.press(.select, forDuration: 1.2)

        let opened = app.staticTexts[channelMenuNote].waitForExistence(timeout: 6)
        if !opened {
            let texts = app.staticTexts.allElementsBoundByIndex.prefix(25).map(\.label)
            XCTFail("click-and-hold did not open the channel menu on this device; on screen: \(texts)")
        }

        // Leave the app as it was found: no write, menu closed.
        remote.press(.menu)
        sleep(1)
    }

    /// The control for the test above: a plain click on the same channel cell must leave the
    /// menu shut. Without this, a pass could mean "any press opens the menu" rather than
    /// "the hold was recognised".
    func testPlainClickOnAChannelCellDoesNotOpenTheChannelMenu() {
        let app = XCUIApplication()
        app.launch()
        let remote = XCUIRemote.shared

        XCTAssertTrue(app.staticTexts["Marlin"].waitForExistence(timeout: 30), "Home did not appear")
        remote.press(.select)
        XCTAssertTrue(app.staticTexts[guideLegend].waitForExistence(timeout: 40), "the Guide did not load")
        sleep(4)
        remote.press(.left)
        sleep(2)

        remote.press(.select)
        sleep(3)
        XCTAssertFalse(app.staticTexts[channelMenuNote].exists,
                       "a plain click opened the channel menu, so the hold test proves nothing")
    }

    /// Which of the two triggers does the hardware actually honour? With the Pass 8
    /// press-state timer switched off by `MARLIN_DISABLE_PRESS_STATE_HOLD`, a pass here means
    /// the window's `UILongPressGestureRecognizer` recognised the hold on its own.
    func testWindowRecognizerAloneRecognisesTheHold() {
        let app = XCUIApplication()
        app.launchEnvironment["MARLIN_DISABLE_PRESS_STATE_HOLD"] = "1"
        app.launch()
        let remote = XCUIRemote.shared

        XCTAssertTrue(app.staticTexts["Marlin"].waitForExistence(timeout: 30), "Home did not appear")
        remote.press(.select)
        XCTAssertTrue(app.staticTexts[guideLegend].waitForExistence(timeout: 40), "the Guide did not load")
        sleep(4)
        remote.press(.left)
        sleep(2)

        remote.press(.select, forDuration: 1.2)
        XCTAssertTrue(app.staticTexts[channelMenuNote].waitForExistence(timeout: 6),
                      "with the press-state trigger off, the window recognizer did not fire")
        remote.press(.menu)
        sleep(1)
    }

    /// The owner's own case: hold on the programme that is on right now. A plain click there
    /// plays the channel, so the airing sheet can only come from a recognised hold.
    func testClickAndHoldOnTheCurrentProgrammeOpensTheAiringSheet() {
        let app = XCUIApplication()
        app.launch()
        let remote = XCUIRemote.shared

        XCTAssertTrue(app.staticTexts["Marlin"].waitForExistence(timeout: 30), "Home did not appear")
        remote.press(.select)
        XCTAssertTrue(app.staticTexts[guideLegend].waitForExistence(timeout: 40), "the Guide did not load")
        sleep(4)

        // Focus lands on the first programme cell, which is the one airing now.
        remote.press(.select, forDuration: 1.2)

        let sheetOpened = app.buttons["Record this airing"].waitForExistence(timeout: 6)
            || app.staticTexts["Record this airing"].waitForExistence(timeout: 1)
        if !sheetOpened {
            let texts = app.staticTexts.allElementsBoundByIndex.prefix(25).map(\.label)
            XCTFail("the hold did not open the airing sheet; on screen: \(texts)")
        }

        // Menu closes the sheet (or stops playback, had the hold been missed).
        remote.press(.menu)
        sleep(2)
    }
}
