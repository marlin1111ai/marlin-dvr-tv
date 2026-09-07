//
//  HomeRadioCountUITests.swift
//  Marlin DVR TVUITests
//
//  Pass 20's evidence harness, not a standing test. It runs on the physical Apple TV and reads
//  the Home tiles' own accessibility labels — a tile's label is "<name>, <sub-line>" — so the
//  assertions are on the text the app actually draws.
//
//  Two things are proven here. The Radio tile carries the server's station count instead of the
//  static word "Stations"; and **no other tile changed**, which is asserted by capturing all
//  nine labels and checking each against the shape it has had since its own pass.
//
//  Step 4's two fallbacks — an empty list and an unreachable server, both of which drop the tile
//  back to the word "Stations" — were proven during the pass with a disclosed temporary switch in
//  `HomeModel` that is not in this build. It staged those two states and wrote nothing;
//  "unreachable" was measured against a dead port on this Apple TV itself rather than any other
//  host. The readings are in reports/2026-09-06-pass20-home-radio-count.md §4.
//

import XCTest

final class HomeRadioCountUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    private func launch() {
        app.launch()
        XCTAssertTrue(app.staticTexts["Marlin"].waitForExistence(timeout: 60), "Home did not appear")
    }

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Every Home tile's label, which is "<tile name>, <sub-line>".
    private func tileLabels() -> [String] {
        let names = ["Guide", "On Now", "On Later", "Recordings", "Cameras", "Favorites", "Weather", "Radio", "Settings"]
        return app.buttons.allElementsBoundByIndex.map(\.label)
            .filter { label in names.contains { label == $0 || label.hasPrefix("\($0), ") } }
    }

    private func subLine(of tile: String) -> String? {
        tileLabels().first { $0.hasPrefix("\(tile), ") }.map { String($0.dropFirst(tile.count + 2)) }
    }

    /// The sub-lines arrive over the network; wait for Radio's to stop being the static word.
    @discardableResult
    private func waitForRadioCount(timeout: Int = 40) -> String? {
        for _ in 0..<timeout {
            if let sub = subLine(of: "Radio"), sub != "Stations", sub != "…" { return sub }
            sleep(1)
        }
        return subLine(of: "Radio")
    }

    // MARK: Steps 2 and 3 — the count, and the other tiles left alone

    func testRadioTileShowsTheServerStationCount() {
        launch()
        let radio = waitForRadioCount()
        shot("01-home-with-the-radio-count")
        let all = tileLabels().sorted()
        print("[pass20] every Home tile label: \(all)")

        XCTAssertNotNil(radio, "the Radio tile has no sub-line at all")
        XCTAssertNotEqual(radio, "Stations", "the Radio tile is still on the static word")
        // The wording the other counted tiles use: the number first, then a lowercase noun.
        let shape = NSPredicate(format: "SELF MATCHES %@", "^[0-9]+ stations?$")
        XCTAssertTrue(shape.evaluate(with: radio), "the Radio sub-line is not '<n> station(s)': '\(radio ?? "nil")'")
        // The owner's list holds two stations, so it is plural today.
        XCTAssertEqual(radio, "2 stations", "the count does not match the server's two stations")
    }

    /// Step 3's other half: nothing else on Home moved. Each tile is checked against the shape
    /// it has had since the pass that built it, so a changed format anywhere would fail here.
    func testNoOtherHomeTileChanged() {
        launch()
        waitForRadioCount()
        sleep(4)
        shot("02-all-nine-tiles")
        let expected: [(String, String)] = [
            ("Guide",      "^[0-9]+ channels live$"),
            ("On Now",     "^[0-9]+ programs live$"),
            ("On Later",   "^[0-9]+ upcoming$"),
            ("Recordings", "^[0-9]+ recordings · [0-9]+ recording now$"),
            ("Cameras",    "^[0-9]+ of [0-9]+ online$"),
            ("Favorites",  "^(None yet|[0-9]+ favourite channels?)$"),
            ("Weather",    "^Local weather$"),
            ("Settings",   "^Server, tuners, storage$"),
        ]
        for (tile, pattern) in expected {
            let sub = subLine(of: tile)
            XCTAssertNotNil(sub, "the \(tile) tile has no sub-line")
            XCTAssertTrue(NSPredicate(format: "SELF MATCHES %@", pattern).evaluate(with: sub),
                          "the \(tile) tile changed: '\(sub ?? "nil")' does not match \(pattern)")
        }
        XCTAssertEqual(tileLabels().count, 9, "Home is not drawing nine tiles: \(tileLabels())")
    }
}
