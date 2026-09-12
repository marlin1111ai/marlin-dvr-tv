//
//  GuideCollectionsUITests.swift
//  Marlin DVR TVUITests
//
//  Pass 72's evidence harness. Not a standing test: it needs the physical Apple TV, the real
//  Siri Remote, and the owner's live server with its "Local" collection.
//
//  **It creates, changes or deletes nothing on the server.** The reads it drives are all GETs —
//  the guide, the schedule, and GET /api/collections. Nothing is recorded, no pass is created, no
//  collection is created, changed or deleted, and the airing sheet is never opened. The one
//  non-GET request is the `POST /api/clients/{id}/ping` the app itself sends on every launch
//  (`ClientSession.swift:62-81`), which these tests trigger once per `app.launch()`.
//
//  Run:
//    xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
//      -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates test \
//      -only-testing:"Marlin DVR TVUITests/GuideCollectionsUITests"
//

import XCTest

final class GuideCollectionsUITests: XCTestCase {
    private var app: XCUIApplication!
    private let remote = XCUIRemote.shared

    /// The header's band. Measured on Home Theater: the title draws at y 60-122 and the pills at
    /// y 79-123, while the grid's first row starts at y 238 — so 200 separates them and 260 does
    /// not. Getting this wrong made the walk to the button mistake row 1 for the header.
    static let headerBottom: CGFloat = 200

