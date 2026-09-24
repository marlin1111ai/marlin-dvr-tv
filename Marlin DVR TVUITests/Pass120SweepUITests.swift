//
//  Pass120SweepUITests.swift
//  Marlin DVR TVUITests
//
//  Pass 120's evidence harness, not a standing test. It needs the physical Apple TV ("Home Theater"),
//  the real Siri Remote and the owner's own server as it stood on the night of 2026-09-24, read with
//  the app's own GETs before the run and not guessed:
//   · the schedule holds 12 bookings and the server 12 series passes (`GET /api/schedule`,
//     `GET /api/passes`), so Scheduled Recordings and Your Passes open on a first row;
//   · the guide lists "Tiki + Tierney" on 6196 CBSSPORTS (`GET /api/guide/find?q=%2B`), and
//     `GET /api/guide/search` answers 0 airings for the old bytes `title=Tiki%20+%20Tierney` and 3 for
//     the new `title=Tiki%20%2B%20Tierney`;
//   · the favourites are 6044 HISTORY, 6101 DISCOVERY and 6111 AHC, all Philo channels, which hold no
//     tuner; DISCOVERY and AHC turn over at 02:00:00, and HISTORY goes from "Pawn Stars: Best Of"
//     (01:05–02:06, no series pass matches it) to "Pawn Stars" (02:06–03:03, which the "Pawn Stars" pass
//     matches, "1 recording scheduled", new episodes) at 02:06:00 (`GET /api/guide`, `GET /api/passes`);
//   · the one camera, "Cow Cam", was offline when read.
//
//  **It makes no server write.** Select is pressed only on a Home tile, a rail entry, the three rows
//  of the Manage DVR hub (each opens a list), one Search result (it opens the airing sheet) and the
//  HISTORY row of Favorites (it plays the channel live). **Inside Scheduled Recordings, Your Passes,
//  Trash, the airing sheet, the Player and its info panel only Menu and Down are pressed** — a Select
//  there could cancel a booking, change or delete a pass, restore a recording, book an airing or create
//  a pass. The only non-GET traffic is the app's own: the launch ping of each method, and the play
//  session the live channel opens and closes. Nothing is played to its end.
//
//  **`launch()`, not `activate()`** (Pass 92): no console is attached, so a run is believed only once
//  each method's launch ping is in `GET /api/logs` at its time.
//
//  Which Pass 120 item each method runs, and what stays code-traced (Pass 119's report §3 (e)):
//
//    test1  S4 (regression only — location allowed): Home's weather glance draws weather from the
//           saved fix. **Location set to Never is traced**: it needs the owner's hands in tvOS Settings.
//           S7/S8: the hub, Scheduled Recordings, Your Passes and Trash on the non-empty path — each list
//           opens on its first row with no false error, Menu returns to the hub, Trash as before. **Every
//           empty list and every failed read is traced**: producing them needs writes or a server fault.
//    test2  S10: "Tiki" typed in Search, the "Tiki + Tierney" row opened — the airing sheet appears, where
//           the old bytes said "The server no longer lists that airing." **";", On Later, Trash, Your
//           Passes and Player posters are traced** (the builders' bytes were checked outside the project).
//    test3  S15: Cameras. With the camera online, no "snapshot.jpg" placeholder is seen across two 45 s
//           reloads after the first picture; offline, today's "no snapshot" is shown and **the kept picture
//           is traced**.
//    test4  S14: Favorites held across DISCOVERY's and AHC's 02:00 turnover — the rows change within
//           about a minute with focus unmoved on HISTORY — and, after a Player round trip across
//           HISTORY's 02:06 turnover, the HISTORY row is current. S12: HISTORY played live, the info panel
//           opened before 02:06 and held past 02:06:02 — it must end on "Pawn Stars", "Edit pass" and the
//           gold "◆ Series pass" line. **The booking half of S12 is traced** (no airing at that boundary
//           is booked).
//
//  S1, S2, S9, S13 and S16 have no method here; see the Pass 120 report.
//
//  Run (the one run, named — the scheme runs no UI test unless one is named, Pass 120 S1):
//    xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
//      -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates \
//      -derivedDataPath build/p120 test -only-testing:"Marlin DVR TVUITests/Pass120SweepUITests"
//  test4 is timed to tonight's two boundaries and skips itself if it starts too late to see them.
//

