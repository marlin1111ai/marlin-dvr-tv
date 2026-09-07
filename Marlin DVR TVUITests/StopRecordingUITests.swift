//
//  StopRecordingUITests.swift
//  Marlin DVR TVUITests
//
//  Pass 32 item A's evidence harness, not a standing test. It runs on the physical Apple TV and
//  drives the real Siri Remote through the owner's own flow: open the Guide, hold on the
//  programme that is on now, book it with "Record this airing", come back to it with a second
//  hold, and stop it.
//
//  It makes real server writes — one POST /api/record and one POST /api/schedule/jobs/{id}/stop
//  — and leaves a short recording behind, exactly as Pass 8's throwaway did. Both were asked for
//  by step 4 of the pass. It never presses Empty Trash and never deletes anything.
//
//  Stop is armed on the first click, so the test clicks it twice and asserts the wording changes
//  in between: a single click must not stop a recording.
//
//  Every query here is scoped and short-circuited (`firstMatch`, an exact label). The first
//  version of this harness enumerated `app.staticTexts.allElementsBoundByIndex` on the Guide,
//  which has 83 channel rows, and each such call took about five minutes on the device — long
//  enough that the programme ended before Stop could be pressed. Do not reintroduce that.
//

import XCTest

final class StopRecordingUITests: XCTestCase {
    private var app: XCUIApplication!
    private let remote = XCUIRemote.shared

    private let guideLegend = "Recording or set to record"
    private let seriesTitle = "Record the series"      // always on the sheet: proof it is open
    private let recordTitle = "Record this airing"
    private let stopTitle = "Stop recording"
    private let stopArmed = "Stop recording — click again"

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    private func shot(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    private func stamp() -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss.SSS"; return f.string(from: Date())
    }
    private func log(_ s: String) { print("[pass32 \(stamp())] \(s)") }

    /// Short-circuited: stops at the first hit instead of walking the whole tree.
    private func text(beginning prefix: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
    }

    private func focusedLabel() -> String {
        app.buttons.matching(NSPredicate(format: "hasFocus == true")).firstMatch.label
    }

    /// Only on a failure, and bounded — this is the expensive call.
    private func diagnose() -> [String] {
        Array(app.staticTexts.allElementsBoundByIndex.prefix(30).map(\.label).filter { !$0.isEmpty })
    }

    private func holdTheCurrentProgramme(_ tag: String) {
        log("\(tag): holding, focus is \(focusedLabel())")
        remote.press(.select, forDuration: 1.2)
        XCTAssertTrue(app.buttons[seriesTitle].waitForExistence(timeout: 25),
                      "the airing sheet did not open (\(tag))")
        sleep(3)   // the sheet's own GET /api/passes and GET /api/schedule
    }

    func testStopARecordingStartedFromTheGuide() {
        XCTAssertTrue(app.staticTexts["Marlin"].waitForExistence(timeout: 60), "Home did not appear")
        sleep(3)
        remote.press(.select)                                   // Guide is the first Home tile
        XCTAssertTrue(app.staticTexts[guideLegend].waitForExistence(timeout: 60), "the Guide did not load")
        sleep(5)

        // ---- book the programme that is on now
        holdTheCurrentProgramme("book")
        shot("01-sheet-before-recording")
        XCTAssertTrue(app.buttons[recordTitle].exists, "the sheet did not offer \(recordTitle): \(diagnose())")
        XCTAssertFalse(app.buttons[stopTitle].exists, "Stop was offered before anything was recording")
        XCTAssertEqual(focusedLabel(), recordTitle, "the sheet did not open on \(recordTitle)")

        remote.press(.select)
        XCTAssertTrue(text(beginning: "Set to record").waitForExistence(timeout: 30),
                      "the server did not accept the booking: \(diagnose())")
        let booked = text(beginning: "Set to record").label
        log("booked: \"\(booked)\"")
        shot("02-sheet-after-booking")

        // ---- come back to it, which is where Stop must appear
        remote.press(.menu)
        sleep(3)
        holdTheCurrentProgramme("reopen")
        shot("03-sheet-reopened-while-recording")

        XCTAssertTrue(app.buttons[stopTitle].waitForExistence(timeout: 30),
                      "Stop recording was not offered while the airing was recording: \(diagnose())")

        // ---- arm it, and prove one click is not enough
        var reached = false
        for _ in 0..<6 {
            if focusedLabel() == stopTitle { reached = true; break }
            remote.press(.right)
            usleep(900_000)
        }
        XCTAssertTrue(reached, "could not move focus to Stop — focus is \(focusedLabel())")

        remote.press(.select)                                   // first click: arms only
        XCTAssertTrue(app.buttons[stopArmed].waitForExistence(timeout: 10),
                      "the first click did not arm Stop: \(diagnose())")
        XCTAssertTrue(text(beginning: "This keeps what has recorded").exists,
                      "arming did not say what would be lost")
        log("armed")
        shot("04-stop-armed")

        // ---- confirm
        remote.press(.select)                                   // second click: the write
        XCTAssertTrue(text(beginning: "Recording stopped").waitForExistence(timeout: 40),
                      "the sheet did not report the stop: \(diagnose())")
        let stopped = text(beginning: "Recording stopped").label
        log("stopped: \"\(stopped)\"")
        sleep(2)
        shot("05-after-the-stop")

        XCTAssertFalse(app.buttons[stopTitle].exists,
                       "Stop is still offered after the recording was stopped")
        XCTAssertFalse(app.buttons[stopArmed].exists, "Stop is still armed after the write")
    }
}
