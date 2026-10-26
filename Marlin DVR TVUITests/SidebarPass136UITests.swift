//
//  SidebarPass136UITests.swift
//  Marlin DVR TVUITests
//
//  Pass 136's evidence harness, not a standing test: the sidebar (logo, Settings at the bottom,
//  Menu opening it and Menu again going Home, the catcher at the boundary), the Settings screen's two
//  panes, and the Guide's Left-at-now and back-step beside the new catcher. It needs the physical
//  Apple TV ("Home Theater") and the owner's server.
//
//  **It makes no server write.** Select is pressed on Home's tiles and on sidebar entries only; in the
//  Guide only Right, Left and Menu are pressed — never Select, never a hold. The only non-GET traffic
//  is the app's own launch ping.
//
//  **`launch()`, not `activate()`** (Pass 92). **Every press here is a click**: XCUITest on tvOS cannot
//  swipe (Pass 108) and cannot hold, so a swipe left and Pass 123's held ring are code-traced only.
//
//  Run:
//    xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
//      -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates test \
//      -only-testing:"Marlin DVR TVUITests/SidebarPass136UITests"
//
//  The Guide helpers are GuideBackStepUITests' (Pass 122), copied so this file runs on its own.
//

import XCTest

final class SidebarPass136UITests: XCTestCase {
    private var app: XCUIApplication!
    private let remote = XCUIRemote.shared

    private static let headerBottom: CGFloat = 200
    /// A rail entry sits at x 80; the first content card, scaled 5 % on focus, starts at about x 190.
    private static let contentLeft: CGFloat = 170
    private static let channelColumnRight: CGFloat = 545
    private static let programmeAreaRight: CGFloat = 1840
    /// The bottom margin: nothing in the sidebar may reach below this.
    private static let bottomMargin: CGFloat = 1080 - 60

