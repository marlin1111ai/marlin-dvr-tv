//
//  RailFocusRestoreUITests.swift
//  Marlin DVR TVUITests
//
//  Pass 25's evidence harness, not a standing test. Pass 24 proved on this same Apple TV that
//  swiping left out of a screen lands on the rail icon nearest the vertical centre of whatever
//  the content had focused — 2 of 9 entries right, 7 wrong, identical over three rounds. Pass 25
//  restores focus to the entry of the screen that is open, and this harness is what says so:
//  it drives the real Siri Remote, opens every rail-drawing entry, swipes back left, and reads
//  the focused element's own label and frame off the device.
//
//  It also covers the two paths Pass 24 never tested — the periodic reloads on On Now (60 s) and
//  Cameras (45 s), and one Player round trip — because both can move focus without the remote.
//
//  It makes no server write. The one thing it starts is a camera stream, which is the app's own
//  Player path and holds no tuner.
//

import XCTest

final class RailFocusRestoreUITests: XCTestCase {
    private var app: XCUIApplication!
    private let remote = XCUIRemote.shared

    /// The rail as `Destination.railOrder` draws it (Pass 24 §2.1 counted these ten on screen).
    private static let rail = ["Home", "Favorites", "On Now", "Guide", "On Later",
                              "Recordings", "Cameras", "Weather", "Radio", "Manage DVR"]
    /// The nine that open a screen with a rail to come back to. Home draws no rail (dc:111).
    private static let testable = Array(1..<rail.count)

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    // MARK: reading the device

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// The focused rail entry, or nil when focus is anywhere else. The rail's buttons are the
    /// only ones that start inside the first 150 pt of the screen: expanded they sit at x=80-102,
    /// and the content beside the rail starts at x=188 at the earliest (Pass 24 §2.3, §4.2).
    private func focusedRailEntry() -> (label: String, frame: CGRect)? {
        let focused = app.buttons.matching(NSPredicate(format: "hasFocus == true")).allElementsBoundByIndex
        for element in focused where element.frame.minX < 150 {
            return (element.label, element.frame)
        }
        return nil
    }

    /// What has focus at all, rail or content — for the log, so a failure says where it went.
    private func focusedAnything() -> String {
        let buttons = app.buttons.matching(NSPredicate(format: "hasFocus == true")).allElementsBoundByIndex
        if let first = buttons.first { return "\(first.label) \(rect(first.frame))" }
        let others = app.otherElements.matching(NSPredicate(format: "hasFocus == true")).allElementsBoundByIndex
        if let first = others.first { return "other:\(first.label) \(rect(first.frame))" }
        let texts = app.staticTexts.matching(NSPredicate(format: "hasFocus == true")).allElementsBoundByIndex
        if let first = texts.first { return "text:\(first.label) \(rect(first.frame))" }
        return "nothing"
    }

    private func rect(_ f: CGRect) -> String {
        "(\(Int(f.minX)),\(Int(f.minY)) \(Int(f.width))x\(Int(f.height)))"
    }

    // MARK: driving the remote

    /// Press Left until a rail entry has focus. Every screen needs one press; the Guide needs two,
    /// because its default focus is a programme cell and the first press reaches the channel cell
    /// (Pass 24 §2.3). Returns the entry it landed on.
    @discardableResult
    private func swipeLeftIntoRail(_ tag: String) -> (label: String, frame: CGRect)? {
        for press in 1...5 {
            if let entry = focusedRailEntry() {
                print("RAIL[\(tag)] reached the rail after \(press - 1) Left presses")
                return entry
            }
            remote.press(.left)
            usleep(900_000)
        }
        let entry = focusedRailEntry()
        print("RAIL[\(tag)] after 5 Left presses focus is: \(focusedAnything())")
        return entry
    }

    /// Walk the rail to `index` from wherever it is now, and confirm the label before selecting.
    private func moveInRail(to index: Int) {
        guard let here = focusedRailEntry(), let from = Self.rail.firstIndex(of: here.label) else {
            XCTFail("not in the rail — focus is \(focusedAnything())")
            return
        }
        let delta = index - from
        for _ in 0..<abs(delta) {
            remote.press(delta > 0 ? .down : .up)
            usleep(700_000)
        }
        XCTAssertEqual(focusedRailEntry()?.label, Self.rail[index],
                       "walking the rail did not reach \(Self.rail[index])")
    }

    /// Wait until focus has left the rail — the new screen's content claiming it.
    @discardableResult
    private func waitForContentFocus(timeout: Int) -> Bool {
        for _ in 0..<timeout {
            if focusedRailEntry() == nil { return true }
            sleep(1)
        }
        return false
    }

