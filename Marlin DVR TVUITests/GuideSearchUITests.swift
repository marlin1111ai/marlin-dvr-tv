//
//  GuideSearchUITests.swift
//  Marlin DVR TVUITests
//
//  Pass 63's evidence harness, rebuilt for Pass 65's layout. Not a standing test: it needs the
//  physical Apple TV, the real Siri Remote and the owner's live guide.
//
//  What changed in Pass 65. The input is `.searchable`, so there is no app-owned text field to
//  focus and no Select that summons a full-screen keyboard. tvOS draws a field and a one-row
//  alphabet strip at the top of the screen; the remote crosses in from the rail, walks **up**
//  to the strip, types, and walks back **down** into the results with the strip still up. Every
//  step below is written around that.
//
//  **It makes no server write** — nothing is recorded, no pass is created, and the airing sheet
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

    private func focusedElements() -> [XCUIElement] {
        app.descendants(matching: .any).allElementsBoundByIndex.filter(\.hasFocus)
    }

    private func focusLabels() -> [String] {
        focusedElements().map { "\($0.elementType.rawValue):\($0.label)" }
    }

    /// True while something that accepts typed characters holds focus — on this screen that is
    /// tvOS's own search field or its keyboard strip.
    private var keyboardHasFocus: Bool {
        focusedElements().contains {
            $0.elementType == .keyboard || $0.elementType == .key
                || $0.elementType == .textField || $0.elementType == .searchField
        }
    }

    private func dump(_ tag: String) {
        print("DUMP[\(tag)] keyboards=\(app.keyboards.count) keys=\(app.keys.count) searchFields=\(app.searchFields.count)")
        for k in app.keyboards.allElementsBoundByIndex { print("DUMP[\(tag)] keyboard.frame=\(k.frame)") }
        print("DUMP[\(tag)] focused=\(focusLabels())")
        print("DUMP[\(tag)] resultRows=\(resultRowLabels().count)")
    }

    /// The result rows, matched on the "title, channel · when · duration" label every row draws.
    private func resultRowLabels() -> [String] {
        app.buttons.allElementsBoundByIndex.map(\.label).filter { $0.contains(" · ") && $0.contains(",") }
    }

    private var countLine: XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@ OR label BEGINSWITH %@ OR label ENDSWITH %@",
                                             "Showing the first ", "No airings match ", " matches")).firstMatch
    }

    private var seriesButton: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@ OR label == %@", "Record the series", "Edit series pass")).firstMatch
    }

    /// Home has no Search tile by decision, so Search is reached the way the owner reaches it:
    /// open any rail screen, swipe left into the rail, walk down to Search. On Later is the
    /// stepping stone because Pass 25's restore guarantees the swipe left lands on it — rail
    /// index 4 — so the walk down to Search (index 9) is a fixed five presses.
    private func openSearch() {
        XCTAssertTrue(app.staticTexts["Marlin"].waitForExistence(timeout: 40), "Home did not appear")
        sleep(3)
        remote.press(.right); sleep(1)
        remote.press(.right); sleep(1)
        remote.press(.select)
        XCTAssertTrue(app.staticTexts[onLaterSubtitle].waitForExistence(timeout: 40), "On Later did not load")
        sleep(4)

        remote.press(.left); sleep(2)
        for _ in 0..<5 { remote.press(.down); usleep(700_000) }
        sleep(1)
        remote.press(.select)

        XCTAssertTrue(app.staticTexts[idleLine].waitForExistence(timeout: 20), "the Search screen did not open")
        sleep(3)
    }

    /// Cross from the rail into the content and walk up to the keyboard strip. Returns the
    /// number of Up presses it took, or nil if it was never reached.
    @discardableResult
    private func reachTheKeyboard(_ tag: String, maxUp: Int = 14) -> Int? {
        if !keyboardHasFocus {
            remote.press(.right); sleep(2)
            print("REACH[\(tag)] Right -> \(focusLabels())")
        }
        for up in 0...maxUp {
            if keyboardHasFocus {
                print("REACH[\(tag)] keyboard reached after \(up) Up press(es)")
                return up
            }
            remote.press(.up); sleep(1)
        }
        print("REACH[\(tag)] keyboard NOT reached in \(maxUp) Up presses; focus=\(focusLabels())")
        return nil
    }

    private func type(_ text: String) {
        XCTAssertTrue(keyboardHasFocus, "nothing that accepts typing has focus")
        app.typeText(text)
        sleep(4)     // the 400 ms debounce plus one round trip to the server
    }

    // MARK: step 3 - where .searchable puts the field relative to the screen's header

    func testWhereTheSearchChromeSitsRelativeToTheHeader() {
        openSearch()
        shot("20-search-on-open")
        dump("on-open")

        // The rail also draws a static text labelled "Search", at x=156. The screen's own
        // header lives in the content area, which starts at x=236, so filter by position.
        let header = app.staticTexts.matching(NSPredicate(format: "label == %@", "Search"))
            .allElementsBoundByIndex.first { $0.frame.minX > 200 } ?? app.staticTexts["Search"].firstMatch
        let subtitle = app.staticTexts["Programme titles in the guide"].firstMatch
        let idle = app.staticTexts[idleLine].firstMatch
        let keyboard = app.keyboards.firstMatch

        XCTAssertTrue(header.exists, "the screen header is not in the tree at all")
        for h in app.staticTexts.matching(NSPredicate(format: "label == %@", "Search")).allElementsBoundByIndex {
            print("LAYOUT every 'Search' static text frame=\(h.frame)")
        }
        print("LAYOUT header Search frame=\(header.frame)")
        print("LAYOUT subtitle frame=\(subtitle.exists ? "\(subtitle.frame)" : "ABSENT")")
        print("LAYOUT idle line frame=\(idle.exists ? "\(idle.frame)" : "ABSENT")")
        print("LAYOUT keyboard frame=\(keyboard.exists ? "\(keyboard.frame)" : "ABSENT")")
        print("LAYOUT searchFields=\(app.searchFields.count)")
        for f in app.searchFields.allElementsBoundByIndex { print("LAYOUT searchField frame=\(f.frame)") }

        // The header must still be on screen and not underneath the search chrome.
        if keyboard.exists && header.exists {
            let clear = header.frame.minY >= keyboard.frame.maxY
            print("LAYOUT header clears the keyboard strip: \(clear)")
            XCTAssertTrue(clear, "the screen header overlaps the search chrome - header \(header.frame), keyboard \(keyboard.frame)")
        }
    }

    // MARK: step 4 - is the keyboard reachable from partway down a long list?

    func testTheKeyboardIsReachableFromPartwayDownTheList() {
        openSearch()
        reachTheKeyboard("step4-initial")
        type("news")
        shot("21-results-before-scrolling")
        dump("before-scrolling")

        let rows = resultRowLabels()
        print("STEP4 rows=\(rows.count)")
        XCTAssertGreaterThan(rows.count, 8, "need a query returning more rows than fit on screen")

        // Walk down into the list far enough that the view has scrolled.
        var downs = 0
        for _ in 0..<8 {
            remote.press(.down); sleep(1)
            downs += 1
        }
        sleep(2)
        shot("22-partway-down-the-list")
        dump("partway-down")
        print("STEP4 after \(downs) Downs focus=\(focusLabels()) keyboards=\(app.keyboards.count)")
        let scrolledRow = focusLabels()

        // Press Up ONCE and report where it goes: is the strip one press away from here, or
        // must the remote walk all the way back up the list?
        remote.press(.up); sleep(2)
        let afterOneUp = focusLabels()
        let keyboardAfterOneUp = keyboardHasFocus
        print("STEP4 one Up from \(scrolledRow) -> \(afterOneUp) keyboardReached=\(keyboardAfterOneUp)")
        shot("23-one-up-from-partway-down")

        // Then keep going and count what it actually takes.
        var extra = 0
        if !keyboardAfterOneUp {
            for _ in 0..<20 {
                if keyboardHasFocus { break }
                remote.press(.up); sleep(1)
                extra += 1
            }
        }
        print("STEP4 keyboard reached after 1 + \(extra) Up presses in total; focus=\(focusLabels())")
        shot("24-back-at-the-keyboard-strip")
        XCTAssertTrue(keyboardHasFocus, "the keyboard strip could not be reached from partway down the list")
    }

    // MARK: step 6 - the owner's path, end to end

    func testTypeATitleOpenAResultAndDriveTheSheet() {
        openSearch()
        shot("25-search-empty-query")
        dump("idle")

        reachTheKeyboard("main")
        type("news")
        shot("26-results-for-news-keyboard-still-up")
        dump("results")

        // The whole point of the change: the list is on screen while the keyboard is.
        XCTAssertGreaterThan(app.keyboards.count, 0, "the keyboard strip went away while typing")
        XCTAssertTrue(countLine.exists, "no count line after searching")
        print("SEARCH countLine: \(countLine.label)")
        let rows = resultRowLabels()
        print("SEARCH result rows (\(rows.count)): \(rows)")
        XCTAssertFalse(rows.isEmpty, "the search returned no result rows")

        // Down from the keyboard strip into the first result.
        remote.press(.down); sleep(2)
        let focusedBefore = focusLabels()
        print("SEARCH focused row: \(focusedBefore)")
        XCTAssertTrue(focusedBefore.contains { $0.contains(" · ") }, "Down from the keyboard did not land on a result row")
        XCTAssertGreaterThan(app.keyboards.count, 0, "the keyboard strip went away when focus entered the list")

        remote.press(.select)
        XCTAssertTrue(seriesButton.waitForExistence(timeout: 30), "the airing sheet did not open from a search result")
        sleep(4)
        shot("27-sheet-from-a-search-result")
        dump("sheet")

        // "The sheet's controls are live": one has focus on open, Down stays inside the sheet,
        // and Right moves between them. Nothing is pressed, so nothing is written.
        let firstFocus = app.buttons.allElementsBoundByIndex.filter(\.hasFocus).map(\.label)
        print("SEARCH sheet focus on open: \(firstFocus)")
        XCTAssertFalse(firstFocus.isEmpty, "nothing in the sheet took focus")

        remote.press(.down); sleep(2)
        let downFocus = app.buttons.allElementsBoundByIndex.filter(\.hasFocus).map(\.label)
        print("SEARCH sheet focus after Down: \(downFocus)")
        XCTAssertEqual(downFocus, firstFocus, "Down moved focus out of the sheet")

        remote.press(.right); sleep(2)
        let secondFocus = app.buttons.allElementsBoundByIndex.filter(\.hasFocus).map(\.label)
        print("SEARCH sheet focus after Right: \(secondFocus)")
        shot("28-sheet-focus-moved")
        XCTAssertNotEqual(firstFocus, secondFocus, "focus did not move between the sheet's controls")

        // Menu closes the sheet and puts the remote back on the row it came from.
        remote.press(.menu); sleep(3)
        shot("29-back-on-the-results")
        dump("after-sheet")
        XCTAssertFalse(seriesButton.exists, "Menu did not close the airing sheet")
        XCTAssertTrue(countLine.exists, "Menu closed the whole screen instead of the sheet")
        let backFocus = focusLabels()
        print("SEARCH focus after closing the sheet: \(backFocus)")
        XCTAssertFalse(backFocus.isEmpty, "nothing at all has focus after the sheet closed")
        XCTAssertEqual(backFocus, focusedBefore, "focus did not come back to the row the sheet was opened from")
    }

    // MARK: the owner's decision that a search survives the rail

    func testAQueryAndItsResultsSurviveATripToTheRail() {
        openSearch()
        reachTheKeyboard("survive")
        type("news")
        let before = countLine.label
        let rowsBefore = resultRowLabels()
        print("SURVIVE before: \(before) rows=\(rowsBefore.count)")
        shot("30-before-the-rail-trip")

        // Out to the rail, up to Radio, back down to Search, back in.
        remote.press(.left); sleep(2)
        shot("31-the-expanded-rail")
        remote.press(.up); sleep(1)
        remote.press(.select); sleep(6)      // Radio
        remote.press(.left); sleep(2)
        remote.press(.down); sleep(1)
        remote.press(.select); sleep(4)      // back to Search
        shot("32-after-the-rail-trip")
        dump("after-rail-trip")

        XCTAssertTrue(countLine.exists, "the Search screen came back with no count line")
        print("SURVIVE after: \(countLine.label)")
        XCTAssertEqual(countLine.label, before, "the result count did not survive the trip to the rail")
        XCTAssertEqual(resultRowLabels(), rowsBefore, "the result rows did not survive the trip to the rail")
        XCTAssertFalse(app.staticTexts[idleLine].exists, "the screen came back to the empty-query state")
    }

    // MARK: the no-match state

    func testAQueryThatMatchesNothingSaysSo() {
        openSearch()
        reachTheKeyboard("nomatch")
        type("zzqqxx")
        shot("33-no-matches")
        dump("no-matches")
        let line = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "No airings match")).firstMatch
        XCTAssertTrue(line.exists, "a query with no matches did not say so")
        print("NOMATCH line: \(line.label)")
    }
}
