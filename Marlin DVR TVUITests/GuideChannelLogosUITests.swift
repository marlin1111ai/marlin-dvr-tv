//
//  GuideChannelLogosUITests.swift
//  Marlin DVR TVUITests
//
//  Pass 86's evidence harness, not a standing test. It runs on the physical Apple TV
//  ("Home Theater") and drives the real Siri Remote through the one device run the pass is
//  allowed: the Guide on All Channels, with three rows photographed —
//
//    86a  a white antenna logo on its backing (WBFF45 45.1 focused, WJZ-TV 13.1 above it)
//    86b  a black provider logo on its backing (Verizon FOX 9000 focused, YouTube CBS 9000 below)
//    86c  9023 AS-INFOMERCIALS, which has no logo, on the initials tile
//
//  **It makes no server write of any kind.** The only non-GET traffic is the app's own launch
//  ping (`ClientSession.swift`). If the Guide is on a collection when the run starts it is
//  switched to All Channels — a `UserDefaults` write on the Apple TV that the app makes itself —
//  and switched back at the end, so the device is left as it was found.
//
//  **`activate()`, never `launch()`** — Pass 38's pattern. If the app was started separately with
//  a console attached, `activate()` joins that process instead of replacing it; if it was not
//  running, `activate()` starts it.
//
//  **What a channel cell's label says is evidence here.** The cell's accessibility label is its
//  texts joined — "WM, WMAR-HD, 2.1" while the initials tile is drawn. When a logo has loaded the
//  tile is an image with no text, so the label loses its leading initials. The harness reads that
//  change; the photographs are what show the backing.
//
//  PERFORMANCE, learned in Passes 32, 33 and 72: never enumerate a screen with a realised grid.
//  Every read below is a scoped predicate.
//

import XCTest

final class GuideChannelLogosUITests: XCTestCase {
    private var app: XCUIApplication!
    private let remote = XCUIRemote.shared