    // MARK: the pass's question

    func testEveryRailEntryLandsOnItself() {
        XCTAssertTrue(app.staticTexts["Marlin"].waitForExistence(timeout: 60), "Home did not appear")

        // Into the shell through the Guide tile, which is where Home's focus starts.
        remote.press(.select)
        XCTAssertTrue(app.staticTexts["Guide"].waitForExistence(timeout: 40), "the Guide did not open")
        sleep(3)

        var results: [(round: Int, entry: String, landedOn: String, frame: String)] = []

        for round in 1...3 {
            for index in Self.testable {
                let name = Self.rail[index]
                let tag = "r\(round)/\(name)"

                // Get into the rail, walk to the entry, open it.
                guard swipeLeftIntoRail(tag) != nil else {
                    XCTFail("\(tag): could not reach the rail to start"); return
                }
                moveInRail(to: index)
                remote.press(.select)
                sleep(4)
                XCTAssertTrue(waitForContentFocus(timeout: 25),
                              "\(tag): the screen opened but focus never left the rail")
                sleep(1)
                let contentFocus = focusedAnything()

                // Swipe back left. This is the pass.
                let landed = swipeLeftIntoRail(tag)
                let label = landed?.label ?? "NOTHING"
                print("RAILRESTORE[\(tag)] content had \(contentFocus) → landed on '\(label)' \(landed.map { rect($0.frame) } ?? "")")
                results.append((round, name, label, landed.map { rect($0.frame) } ?? "-"))
                if round == 1 {
                    shot(String(format: "%02d-%@-lands-on-itself", index, name.replacingOccurrences(of: " ", with: "-").lowercased()))
                }
                XCTAssertEqual(label, name, "\(tag): swipe left landed on '\(label)', not '\(name)'")
            }
        }

        print("RAILRESTORE TABLE round | entry | landed on | frame")
        for r in results { print("RAILRESTORE TABLE \(r.round) | \(r.entry) | \(r.landedOn) | \(r.frame)") }
        let wrong = results.filter { $0.entry != $0.landedOn }
        print("RAILRESTORE TOTAL \(results.count) attempts, \(results.count - wrong.count) correct, \(wrong.count) wrong")
        XCTAssertTrue(wrong.isEmpty, "\(wrong.count) of \(results.count) landings were wrong")
    }

    /// Home is the tenth entry and the one exception: it draws no rail (dc:111), so there is
    /// nothing to swipe back to. Asserted rather than assumed.
    func testHomeStillDrawsNoRail() {
        XCTAssertTrue(app.staticTexts["Marlin"].waitForExistence(timeout: 60), "Home did not appear")
        remote.press(.select)
        XCTAssertTrue(app.staticTexts["Guide"].waitForExistence(timeout: 40), "the Guide did not open")
        sleep(3)
        swipeLeftIntoRail("home")
        moveInRail(to: 0)
        remote.press(.select)
        sleep(4)
        shot("10-home-from-the-rail-draws-no-rail")

        // Home is a different view, not the shell with the rail hidden: `ContentView` swaps
        // `HomeView` in for `ScreenShell`. The greeting is Home's and only Home's.
        let greeting = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Good '")).firstMatch
        XCTAssertTrue(greeting.waitForExistence(timeout: 20),
                      "selecting Home did not leave the shell — focus is \(focusedAnything())")

        // And no rail is drawn. Home's own tiles also start inside the first 150 pt, so the
        // rail is told apart by its width: entries are 258 pt expanded and 64 pt collapsed,
        // where a Home tile spans a third of the 1920 pt screen.
        let narrow = app.buttons.allElementsBoundByIndex
            .filter { $0.frame.minX < 150 && $0.frame.width < 300 }
        print("RAILHOME greeting='\(greeting.label)' narrow-left-buttons=\(narrow.count) focus=\(focusedAnything())")
        for b in narrow { print("RAILHOME leftover rail-shaped button: '\(b.label)' \(rect(b.frame))") }
        XCTAssertTrue(narrow.isEmpty, "Home is drawing a rail, which the design says it must not (dc:111)")
    }

