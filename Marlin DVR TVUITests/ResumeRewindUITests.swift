//
//  ResumeRewindUITests.swift
//  Marlin DVR TVUITests
//
//  Pass 96's evidence harness, not a standing test. It needs the physical Apple TV
//  ("Home Theater"), the real Siri Remote, and **a saved position on `5328bb632e76`** — History's
//  Greatest Mysteries S4 E14 "Who Is D.B. Cooper?", the one recording in the owner's library with
//  detected commercial breaks that this project has ever proved anything on.
//
//  **What it is for.** Before Pass 96 a resumed recording's session carried `start: N`, the server
//  applied it as ffmpeg's `-ss`, and the single-file MP4 it built *began* at the resume point — so
//  there was no picture before it to rewind to. The session now asks for the whole recording and
//  the app seeks to the saved position once the item is ready. This drives the three claims that
//  follow from that, in one playback and in this order:
//
//    1. Resume lands on the **saved position**, not at 0.
//    2. Scrubbing back with the remote reaches **0:00** — the part that did not exist before.
//    3. The commercial prompt arms at the next break and **Select lands on that break's
//       `endSeconds`** — and the break it proves this on, 176.54–206.54 s, is one of the three that
//       used to be inside the trimmed-away part of the file and could not be reached at all.
//
//  **`launch()`, not `activate()`** (Pass 92): this harness attaches no console, and `activate()`
//  would resume whatever build happened to be running. The app's launch ping in the server's own
//  log (`ClientSession.swift:8-9`) is the proof that the build just installed is the build tested.
//
//  **It clears no saved position.** Playing saves one every 10 seconds, so the position moves
//  while this runs; step 4 ends by scrubbing back up to roughly where it started, so what is left
//  behind is a position on the same recording rather than a cleared one. Nothing is deleted,
//  trashed, kept, scheduled or marked watched, and the recording is never played to its end.
//
//  It reads where playback is from **the app's own HUD**, which `PlayerScreen` keeps on screen for
//  as long as a recording is paused (`PlayerModel.timeControlChanged` → `showHUD(for: nil)`), so a
//  pause is how this harness takes a reading.
//

import XCTest

final class ResumeRewindUITests: XCTestCase {
    private var app: XCUIApplication!
    private let remote = XCUIRemote.shared

    /// Home tile order, frame 2a — three rows of three (Destination.homeTiles).
    private static let homeTiles = ["Guide", "On Now", "On Later",
                                    "Recordings", "Cameras", "Favorites",
                                    "Weather", "Radio", "Settings"]
    /// Only on the Recordings shelves.
    private let shelvesNote = "Watched and keep flags are shared with the other Apple TV"
    /// Only in show detail.
    private let detailNote = "Click and hold an episode for Keep and Delete"
    /// The Pass 38 prompt. Nothing else in the app draws this string.
    private let promptText = "Skip the commercial break"

