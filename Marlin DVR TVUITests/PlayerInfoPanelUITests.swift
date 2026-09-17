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
//  **Pass 109 adds `testUpClosesThePanelOverARecording`**, run on its own: the same recording, the panel
//  opened with `remote.press(.down)` and closed with **`remote.press(.up)`** — the click up — and then
//  the proof that the recording is still playing: the Player is still up, the recording HUD that a pause
//  would bring back is not, and two screenshots taken seconds apart differ. It presses no panel button,
//  and the swipe up is code-traced only for the same reason the swipe down was.
//
//    109a  the panel up over the recording, focus on its button
//    109b  after Up: the panel gone, the recording on screen
//    109c  a few seconds later: a different frame — still playing
//    109d  Menu: the Player gone and show detail back, the resume point further on
//
//  **Pass 110 adds `testNoTopCardOnARecordingOrALiveChannel`**, run on its own. The card across the top
//  of the Player — "History's Greatest Mysteries / S4 E14 · … · 9001 HISTORY / 2:09 of 42:51 / Resume
//  kept by …" on a recording, the LIVE badge card on a live channel — is gone on both (owner). This checks
//  for it at every moment the app used to draw it: just after playback starts (it showed for 6 s), while
//  paused (a recording kept it up for the whole pause), and just after resuming (6 s again). Then Down
//  still opens the info panel and Up still closes it. It presses no panel button.
//
//  **The two methods above cannot pass after Pass 110**, and are left as their passes ran them: both wait
//  for the recording card's "Resume kept by …" line, and the live half waits for its "LIVE" badge, to know
//  playback has started. This method knows it from the Starting screen going away instead.
//
//    110a  a recording just started: no card
//    110b  the recording paused: no card (Apple's own transport bar is not the card)
//    110c  Down over the recording: the info panel
//    110d  Up: the panel gone, still no card
//    110e  a live channel just started: no card
//    110f  the live channel paused: the paused-live screen (6d), which is not the card
//    110g  Down over the live channel: the info panel
//    110h  Up: the panel gone, still no card
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

    /// Pass 109: the click up closes the panel, the same as Menu, and the recording plays on.
    func testUpClosesThePanelOverARecording() {
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
        log("recording playing; HUD up \(hud.exists); focus before Down: \(focusedLabel())")

        // ---- Down opens the panel ----
        remote.press(.down)
        XCTAssertTrue(waitFor(20) { panelUp }, "Down did not open the panel over the recording: \(screenText())")
        sleep(3)
        let focusInPanel = focusedLabel()
        log("panel up — title: \(panelText("infoPanel.title") ?? "none") · pass button: \(panelButton("infoPanel.pass") ?? "none") · focus: \(focusInPanel)")
        shot("109a-panel-up")
        XCTAssertEqual(panelButton("infoPanel.pass"), focusInPanel, "the panel's button did not take focus")

        // ---- Up closes it ----
        remote.press(.up)
        XCTAssertTrue(waitFor(10) { !panelUp }, "Up did not close the panel")
        sleep(2)
        let afterUp = focusedLabel()
        let firstFrame = XCUIScreen.main.screenshot()
        let hudAfterUp = hud.exists
        log("after Up: panel up \(panelUp), focus \(afterUp), recording HUD up \(hudAfterUp)")
        let a = XCTAttachment(screenshot: firstFrame)
        a.name = "109b-after-up-panel-closed"
        a.lifetime = .keepAlways
        add(a)
        XCTAssertFalse(afterUp.hasPrefix("Resume") || afterUp == "Play newest" || afterUp == "Edit series pass",
                       "Up left the Player instead of only closing the panel — focus is on show detail: \(afterUp)")
        XCTAssertNotEqual(afterUp, focusInPanel, "focus is still on the panel's button")
        // A pause brings the recording HUD back and keeps it up (`PlayerModel.timeControlChanged`).
        XCTAssertFalse(hudAfterUp, "the recording HUD is up after Up — the recording looks paused")

        // ---- still playing: the picture moves ----
        sleep(4)
        let secondFrame = XCUIScreen.main.screenshot()
        let b = XCTAttachment(screenshot: secondFrame)
        b.name = "109c-seconds-later-still-playing"
        b.lifetime = .keepAlways
        add(b)
        let moved = firstFrame.pngRepresentation != secondFrame.pngRepresentation
        log("two frames 4 s apart: \(firstFrame.pngRepresentation.count) and \(secondFrame.pngRepresentation.count) bytes, identical \(!moved); HUD up \(hud.exists); panel up \(panelUp)")
        XCTAssertTrue(moved, "the two frames are identical — the recording is not playing")
        XCTAssertFalse(hud.exists, "the recording HUD came up — the recording looks paused")
        XCTAssertFalse(panelUp, "the panel came back")

        // ---- Menu leaves the Player, as before ----
        remote.press(.menu)
        let back = waitFor(20) {
            let f = focusedLabel()
            return f.hasPrefix("Resume") || f == "Play newest" || f == "Edit series pass" || f == "Record the series"
        }
        log("after Menu: focus \(focusedLabel())")
        shot("109d-menu-left-the-player")
        XCTAssertTrue(back, "Menu did not return to show detail — focus is \(focusedLabel())")
    }

    // MARK: Pass 110 — no top card on recordings or live channels

    /// Only the Starting screen (6a) draws this, on every kind.
    private var starting: Bool {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Press Menu to cancel'")).firstMatch.exists
    }

    /// The Pass 38 prompt, which owns Select while it is up.
    private var skipPromptUp: Bool { app.staticTexts["Skip the commercial break"].exists }

    /// Every line the recording card drew that nothing else in the app draws: the "x of y" clock,
    /// "Prepared to …" and "Resume kept by …".
    private func recordingCardLines() -> [String] {
        screenText().filter {
            $0.hasPrefix("Resume kept by ") || $0.hasPrefix("Prepared to ")
                || $0.range(of: "^[0-9]{1,2}:[0-9]{2}(:[0-9]{2})? of [0-9]{1,2}:[0-9]{2}(:[0-9]{2})?$", options: .regularExpression) != nil
        }
    }

    /// Every text on screen that reads like a line of the live card — the badge ("LIVE" or
    /// "LIVE · −12 s"), the title line "ch<number> <name>", "… behind live · buffer …" — with where it is.
    /// The paused-live screen's "LIVE · HELD" and its "title · subtitle" line are not among them.
    private func liveLookalikes(title: String) -> [(label: String, frame: CGRect)] {
        app.staticTexts.allElementsBoundByIndex.compactMap { element in
            let label = element.label
            guard label == "LIVE" || label.hasPrefix("LIVE · −") || label == title || label.contains(" behind live · buffer ") else { return nil }
            return (label, element.frame)
        }
    }

    /// The live card's lines: lookalikes **in the top half of the screen**, where the card was drawn (60 pt
    /// from the top, 80 pt from the left). Measured in this pass's first run and kept as the reason: Apple's
    /// own transport bar carries the same "LIVE" badge and the same "ch9001 HISTORY" title — the item's
    /// metadata — along the bottom of the screen, and keeps them in the accessibility tree while hidden, so
    /// a text-only check read them at every step although no card was drawn (screenshots 110e and 110h of
    /// that run). Text alone cannot tell the two apart at the live edge; position can.
    private func liveCardLines(title: String) -> [String] {
        let screenMidY = app.frame.midY
        return liveLookalikes(title: title)
            .filter { !$0.frame.isEmpty && $0.frame.midY < screenMidY }
            .map { "\($0.label) @ y \(Int($0.frame.minY))" }
    }

    private func describeLookalikes(_ title: String) -> String {
        liveLookalikes(title: title).map { "\"\($0.label)\" @ x \(Int($0.frame.minX)) y \(Int($0.frame.minY))" }.joined(separator: ", ")
    }

    /// Apple's transport clock texts, "05:16" and the like — read, never relied on alone.
    private func clockTexts() -> [String] {
        screenText().filter { $0.range(of: "^-?[0-9]{1,2}:[0-9]{2}(:[0-9]{2})?$", options: .regularExpression) != nil }
    }

    /// Playback has started once the Starting screen has come and gone.
    private func waitForPlayback(_ what: String) -> Bool {
        sleep(2)
        let gone = waitFor(120) { !starting }
        log("\(what): Starting screen gone \(gone)")
        return gone
    }

    private func waitOutSkipPrompt() {
        guard skipPromptUp else { return }
        log("the skip prompt is up — waiting it out rather than pressing Select")
        _ = waitFor(10) { !skipPromptUp }
    }

    func testNoTopCardOnARecordingOrALiveChannel() {
        // ================= a recording =================
        openFromHome("Recordings")
        XCTAssertTrue(app.staticTexts[shelvesNote].waitForExistence(timeout: 40), "the Recordings shelves did not appear")
        sleep(3)
        guard openShow(Self.show) else { return XCTFail("could not open \(Self.show)") }
        let play = focusedLabel()
        log("show detail focus, the control about to be pressed: \"\(play)\"")
        XCTAssertTrue(play.hasPrefix("Resume") || play == "Play newest", "focus is not on a play control: \(play)")
        remote.press(.select)
        XCTAssertTrue(waitForPlayback("recording"), "the recording never left the Starting screen")

        // Just started — the card used to show for 6 s here.
        sleep(1)
        var card = recordingCardLines()
        log("recording, just started: card lines \(card); clock texts \(clockTexts()); focus \(focusedLabel())")
        shot("110a-recording-started-no-card")
        XCTAssertTrue(card.isEmpty, "the recording card is drawn just after start: \(card)")

        // Paused — the card used to stay up for the whole pause.
        sleep(3)
        waitOutSkipPrompt()
        remote.press(.select)
        sleep(4)
        let pausedA = XCUIScreen.main.screenshot()
        let clockA = clockTexts()
        sleep(2)
        let pausedB = XCUIScreen.main.screenshot()
        let clockB = clockTexts()
        card = recordingCardLines()
        let framesStill = pausedA.pngRepresentation == pausedB.pngRepresentation
        let clockStill = !clockA.isEmpty && clockA == clockB
        log("recording, paused: frames identical \(framesStill); clock \(clockA) → \(clockB); card lines \(card); text \(screenText())")
        add(attachment(pausedB, "110b-recording-paused-no-card"))
        XCTAssertTrue(framesStill || clockStill, "no sign the recording paused — frames identical \(framesStill), clock \(clockA) → \(clockB)")
        XCTAssertTrue(card.isEmpty, "the recording card is drawn while paused: \(card)")

        // Resumed — the card used to show for 6 s again.
        remote.press(.select)
        sleep(2)
        card = recordingCardLines()
        let resumedA = XCUIScreen.main.screenshot()
        sleep(3)
        let resumedB = XCUIScreen.main.screenshot()
        log("recording, resumed: frames moving \(resumedA.pngRepresentation != resumedB.pngRepresentation); card lines \(card) / \(recordingCardLines())")
        XCTAssertTrue(card.isEmpty && recordingCardLines().isEmpty, "the recording card is drawn after resuming")
        XCTAssertNotEqual(resumedA.pngRepresentation, resumedB.pngRepresentation, "the recording did not resume")

        // Down opens the panel; Up closes it.
        remote.press(.down)
        XCTAssertTrue(waitFor(20) { panelUp }, "Down did not open the panel over the recording")
        sleep(3)
        log("recording panel up — title \(panelText("infoPanel.title") ?? "none") · button \(panelButton("infoPanel.pass") ?? "none") · focus \(focusedLabel())")
        shot("110c-recording-panel-up")
        remote.press(.up)
        XCTAssertTrue(waitFor(10) { !panelUp }, "Up did not close the panel over the recording")
        sleep(2)
        card = recordingCardLines()
        log("recording after Up: panel up \(panelUp); card lines \(card); focus \(focusedLabel())")
        shot("110d-recording-panel-closed-no-card")
        XCTAssertTrue(card.isEmpty, "the recording card is drawn after the panel closed: \(card)")

        remote.press(.menu)
        let backToShow = waitFor(20) {
            let f = focusedLabel()
            return f.hasPrefix("Resume") || f == "Play newest" || f == "Edit series pass" || f == "Record the series"
        }
        log("recording, after Menu: focus \(focusedLabel())")
        XCTAssertTrue(backToShow, "Menu did not return to show detail — focus is \(focusedLabel())")

        // ================= a live channel =================
        goHome()
        openFromHome("Favorites")
        XCTAssertTrue(app.staticTexts[favoritesNote].waitForExistence(timeout: 40), "Favorites did not appear")
        sleep(4)
        let row = focusedLabel()
        let parts = (row.components(separatedBy: ", ").first ?? "").components(separatedBy: " · ")
        let liveTitle = parts.count == 2 ? "ch\(parts[0]) \(parts[1])" : ""
        log("Favorites focus, the channel about to be played: \"\(row)\" → the live card's title would read \"\(liveTitle)\"")
        XCTAssertFalse(liveTitle.isEmpty, "could not read the channel off the Favorites row: \(row)")
        remote.press(.select)
        XCTAssertTrue(waitForPlayback("live"), "the live channel never left the Starting screen")

        // Just started — the live card used to show for 6 s here.
        sleep(1)
        card = liveCardLines(title: liveTitle)
        log("live, just started: card lines \(card); lookalikes anywhere: \(describeLookalikes(liveTitle)); screen midY \(Int(app.frame.midY)); focus \(focusedLabel())")
        shot("110e-live-started-no-card")
        XCTAssertTrue(card.isEmpty, "the live card is drawn just after start: \(card)")

        // Paused — the paused-live screen (6d) comes up; it is not the card and stays.
        sleep(3)
        remote.press(.select)
        let pausedLive = app.staticTexts["Paused"].waitForExistence(timeout: 10)
        sleep(2)
        card = liveCardLines(title: liveTitle)
        log("live, paused: paused-live screen \(pausedLive); card lines \(card); lookalikes anywhere: \(describeLookalikes(liveTitle)); text \(screenText())")
        shot("110f-live-paused-no-card")
        XCTAssertTrue(pausedLive, "the live channel did not pause")
        XCTAssertTrue(card.isEmpty, "the live card is drawn while paused: \(card)")

        // Resumed — the live card used to show for 6 s again.
        remote.press(.select)
        let resumedLive = waitFor(10) { !app.staticTexts["Paused"].exists }
        sleep(1)
        card = liveCardLines(title: liveTitle)
        log("live, resumed: paused screen gone \(resumedLive); card lines \(card); lookalikes anywhere: \(describeLookalikes(liveTitle))")
        XCTAssertTrue(resumedLive, "the live channel did not resume")
        XCTAssertTrue(card.isEmpty, "the live card is drawn after resuming: \(card)")

        // Down opens the panel; Up closes it.
        remote.press(.down)
        XCTAssertTrue(waitFor(25) { panelUp }, "Down did not open the panel over the live channel")
        sleep(4)
        log("live panel up — title \(panelText("infoPanel.title") ?? "none") · record \(panelButton("infoPanel.record") ?? "none") · favorite \(panelButton("infoPanel.favorite") ?? "none") · focus \(focusedLabel())")
        shot("110g-live-panel-up")
        remote.press(.up)
        XCTAssertTrue(waitFor(10) { !panelUp }, "Up did not close the panel over the live channel")
        sleep(2)
        card = liveCardLines(title: liveTitle)
        log("live after Up: panel up \(panelUp); card lines \(card); lookalikes anywhere: \(describeLookalikes(liveTitle)); focus \(focusedLabel())")
        shot("110h-live-panel-closed-no-card")
        XCTAssertTrue(card.isEmpty, "the live card is drawn after the panel closed: \(card)")

        remote.press(.menu)
        let backToFavorites = waitFor(20) { focusedLabel().contains(" · ") }
        log("live, after Menu: focus \(focusedLabel())")
        XCTAssertTrue(backToFavorites, "Menu did not return to Favorites — focus is \(focusedLabel())")
    }

    private func attachment(_ screenshot: XCUIScreenshot, _ name: String) -> XCTAttachment {
        let a = XCTAttachment(screenshot: screenshot)
        a.name = name
        a.lifetime = .keepAlways
        return a
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