    private static let railLabels = ["Home", "Favorites", "On Now", "Guide", "On Later", "Recordings", "Cameras", "Weather", "Radio", "Search", "Manage DVR", "Settings"]
    private static let homeTiles = [["Guide", "On Now", "On Later"], ["Recordings", "Cameras", "Favorites"], ["Weather", "Radio", "Settings"]]

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        log("launched")
    }

    // MARK: reading the device

    private func stamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: Date())
    }

    private func log(_ line: String) { print("[pass136 \(stamp())] \(line)") }

    private func shot(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    private func focusedElements() -> [XCUIElement] {
        app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == YES")).allElementsBoundByIndex
    }

    private func focusLine() -> String {
        let focused = focusedElements()
        if focused.isEmpty { return "NOTHING FOCUSED" }
        return focused.map { f in
            "\(f.elementType.rawValue):\u{201C}\(f.label)\u{201D} (\(Int(f.frame.minX)),\(Int(f.frame.minY)) \(Int(f.frame.width))x\(Int(f.frame.height)))"
        }.joined(separator: " | ")
    }

    private func focusedLabel() -> String? { focusedElements().first?.label }

    private func zone() -> String {
        guard let f = focusedElements().first else { return "nowhere" }
        let r = f.frame
        if r.minX < Self.contentLeft { return "rail" }
        if r.minY < Self.headerBottom { return "header" }
        if r.minX < Self.channelColumnRight { return "grid:channel-cell" }
        return "grid:programme-cell"
    }

    /// The expanded sidebar draws its labels; the collapsed strip draws none. "Manage DVR" is the
    /// one label no screen shares (On Now's filter pills carry "Favorites").
    private func sidebarOpen() -> Bool { app.buttons["Manage DVR"].exists }

    private func waitSidebar(open: Bool, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if sidebarOpen() == open { return true }
            usleep(200_000)
        }
        return sidebarOpen() == open
    }

    private func rect(_ r: CGRect) -> String { "(\(Int(r.minX)),\(Int(r.minY)) \(Int(r.width))x\(Int(r.height)))" }

    // MARK: Home

    private func homeTile(_ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(name), ")).firstMatch
    }

    private func waitForHome() {
        XCTAssertTrue(homeTile("Guide").waitForExistence(timeout: 40), "Home did not appear")
        sleep(3)
    }

    private func tilePosition(of label: String?) -> (Int, Int)? {
        guard let label else { return nil }
        for (r, row) in Self.homeTiles.enumerated() {
            for (c, name) in row.enumerated() where label.hasPrefix("\(name), ") { return (r, c) }
        }
        return nil
    }

    /// Walk the 3 × 3 grid to the tile named, one press at a time, reading focus after each.
    private func focusTile(_ name: String) {
        for _ in 0..<12 {
            guard let here = tilePosition(of: focusedLabel()) else {
                remote.press(.up); usleep(800_000); continue
            }
            var target = (0, 0)
            for (r, row) in Self.homeTiles.enumerated() { if let c = row.firstIndex(of: name) { target = (r, c) } }
            if here == target { return }
            if here.0 < target.0 { remote.press(.down) }
            else if here.0 > target.0 { remote.press(.up) }
            else if here.1 < target.1 { remote.press(.right) }
            else { remote.press(.left) }
            usleep(800_000)
        }
        XCTFail("could not focus Home's \(name) tile; focus=\(focusLine())")
    }

    // MARK: the Guide (GuideBackStepUITests' helpers, Pass 122)

    private func windowLabel() -> String? {
        for needle in [" \u{2013} ", " \u{2192} "] {
            let e = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", needle)).firstMatch
            if e.exists { return e.label }
        }
        return nil
    }

    private func windowPosition() -> Int? {
        guard let label = windowLabel() else { return nil }
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        guard let dateR = label.range(of: "[A-Z][a-z]{2} [0-9]{1,2}", options: .regularExpression) else { return nil }
        let date = String(label[dateR]).split(separator: " ")
        guard date.count == 2, let month = months.firstIndex(of: String(date[0])), let day = Int(date[1]) else { return nil }
        guard let clockR = label.range(of: "[0-9]{1,2}:[0-9]{2}", options: .regularExpression) else { return nil }
        let hm = String(label[clockR]).split(separator: ":")
        guard hm.count == 2, var h = Int(hm[0]), let m = Int(hm[1]) else { return nil }
        let tail = label[clockR.upperBound...]
        let meridiem: String
        if tail.hasPrefix(" AM") { meridiem = "AM" }
        else if tail.hasPrefix(" PM") { meridiem = "PM" }
        else if let r = tail.range(of: "(AM|PM)", options: .regularExpression) { meridiem = String(tail[r]) }
        else { return nil }
        if h == 12 { h = 0 }
        if meridiem == "PM" { h += 12 }
        return ((month * 31) + day) * 1440 + h * 60 + m
    }

    private func stripFirstColumn() -> String? {
        guard let label = windowLabel(),
              let r = label.range(of: "[0-9]{1,2}:[0-9]{2}", options: .regularExpression) else { return nil }
        let clock = String(label[r])
        let e = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", clock)).firstMatch
        return e.exists ? e.label : nil
    }

    private func nowPillDrawn() -> Bool {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "\u{21A9} Now")).firstMatch.exists
    }

    private func stage(_ tag: String) -> String {
        "\(tag) window=\u{201C}\(windowLabel() ?? "NO LABEL")\u{201D} startMin=\(windowPosition().map(String.init) ?? "?") " +
        "strip=\u{201C}\(stripFirstColumn() ?? "?")\u{201D} nowPill=\(nowPillDrawn()) zone=\(zone()) focus=\(focusLine())"
    }

    private func walkToLastCell() -> Bool {
        for _ in 0...14 {
            guard let f = focusedElements().first, f.frame.minX > Self.channelColumnRight,
                  f.frame.minY >= Self.headerBottom else { return false }
            if f.frame.maxX >= Self.programmeAreaRight - 12 { return true }
            remote.press(.right)
            usleep(1_500_000)
        }
        return false
    }

    private func nudgeAhead(_ slots: Int, from start: Int) -> Int {
        var advanced = 0
        for _ in 0..<(slots * 5) {
            remote.press(.right)
            usleep(1_500_000)
            if let now = windowPosition() { advanced = (now - start) / 30 }
            if advanced >= slots { break }
        }
        return advanced
    }

    private func walkLeftToChannelCell(window: Int) -> Bool {
        for i in 0..<12 {
            if zone() == "grid:channel-cell" { return true }
            guard zone() == "grid:programme-cell" else { return false }
            remote.press(.left)
            usleep(1_500_000)
            let w = windowPosition()
            log("walk left #\(i + 1): startMin=\(w.map(String.init) ?? "?") zone=\(zone()) focus=\(focusLine())")
            XCTAssertEqual(w, window, "a Left along the row moved the window")
        }
        return zone() == "grid:channel-cell"
    }

    // MARK: the run

    func testSidebarMenuSettingsAndTheGuideBoundary() {
        waitForHome()
        XCTAssertFalse(sidebarOpen(), "Home draws a sidebar")
        shot("01-home")

        // On Now, then a Left out of its first card.
        focusTile("On Now")
        remote.press(.select)
        XCTAssertTrue(app.staticTexts["On Now"].waitForExistence(timeout: 30), "On Now did not open")
        XCTAssertTrue(waitSidebar(open: false, timeout: 20), "the sidebar did not collapse once On Now had focus; focus=\(focusLine())")
        sleep(2)
        log("ON NOW focus=\(focusLine())")
        XCTAssertNotEqual(zone(), "rail", "focus is not in On Now's content")
        remote.press(.left)
        XCTAssertTrue(waitSidebar(open: true, timeout: 5), "Left did not open the sidebar")
        sleep(1)
        log("LEFT OUT OF ON NOW focus=\(focusLine())")
        XCTAssertEqual(zone(), "rail", "Left did not reach the sidebar")
        XCTAssertEqual(focusedLabel(), "On Now", "the sidebar did not open on On Now")
        shot("02-sidebar-open-by-left")

        // All twelve entries in order, Settings at the bottom under Manage DVR, inside the margin:
        // Up to Home, then Down through the list, reading the focused entry after each press (a
        // lookup by label would also find On Now's own filter pills).
        for _ in 0..<12 {
            if focusedLabel() == "Home" { break }
            remote.press(.up); usleep(600_000)
        }
        XCTAssertEqual(focusedLabel(), "Home", "could not reach the Home entry; focus=\(focusLine())")
        var seen: [String] = []
        var settingsFrame = CGRect.zero
        var lastMaxY: CGFloat = 0
        for i in 0..<Self.railLabels.count {
            if i > 0 { remote.press(.down); usleep(700_000) }
            guard let f = focusedElements().first else { seen.append("?"); continue }
            seen.append(f.label)
            log("entry #\(i + 1) \(f.label) \(rect(f.frame))")
            XCTAssertGreaterThan(f.frame.minY, lastMaxY - 8, "\(f.label) is not below the entry before it")
            lastMaxY = f.frame.maxY
            if f.label == "Settings" { settingsFrame = f.frame }
        }
        XCTAssertEqual(seen, Self.railLabels, "the sidebar's entries are not the twelve in order")
        XCTAssertLessThanOrEqual(settingsFrame.maxY, Self.bottomMargin + 3, "Settings runs into the bottom margin")
        shot("02b-sidebar-settings-at-the-bottom")
        let logo = app.images.firstMatch
        log("logo exists=\(logo.exists) \(logo.exists ? rect(logo.frame) : "")")
        let footer = app.staticTexts["192.168.1.250:8090"]
        XCTAssertTrue(footer.exists, "the footer's server line is missing")
        log("footer \(rect(footer.frame))")
        XCTAssertLessThanOrEqual(footer.frame.maxY, Self.bottomMargin + 1, "the footer runs into the bottom margin")

        // Right goes back into the content and the sidebar closes.
        remote.press(.right)
        XCTAssertTrue(waitSidebar(open: false, timeout: 5), "Right did not close the sidebar")
        sleep(1)
        log("RIGHT BACK IN focus=\(focusLine())")
        XCTAssertNotEqual(zone(), "rail", "Right did not leave the sidebar")

        // 1a: Menu opens the sidebar on the current entry; Menu again goes Home.
        remote.press(.menu)
        XCTAssertTrue(waitSidebar(open: true, timeout: 5), "Menu did not open the sidebar")
        sleep(1)
        log("MENU focus=\(focusLine())")
        XCTAssertEqual(focusedLabel(), "On Now", "Menu did not open the sidebar on On Now")
        shot("03-menu-opens-sidebar")
        remote.press(.menu)
        XCTAssertTrue(homeTile("Guide").waitForExistence(timeout: 10), "Menu again did not go Home")
        sleep(2)
        log("MENU AGAIN focus=\(focusLine())")
        shot("04-menu-again-home")

        // Settings from its Home tile: two panes.
        focusTile("Settings")
        remote.press(.select)
        XCTAssertTrue(app.buttons["Server"].waitForExistence(timeout: 20), "Settings did not open")
        XCTAssertTrue(waitSidebar(open: false, timeout: 10), "the sidebar did not collapse on Settings")
        sleep(2)
        log("SETTINGS focus=\(focusLine())")
        XCTAssertEqual(focusedLabel(), "This Apple TV", "Settings did not open on its first group")
        let nameRow = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Name, ")).firstMatch
        XCTAssertTrue(nameRow.exists, "the Name row is missing")
        log("name row \u{201C}\(nameRow.label)\u{201D}")
        shot("05-settings-this-apple-tv")
        remote.press(.right)
        sleep(1)
        log("RIGHT INTO ROWS focus=\(focusLine())")
        XCTAssertTrue(focusedLabel()?.hasPrefix("Name, ") == true, "Right did not land on the Name row")
        remote.press(.down)
        sleep(1)
        XCTAssertTrue(focusedLabel()?.hasPrefix("tvOS, ") == true, "Down did not land on the tvOS row; focus=\(focusLine())")
        remote.press(.menu)
        sleep(1)
        log("MENU ON A ROW focus=\(focusLine())")
        XCTAssertEqual(focusedLabel(), "This Apple TV", "Menu on a row did not go back to its group")
        XCTAssertFalse(sidebarOpen(), "Menu on a row opened the sidebar")
        remote.press(.down)
        sleep(1)
        XCTAssertEqual(focusedLabel(), "Server", "Down did not reach the Server group")
        let addressRow = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Address, ")).firstMatch
        XCTAssertTrue(addressRow.waitForExistence(timeout: 5), "the Address row is missing")
        XCTAssertTrue(addressRow.label.hasSuffix("192.168.1.250:8090"), "the Address row does not end with the server address: \(addressRow.label)")
        let versionRow = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Version, ")).firstMatch
        let deadline = Date().addingTimeInterval(15)
        while Date() < deadline, versionRow.exists, versionRow.label.contains("Reading the server") { usleep(300_000) }
        log("version row \u{201C}\(versionRow.exists ? versionRow.label : "MISSING")\u{201D}")
        XCTAssertTrue(versionRow.exists, "the Version row is missing")
        XCTAssertFalse(versionRow.label.contains("Reading the server"), "the server's version never arrived")
        XCTAssertFalse(versionRow.label.contains("could not read"), "the status read failed: \(versionRow.label)")
        shot("06-settings-server")
        remote.press(.down)
        sleep(1)
        XCTAssertEqual(focusedLabel(), "App", "Down did not reach the App group")
        let appRow = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Version, ")).firstMatch
        XCTAssertTrue(appRow.waitForExistence(timeout: 5), "the App version row is missing")
        log("app row \u{201C}\(appRow.label)\u{201D}")
        shot("07-settings-app")

        // Menu on a group opens the sidebar on Settings.
        remote.press(.menu)
        XCTAssertTrue(waitSidebar(open: true, timeout: 5), "Menu on a group did not open the sidebar")
        sleep(1)
        log("MENU ON SETTINGS focus=\(focusLine())")
        XCTAssertEqual(focusedLabel(), "Settings", "the sidebar did not open on Settings")
        shot("08-settings-menu-opens-sidebar")

        // Up the sidebar to Guide, open it.
        for _ in 0..<12 {
            if focusedLabel() == "Guide" { break }
            remote.press(.up); usleep(600_000)
        }
        XCTAssertEqual(focusedLabel(), "Guide", "could not reach the Guide entry; focus=\(focusLine())")
        remote.press(.select)
        XCTAssertTrue(app.staticTexts["Recording or set to record"].waitForExistence(timeout: 40), "the Guide did not open")
        sleep(6)
        guard let atNow = windowPosition() else { return XCTFail("no window label at open") }
        log(stage("GUIDE OPEN"))
        XCTAssertTrue(stripFirstColumn()?.hasSuffix("\u{00B7} now") == true, "the Guide did not open at now")
        XCTAssertNotEqual(zone(), "rail", "the Guide did not take focus")

        // Left to the channel cell, then Left at now: the sidebar, ring on Guide (through the catcher).
        XCTAssertTrue(walkLeftToChannelCell(window: atNow), "could not reach the channel cell; focus=\(focusLine())")
        remote.press(.left)
        sleep(3)
        log(stage("LEFT AT NOW"))
        XCTAssertEqual(zone(), "rail", "Left at now did not reach the sidebar")
        XCTAssertEqual(focusedLabel(), "Guide", "the sidebar's ring is not on Guide")
        XCTAssertEqual(windowPosition(), atNow, "the window moved on the Left into the sidebar")
        shot("09-guide-left-at-now-reaches-sidebar")

        // Right back into the Guide; two slots ahead by Pass 77's Right; back-step twice; then the sidebar.
        remote.press(.right)
        sleep(2)
        log(stage("RIGHT BACK INTO THE GUIDE"))
        XCTAssertNotEqual(zone(), "rail", "Right did not leave the sidebar")
        XCTAssertFalse(sidebarOpen(), "the sidebar stayed open after Right")
        // Right from the sidebar lands on a channel cell (the nearest thing); one more Right puts
        // focus on a programme cell, where the walk to the row's last cell starts.
        if zone() == "grid:channel-cell" {
            remote.press(.right)
            usleep(1_500_000)
            log(stage("RIGHT ONTO A PROGRAMME CELL"))
        }
        XCTAssertTrue(walkToLastCell(), "could not reach the row's last cell; focus=\(focusLine())")
        let ahead = nudgeAhead(2, from: atNow)
        log(stage("AHEAD \(ahead) slot(s)"))
        XCTAssertEqual(ahead, 2, "the window did not go two slots ahead")
        let aheadStart = atNow + 2 * 30
        XCTAssertTrue(walkLeftToChannelCell(window: aheadStart), "could not reach the channel cell; focus=\(focusLine())")
        guard let channel = focusedLabel() else { return XCTFail("nothing focused on the channel cell") }
        var expected = aheadStart
        for press in 1...2 {
            remote.press(.left)
            sleep(3)
            expected -= 30
            log(stage("BACK-STEP LEFT #\(press)"))
            XCTAssertEqual(windowPosition(), expected, "Left #\(press) did not step the window back one slot")
            XCTAssertEqual(zone(), "grid:channel-cell", "Left #\(press) took focus out of the grid")
            XCTAssertEqual(focusedLabel(), channel, "Left #\(press) moved focus off the channel cell")
            XCTAssertFalse(sidebarOpen(), "Left #\(press) opened the sidebar")
        }
        XCTAssertEqual(windowPosition(), atNow, "two Lefts did not bring the window back to now")
        shot("10-guide-back-at-now")
        remote.press(.left)
        sleep(3)
        log(stage("ONE MORE LEFT AT NOW"))
        XCTAssertEqual(zone(), "rail", "Left at now did not reach the sidebar after the back-steps")
        XCTAssertEqual(focusedLabel(), "Guide", "the sidebar's ring is not on Guide after the back-steps")
        shot("11-guide-left-after-back-steps-reaches-sidebar")
    }
}