    /// Drawn by the Guide's legend whatever the grid holds — the marker that the screen is up.
    private let guideLegend = "Recording or set to record"
    /// Only on the On Later screen.
    private let onLaterSubtitle = "New, premiere, live, finale and movie airings"
    /// The name of the owner's one collection today.
    private let localName = "Local"

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launch()
    }

    // MARK: evidence helpers

    private func shot(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    /// **Every query here is a predicate, never an enumeration.** The Guide's grid is a plain
    /// `VStack` inside a `ScrollView`, so all 91 channel rows are realised at once: walking
    /// `descendants(matching: .any).allElementsBoundByIndex` resolves 585+ elements at roughly
    /// 0.8 s each and the test never finishes. Measured on Home Theater, 2026-09-12.
    private func focusedElements() -> [XCUIElement] {
        app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == YES")).allElementsBoundByIndex
    }

    private func focusLabels() -> [String] {
        focusedElements().map { "\($0.elementType.rawValue):\($0.label)" }
    }

    /// The five members of the owner's "Local" collection, in the order the server returns
    /// them (`GET /api/guide?filter=col-1788571411827`, read live on 2026-09-12), and two
    /// channels that are not members. A channel cell's accessibility label ends in its channel
    /// number — "WM, WMAR-HD, 2.1" — which makes an exact, cheap predicate.
    private let localRows = [("WMAR-HD", "2.1"), ("WGAL-TV", "8.1"), ("WBAL-DT", "11.1"), ("WJZ-TV", "13.1"), ("ESPN", "50007")]
    private let notInLocal = [("WBFF45", "45.1"), ("CWWNUV", "54.1")]

    private func channelCell(_ number: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label ENDSWITH %@", ", \(number)")).firstMatch
    }

    /// The collection's members as they are drawn, top to bottom, with the ones that are
    /// missing named. Targeted queries only.
    private func localRowOrder() -> [String] {
        localRows
            .map { (name: $0.0, element: channelCell($0.1)) }
            .filter { $0.element.exists }
            .sorted { $0.element.frame.minY < $1.element.frame.minY }
            .map(\.name)
    }

    /// The header's collections button, whatever it currently reads.
    private func collectionsButton() -> XCUIElement? {
        for label in ["All Channels", localName] {
            let element = app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
            if element.exists && element.frame.minY < Self.headerBottom { return element }
        }
        return nil
    }

    private func collectionsButtonLabel() -> String {
        collectionsButton()?.label ?? "ABSENT"
    }

    private func dump(_ tag: String) {
        print("DUMP[\(tag)] collectionsButton=\(collectionsButtonLabel())")
        print("DUMP[\(tag)] focused=\(focusLabels())")
        print("DUMP[\(tag)] buttonsOnScreen=\(app.buttons.count)")
        print("DUMP[\(tag)] localMembersDrawn=\(localRowOrder())")
        print("DUMP[\(tag)] nonMembersDrawn=\(notInLocal.filter { channelCell($0.1).exists }.map(\.0))")
    }

    // MARK: navigation

    /// Home's first tile is the Guide (`Destination.homeTiles`), so one Select opens it.
    private func openGuide() {
        XCTAssertTrue(app.staticTexts["Marlin"].waitForExistence(timeout: 40), "Home did not appear")
        sleep(3)
        remote.press(.select)
        XCTAssertTrue(app.staticTexts[guideLegend].waitForExistence(timeout: 40), "the Guide did not open")
        sleep(5)
    }

    /// The rail is the left edge of the screen; the content area starts at x≈236.
    private func focusIsInTheRail() -> Bool {
        focusedElements().contains { $0.frame.minX < 200 }
    }

    private func focusIsOnTheCollectionsButton() -> Bool {
        focusedElements().contains {
            ($0.label == "All Channels" || $0.label == localName) && $0.frame.minY < Self.headerBottom
        }
    }

    private func focusIsInTheHeader() -> Bool {
        focusedElements().contains { $0.frame.minY < Self.headerBottom && $0.frame.minX > 200 }
    }

    /// Into the rail, however many Lefts that takes: from a programme cell the first Left only
    /// moves to the channel cell in the same row.
    private func enterTheRail(_ tag: String) {
        for press in 1...4 {
            if focusIsInTheRail() {
                print("RAIL[\(tag)] in the rail after \(press - 1) Left press(es): \(focusLabels())")
                return
            }
            remote.press(.left); sleep(2)
            print("RAIL[\(tag)] Left \(press) -> \(focusLabels())")
        }
        XCTAssertTrue(focusIsInTheRail(), "could not reach the rail; focus=\(focusLabels())")
    }

    /// Walk to the header's collections button from wherever focus is, reporting every press:
    /// Up until focus is in the header, then Left along it. This is step 2's claim measured —
    /// the button is reachable by the same path the existing header pills are.
    @discardableResult
    private func reachTheCollectionsButton(_ tag: String) -> Int? {
        var steps = 0
        for _ in 0..<7 {
            if focusIsOnTheCollectionsButton() { break }
            if focusIsInTheHeader() { break }
            if focusIsInTheRail() { remote.press(.right); sleep(2); steps += 1 }
            else { remote.press(.up); sleep(1); steps += 1 }
            print("REACH[\(tag)] step \(steps) -> \(focusLabels())")
        }
        for _ in 0..<7 {
            if focusIsOnTheCollectionsButton() {
                print("REACH[\(tag)] the collections button has focus after \(steps) press(es): \(focusLabels())")
                return steps
            }
            remote.press(.left); sleep(1); steps += 1
            print("REACH[\(tag)] step \(steps) (left) -> \(focusLabels())")
            if focusIsInTheRail() {
                remote.press(.right); sleep(2); steps += 1
                print("REACH[\(tag)] step \(steps) (back from the rail) -> \(focusLabels())")
                break
            }
        }
        if focusIsOnTheCollectionsButton() {
            print("REACH[\(tag)] the collections button has focus after \(steps) press(es): \(focusLabels())")
            return steps
        }
        print("REACH[\(tag)] NOT reached in \(steps) presses; focus=\(focusLabels())")
        return nil
    }

    /// Open the drop-down and wait for the read behind it to land.
    private func openTheOverlay(_ tag: String) {
        XCTAssertNotNil(reachTheCollectionsButton(tag), "could not put focus on the collections button")
        remote.press(.select)
        XCTAssertTrue(app.staticTexts["Show in the Guide"].waitForExistence(timeout: 20), "the overlay did not open")
        sleep(4)   // the GET /api/collections behind it, then the focus move to the selection
    }

    /// Choose a row of the open overlay by walking to it and pressing Select.
    private func chooseRow(_ title: String, _ tag: String, maxSteps: Int = 8) {
        for step in 0...maxSteps {
            let focus = focusLabels()
            if focus.contains(where: { $0.contains(title) }) {
                print("CHOOSE[\(tag)] \u{201C}\(title)\u{201D} has focus after \(step) step(s): \(focus)")
                remote.press(.select)
                sleep(6)
                return
            }
            if step == maxSteps { break }
            remote.press(title == "All Channels" ? .up : .down); sleep(1)
        }
        XCTFail("could not reach the \u{201C}\(title)\u{201D} row; focus=\(focusLabels())")
    }

    // MARK: (a) and (b) — the header and the drop-down

    func testTheHeaderButtonAndTheOverlay() {
        openGuide()
        // Whatever a previous run left behind, start from All Channels.
        if collectionsButtonLabel() != "All Channels" {
            openTheOverlay("reset")
            chooseRow("All Channels", "reset")
        }

        dump("a-header")
        shot("72a-guide-header-all-channels")

        // (a) the button, the date range beside it, the pills still on the right.
        let button = collectionsButton()
        XCTAssertNotNil(button, "the collections button is not in the tree")
        XCTAssertEqual(button?.label, "All Channels", "the button does not read All Channels with nothing selected")
        let title = app.staticTexts.matching(NSPredicate(format: "label == %@", "Guide"))
            .allElementsBoundByIndex.first { $0.frame.minX > 200 }
        XCTAssertNotNil(title, "the Guide title is not in the content area")
        // The window label — "Sat Sep 12 · 11:30 PM – 1:30 AM". The spaced en dash is unique
        // to it, which keeps this a predicate rather than a walk of the whole grid.
        let range = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", " \u{2013} "))
            .allElementsBoundByIndex.first { $0.frame.minY < Self.headerBottom && $0.frame.minX > 200 }
        print("HEADER title=\(title!.frame) button=\(button!.frame) dateRange=\(range.map { "\($0.label) \($0.frame)" } ?? "ABSENT")")
        XCTAssertNotNil(range, "the date range is not beside the button")
        XCTAssertTrue(title!.frame.maxX <= button!.frame.minX, "the button is not after the title")
        XCTAssertTrue(button!.frame.maxX <= range!.frame.minX, "the date range is not after the button")

        // Reachable from the rail as well as from the grid: go out and come back in.
        enterTheRail("header-test")
        print("RAIL focus in the rail: \(focusLabels())")
        remote.press(.right); sleep(2)
        print("RAIL focus back in the content: \(focusLabels())")
        let fromRail = reachTheCollectionsButton("from-rail")
        XCTAssertNotNil(fromRail, "the collections button cannot be reached coming in from the rail")
        shot("72a2-collections-button-focused-from-the-rail")

        // (b) the overlay.
        remote.press(.select)
        XCTAssertTrue(app.staticTexts["Show in the Guide"].waitForExistence(timeout: 20), "the overlay did not open")
        sleep(4)
        shot("72b-overlay-open")
        print("OVERLAY focused=\(focusLabels())")
        // The card sits below the header, so position separates the overlay's own
        // "All Channels" row from the header button that reads the same.
        let allRow = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "All Channels"))
            .allElementsBoundByIndex.first { $0.frame.minY > 260 }
        let localRow = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", localName))
            .allElementsBoundByIndex.first { $0.frame.minY > 260 }
        print("OVERLAY allChannelsRow=\(allRow.map { "\($0.label) \($0.frame)" } ?? "ABSENT")")
        print("OVERLAY localRow=\(localRow.map { "\($0.label) \($0.frame)" } ?? "ABSENT")")
        XCTAssertNotNil(allRow, "the overlay does not list All Channels")
        XCTAssertNotNil(localRow, "the overlay does not list \(localName)")
        XCTAssertTrue(allRow!.frame.minY < localRow!.frame.minY, "All Channels is not the first row")
        // Focus lands on the current selection, which is All Channels here.
        XCTAssertTrue(allRow!.hasFocus, "focus did not land on the current selection")

        // Menu closes it with no change.
        remote.press(.menu); sleep(3)
        shot("72b2-overlay-closed-by-menu")
        dump("b-after-menu")
        XCTAssertFalse(app.staticTexts["Show in the Guide"].exists, "Menu did not close the overlay")
        XCTAssertTrue(app.staticTexts[guideLegend].exists, "Menu closed the Guide instead of the overlay")
        XCTAssertEqual(collectionsButtonLabel(), "All Channels", "Menu changed the selection")
        XCTAssertFalse(focusLabels().isEmpty, "nothing has focus after Menu closed the overlay")
    }

    // MARK: (c), (d), (e) — the filtered grid, paging while filtered, and back

    func testChoosingACollectionFiltersTheGridAndComingBack() {
        openGuide()
        if collectionsButtonLabel() != "All Channels" {
            openTheOverlay("reset")
            chooseRow("All Channels", "reset")
        }
        let unfilteredButtons = app.buttons.count
        print("FILTER unfiltered: buttons=\(unfilteredButtons) nonMembersDrawn=\(notInLocal.filter { channelCell($0.1).exists }.map(\.0))")
        for (name, number) in notInLocal {
            XCTAssertTrue(channelCell(number).exists, "\(name) is missing from the unfiltered grid")
        }
        shot("72c0-grid-all-channels")

        // (c) choose Local.
        openTheOverlay("pick-local")
        chooseRow(localName, "pick-local")
        shot("72c-grid-filtered-to-local")
        dump("c-filtered")
        XCTAssertEqual(collectionsButtonLabel(), localName, "the button does not read \(localName)")
        let filtered = localRowOrder()
        let filteredButtons = app.buttons.count
        print("FILTER filtered: order=\(filtered) buttons=\(filteredButtons) (was \(unfilteredButtons))")
        XCTAssertEqual(filtered, localRows.map(\.0), "the collection's five rows are missing or out of the server's order")
        for (name, number) in notInLocal {
            XCTAssertFalse(channelCell(number).exists, "\(name) is not in the collection but is still drawn")
        }
        XCTAssertLessThan(filteredButtons, unfilteredButtons, "the grid did not shrink")
        XCTAssertFalse(focusLabels().isEmpty, "nothing has focus after the filtered reload")

        // (d) +12h, then back to now, while filtered.
        XCTAssertNotNil(reachTheCollectionsButton("before-page"), "lost the header")
        remote.press(.right); sleep(1)
        print("PAGE focus right of the button: \(focusLabels())")
        remote.press(.right); sleep(1)
        print("PAGE focus right again: \(focusLabels())")
        if focusLabels().contains(where: { $0.contains("+12h") }) {
            remote.press(.select); sleep(6)
            shot("72d-plus-12h-while-filtered")
            dump("d-paged")
            let paged = localRowOrder()
            print("PAGE rows after +12h: \(paged)")
            XCTAssertEqual(collectionsButtonLabel(), localName, "+12h lost the collection")
            XCTAssertEqual(paged, localRows.map(\.0), "+12h changed the row set")
            for (name, number) in notInLocal {
                XCTAssertFalse(channelCell(number).exists, "+12h brought \(name) back into a filtered grid")
            }
            XCTAssertFalse(focusLabels().isEmpty, "nothing has focus after +12h")

            remote.press(.menu); sleep(6)   // Menu at not-now snaps back to now
            shot("72d2-back-at-now-while-filtered")
            dump("d-snapped")
            let back = localRowOrder()
            print("PAGE rows after snapping back: \(back)")
            XCTAssertEqual(collectionsButtonLabel(), localName, "snapping back to now lost the collection")
            XCTAssertEqual(back, filtered, "the rows changed on the way back to now")
            for (name, number) in notInLocal {
                XCTAssertFalse(channelCell(number).exists, "\u{21A9} Now brought \(name) back into a filtered grid")
            }
        } else {
            print("PAGE +12h is not drawn - focus=\(focusLabels())")
            shot("72d-no-plus-12h")
        }

        // (e) back to All Channels.
        openTheOverlay("pick-all")
        chooseRow("All Channels", "pick-all")
        shot("72e-grid-back-to-all-channels")
        dump("e-unfiltered")
        XCTAssertEqual(collectionsButtonLabel(), "All Channels", "the button did not go back to All Channels")
        let restoredButtons = app.buttons.count
        print("FILTER restored: buttons=\(restoredButtons) (unfiltered was \(unfilteredButtons))")
        for (name, number) in notInLocal {
            XCTAssertTrue(channelCell(number).exists, "\(name) did not come back with All Channels")
        }
        XCTAssertGreaterThan(restoredButtons, filteredButtons, "the full grid did not come back")
        XCTAssertFalse(focusLabels().isEmpty, "nothing has focus after going back to All Channels")
    }

    // MARK: (f) — the selection survives a trip to the rail

    func testTheCollectionSurvivesATripToTheRail() {
        openGuide()
        openTheOverlay("survive-pick")
        chooseRow(localName, "survive-pick")
        let before = localRowOrder()
        print("SURVIVE before: \(before)")
        XCTAssertEqual(before, localRows.map(\.0), "the pick did not take")
        shot("72f0-filtered-before-the-rail-trip")

        // Out to the rail, down to Radio, play nothing, back up to the Guide, back in.
        enterTheRail("survive-out")
        for _ in 0..<5 { remote.press(.down); usleep(700_000) }   // Guide(3) -> Radio(8)
        sleep(1)
        remote.press(.select); sleep(8)
        shot("72f1-radio")
        print("SURVIVE on Radio: focus=\(focusLabels())")
        enterTheRail("survive-back")
        for _ in 0..<5 { remote.press(.up); usleep(700_000) }     // Radio(8) -> Guide(3)
        sleep(1)
        remote.press(.select)
        XCTAssertTrue(app.staticTexts[guideLegend].waitForExistence(timeout: 40), "the Guide did not come back")
        sleep(6)
        shot("72f2-back-on-the-guide-still-filtered")
        dump("f-after-rail-trip")
        XCTAssertEqual(collectionsButtonLabel(), localName, "the collection did not survive the trip to the rail")
        let after = localRowOrder()
        print("SURVIVE after: \(after)")
        XCTAssertEqual(after, before, "the rows changed over the trip to the rail")
        for (name, number) in notInLocal {
            XCTAssertFalse(channelCell(number).exists, "the Guide came back unfiltered - \(name) is drawn")
        }
    }

    // MARK: (g) — the selection survives a relaunch

    func testTheCollectionSurvivesARelaunch() {
        openGuide()
        openTheOverlay("relaunch-pick")
        chooseRow(localName, "relaunch-pick")
        let before = localRowOrder()
        print("RELAUNCH before: \(before)")
        XCTAssertEqual(collectionsButtonLabel(), localName, "the pick did not take")
        shot("72g0-filtered-before-the-relaunch")

        app.terminate()
        sleep(4)
        app.launch()
        XCTAssertTrue(app.staticTexts["Marlin"].waitForExistence(timeout: 60), "Home did not come back")
        sleep(3)
        remote.press(.select)
        XCTAssertTrue(app.staticTexts[guideLegend].waitForExistence(timeout: 40), "the Guide did not open after the relaunch")
        sleep(6)
        shot("72g-guide-opens-on-local-after-a-relaunch")
        dump("g-after-relaunch")
        XCTAssertEqual(collectionsButtonLabel(), localName, "the Guide did not open on \(localName) after a relaunch")
        let after = localRowOrder()
        print("RELAUNCH after: \(after)")
        XCTAssertEqual(after, before, "the Guide opened on a different row set after the relaunch")
        for (name, number) in notInLocal {
            XCTAssertFalse(channelCell(number).exists, "the Guide opened unfiltered - \(name) is drawn")
        }

        // Leave the device on All Channels, so a later run starts where the owner left it.
        openTheOverlay("relaunch-reset")
        chooseRow("All Channels", "relaunch-reset")
        XCTAssertEqual(collectionsButtonLabel(), "All Channels", "could not put it back to All Channels")
    }

    // MARK: (h) — two screens that pass nothing into the new slot

    /// Step 1's proof. Run once on the code before the change and once after: the two headers
    /// must be pixel-identical, and the frames printed here identical to the point.
    func testTwoUnchangedScreens() {
        XCTAssertTrue(app.staticTexts["Marlin"].waitForExistence(timeout: 40), "Home did not appear")
        sleep(3)
        remote.press(.select)                                  // Guide, tile 0
        XCTAssertTrue(app.staticTexts[guideLegend].waitForExistence(timeout: 40), "the Guide did not open")
        sleep(4)

        enterTheRail("unchanged-1")                            // into the rail, on Guide (3)
        remote.press(.down); sleep(1)                          // On Later (4)
        remote.press(.select)
        XCTAssertTrue(app.staticTexts[onLaterSubtitle].waitForExistence(timeout: 40), "On Later did not load")
        sleep(5)
        shot("72h1-on-later")
        reportHeader("On Later", subtitle: onLaterSubtitle)

        enterTheRail("unchanged-2")
        remote.press(.down); sleep(1)                          // Recordings (5)
        remote.press(.down); sleep(1)                          // Cameras (6)
        remote.press(.select)
        XCTAssertTrue(app.staticTexts["Cameras"].waitForExistence(timeout: 40), "Cameras did not load")
        sleep(6)
        shot("72h2-cameras")
        reportHeader("Cameras", subtitle: nil)
    }

    /// Print the header's own geometry, so "unchanged" is a number and not an impression.
    private func reportHeader(_ title: String, subtitle: String?) {
        let heading = app.staticTexts.matching(NSPredicate(format: "label == %@", title))
            .allElementsBoundByIndex.first { $0.frame.minX > 200 }
        print("UNCHANGED[\(title)] title=\(heading.map { "\($0.frame)" } ?? "ABSENT")")
        if let subtitle {
            let s = app.staticTexts[subtitle].firstMatch
            print("UNCHANGED[\(title)] subtitle=\(s.exists ? "\(s.frame)" : "ABSENT")")
        } else {
            // Cameras' subtitle is "<n> of <n> online", computed from the server.
            let s = app.staticTexts.allElementsBoundByIndex.first { $0.label.hasSuffix(" online") && $0.frame.minY < Self.headerBottom }
            print("UNCHANGED[\(title)] subtitle=\(s.map { "\($0.label) \($0.frame)" } ?? "ABSENT")")
        }
        for b in app.buttons.allElementsBoundByIndex where b.frame.minY < Self.headerBottom {
            print("UNCHANGED[\(title)] header button \(b.label) \(b.frame)")
        }
        XCTAssertNotNil(heading, "the \(title) header is not in the content area")
    }
}
