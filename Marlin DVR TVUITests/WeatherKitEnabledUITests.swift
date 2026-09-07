//
//  WeatherKitEnabledUITests.swift
//  Marlin DVR TVUITests
//
//  Pass 22's evidence harness, not a standing test. Pass 13 built the Weather screen (frame 5f)
//  and the Home glance (frame 2a) and never saw either with data on it, because
//  `com.apple.developer.weatherkit` was not in the app's signing and every WeatherKit call died
//  with `xpcConnectionFailed … com.apple.weatherkit.authservice … Sandbox restriction`.
//
//  The App ID now carries WeatherKit and the target is entitled, so this harness does the one
//  thing that was impossible before: it photographs both screens **populated**, on the physical
//  Apple TV, driven by the real Siri Remote, and prints every string they draw so the pass can
//  report field by field against the design instead of against the source.
//
//  It makes no server write, changes nothing, and asks WeatherKit for nothing of its own.
//

import XCTest

final class WeatherKitEnabledUITests: XCTestCase {
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

    private func tile(_ prefix: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    /// Every string on screen, in tree order, printed into the test log so the report can quote
    /// what the Apple TV actually drew rather than what the source says it should draw.
    private func dump(_ tag: String) {
        let texts = app.staticTexts.allElementsBoundByIndex.map(\.label)
        print("TEXTDUMP[\(tag)] count=\(texts.count)")
        for (i, t) in texts.enumerated() { print("TEXTDUMP[\(tag)] \(i): \(t)") }
        let buttons = app.buttons.allElementsBoundByIndex.map(\.label)
        print("BTNDUMP[\(tag)] count=\(buttons.count)")
        for (i, b) in buttons.enumerated() { print("BTNDUMP[\(tag)] \(i): \(b)") }
    }

    /// The grant is cached from Pass 13 and an upgrade install keeps it, so this normally
    /// reports `no-location-prompt`. Kept because a prompt on screen would otherwise look like
    /// a hung Home. Walking up first clamps at the prompt's caption, so the two downs always
    /// land on Allow While Using App.
    private func answerLocationPromptIfPresent() {
        let guideTile = tile("Guide")
        _ = guideTile.waitForExistence(timeout: 40)
        sleep(6)
        if guideTile.hasFocus {
            shot("00-no-location-prompt")
            return
        }
        shot("00-location-prompt")
        for _ in 0..<4 { remote.press(.up); usleep(600_000) }
        remote.press(.down); sleep(1)
        remote.press(.down); sleep(1)
        remote.press(.select)
        sleep(10)
        shot("00-after-location-prompt")
    }

    func testBothScreensPopulatedOnTheDevice() {
        answerLocationPromptIfPresent()
        XCTAssertTrue(app.staticTexts["Marlin"].waitForExistence(timeout: 60), "Home did not appear")

        // ---- step 5: the Home glance, frame 2a. The card only exists once WeatherKit answered;
        // until then the slot holds one sentence, so waiting on the card is waiting on the data.
        let feels = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Feels '")).firstMatch
        let glanceArrived = feels.waitForExistence(timeout: 90)
        sleep(2)
        shot(glanceArrived ? "01-home-glance-populated" : "01-home-glance-still-empty")
        dump("home")
        XCTAssertTrue(glanceArrived, "the Home weather glance never filled — WeatherKit did not answer")

        // ---- step 4: the Weather screen, frame 5f.
        // Home tile order is Guide, On Now, On Later / Recordings, Cameras, Favorites /
        // Weather, Radio, Settings. Focus starts on Guide, so Weather is two rows down.
        remote.press(.down); sleep(1)
        remote.press(.down); sleep(1)
        XCTAssertTrue(tile("Weather").hasFocus, "focus did not reach the Weather tile")
        remote.press(.select)

        XCTAssertTrue(app.staticTexts["From this Apple TV's location, not the server"].waitForExistence(timeout: 40),
                      "the Weather screen did not open")
        let attribution = app.staticTexts["· data and attribution required by WeatherKit"]
        let populated = attribution.waitForExistence(timeout: 90)
        sleep(3)
        shot(populated ? "02-weather-populated" : "02-weather-not-populated")
        dump("weather")
        XCTAssertTrue(populated, "the Weather screen never filled — WeatherKit did not answer")

        // The daily rows are focusable and the first takes focus when the screen opens
        // (dc:1402-1403 draws the ring there). Before Pass 22's fix the focus stayed in the
        // rail, because the shared model was already `.ready` and the phase never changed.
        shot("03-weather-first-daily-row-focused")

        // Walk the daily list with the remote so the focus ring is seen on a row that was not
        // the default, and so the list is proven reachable with content in it.
        remote.press(.down); sleep(1)
        shot("04-weather-daily-second-row-focused")
        remote.press(.down); sleep(1)
        shot("05-weather-daily-third-row-focused")

        // Up out of the list reaches the Radar entry in the header — which is only possible if
        // focus was in the content in the first place, so this doubles as the focus assertion.
        var guardRail = 0
        while !app.buttons["Radar"].hasFocus && guardRail < 8 {
            remote.press(.up); sleep(1); guardRail += 1
        }
        XCTAssertTrue(app.buttons["Radar"].hasFocus,
                      "focus never reached the Weather screen's content — it is stuck in the rail")
        shot("06-radar-entry-reachable-from-the-list")

        // Back to Home, and photograph the glance again beside the tiles it shares the row with.
        remote.press(.menu); sleep(3)
        XCTAssertTrue(app.staticTexts["Marlin"].waitForExistence(timeout: 30), "Menu did not return to Home")
        sleep(2)
        shot("07-home-again")
    }
}