import XCTest

final class Pass120SweepUITests: XCTestCase {
    private var app: XCUIApplication!
    private let remote = XCUIRemote.shared

    /// Home tile order, frame 2a (Destination.homeTiles).
    private static let homeTiles = ["Guide", "On Now", "On Later",
                                    "Recordings", "Cameras", "Favorites",
                                    "Weather", "Radio", "Settings"]

    private let hubNote = "Everything here is the server's own state, shared with the web UI"
    private let listNote = "Menu goes back to Manage DVR"
    private let searchIdle = "Type a title. Search matches the title only, from now forward."
    private let favoritesNote = "The server's own favourites — shared with the web UI and the other Apple TV"

    /// Tonight's two boundaries, from `GET /api/guide` at 00:50 (epoch seconds).
    private static let discoveryTurnover: TimeInterval = 1_790_229_600   // 02:00:00
    private static let historyTurnover: TimeInterval = 1_790_229_960     // 02:06:00

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launch()
        log("launched")
        goHome()
    }

    // MARK: reading the device

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func stamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: Date())
    }

    private func log(_ line: String) { print("[pass120 \(stamp())] \(line)") }

    private func screenText() -> [String] {
        app.staticTexts.allElementsBoundByIndex.map(\.label).filter { !$0.isEmpty }
    }

    private func buttonLabels() -> [String] {
        app.buttons.allElementsBoundByIndex.map(\.label).filter { !$0.isEmpty }
    }

    private func focusedLabel() -> String {
        let buttons = app.buttons.matching(NSPredicate(format: "hasFocus == true")).allElementsBoundByIndex
        if let first = buttons.first { return first.label }
        let others = app.otherElements.matching(NSPredicate(format: "hasFocus == true")).allElementsBoundByIndex
        if let first = others.first { return "other:\(first.label)" }
        let texts = app.staticTexts.matching(NSPredicate(format: "hasFocus == true")).allElementsBoundByIndex
        if let first = texts.first { return "text:\(first.label)" }
        return "nothing"
    }

    /// The focused rail entry, or nil — the rail's buttons sit left of x = 150 (RailFocusRestoreUITests).
    private func focusedRailEntry() -> String? {
        app.buttons.matching(NSPredicate(format: "hasFocus == true")).allElementsBoundByIndex
            .first { $0.frame.minX < 150 }?.label
    }

    private func textExists(_ text: String) -> Bool {
        app.staticTexts.matching(NSPredicate(format: "label == %@", text)).firstMatch.exists
    }

    private func textContaining(_ fragment: String) -> String? {
        let match = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", fragment)).firstMatch
        return match.exists ? match.label : nil
    }

    private func waitFor(_ seconds: Int, _ condition: () -> Bool) -> Bool {
        for _ in 0..<(seconds * 2) {
            if condition() { return true }
            usleep(500_000)
        }
        return condition()
    }

    /// Waits with the app left exactly as it is, reading the focus every 20 s — Pass 79's pattern
    /// (`GuideRightEdgeUITests.waitOutABoundary`): the Mac's wireless test link is what drops when idle.
    private func sleepUntil(_ epoch: TimeInterval) {
        let wait = epoch - Date().timeIntervalSince1970
        guard wait > 0 else { return }
        log("waiting \(Int(wait)) s")
        while true {
            let left = epoch - Date().timeIntervalSince1970
            if left <= 0 { break }
            Thread.sleep(forTimeInterval: min(20, left))
            if epoch - Date().timeIntervalSince1970 > 0 { log("… focus \(focusedLabel())") }
        }
    }

    // MARK: driving the remote

    private func goHome() {
        for _ in 0..<7 {
            if app.staticTexts["Marlin"].waitForExistence(timeout: 8) { sleep(2); return }
            remote.press(.menu)
            sleep(3)
        }
    }

    private func openFromHome(_ tile: String) {
        XCTAssertTrue(app.staticTexts["Marlin"].waitForExistence(timeout: 60), "Home did not appear")
        sleep(3)
        guard let target = Self.homeTiles.firstIndex(of: tile) else { return XCTFail("no such tile: \(tile)") }
        guard let here = Self.homeTiles.firstIndex(where: { focusedLabel() == $0 || focusedLabel().hasPrefix("\($0), ") }) else {
            return XCTFail("Home focus is not on a tile — it is \(focusedLabel())")
        }
        log("Home focus is \(Self.homeTiles[here]); walking to \(tile)")
        let dRow = target / 3 - here / 3, dCol = target % 3 - here % 3
        for _ in 0..<abs(dRow) { remote.press(dRow > 0 ? .down : .up); usleep(700_000) }
        for _ in 0..<abs(dCol) { remote.press(dCol > 0 ? .right : .left); usleep(700_000) }
        remote.press(.select)
    }

    /// Left into the rail, then Down or Up to `entry`, checked by label before the Select.
    @discardableResult
    private func railTo(_ entry: String) -> Bool {
        let order = ["Home", "Favorites", "On Now", "Guide", "On Later", "Recordings", "Cameras",
                     "Weather", "Radio", "Search", "Manage DVR"]
        for _ in 0..<4 where focusedRailEntry() == nil {
            remote.press(.left)
            sleep(2)
        }
        guard let here = focusedRailEntry(), let from = order.firstIndex(of: here),
              let to = order.firstIndex(of: entry) else {
            XCTFail("not in the rail — focus is \(focusedLabel())")
            return false
        }
        for _ in 0..<abs(to - from) { remote.press(to > from ? .down : .up); usleep(700_000) }
        sleep(1)
        guard focusedRailEntry() == entry else {
            XCTFail("the rail walk to \(entry) ended on \(focusedRailEntry() ?? focusedLabel())")
            return false
        }
        remote.press(.select)
        return true
    }

    // MARK: test1 — S4 (regression) and S7/S8

    func test1_WeatherGlanceAndManageDVRLists() {
        // S4, location allowed: the saved fix is still used — the glance's detail line is drawn.
        let feels = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Feels '")).firstMatch
        let drawn = feels.waitForExistence(timeout: 40)
        log("S4 glance: detail line \(drawn ? "\"\(feels.label)\"" : "absent"); needs-location sentence \(textExists("Weather needs this Apple TV's location — open Weather"))")
        shot("120-s4-home-glance")
        XCTAssertTrue(drawn, "Home's weather glance drew no weather: \(screenText())")
        XCTAssertFalse(textExists("Weather needs this Apple TV's location — open Weather"))

        openFromHome("On Now")
        sleep(6)
        guard railTo("Manage DVR") else { return }
        XCTAssertTrue(app.staticTexts[hubNote].waitForExistence(timeout: 30), "the Manage DVR hub did not open")
        sleep(4)
        let hub = buttonLabels()
        log("S8 hub buttons: \(hub)")
        log("S8 hub text: \(screenText())")
        log("S8 hub focus: \(focusedLabel())")
        shot("120-s8-hub")
        XCTAssertFalse(hub.contains { $0.contains("could not read") }, "a successful read shows \"could not read\": \(hub)")
        XCTAssertNil(textContaining("could not be read"), "a successful read shows an error line")
        XCTAssertNil(textContaining("Could not read the disk space"), "the storage card shows an error on a good read")
        XCTAssertNotNil(textContaining(" used · "), "the storage card has no disk figures: \(screenText())")

        for (index, row) in ["Scheduled Recordings", "Your Passes", "Trash"].enumerated() {
            if index > 0 {
                remote.press(.down)
                sleep(1)
            }
            guard focusedLabel().hasPrefix(row) else {
                XCTFail("hub focus should be on \(row) — it is \(focusedLabel()); stopping before any Select")
                return
            }
            remote.press(.select)
            let opened = waitFor(15) { !self.textExists(self.hubNote) }
            sleep(3)
            let focus = focusedLabel()
            let tag = row.replacingOccurrences(of: " ", with: "-").lowercased()
            log("S7 \(row): opened \(opened); focus \(focus)")
            log("S7 \(row) text: \(screenText())")
            shot("120-s7-\(tag)-open")
            if row != "Trash" {
                XCTAssertTrue(textExists(listNote), "\(row) did not open")
                XCTAssertFalse(focus == "nothing", "\(row) opened with nothing focused")
                XCTAssertNil(textContaining("could not be read"), "\(row) shows a read error on a good read")
                XCTAssertFalse(textExists("Nothing is scheduled. Record an airing from the Guide, or add a series pass."))
                XCTAssertFalse(textExists("No series passes yet. Open an airing in the Guide and choose Record the series."))
            }
            remote.press(.menu)
            let back = app.staticTexts[hubNote].waitForExistence(timeout: 15)
            sleep(2)
            log("S7 \(row): Menu → hub \(back); focus \(focusedLabel())")
            XCTAssertTrue(back, "Menu from \(row) did not return to Manage DVR — text \(screenText())")
        }
        shot("120-s7-hub-after-the-lists")
        remote.press(.menu)
        sleep(2)
    }

    // MARK: test2 — S10

    private var keyboardHasFocus: Bool {
        app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == true")).allElementsBoundByIndex.contains {
            $0.elementType == .keyboard || $0.elementType == .key || $0.elementType == .textField || $0.elementType == .searchField
        }
    }

    func test2_SearchOpensATitleWithAPlus() {
        openFromHome("On Now")
        sleep(6)
        guard railTo("Search") else { return }
        XCTAssertTrue(app.staticTexts[searchIdle].waitForExistence(timeout: 20), "Search did not open")
        sleep(3)
        remote.press(.right)
        sleep(2)
        for _ in 0..<14 where !keyboardHasFocus {
            remote.press(.up)
            sleep(1)
        }
        guard keyboardHasFocus else { return XCTFail("the keyboard strip was never reached — focus \(focusedLabel())") }
        app.typeText("Tiki")
        sleep(5)
        let rows = buttonLabels().filter { $0.contains("Tiki + Tierney") }
        log("S10 rows for \"Tiki\": \(rows)")
        shot("120-s10-results")
        XCTAssertFalse(rows.isEmpty, "no \"Tiki + Tierney\" row: \(buttonLabels())")
        for _ in 0..<6 where !focusedLabel().contains("Tiki + Tierney") {
            remote.press(.down)
            sleep(1)
        }
        guard focusedLabel().contains("Tiki + Tierney") else {
            return XCTFail("focus never reached a \"Tiki + Tierney\" row — it is \(focusedLabel()); no Select")
        }
        log("S10 focus before Select: \(focusedLabel())")
        remote.press(.select)
        let series = app.buttons.matching(NSPredicate(format: "label == %@ OR label == %@", "Record the series", "Edit series pass")).firstMatch
        let sheet = series.waitForExistence(timeout: 20)
        sleep(2)
        let refused = textExists("The server no longer lists that airing.")
        log("S10 sheet \(sheet); \"no longer lists\" \(refused); text \(screenText()); focus \(focusedLabel())")
        shot("120-s10-sheet")
        XCTAssertTrue(sheet, "the airing sheet did not open for \"Tiki + Tierney\"")
        XCTAssertFalse(refused, "Search said the server no longer lists that airing")
        XCTAssertTrue(textExists("Tiki + Tierney"), "the sheet is not showing \"Tiki + Tierney\"")
        remote.press(.menu)
        sleep(2)
        log("S10 after Menu: sheet \(series.exists); focus \(focusedLabel())")
        XCTAssertFalse(series.exists, "Menu did not close the airing sheet")
    }

    // MARK: test3 — S15

    /// The card is a Button, so its texts may be folded into the button's label rather than drawn as
    /// static texts of their own; both are read.
    private func cardSays(_ text: String) -> Bool {
        textExists(text) || buttonLabels().contains { $0.contains(text) }
    }

    func test3_CameraCardsKeepThePicture() {
        openFromHome("Cameras")
        let age = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Snapshot age'")).firstMatch
        XCTAssertTrue(age.waitForExistence(timeout: 30), "Cameras did not load")
        sleep(2)
        let online = cardSays("Online")
        log("S15 camera online \(online); buttons \(buttonLabels()); text \(screenText()); focus \(focusedLabel())")
        shot("120-s15-cameras-open")
        guard online else {
            XCTAssertTrue(cardSays("no snapshot"), "an offline camera should keep today's \"no snapshot\"")
            log("S15 the camera is offline: the kept picture cannot be shown on this run")
            return
        }
        let firstPicture = waitFor(30) { !self.cardSays("snapshot.jpg") }
        log("S15 first picture loaded \(firstPicture)")
        var sightings = 0, samples = 0, ages: [String] = []
        let focusBefore = focusedLabel()
        let end = Date().addingTimeInterval(100)
        while Date() < end {
            samples += 1
            if cardSays("snapshot.jpg") {
                sightings += 1
                log("S15 placeholder seen at \(age.label)")
                shot("120-s15-placeholder-seen")
            }
            if age.label.hasPrefix("Snapshot age 0 s") || age.label.hasPrefix("Snapshot age 1 s") {
                if ages.last != age.label { shot("120-s15-at-reload-\(ages.count)") }
                ages.append(age.label)
            }
        }
        log("S15 \(samples) samples over 100 s, placeholder seen \(sightings) times; reload moments sampled \(Set(ages).count); focus \(focusBefore) → \(focusedLabel())")
        XCTAssertEqual(sightings, 0, "the placeholder showed during a reload")
        XCTAssertEqual(focusedLabel(), focusBefore, "a reload moved focus")
    }

    // MARK: test4 — S14 and S12

    private func favouriteRow(_ channel: String) -> String? {
        buttonLabels().first { $0.contains(channel) && $0.contains(" · ") }
    }

    private func panelButton(_ id: String) -> String? {
        let element = app.buttons[id]
        return element.exists ? element.label : nil
    }

    private func panelText(_ id: String) -> String? {
        let element = app.staticTexts[id]
        return element.exists ? element.label : nil
    }

    private var panelUp: Bool { app.buttons["infoPanel.favorite"].exists }

    private func describePanel() -> String {
        "title \(panelText("infoPanel.title") ?? "-") · series \(panelButton("infoPanel.series") ?? "-") · record \(panelButton("infoPanel.record") ?? "-") · passLine \(panelText("infoPanel.passLine") ?? "-") · message \(panelText("infoPanel.message") ?? "-") · focus \(focusedLabel())"
    }

    private var starting: Bool {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Press Menu to cancel'")).firstMatch.exists
    }

    func test4_FavoritesAndThePanelAcrossTheTurnovers() throws {
        let now = Date().timeIntervalSince1970
        guard now < Self.discoveryTurnover - 30 else {
            throw XCTSkip("started at \(stamp()), too late for tonight's 02:00 turnover")
        }
        sleepUntil(Self.discoveryTurnover - 90)

        // S14 in place: DISCOVERY and AHC turn over at 02:00; focus sits on HISTORY throughout.
        openFromHome("Favorites")
        XCTAssertTrue(app.staticTexts[favoritesNote].waitForExistence(timeout: 30), "Favorites did not appear")
        sleep(4)
        let focusAtOpen = focusedLabel()
        let discoveryBefore = favouriteRow("DISCOVERY") ?? "-"
        let ahcBefore = favouriteRow("AHC") ?? "-"
        log("S14 opened: focus \(focusAtOpen); DISCOVERY \(discoveryBefore); AHC \(ahcBefore); HISTORY \(favouriteRow("HISTORY") ?? "-")")
        shot("120-s14-favorites-before-0200")
        XCTAssertTrue(focusAtOpen.contains("HISTORY"), "Favorites did not open on HISTORY")
        var changedAt: String?
        var focusMoved = false
        while Date().timeIntervalSince1970 < Self.discoveryTurnover + 80 {
            sleep(10)
            let discovery = favouriteRow("DISCOVERY") ?? "-"
            let focus = focusedLabel()
            if !focus.contains("HISTORY") { focusMoved = true }
            log("S14 sample: DISCOVERY \(discovery); AHC \(favouriteRow("AHC") ?? "-"); focus \(focus)")
            if changedAt == nil, discovery != discoveryBefore, Date().timeIntervalSince1970 >= Self.discoveryTurnover {
                changedAt = stamp()
                shot("120-s14-favorites-after-0200")
            }
        }
        log("S14 in place: DISCOVERY row changed at \(changedAt ?? "never"); focus moved \(focusMoved)")
        XCTAssertNotNil(changedAt, "the DISCOVERY row did not change within 80 s of 02:00")
        XCTAssertFalse(focusMoved, "a reload moved focus off HISTORY")

        // S12: HISTORY live, the panel open across 02:06.
        sleepUntil(Self.historyTurnover - 110)
        guard focusedLabel().contains("HISTORY") else {
            return XCTFail("focus is not on HISTORY — it is \(focusedLabel()); not starting the Player")
        }
        remote.press(.select)
        sleep(2)
        let playing = waitFor(90) { !self.starting }
        log("S12 HISTORY playing \(playing)")
        XCTAssertTrue(playing, "HISTORY never left the Starting screen")
        sleep(4)
        remote.press(.down)
        let up = waitFor(20) { self.panelUp }
        sleep(3)
        let before = describePanel()
        log("S12 panel before 02:06: up \(up); \(before)")
        shot("120-s12-panel-before-0206")
        XCTAssertTrue(up, "the info panel did not open")
        XCTAssertEqual(panelText("infoPanel.title"), "Pawn Stars: Best Of")
        XCTAssertEqual(panelButton("infoPanel.series"), "Add to pass")

        sleepUntil(Self.historyTurnover + 8)
        let turned = waitFor(40) { self.panelText("infoPanel.title") == "Pawn Stars" }
        sleep(4)
        let after = describePanel()
        log("S12 panel after 02:06: title changed \(turned); \(after)")
        shot("120-s12-panel-after-0206")
        XCTAssertTrue(turned, "the panel did not move on to the next airing")
        XCTAssertEqual(panelButton("infoPanel.series"), "Edit pass", "the panel kept the ended show's pass state")
        XCTAssertTrue(panelText("infoPanel.passLine")?.hasPrefix("◆ Series pass") == true, "no pass line for \"Pawn Stars\"")

        remote.press(.menu)
        let closed = waitFor(10) { !self.panelUp }
        log("S12 Menu: panel closed \(closed)")
        remote.press(.menu)
        let backOnFavorites = app.staticTexts[favoritesNote].waitForExistence(timeout: 20)
        log("S14 Menu: Favorites back \(backOnFavorites); focus \(focusedLabel()); HISTORY \(favouriteRow("HISTORY") ?? "-")")
        XCTAssertTrue(backOnFavorites, "Menu did not return to Favorites")

        // S14 after the round trip: HISTORY's row carries the airing that began under the Player.
        let current = waitFor(100) {
            let row = self.favouriteRow("HISTORY") ?? ""
            return row.contains("Pawn Stars") && !row.contains("Best Of")
        }
        log("S14 after the round trip: HISTORY current \(current) at \(stamp()); row \(favouriteRow("HISTORY") ?? "-"); focus \(focusedLabel())")
        shot("120-s14-favorites-after-the-player")
        XCTAssertTrue(current, "the HISTORY row still shows the airing that ended")
        remote.press(.menu)
        sleep(2)
    }
}
