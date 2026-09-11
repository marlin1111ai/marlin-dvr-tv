//
//  GuideSearchUITests.swift
//  Marlin DVR TVUITests
//
//  Pass 63's evidence harness, not a standing test. It needs the physical Apple TV, the real
//  Siri Remote and the owner's live guide: it types a title on the on-screen keyboard, reads
//  the results the server answers with, opens one, and checks the airing sheet's controls are
//  live. **It makes no server write** — nothing is recorded, no pass is created, and the sheet
//  is always left by Menu.
//
//  Run:
//    xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
//      -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates test \
//      -only-testing:"Marlin DVR TVUITests/GuideSearchUITests"
//

import XCTest

final class GuideSearchUITests: XCTestCase {
    private var app: XCUIApplication!
    private let remote = XCUIRemote.shared

    /// Only on the Search screen, before anything is typed.
    private let idleLine = "Type a title. Search matches the title only, from now forward."
    /// Only on the On Later screen — the stepping stone that gets the remote into the rail.
    private let onLaterSubtitle = "New, premiere, live, finale and movie airings"

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launch()
    }

    private func shot(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    private func dump(_ tag: String) {
        let texts = app.staticTexts.allElementsBoundByIndex.map(\.label)
        print("TEXTDUMP[\(tag)] count=\(texts.count)")
        for (i, t) in texts.enumerated() { print("TEXTDUMP[\(tag)] \(i): \(t)") }
        let buttons = app.buttons.allElementsBoundByIndex.map(\.label)
        print("BTNDUMP[\(tag)] count=\(buttons.count)")
        for (i, b) in buttons.enumerated() { print("BTNDUMP[\(tag)] \(i): \(b)") }
        let focusedButtons = app.buttons.allElementsBoundByIndex.filter(\.hasFocus).map(\.label)
        let fieldFocused = app.textFields.allElementsBoundByIndex.map(\.hasFocus)
        let otherFocused = app.descendants(matching: .any).allElementsBoundByIndex.filter(\.hasFocus).map { "\($0.elementType.rawValue):\($0.label)" }
        print("FOCUS[\(tag)] buttons=\(focusedButtons) textFieldFocus=\(fieldFocused) keyboards=\(app.keyboards.count)")
        print("FOCUSALL[\(tag)] \(otherFocused)")
    }

    /// Home has no Search tile by decision, so Search is reached the way the owner reaches it:
    /// open any rail screen, swipe left into the rail, walk down to Search.
    ///
    /// On Later is the stepping stone because it loads in one read and because Pass 25's
    /// restore guarantees the swipe left lands on On Later itself — rail index 4 — so the walk
    /// down to Search (index 9) is a fixed five presses rather than a guess.
    private func openSearch() {
        XCTAssertTrue(app.staticTexts["Marlin"].waitForExistence(timeout: 40), "Home did not appear")
        sleep(3)
        remote.press(.right)        // Guide → On Now
        sleep(1)
        remote.press(.right)        // On Now → On Later
        sleep(1)
        remote.press(.select)
        XCTAssertTrue(app.staticTexts[onLaterSubtitle].waitForExistence(timeout: 40), "On Later did not load")
        sleep(4)

        remote.press(.left)         // into the rail; Pass 25 restores it to On Later
        sleep(2)
        for _ in 0..<5 { remote.press(.down); usleep(700_000) }   // onLater → … → search
        sleep(1)
        remote.press(.select)

        XCTAssertTrue(app.staticTexts[idleLine].waitForExistence(timeout: 20), "the Search screen did not open")
        sleep(3)
    }

    private var countLine: XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@ OR label BEGINSWITH %@ OR label ENDSWITH %@",
                                             "Showing the first ", "No airings match ", " matches")).firstMatch
    }

    private var seriesButton: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@ OR label == %@", "Record the series", "Edit series pass")).firstMatch
    }

    /// Focus the field, open the keyboard, type, and dismiss the keyboard again.
    private func type(_ text: String) {
        remote.press(.select)
        sleep(3)
        XCTAssertTrue(app.keyboards.count > 0, "the keyboard did not appear for \u{201C}\(text)\u{201D}")
        app.typeText(text)
        // The search is debounced by 400 ms and then has a round trip to make; the keyboard is
        // a full-screen takeover, so this all happens out of sight.
        sleep(4)
        remote.press(.menu)
        sleep(3)
        XCTAssertEqual(app.keyboards.count, 0, "the keyboard did not go away")
    }

    // MARK: The owner's path, end to end

    func testTypeATitleOpenAResultAndDriveTheSheet() {
        openSearch()
        shot("10-search-empty-query")
        dump("idle")

        type("news")
        shot("11-results-for-news")
        dump("results")

        XCTAssertTrue(countLine.exists, "no count line after searching")
        print("SEARCH countLine: \(countLine.label)")

        let resultButtons = app.buttons.allElementsBoundByIndex.map(\.label)
            .filter { !$0.isEmpty && !["Home", "Favorite", "Tv", "Grid View", "Clock", "Movie", "Video", "Partly Cloudy", "radio", "Magnifyingglass", "Edit"].contains($0) }
        print("SEARCH result buttons (\(resultButtons.count)): \(resultButtons)")
        XCTAssertFalse(resultButtons.isEmpty, "the search returned no result rows")

        // Field → the first result.
        remote.press(.down)
        sleep(2)
        let focusedBefore = app.buttons.allElementsBoundByIndex.filter(\.hasFocus).map(\.label)
        print("SEARCH focused row: \(focusedBefore)")
        XCTAssertFalse(focusedBefore.isEmpty, "Down from the field focused nothing")

        remote.press(.select)
        XCTAssertTrue(seriesButton.waitForExistence(timeout: 30), "the airing sheet did not open from a search result")
        sleep(4)
        shot("12-sheet-from-a-search-result")
        dump("sheet")

        // "The sheet's controls are live": one of them has focus on open, and the remote moves
        // between them. Nothing is pressed, so nothing is written to the server.
        let firstFocus = app.buttons.allElementsBoundByIndex.filter(\.hasFocus).map(\.label)
        print("SEARCH sheet focus on open: \(firstFocus)")
        XCTAssertFalse(firstFocus.isEmpty, "nothing in the sheet took focus")

        // And focus stays inside the sheet: the results behind it are disabled, so Down and
        // Up cannot walk the remote out of the sheet onto a row it is covering.
        remote.press(.down)
        sleep(2)
        let downFocus = app.buttons.allElementsBoundByIndex.filter(\.hasFocus).map(\.label)
        print("SEARCH sheet focus after Down: \(downFocus)")
        XCTAssertEqual(downFocus, firstFocus, "Down moved focus out of the sheet")

        remote.press(.right)
        sleep(2)
        let secondFocus = app.buttons.allElementsBoundByIndex.filter(\.hasFocus).map(\.label)
        print("SEARCH sheet focus after Right: \(secondFocus)")
        shot("13-sheet-focus-moved")
        XCTAssertNotEqual(firstFocus, secondFocus, "focus did not move between the sheet's controls")

        // Menu closes the sheet and puts the remote back on the row it came from.
        remote.press(.menu)
        sleep(3)
        shot("14-back-on-the-results")
        dump("after-sheet")
        XCTAssertFalse(seriesButton.exists, "Menu did not close the airing sheet")
        XCTAssertTrue(countLine.exists, "Menu closed the whole screen instead of the sheet")
        let backFocus = app.buttons.allElementsBoundByIndex.filter(\.hasFocus).map(\.label)
        print("SEARCH focus after closing the sheet: \(backFocus)")
        XCTAssertEqual(backFocus, focusedBefore, "focus did not come back to the row the sheet was opened from")
    }

    // MARK: The owner's decision that a search survives the rail

    func testAQueryAndItsResultsSurviveATripToTheRail() {
        openSearch()
        type("news")
        let before = countLine.label
        let rowsBefore = app.buttons.allElementsBoundByIndex.map(\.label)
        print("SURVIVE before: \(before)")
        shot("15-before-the-rail-trip")

        // Out to the rail, up to Radio, back down to Search, back in.
        remote.press(.left)
        sleep(2)
        // Pass 62 §5.3 worked out from Pass 24's measured frames that an eleventh entry
        // *ought* to fit the expanded rail and asked for a photograph before anyone relied
        // on it. This is that photograph: eleven entries and the two-line footer.
        shot("19-the-expanded-rail-with-eleven-entries")
        print("RAIL buttons: \(app.buttons.allElementsBoundByIndex.map(\.label))")
        print("RAIL texts: \(app.staticTexts.allElementsBoundByIndex.map(\.label))")
        remote.press(.up)
        sleep(1)
        remote.press(.select)       // Radio
        sleep(6)
        shot("16-away-on-radio")
        remote.press(.left)
        sleep(2)
        remote.press(.down)
        sleep(1)
        remote.press(.select)       // back to Search
        sleep(4)
        shot("17-after-the-rail-trip")
        dump("after-rail-trip")

        XCTAssertTrue(countLine.exists, "the Search screen came back with no count line")
        print("SURVIVE after: \(countLine.label)")
        XCTAssertEqual(countLine.label, before, "the result count did not survive the trip to the rail")
        let rowsAfter = app.buttons.allElementsBoundByIndex.map(\.label)
        XCTAssertEqual(rowsAfter, rowsBefore, "the result rows did not survive the trip to the rail")
        XCTAssertFalse(app.staticTexts[idleLine].exists, "the screen came back to the empty-query state")
    }

    // MARK: The no-match state

    func testAQueryThatMatchesNothingSaysSo() {
        openSearch()
        type("zzqqxx")
        shot("18-no-matches")
        dump("no-matches")
        let line = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "No airings match")).firstMatch
        XCTAssertTrue(line.exists, "a query with no matches did not say so")
        print("NOMATCH line: \(line.label)")
    }
}