    /// On Now reloads every 60 s and Cameras every 45 s. Neither may move focus — not while the
    /// remote is parked in the rail, and not while it is in the content.
    func testReloadsDoNotMoveFocus() {
        XCTAssertTrue(app.staticTexts["Marlin"].waitForExistence(timeout: 60), "Home did not appear")
        remote.press(.select)
        XCTAssertTrue(app.staticTexts["Guide"].waitForExistence(timeout: 40), "the Guide did not open")
        sleep(3)

        for (index, name, wait) in [(2, "On Now", 75), (6, "Cameras", 55)] {
            swipeLeftIntoRail("open-\(name)")
            moveInRail(to: index)
            remote.press(.select)
            sleep(4)
            XCTAssertTrue(waitForContentFocus(timeout: 25), "\(name): focus never left the rail")

            // (a) parked in the rail across a reload.
            guard let parked = swipeLeftIntoRail("\(name)-park") else {
                XCTFail("\(name): could not reach the rail"); return
            }
            XCTAssertEqual(parked.label, name, "\(name): the swipe left did not land on itself")
            print("RELOAD[\(name)] parked in the rail on '\(parked.label)'; watching for \(wait) s")
            for t in stride(from: 5, through: wait, by: 5) {
                sleep(5)
                print("RELOAD[\(name)] t=\(t)s rail focus='\(focusedRailEntry()?.label ?? "NONE")' subtitle='\(subtitle(for: name))'")
            }
            shot("2\(index)-\(name.replacingOccurrences(of: " ", with: "-").lowercased())-rail-focus-after-a-reload")
            XCTAssertEqual(focusedRailEntry()?.label, name,
                           "\(name): a reload moved focus out of the rail entry it was parked on")

            // (b) in the content across a reload, then back left.
            remote.press(.right)
            sleep(2)
            XCTAssertNil(focusedRailEntry(), "\(name): Right did not move focus into the content")
            let before = focusedAnything()
            print("RELOAD[\(name)] in the content on \(before); watching for \(wait) s")
            for t in stride(from: 5, through: wait, by: 5) {
                sleep(5)
                print("RELOAD[\(name)] t=\(t)s content focus='\(focusedAnything())' subtitle='\(subtitle(for: name))'")
            }
            let after = focusedAnything()
            XCTAssertEqual(before, after, "\(name): a reload moved focus inside the content")
            let landed = swipeLeftIntoRail("\(name)-after-reload")
            print("RELOAD[\(name)] after a reload cycle in the content, swipe left landed on '\(landed?.label ?? "NOTHING")'")
            shot("2\(index + 1)-\(name.replacingOccurrences(of: " ", with: "-").lowercased())-lands-on-itself-after-a-reload")
            XCTAssertEqual(landed?.label, name, "\(name): after a reload the swipe left landed elsewhere")
        }
    }

    /// The screen's own subtitle, which is how the harness sees a reload happen rather than
    /// assuming one did: On Now prints "Refreshed <clock>" and Cameras a snapshot age in seconds.
    private func subtitle(for screen: String) -> String {
        let prefix = screen == "On Now" ? "Refreshed " : "Snapshot age "
        return app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch.label
    }

    /// One Player round trip. A camera, because it is the one Player path that holds no tuner.
    func testFocusSurvivesAPlayerRoundTrip() {
        XCTAssertTrue(app.staticTexts["Marlin"].waitForExistence(timeout: 60), "Home did not appear")
        remote.press(.select)
        XCTAssertTrue(app.staticTexts["Guide"].waitForExistence(timeout: 40), "the Guide did not open")
        sleep(3)

        swipeLeftIntoRail("open-cameras")
        moveInRail(to: 6)
        remote.press(.select)
        sleep(5)
        XCTAssertTrue(waitForContentFocus(timeout: 25), "Cameras: focus never left the rail")
        let card = focusedAnything()
        print("PLAYER content focus before the Player: \(card)")
        shot("30-cameras-before-the-player")

        remote.press(.select)
        sleep(12)
        shot("31-player-up")
        print("PLAYER while the Player is up, focus is: \(focusedAnything())")

        remote.press(.menu)
        sleep(6)
        XCTAssertTrue(app.staticTexts["Cameras"].waitForExistence(timeout: 30),
                      "Menu did not come back to the Cameras screen")
        sleep(2)
        shot("32-back-from-the-player")
        print("PLAYER back on Cameras, focus is: \(focusedAnything())")

        let landed = swipeLeftIntoRail("after-player")
        print("PLAYER after the round trip, swipe left landed on '\(landed?.label ?? "NOTHING")'")
        shot("33-lands-on-cameras-after-the-player")
        XCTAssertEqual(landed?.label, "Cameras",
                       "after a Player round trip the swipe left landed on '\(landed?.label ?? "NOTHING")'")
    }
}