    /// Only on the Guide (its legend).
    private let guideLegend = "Recording or set to record"
    /// The server's collections on 2026-09-13 (`GET /api/collections`): Local (5), Test (0).
    private let collectionNames = ["All Channels", "Local", "Test"]
    private static let headerBottom: CGFloat = 200

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.activate()
        goHome()
    }

    private func goHome() {
        for _ in 0..<7 {
            if app.staticTexts["Marlin"].waitForExistence(timeout: 8) { sleep(2); return }
            remote.press(.menu)
            sleep(3)
        }
    }

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: reading the screen — predicates only

    private func focusedElements() -> [XCUIElement] {
        app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == YES")).allElementsBoundByIndex
    }

    private func focusLabels() -> [String] { focusedElements().map(\.label) }

    /// A channel cell: its label ends in the channel number and carries the channel's name.
    private func channelCell(_ name: String, _ number: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label ENDSWITH %@ AND label CONTAINS %@", ", \(number)", name)).firstMatch
    }

    private func describe(_ element: XCUIElement) -> String {
        element.exists ? "\u{201C}\(element.label)\u{201D} frame=\(element.frame)" : "ABSENT"
    }

    private func collectionsButton() -> XCUIElement? {
        for label in collectionNames {
            let element = app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
            if element.exists && element.frame.minY < Self.headerBottom { return element }
        }
        return nil
    }

    private func focusIsOnTheCollectionsButton() -> Bool {
        focusedElements().contains { collectionNames.contains($0.label) && $0.frame.minY < Self.headerBottom }
    }

    // MARK: navigation

    private func openGuide() {
        remote.press(.select)   // Home's first tile is the Guide (`Destination.homeTiles`)
        XCTAssertTrue(app.staticTexts[guideLegend].waitForExistence(timeout: 40), "the Guide did not open")
        sleep(5)
    }

    /// Up until the header, then Left along it to the collections button.
    private func reachTheCollectionsButton() -> Bool {
        for _ in 0..<120 {
            if focusIsOnTheCollectionsButton() { return true }
            let inHeader = focusedElements().contains { $0.frame.minY < Self.headerBottom && $0.frame.minX > 200 }
            remote.press(inHeader ? .left : .up)
            usleep(600_000)
        }
        return focusIsOnTheCollectionsButton()
    }

    /// Pick a row in the collections drop-down.
    private func choose(_ title: String) {
        XCTAssertTrue(reachTheCollectionsButton(), "could not reach the collections button; focus=\(focusLabels())")
        remote.press(.select)
        XCTAssertTrue(app.staticTexts["Show in the Guide"].waitForExistence(timeout: 20), "the drop-down did not open")
        sleep(4)
        for _ in 0..<8 {
            if focusLabels().contains(where: { $0.contains(title) }) {
                remote.press(.select)
                sleep(8)
                return
            }
            remote.press(title == "All Channels" ? .up : .down)
            sleep(1)
        }
        XCTFail("could not reach \u{201C}\(title)\u{201D} in the drop-down; focus=\(focusLabels())")
    }

    /// Walk focus onto `target`, one press at a time, by comparing frames: Left out of a programme
    /// cell into the channel column, then Up or Down along it.
    private func focus(_ target: XCUIElement, _ tag: String) {
        XCTAssertTrue(target.exists, "[\(tag)] the target cell is not on the screen")
        var presses = 0
        for _ in 0..<140 {
            guard let here = focusedElements().first else {
                remote.press(.down); usleep(700_000); presses += 1; continue
            }
            if here.label == target.label && abs(here.frame.minY - target.frame.minY) < 2 {
                print("[pass86] FOCUS[\(tag)] on target after \(presses) press(es): \(describe(here))")
                return
            }
            let there = target.frame
            if here.frame.minY < Self.headerBottom { remote.press(.down) }
            else if here.frame.minX > there.minX + 40 && abs(here.frame.midY - there.midY) > 2 && here.frame.minX > 560 { remote.press(.left) }
            else if there.midY > here.frame.maxY { remote.press(.down) }
            else if there.midY < here.frame.minY { remote.press(.up) }
            else { remote.press(.left) }
            presses += 1
            usleep(700_000)
        }
        XCTFail("[\(tag)] could not focus the target after \(presses) presses; focus=\(focusLabels()) target=\(describe(target))")
    }

    /// Wait until a logo channel's label has lost its leading initials — the tile is an image now.
    @discardableResult
    private func waitForLogo(_ cell: XCUIElement, initials: String, _ tag: String) -> Bool {
        for second in 0..<60 {
            if cell.exists && !cell.label.hasPrefix("\(initials), ") {
                print("[pass86] LOGO[\(tag)] drawn after ~\(second) s: \(describe(cell))")
                return true
            }
            sleep(1)
        }
        print("[pass86] LOGO[\(tag)] still the initials tile after 60 s: \(describe(cell))")
        return false
    }

    // MARK: The one device run

    func testTheGuideDrawsLogosOnTheirBackingAndTheInitialsTileWithoutOne() {
        openGuide()
        let found = collectionsButton()?.label ?? "ABSENT"
        print("[pass86] OPEN collections=\(found) focus=\(focusLabels())")
        if found != "All Channels" {
            choose("All Channels")
            print("[pass86] SWITCHED to All Channels from \(found); now \(collectionsButton()?.label ?? "ABSENT")")
        }
        XCTAssertEqual(collectionsButton()?.label, "All Channels", "the Guide is not on All Channels")

        let wjz = channelCell("WJZ-TV", "13.1")
        let wbff = channelCell("WBFF45", "45.1")
        let fox = channelCell("FOX", "9000")
        let cbs = channelCell("CBS", "9000")
        let infomercials = channelCell("AS-INFOMERCIALS", "9023")

        // ---- 86a: a white antenna logo on its backing
        XCTAssertTrue(waitForLogo(wjz, initials: "WJ", "13.1"), "WJZ-TV's logo never replaced its initials tile")
        XCTAssertTrue(waitForLogo(wbff, initials: "WB", "45.1"), "WBFF45's logo never replaced its initials tile")
        focus(wbff, "86a")
        sleep(2)
        shot("86a-white-antenna-logos-on-their-backing")
        print("[pass86] 86a 13.1=\(describe(wjz)) 45.1=\(describe(wbff)) focus=\(focusLabels())")

        // ---- 86b: a black provider logo on its backing
        focus(fox, "86b")
        XCTAssertTrue(waitForLogo(fox, initials: "FO", "FOX 9000"), "FOX's logo never replaced its initials tile")
        XCTAssertTrue(waitForLogo(cbs, initials: "CB", "CBS 9000"), "CBS's logo never replaced its initials tile")
        sleep(2)
        shot("86b-black-provider-logos-on-their-backing")
        print("[pass86] 86b FOX=\(describe(fox)) CBS=\(describe(cbs)) focus=\(focusLabels())")

        // ---- 86c: no logo, the initials tile
        focus(infomercials, "86c")
        sleep(2)
        shot("86c-no-logo-the-initials-tile")
        print("[pass86] 86c 9023=\(describe(infomercials)) focus=\(focusLabels())")
        XCTAssertTrue(infomercials.label.hasPrefix("AS, "),
                      "AS-INFOMERCIALS should draw its initials tile; label=\(infomercials.label)")

        // Read, not photographed: the Marlin Cast rows, one of whose logos is an .svg URL (Pass 85 §10 Q3).
        for (name, number, initials) in [("NFL Network", "50000", "NF"), ("Golf Channel", "50001", "GO"), ("Science Channel", "50002", "SC")] {
            let cell = channelCell(name, number)
            let tile = cell.exists && cell.label.hasPrefix("\(initials), ") ? "initials tile" : "logo"
            print("[pass86] READ \(number) \(name): \(tile) — \(describe(cell))")
        }

        // Leave the device as it was found.
        if found != "All Channels" && found != "ABSENT" {
            choose(found)
            print("[pass86] RESTORED collections=\(collectionsButton()?.label ?? "ABSENT")")
            XCTAssertEqual(collectionsButton()?.label, found, "the Guide was not put back on \(found)")
        }
    }
}
