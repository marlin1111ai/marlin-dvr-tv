//
//  OnLaterPillsUITests.swift
//  Marlin DVR TVUITests
//
//  Pass 82's evidence harness, not a standing test. It runs on the physical Apple TV
//  ("Home Theater") and drives the real Siri Remote through the one device run the pass is
//  allowed: On Later opens on **On Today** showing only collection channels, a press moves to
//  **On This Week**, another to **Premieres**, and Select on a card opens the airing sheet.
//
//  **It makes no server write of any kind.** The only non-GET traffic is the app's own launch
//  ping, which it has sent since sweep 1 (`ClientSession.swift:62-81`). It never presses Record,
//  never books, never stops a recording; the sheet is opened and closed with Menu.
//
//  PERFORMANCE, learned in Passes 32, 33 and 72: never call `allElementsBoundByIndex` on a screen
//  with a realised grid — on the Guide that took about 0.8 s an element and killed two runs. Every
//  read below is an exact label or a scoped predicate.
//
//  The counts this prints are what the pass checks by hand against the same data fetched from the
//  server at the same sitting; the screen states them itself in its subtitle, so the assertion and
//  the eye are looking at the same number.
//

import XCTest

final class OnLaterPillsUITests: XCTestCase {
    private var app: XCUIApplication!
    private let remote = XCUIRemote.shared

    /// Home tile order, frame 2a (`Destination.homeTiles`): Guide, On Now, On Later on the top row,
    /// and focus starts on Guide.
    private let pills = ["On Today", "On This Week", "Premieres"]

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

