//
//  WeatherRadarUITests.swift
//  Marlin DVR TVUITests
//
//  Pass 13's evidence harness, not a standing test. It drives the real Siri Remote
//  (XCUIRemote, the same route Passes 9 and 10B used because Mac keyboard focus was
//  unreliable) so the Weather screen and the radar can be photographed on the Apple TV
//  itself, and so the one-shot location prompt of step 3 can be answered.
//
//  It makes no server write and no WeatherKit call of its own; it only presses buttons.
//

import XCTest

final class WeatherRadarUITests: XCTestCase {
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

    /// The tile with this label prefix — Home tiles carry their sub-line in the label
    /// ("Weather, Local weather"), so an exact match will not find them.
    private func tile(_ prefix: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    /// tvOS puts the Core Location prompt up in a process of its own: it is on screen (and
    /// photographed below) but it is not in the app's element tree, so it cannot be queried.
    /// What can be read is that nothing in the app has focus while it is up. "Allow While
    /// Using App" is the prompt's default button, so one Select answers it.
    private func answerLocationPromptIfPresent() {
        let guideTile = tile("Guide")
        _ = guideTile.waitForExistence(timeout: 40)
        sleep(6)
        if guideTile.hasFocus {
            shot("00-no-location-prompt")   // already answered on an earlier run
            return
        }
        shot("00-location-prompt")
        // The prompt's rows are, top to bottom: the "Select:" caption (which takes focus and
        // is not a button), Allow Once, Allow While Using App, Don't Allow. Photographed this
        // pass in reports/assets/pass13/atv-01-location-prompt.png. Walking up first clamps at
        // the caption whatever ran before, so the two downs always land on Allow While Using
        // App — never on Don't Allow, which is how an earlier run of this pass denied it.
        for _ in 0..<4 { remote.press(.up); usleep(600_000) }
        remote.press(.down); sleep(1)
        remote.press(.down); sleep(1)
        shot("00-allow-focused")
        remote.press(.select)
        sleep(10)
        shot("00-after-location-prompt")
        XCTAssertTrue(guideTile.hasFocus, "the app did not get focus back after the location prompt")
    }

    func testWeatherScreenAndRadarOnTheDevice() {
        answerLocationPromptIfPresent()

        XCTAssertTrue(app.staticTexts["Marlin"].waitForExistence(timeout: 40), "Home did not appear")
        // The glance needs the location shot and the WeatherKit read to land.
        sleep(15)
        shot("01-home-with-the-weather-glance")

        // Home tile order is Guide, On Now, On Later / Recordings, Cameras, Favorites /
        // Weather, Radio, Settings. Focus starts on Guide, so Weather is two rows down.
        remote.press(.down)
        sleep(1)
        remote.press(.down)
        sleep(1)
        XCTAssertTrue(tile("Weather").hasFocus, "focus did not reach the Weather tile")
        remote.press(.select)

        XCTAssertTrue(app.staticTexts["From this Apple TV's location, not the server"].waitForExistence(timeout: 40),
                      "the Weather screen did not open")
        sleep(12)
        shot("02-weather-screen")

        // Every field the design draws should be on screen when WeatherKit answered.
        let attributionShown = app.staticTexts["· data and attribution required by WeatherKit"].exists
        shot(attributionShown ? "03-weather-with-data" : "03-weather-without-data")

        // ---- step 6: the radar is reachable from the Weather screen
        var guardRail = 0
        while !app.buttons["Radar"].hasFocus && guardRail < 10 {
            remote.press(.up)
            sleep(1)
            guardRail += 1
        }
        XCTAssertTrue(app.buttons["Radar"].hasFocus, "could not reach the Radar entry on the Weather screen")
        shot("04-radar-entry-focused")
        remote.press(.select)

        XCTAssertTrue(app.staticTexts["Radar"].waitForExistence(timeout: 25), "the radar view did not open")
        sleep(8)
        shot("05-radar-view")
        // The loop, if there are frames, moves the frame time on.
        sleep(3)
        shot("06-radar-view-later")
        sleep(3)
        shot("06b-radar-view-later-still")
        sleep(10)
        shot("06c-radar-view-ten-seconds-on")

        remote.press(.menu)
        sleep(3)
        XCTAssertTrue(app.staticTexts["From this Apple TV's location, not the server"].waitForExistence(timeout: 20),
                      "Menu did not return from the radar to Weather")
        shot("07-back-on-weather")
    }
}