    /// The subject: `5328bb632e76`, reached through its show.
    private static let show = "History's Greatest Mysteries"
    /// Its four breaks, from `GET /api/library/recordings/5328bb632e76/commercials` as Pass 94
    /// last read it. The harness does not decide in advance which one it will prove: it walks
    /// forward until the prompt arms and then checks that the skip landed on the `endSeconds` of
    /// whichever of these the skip belonged to. Each range prompts **at most once per playback**
    /// (`PlayerModel.noticeCommercialBreak`), so which one is available depends on where the
    /// playback has already been — and that is the app's design, not a variable to pin down.
    private static let breaks: [(start: Double, end: Double)] = [
        (176.54, 206.54), (305.57, 371.54), (730.56, 925.46), (1271.20, 1478.54)
    ]
    /// Where the owner's position on this recording sat before Pass 96's first harness run; the
    /// run ends by walking back up to it, so what is left behind is his position, not the top of
    /// the recording or the middle of it.
    private static let restoreTo = 931.0

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launch()
        goHome()
    }

    // MARK: reading the device

    private func shot(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    private func stamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: Date())
    }

    private func log(_ line: String) { print("[pass96 \(stamp())] \(line)") }

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

    private var promptOnScreen: Bool { app.staticTexts[promptText].exists }

    /// The prompt owns Select for the five seconds it is up (`PlayerHost.armSelectOwnership`), so
    /// every Select this harness presses for some other reason waits for it to go first. Letting it
    /// time out is also the only way to leave the break unskipped.
    private func waitForPromptToClear(_ why: String) {
        guard promptOnScreen else { return }
        log("the skip prompt is up (\(why)) — waiting it out rather than pressing Select")
        for _ in 0..<10 {
            sleep(1)
            if !promptOnScreen { return }
        }
        log("the prompt is still up after 10 s (\(why))")
    }

    /// Apple's own transport-bar clock — "05:16" and the like. The one reading available while the
    /// prompt is up, because taking the app's own needs a Select the prompt would consume.
    private func transportClock() -> Double? {
        for text in screenText() where text.range(of: "^[0-9]{1,2}:[0-9]{2}(:[0-9]{2})?$", options: .regularExpression) != nil {
            if let s = Self.seconds(text) { return s }
        }
        return nil
    }

    /// "12:34" / "1:02:14" → seconds. Anything else → nil.
    private static func seconds(_ clock: String) -> Double? {
        let bits = clock.split(separator: ":").map(String.init)
        guard bits.count == 2 || bits.count == 3, bits.allSatisfy({ Int($0) != nil }) else { return nil }
        let n = bits.compactMap { Double($0) }
        return bits.count == 2 ? n[0] * 60 + n[1] : n[0] * 3600 + n[1] * 60 + n[2]
    }

    /// The recording HUD's "x of y" (`PlayerScreen.swift`, RecordingHUD), turned back into seconds.
    private func hudPosition() -> Double? {
        for text in screenText() where text.contains(" of ") {
            let parts = text.components(separatedBy: " of ")
            guard parts.count == 2, let here = Self.seconds(parts[0]), Self.seconds(parts[1]) != nil else { continue }
            return here
        }
        return nil
    }

    /// Pause, read the HUD it brings up, photograph it, and carry on playing.
    ///
    /// **It must be entered while playing and it always leaves playing.** Pass 96's first run broke
    /// on exactly that: a stray Select had already paused the player, so this pressed Select to
    /// "pause" (which played), read, and pressed Select again (which paused) — and the Right
    /// presses that followed went to the app's frame stepper instead of Apple's transport, moving
    /// playback 0.033367 s a click instead of 10 s. So this now waits out any prompt first and
    /// checks that the pause actually took.
    @discardableResult
    private func readPaused(_ name: String) -> Double? {
        waitForPromptToClear(name)
        remote.press(.select)
        sleep(4)
        let here = hudPosition()
        log("\(name): paused at \(here.map { String(format: "%.0f s", $0) } ?? "nothing readable") — \(screenText())")
        shot(name)
        XCTAssertNotNil(here, "\(name): the recording HUD was not up, so this was not a pause — the player may have been paused already")
        remote.press(.select)
        sleep(3)
        return here
    }

    // MARK: driving the remote

    private func goHome() {
        for _ in 0..<7 {
            if app.staticTexts["Marlin"].waitForExistence(timeout: 10) { sleep(2); return }
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
        let dRow = target / 3 - here / 3, dCol = target % 3 - here % 3
        for _ in 0..<abs(dRow) { remote.press(dRow > 0 ? .down : .up); usleep(700_000) }
        for _ in 0..<abs(dCol) { remote.press(dCol > 0 ? .right : .left); usleep(700_000) }
        remote.press(.select)
    }

    /// Walk the whole shelf grid to the named show and open it. The shelves reorder themselves as
    /// recordings are played, so nothing here assumes a fixed position.
    private func openShow(_ needle: String) -> Bool {
        var seen: [String] = []
        for row in 0..<4 {
            for _ in 0..<8 { remote.press(.left); usleep(420_000) }
            for _ in 0..<9 {
                let here = focusedLabel()
                if !seen.contains(here) { seen.append(here) }
                if here.contains(needle) {
                    log("row \(row): focus is \"\(here)\" — opening it")
                    remote.press(.select)
                    guard app.staticTexts[detailNote].waitForExistence(timeout: 40) else {
                        log("show detail did not open"); return false
                    }
                    sleep(3)
                    return true
                }
                remote.press(.right)
                usleep(600_000)
            }
            remote.press(.down)
            usleep(900_000)
        }
        log("no shelf card matched \"\(needle)\". Focus visited: \(seen)")
        return false
    }

    /// Apple's own transport skip, which is ±10 s a click and is untouched by this app while a
    /// recording is playing. `stopAtPrompt` ends the walk the moment the skip prompt appears.
    /// `gap` matters. Pass 38 walked at 1.2 s a press so the model's 1 Hz `tick()` — the only thing
    /// that notices a break — had time to land inside one. Pass 96's first run walked at 340 ms and
    /// crossed a 30-second break in about one second of wall time, which is part of why no prompt
    /// armed. Scrubbing that is not hunting for a break keeps the fast pace.
    @discardableResult
    private func skip(_ button: XCUIRemote.Button, _ presses: Int, gap: UInt32 = 340_000, stopAtPrompt: Bool = false) -> Int {
        for n in 0..<presses {
            if stopAtPrompt && promptOnScreen { return n }
            remote.press(button)
            usleep(gap)
            if stopAtPrompt && promptOnScreen { return n + 1 }
        }
        return presses
    }

    // MARK: the pass's question

    func testResumeLandsOnTheSavedPositionRewindsToZeroAndSkipsABreak() {
        openFromHome("Recordings")
        XCTAssertTrue(app.staticTexts[shelvesNote].waitForExistence(timeout: 40), "the Recordings shelves did not appear")
        sleep(3)
        XCTAssertTrue(openShow(Self.show), "could not open \(Self.show)")

        // Show detail puts focus on Resume whenever a saved position exists (`.defaultFocus`), so a
        // bare Select here is the Resume press — the same one the owner makes.
        let resumeLabel = focusedLabel()
        log("show detail focus: \"\(resumeLabel)\"")
        XCTAssertTrue(resumeLabel.hasPrefix("Resume"), "the focused control is not Resume — it is \(resumeLabel)")
        shot("96a-show-detail-resume-button")
        remote.press(.select)

        // ---- CLAIM 1: Resume lands on the saved position, not at 0 ----
        XCTAssertTrue(app.staticTexts["Resume kept by D/S Apple TV"].waitForExistence(timeout: 120)
                      || hudPosition() != nil, "the player never reached the recording HUD")
        sleep(6)
        guard let landed = readPaused("96b-resumed-at-the-saved-position") else {
            return XCTFail("could not read the HUD after Resume")
        }
        XCTAssertGreaterThan(landed, 60, "Resume started at \(landed) s — that is the top of the recording, not the saved position")
        log("CLAIM 1: Resume landed at \(landed) s, not 0")

        // ---- CLAIM 2: scrubbing back reaches 0:00 ----
        // Every second of this was absent from the file before Pass 96: the server trimmed it away
        // with -ss, so there was nothing here to seek to.
        var here = landed
        var pressed = 0
        while here > 2, pressed < 300 {
            pressed += skip(.left, 20)
            waitForPromptToClear("scrubbing back, press \(pressed)")
            guard let now = readPaused("96c-scrubbing-back-\(pressed)") else { break }
            log("after \(pressed) left presses: \(now) s")
            if now >= here - 1 { log("the clock stopped moving at \(now) s"); here = now; break }
            here = now
        }
        shot("96d-rewound-to-the-start")
        XCTAssertLessThan(here, 15, "scrubbing back stopped at \(here) s and never reached the start")
        log("CLAIM 2: scrubbing back reached \(here) s after \(pressed) left presses")

        // ---- CLAIM 3: the prompt arms at a break, and Select lands on that break's endSeconds ----
        // Walk forward at Pass 38's pace until it arms. Which break it arms on depends on which are
        // still unspent for this playback, so the harness reads the transport clock when it arms and
        // checks the landing against the break that clock sits in.
        var whenArmed: Double?
        var rightPresses = 0
        while rightPresses < 140, !promptOnScreen {
            rightPresses += skip(.right, 5, gap: 1_200_000, stopAtPrompt: true)
            if promptOnScreen { whenArmed = transportClock(); break }
        }
        log("pressed Right \(rightPresses) time(s); prompt on screen: \(promptOnScreen); transport clock \(whenArmed.map { String(format: "%.0f s", $0) } ?? "unreadable")")
        XCTAssertTrue(promptOnScreen, "the skip prompt did not arm at any break: \(screenText())")
        shot("96e-prompt-armed-at-a-break")
        guard promptOnScreen else { return }
        log("CLAIM 3a: the prompt armed at about \(whenArmed.map { String(format: "%.0f s", $0) } ?? "an unread position")")

        remote.press(.select)   // the app owns Select while the prompt is up: this is the skip
        sleep(4)
        guard let afterSkip = readPaused("96f-landed-on-the-breaks-end") else {
            return XCTFail("could not read the HUD after the skip")
        }
        // The skip must land on the end of one of the four breaks — the one it belonged to. The
        // reading is taken a few seconds later, so playback has moved on a little.
        let match = Self.breaks.first { afterSkip >= $0.end - 2 && afterSkip < $0.end + 20 }
        log("CLAIM 3b: the skip put playback at \(afterSkip) s; nearest break end: \(match.map { String(format: "%.2f s", $0.end) } ?? "none of the four")")
        XCTAssertNotNil(match, "the skip landed at \(afterSkip) s, which is not the end of any of the four breaks \(Self.breaks)")
        if let armedAt = whenArmed, let containing = Self.breaks.first(where: { armedAt >= $0.start - 12 && armedAt < $0.end }) {
            XCTAssertEqual(match?.end ?? -1, containing.end, accuracy: 0.01,
                           "the prompt armed inside the break ending at \(containing.end) s but the skip landed past \(match?.end ?? -1) s")
        }

        // ---- leave the owner's saved position where it was found ----
        var restored = afterSkip
        var restorePresses = 0
        while restored < Self.restoreTo - 12, restorePresses < 220 {
            restorePresses += skip(.right, 20)
            waitForPromptToClear("restoring, press \(restorePresses)")
            guard let now = readPaused("96g-restoring-\(restorePresses)") else { break }
            log("restoring: after \(restorePresses) right presses, \(now) s")
            if now <= restored + 1 { log("the clock stopped moving at \(now) s"); restored = now; break }
            restored = now
        }
        shot("96h-position-restored")
        log("leaving with the position at \(restored) s; Pass 96 found it at \(Self.restoreTo) s before its first run")

        remote.press(.menu)
        sleep(5)
    }
}