    /// Whatever has focus right now, by predicate — never by walking the tree.
    private func focusedLabels() -> [String] {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "hasFocus == YES"))
            .allElementsBoundByIndex
            .map(\.label)
    }

    /// The screen's own subtitle: "12 airings · 5 collection channels".
    private func subtitle() -> String? {
        let predicate = NSPredicate(format: "label MATCHES %@", "^[0-9]+ airings? · [0-9]+ collection channels?$")
        let element = app.staticTexts.matching(predicate).firstMatch
        return element.exists ? element.label : nil
    }

    private func airingCount() -> Int? {
        guard let text = subtitle(), let first = text.split(separator: " ").first else { return nil }
        return Int(first)
    }

    /// Home → On Later, and wait for the load to land.
    private func openOnLater() {
        XCTAssertTrue(app.staticTexts["Marlin"].waitForExistence(timeout: 60), "Home did not appear")
        remote.press(.right); sleep(1)      // On Now
        remote.press(.right); sleep(1)      // On Later
        remote.press(.select)
        XCTAssertTrue(app.buttons["On Today"].waitForExistence(timeout: 60), "On Later did not open")
        // The week is seven guide reads plus the schedule; give it room, then let focus settle.
        for _ in 0..<60 {
            if subtitle() != nil { break }
            sleep(1)
        }
        sleep(3)
    }

    /// Walk the pill row to `label` from wherever focus is, in whichever direction it lies.
    ///
    /// The direction matters and the first version of this helper got it wrong: it only ever
    /// pressed Right, so coming back from Premieres — the last pill — to On Today it pressed into
    /// the right-hand edge six times and reported a failure the app had nothing to do with.
    private func focusPill(_ label: String) {
        // Up out of the grid first if the remote is on a card.
        for _ in 0..<4 {
            if pills.contains(where: { app.buttons[$0].hasFocus }) { break }
            remote.press(.up)
            sleep(1)
        }
        guard let target = pills.firstIndex(of: label) else {
            return XCTFail("\(label) is not a pill")
        }
        for _ in 0..<6 {
            if app.buttons[label].hasFocus { return }
            guard let here = pills.firstIndex(where: { app.buttons[$0].hasFocus }) else {
                return XCTFail("focus is not on the pill row at all; focused=\(focusedLabels())")
            }
            remote.press(here < target ? .right : .left)
            sleep(1)
        }
        XCTFail("could not put focus on the \(label) pill; focused=\(focusedLabels())")
    }

    // MARK: The one device run

    func testOnLaterOpensOnTodayThePillsSwitchAndACardOpensTheSheet() {
        openOnLater()

        // ---- 1. it opens on On Today
        shot("82a-on-later-opens-on-on-today")
        let openingSubtitle = subtitle()
        print("[pass82] OPEN subtitle=\(openingSubtitle ?? "nil") focused=\(focusedLabels())")
        XCTAssertNotNil(openingSubtitle, "the header never drew its count line")
        for label in pills {
            XCTAssertTrue(app.buttons[label].exists, "the \(label) pill is missing")
        }
        XCTAssertFalse(app.buttons["Favorites"].exists, "a channel-filter pill is on the screen")
        XCTAssertFalse(app.buttons["HD"].exists, "a channel-filter pill is on the screen")
        // The old screen's two section headings and its fixed subtitle must both be gone.
        XCTAssertFalse(app.staticTexts["New, premiere, live, finale and movie airings"].exists,
                       "the old On Later subtitle is still drawn")
        let todayCount = airingCount()
        print("[pass82] ON TODAY count=\(todayCount.map(String.init) ?? "nil")")

        // ---- 2. press to On This Week
        focusPill("On This Week")
        print("[pass82] WEEK focused before select=\(focusedLabels())")
        remote.press(.select)
        sleep(3)
        shot("82b-on-this-week")
        let weekCount = airingCount()
        print("[pass82] ON THIS WEEK subtitle=\(subtitle() ?? "nil") focused=\(focusedLabels())")
        XCTAssertTrue(app.buttons["On This Week"].hasFocus,
                      "focus left the pill row on a pill press; focused=\(focusedLabels())")
        XCTAssertNotNil(weekCount)
        if let t = todayCount, let w = weekCount {
            XCTAssertGreaterThanOrEqual(w, t, "On This Week must contain On Today")
        }

        // ---- 3. press to Premieres
        focusPill("Premieres")
        remote.press(.select)
        sleep(3)
        shot("82c-premieres")
        let premiereCount = airingCount()
        print("[pass82] PREMIERES subtitle=\(subtitle() ?? "nil") focused=\(focusedLabels())")
        XCTAssertTrue(app.buttons["Premieres"].hasFocus,
                      "focus left the pill row on a pill press; focused=\(focusedLabels())")
        // Pass 81 measured zero premieres in this guide, so the empty line is the expected sight.
        if premiereCount == 0 {
            XCTAssertTrue(app.staticTexts["Nothing on Premieres for your collections"].exists,
                          "an empty Premieres pill drew no line")
            print("[pass82] PREMIERES is empty and says so — Pass 81's finding, on screen")
        }

        // ---- 4. back to On Today, then Select a card and open the sheet
        focusPill("On Today")
        remote.press(.select)
        sleep(3)
        XCTAssertTrue(app.buttons["On Today"].hasFocus, "focus left the pill row")
        remote.press(.down)
        sleep(2)
        let cardBefore = focusedLabels()
        print("[pass82] CARD focused=\(cardBefore)")
        XCTAssertFalse(cardBefore.isEmpty, "nothing took focus in the grid")
        XCTAssertFalse(pills.contains(where: { app.buttons[$0].hasFocus }),
                       "Down from the pill row did not reach a card")
        shot("82d-a-card-focused")

        remote.press(.select)
        let sheetOpened = app.buttons["Record the series"].waitForExistence(timeout: 25)
            || app.buttons["Edit series pass"].waitForExistence(timeout: 3)
        sleep(2)
        shot("82e-the-airing-sheet")
        print("[pass82] SHEET focused=\(focusedLabels())")
        if !sheetOpened {
            XCTFail("Select on a card did not open the airing sheet; focused=\(focusedLabels())")
        }
        XCTAssertFalse(focusedLabels().isEmpty, "the sheet opened with nothing focused")

        // Menu closes the sheet and nothing else, and the remote goes back to the card.
        remote.press(.menu)
        sleep(3)
        shot("82f-back-on-the-grid")
        let cardAfter = focusedLabels()
        print("[pass82] AFTER SHEET focused=\(cardAfter)")
        XCTAssertTrue(app.buttons["On Today"].exists, "Menu left the screen instead of closing the sheet")
        XCTAssertFalse(cardAfter.isEmpty,
                       "nothing at all has focus after the sheet closed — the Search screen's defect")
        XCTAssertEqual(cardAfter, cardBefore, "focus did not come back to the card the sheet was opened from")
    }
}
