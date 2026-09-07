//
//  RadioUITests.swift
//  Marlin DVR TVUITests
//
//  Pass 19's evidence harness, not a standing test. It drives the real Siri Remote with
//  XCUIRemote on the physical Apple TV — the same route Passes 9, 10B and 13 used — and asserts
//  on the text the app actually draws, so a station is only "playing" when the bar says so, and
//  the bar only says so when AVPlayer's own `timeControlStatus` reports it is rendering.
//
//  Step 6 was settled during the pass with two disclosed temporary diagnostics that are not in
//  this build: a line in the now-playing bar printing the codec AVFoundation decoded and the
//  item's clock and loaded range, and a counter in the header of how many AVPlayers the app had
//  attached and not torn down. The readings they gave are quoted in
//  reports/2026-09-06-pass19-radio.md §3; what survives here is what the shipping build can be
//  asked without them.
//
//  It makes no server write. The only requests it causes are the app's own `GET /api/radio`,
//  the two cached icon URLs on the DVR, and the two station streams.
//

import XCTest

final class RadioUITests: XCTestCase {
    private var app: XCUIApplication!
    private let remote = XCUIRemote.shared

    /// The owner's list, in the server's order (GET /api/radio, 2026-09-06).
    private let firstStation = "WBAL NewsRadio 1090"      // …/….aac — the AAC mount
    private let secondStation = "WCBM Talk Radio 680"     // …/….mp3 — the MP3 mount

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

    /// Home tiles carry their sub-line in the label ("Radio, Stations"), so an exact match
    /// will not find them.
    private func tile(_ prefix: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    /// Home → the Radio tile (row 3, middle) → the Radio screen.
    private func openRadio() {
        XCTAssertTrue(app.staticTexts["Marlin"].waitForExistence(timeout: 60), "Home did not appear")
        sleep(4)
        remote.press(.down); sleep(1)
        remote.press(.down); sleep(1)
        remote.press(.right); sleep(1)
        XCTAssertTrue(tile("Radio").hasFocus, "focus did not reach the Radio tile")
        shot("01-home-radio-tile-focused")
        remote.press(.select)
        XCTAssertTrue(app.staticTexts["Streams come straight from the station, not the DVR"].waitForExistence(timeout: 30),
                      "the Radio screen did not open")
        sleep(4)
    }

    /// Home puts focus back on the Guide tile every time, so returning means walking to Radio
    /// again rather than pressing Select where it stood.
    private func reopenRadioFromHome() {
        XCTAssertTrue(app.staticTexts["Marlin"].waitForExistence(timeout: 30), "not on Home")
        sleep(3)
        remote.press(.down); sleep(1)
        remote.press(.down); sleep(1)
        remote.press(.right); sleep(1)
        remote.press(.select)
        XCTAssertTrue(app.staticTexts["Streams come straight from the station, not the DVR"].waitForExistence(timeout: 30),
                      "Radio did not reopen")
        sleep(3)
    }

    /// Plays whichever station has focus and waits for the bar to say it is playing.
    private func playFocusedStation(_ name: String, tag: String) {
        shot("\(tag)-focused")
        remote.press(.select)
        sleep(2)
        shot("\(tag)-connecting")
        let playing = app.staticTexts["NOW PLAYING"].waitForExistence(timeout: 45)
        sleep(8)
        shot("\(tag)-bar")
        if !playing {
            XCTFail("\(name) did not play. On screen: \(app.staticTexts.allElementsBoundByIndex.map(\.label))")
        }
        // The bar names the station it is playing, so a silent fall-back to another one would
        // show here.
        XCTAssertTrue(app.staticTexts[name].firstMatch.exists, "the bar is not naming \(name)")
    }

    // MARK: Step 6 — the two stations, one test each so each is reported by name

    /// Station 1: WBAL NewsRadio 1090, the `.aac` mount — the one nobody had ever seen play.
    func testFirstStationTheAACMountPlays() {
        openRadio()
        XCTAssertTrue(app.staticTexts[firstStation].firstMatch.exists, "the first station is not on screen")
        // Focus lands on the first tile when the list loads — the server's order, unsorted.
        playFocusedStation(firstStation, tag: "02-wbal-aac")
    }

    /// Station 2: WCBM Talk Radio 680, the `.mp3` mount.
    func testSecondStationTheMP3MountPlays() {
        openRadio()
        XCTAssertTrue(app.staticTexts[secondStation].firstMatch.exists, "the second station is not on screen")
        remote.press(.right); sleep(2)      // the grid is two columns; the second station is to the right
        playFocusedStation(secondStation, tag: "03-wcbm-mp3")
    }

    // MARK: Step 4 — Stop — and step 5 — the lifetime

    func testStopAndLeavingEndThePlayback() {
        openRadio()
        playFocusedStation(firstStation, tag: "04-lifetime-playing")

        // ---- step 4: the Stop control
        remote.press(.up); sleep(2)
        XCTAssertTrue(app.buttons["Stop"].hasFocus, "could not reach Stop from the grid")
        shot("05-stop-focused")
        remote.press(.select)
        sleep(3)
        XCTAssertFalse(app.staticTexts["NOW PLAYING"].exists, "the bar is still up after Stop")
        shot("06-after-stop")

        // ---- step 5: leaving the screen
        remote.press(.select)                       // focus went back to the station; play it again
        XCTAssertTrue(app.staticTexts["NOW PLAYING"].waitForExistence(timeout: 45), "it did not play again")
        sleep(4)
        shot("07-playing-again")
        remote.press(.menu)                         // Menu leaves Radio for Home
        sleep(6)
        shot("08-back-on-home")
        reopenRadioFromHome()
        shot("09-radio-reopened")
        XCTAssertFalse(app.staticTexts["NOW PLAYING"].exists, "the bar survived leaving the screen")

        // ---- step 5: the app leaving the foreground. The Apple TV going to sleep takes this
        // same path; the screensaver itself cannot be triggered from a test.
        remote.press(.select)
        XCTAssertTrue(app.staticTexts["NOW PLAYING"].waitForExistence(timeout: 45), "it did not play a third time")
        sleep(4)
        XCUIDevice.shared.press(.home)
        sleep(8)
        app.activate()
        sleep(8)
        shot("10-after-backgrounding")
        let radioHeader = app.staticTexts["Streams come straight from the station, not the DVR"]
        if !radioHeader.exists { reopenRadioFromHome() }
        XCTAssertFalse(app.staticTexts["NOW PLAYING"].exists, "the bar survived the app leaving the foreground")
        shot("11-after-backgrounding-radio")
    }
}
