//
//  PlayerInfoPanelUITests.swift
//  Marlin DVR TVUITests
//
//  Pass 108's evidence harness, not a standing test. It needs the physical Apple TV ("Home Theater"),
//  the real Siri Remote, and the owner's own server as it stood when the run was made: **History's
//  Greatest Mysteries** has a series pass (`GET /api/passes`) and a saved position on this Apple TV,
//  its recordings' channel text is `"9001 HISTORY"` (`GET /api/library/shows/{id}`), and the first
//  row of Favorites is a favourite channel by definition. Those were read before the run with the
//  app's own GETs, not guessed.
//
//  **What it drives.** The Player's info panel, opened with `remote.press(.down)` — the click down on
//  the ring — once over a recording and once over a live channel:
//
//    108a  a recording playing, the panel up: logo, title, "S.. E.. · episode", HD and rating,
//          description, and "Edit pass" because the show has a pass; focus on that button
//    108b  Menu: the panel is gone and the recording is still playing
//    108c  Menu again: the Player is gone and show detail is back
//    108d  a live channel playing, the panel up: the airing now, Record (or its ● state), the pass
//          label and "Unfavorite"
//    108e  Menu: the panel is gone and the channel is still playing
//    108f  Menu again: the Player is gone and Favorites is back
//
//  **It presses no panel button, ever.** Every one of them writes to the owner's DVR — `POST
//  /api/record`, `POST /api/passes`, the editor's `PUT`/`DELETE /api/passes/{id}`, `PUT
//  /api/sources/{id}/lineup/{guid}` — so the harness reads each label, photographs it, and leaves by
//  **Menu**, never Select, while the panel is up. The only non-GET traffic is the app's own: its launch
//  ping, and the play session each playback opens and closes (`POST` and `DELETE /api/play/sessions`).
//  The live channel is a Philo channel, which holds no tuner. The recording is never played to its
//  end, so nothing is marked watched; its saved position moves by the seconds it plays.
//
//  **Code-traced only, not driven here:** the touch-surface swipe (XCUITest on tvOS can press buttons
//  and cannot swipe — `XCUIElement.h:176-208` is `#if !TARGET_OS_TV`), the down click while paused on
//  a recording, commercial skip, frame stepping, and every button press.
//
//  **`launch()`, not `activate()`** (Pass 92): this harness attaches no console, and `activate()` can
//  resume the build already running on the television. The run is only believed once the app's launch
//  ping is found in `GET /api/logs` at the run's timestamp.
//

import XCTest

final class PlayerInfoPanelUITests: XCTestCase {
    private var app: XCUIApplication!
    private let remote = XCUIRemote.shared

    /// Home tile order, frame 2a (Destination.homeTiles).
    private static let homeTiles = ["Guide", "On Now", "On Later",
                                    "Recordings", "Cameras", "Favorites",
                                    "Weather", "Radio", "Settings"]

    private let shelvesNote = "Watched and keep flags are shared with the other Apple TV"
    private let detailNote = "Click and hold an episode for Keep and Delete"
    private let favoritesNote = "The server's own favourites — shared with the web UI and the other Apple TV"

    /// The recording's show, which the server holds a pass for — read before the run.
    private static let show = "History's Greatest Mysteries"
    /// That show's recordings carry the channel text "9001 HISTORY"; the number must not appear.
    private static let recordingChannelNumber = "9001"

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launch()
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

    private func log(_ line: String) { print("[pass108 \(stamp())] \(line)") }

    private func screenText() -> [String] {
        app.staticTexts.allElementsBoundByIndex.map(\.label).filter { !$0.isEmpty }
    }

    private func focusedLabel() -> String {
        let buttons = app.buttons.matching(NSPredicate(format: "hasFocus == true")).allElementsBoundByIndex
        if let first = buttons.first { return first.label }
        let others = app.otherElements.matching(NSPredicate(format: "hasFocus == true")).allElementsBoundByIndex
        if let first = others.first { return "other:\(first.label)" }
        return "nothing"
    }

    private func panelText(_ id: String) -> String? {
        let element = app.staticTexts[id]
        return element.exists ? element.label : nil
    }

    private func panelButton(_ id: String) -> String? {
        let element = app.buttons[id]
        return element.exists ? element.label : nil
    }

    private var panelTags: [String] {
        app.staticTexts.matching(identifier: "infoPanel.tag").allElementsBoundByIndex.map(\.label)
    }

    private var panelLogoDrawn: Bool {
        app.descendants(matching: .any).matching(identifier: "infoPanel.logo").count > 0
    }

    /// Everything the panel draws as text, for the no-channel-number check.
    private func panelStrings() -> [String] {
        var out: [String] = []
        for id in ["infoPanel.title", "infoPanel.episode", "infoPanel.description", "infoPanel.message", "infoPanel.passLine"] {
            if let text = panelText(id) { out.append(text) }
        }
        out += panelTags
        for id in ["infoPanel.record", "infoPanel.series", "infoPanel.favorite", "infoPanel.pass"] {
            if let label = panelButton(id) { out.append(label) }
        }
        return out
    }

    /// The panel is up once one of its controls is drawn: the recording's pass button, or live's
    /// favourite button, which live draws in every case once its read has returned.
    private var panelUp: Bool {
        app.buttons["infoPanel.pass"].exists || app.buttons["infoPanel.favorite"].exists
    }

    private func waitFor(_ seconds: Int, _ condition: () -> Bool) -> Bool {
        for _ in 0..<(seconds * 2) {
            if condition() { return true }
            usleep(500_000)
        }
        return condition()
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

    /// Pass 103's shelf walk (`ShowDetailSeriesPassUITests.openShow`): each row walked right and back
    /// to the left-hand column before Down, because from a row's last card there may be no card below.
    private func openShow(_ title: String) -> Bool {
        log("looking for a card for \"\(title)\"; focus is \(focusedLabel())")
        for row in 0..<3 {
            var rights = 0
            while true {
                let here = focusedLabel()
                if here.contains(title) {
                    log("found it on row \(row) at \(rights) right(s): \(here)")
                    remote.press(.select)
                    guard app.staticTexts[detailNote].waitForExistence(timeout: 40) else {
                        log("show detail did not open for \"\(title)\""); return false
                    }
                    sleep(3)
                    return true
                }
                if rights == 6 { break }
                remote.press(.right)
                usleep(800_000)
                let next = focusedLabel()
                if next == here { break }
                rights += 1
            }
            for _ in 0..<rights { remote.press(.left); usleep(600_000) }
            if row == 2 { break }
            let before = focusedLabel()
            remote.press(.down)
            usleep(900_000)
            if focusedLabel() == before { log("Down did not leave row \(row): \(before)"); return false }
        }
        return false
    }

    // MARK: the pass's question

    func testTheInfoPanelOverARecordingAndALiveChannel() {
        recordingPanel()
        goHome()
        livePanel()
    }

    private func recordingPanel() {
        openFromHome("Recordings")
        XCTAssertTrue(app.staticTexts[shelvesNote].waitForExistence(timeout: 40), "the Recordings shelves did not appear")
        sleep(3)
        guard openShow(Self.show) else { return XCTFail("could not open \(Self.show)") }

        let play = focusedLabel()
        log("show detail focus, the control about to be pressed: \"\(play)\"")
        XCTAssertTrue(play.hasPrefix("Resume") || play == "Play newest", "focus is not on a play control: \(play)")
        remote.press(.select)

        let hud = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Resume kept by'")).firstMatch
        XCTAssertTrue(hud.waitForExistence(timeout: 120), "the recording never started playing: \(screenText())")
        sleep(9)
        let beforeDown = focusedLabel()
        log("recording playing; focus before Down: \(beforeDown)")

        // ---- the panel over a recording ----
        remote.press(.down)
        XCTAssertTrue(waitFor(20) { panelUp }, "Down did not open the panel over the recording: \(screenText())")
        sleep(4)   // show detail's pass read and the channel read
        let title = panelText("infoPanel.title")
        let episode = panelText("infoPanel.episode")
        let description = panelText("infoPanel.description")
        let tags = panelTags
        let passLabel = panelButton("infoPanel.pass")
        let focus = focusedLabel()
        log("recording panel — title: \(title ?? "none") · episode: \(episode ?? "none") · tags: \(tags) · logo: \(panelLogoDrawn)")
        log("recording panel — description: \(description ?? "none")")
        log("recording panel — pass button: \(passLabel ?? "none") · pass line: \(panelText("infoPanel.passLine") ?? "none") · focus: \(focus)")
        log("recording panel — every panel string: \(panelStrings())")
        shot("108a-recording-panel")

        XCTAssertEqual(title, Self.show, "the panel's title is not the show's")
        XCTAssertTrue(episode?.hasPrefix("S") == true, "no \"S.. E.. · episode\" line: \(episode ?? "none")")
        XCTAssertTrue(tags.contains("HD"), "no HD tag: \(tags)")
        XCTAssertEqual(tags.count, 2, "tags should be HD and the rating, and nothing else: \(tags)")
        XCTAssertNotNil(description, "no description")
        XCTAssertTrue(panelLogoDrawn, "no channel logo — \"9001 HISTORY\" matches a channel on this server")
        XCTAssertEqual(passLabel, "Edit pass", "\(Self.show) has a pass, so the button should read \"Edit pass\"")
        XCTAssertEqual(focus, "Edit pass", "the panel's button did not take focus")
        XCTAssertFalse(panelStrings().contains { $0.contains(Self.recordingChannelNumber) },
                       "the channel number is on the panel: \(panelStrings())")

        // ---- Menu closes the panel; the recording plays on ----
        remote.press(.menu)
        XCTAssertTrue(waitFor(10) { !panelUp }, "Menu did not close the panel")
        sleep(2)
        let afterClose = focusedLabel()
        log("after Menu: panel up \(panelUp), focus \(afterClose), show detail focused \(afterClose.hasPrefix("Resume") || afterClose == "Play newest")")
        shot("108b-recording-panel-closed")
        XCTAssertFalse(afterClose.hasPrefix("Resume") || afterClose == "Play newest" || afterClose == "Edit series pass",
                       "the first Menu left the Player instead of only closing the panel — focus is on show detail: \(afterClose)")

        // ---- Menu again leaves the Player ----
        remote.press(.menu)
        let back = waitFor(20) {
            let f = focusedLabel()
            return f.hasPrefix("Resume") || f == "Play newest" || f == "Edit series pass" || f == "Record the series"
        }
        log("after the second Menu: focus \(focusedLabel())")
        shot("108c-recording-player-left")
        XCTAssertTrue(back, "the second Menu did not return to show detail — focus is \(focusedLabel())")
    }

    private func livePanel() {
        openFromHome("Favorites")
        XCTAssertTrue(app.staticTexts[favoritesNote].waitForExistence(timeout: 40), "Favorites did not appear")
        sleep(4)
        let row = focusedLabel()
        log("Favorites focus, the channel about to be played: \"\(row)\"")
        // The row reads "<number> · <name>, …": its number is what must not reach the panel.
        let number = row.components(separatedBy: " · ").first ?? ""
        XCTAssertFalse(number.isEmpty || row == "nothing", "no favourite row has focus: \(row)")
        remote.press(.select)

        XCTAssertTrue(app.staticTexts["LIVE"].waitForExistence(timeout: 90)
                      || app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'LIVE'")).firstMatch.exists,
                      "the live channel never started playing: \(screenText())")
        sleep(9)
        log("live playing; focus before Down: \(focusedLabel())")

        // ---- the panel over a live channel ----
        remote.press(.down)
        XCTAssertTrue(waitFor(25) { panelUp }, "Down did not open the panel over the live channel: \(screenText())")
        sleep(4)   // the schedule and pass reads after guide/now
        let title = panelText("infoPanel.title")
        let episode = panelText("infoPanel.episode")
        let description = panelText("infoPanel.description")
        let tags = panelTags
        let record = panelButton("infoPanel.record")
            ?? (app.staticTexts["● Recording"].exists ? "● Recording" : nil)
            ?? (app.staticTexts["● Scheduled"].exists ? "● Scheduled" : nil)
        let series = panelButton("infoPanel.series")
        let favorite = panelButton("infoPanel.favorite")
        let focus = focusedLabel()
        log("live panel — title: \(title ?? "none (nothing in the guide)") · episode: \(episode ?? "none") · tags: \(tags) · logo: \(panelLogoDrawn)")
        log("live panel — description: \(description ?? "none")")
        log("live panel — record: \(record ?? "none") · series: \(series ?? "none") · favorite: \(favorite ?? "none") · pass line: \(panelText("infoPanel.passLine") ?? "none") · focus: \(focus)")
        log("live panel — every panel string: \(panelStrings())")
        shot("108d-live-panel")

        XCTAssertEqual(favorite, "Unfavorite", "the channel is a favourite, so the button should read \"Unfavorite\"")
        XCTAssertTrue(panelLogoDrawn, "no channel logo")
        if title != nil {
            XCTAssertTrue(["Record", "● Recording", "● Scheduled"].contains(record ?? ""), "no Record control: \(record ?? "none")")
            XCTAssertTrue(["Add to pass", "Edit pass"].contains(series ?? ""), "no pass control: \(series ?? "none")")
            XCTAssertTrue(tags.allSatisfy { $0 == "HD" || $0.hasPrefix("TV-") || ["G", "PG", "PG-13", "R", "NC-17", "NR"].contains($0) },
                          "a tag that is neither HD nor a rating: \(tags)")
            XCTAssertTrue([focus].contains { $0 == "Record" || $0 == "Add to pass" || $0 == "Edit pass" },
                          "the panel's first control did not take focus: \(focus)")
        } else {
            XCTAssertNil(record, "nothing in the guide, yet a Record control is drawn")
            XCTAssertNil(series, "nothing in the guide, yet a pass control is drawn")
        }
        if !number.isEmpty {
            XCTAssertFalse(panelStrings().contains { $0.contains(number) }, "the channel number \(number) is on the panel: \(panelStrings())")
        }

        // ---- Menu closes the panel; the channel plays on ----
        remote.press(.menu)
        XCTAssertTrue(waitFor(10) { !panelUp }, "Menu did not close the live panel")
        sleep(2)
        let afterClose = focusedLabel()
        log("after Menu: panel up \(panelUp), focus \(afterClose)")
        shot("108e-live-panel-closed")
        XCTAssertFalse(afterClose.contains(" · "), "the first Menu left the Player instead of only closing the panel — focus is on a Favorites row: \(afterClose)")

        // ---- Menu again leaves the Player ----
        remote.press(.menu)
        let back = waitFor(20) { focusedLabel().contains(" · ") }
        log("after the second Menu: focus \(focusedLabel())")
        shot("108f-live-player-left")
        XCTAssertTrue(back, "the second Menu did not return to Favorites — focus is \(focusedLabel())")
    }
}
