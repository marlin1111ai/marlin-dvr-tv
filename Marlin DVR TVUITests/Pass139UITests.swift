//
//  Pass139UITests.swift
//  Marlin DVR TVUITests
//
//  Pass 139's evidence harness, not a standing test: the `marlindvr://` deep links and the notify banner. XCUITest
//  cannot open a URL on tvOS — `XCUIApplication.open(_:)` is not in the tvOS SDK's XCUIApplication.h — so the links
//  are sent from the Mac, to the app already running, with
//    xcrun devicectl device process launch --device "Home Theater" --payload-url "<link>" com.marlin1111.MarlinDVRTV
//  while this method, joined to that process — neither `launch()` nor `activate()` (Pass 116) — watches the screen
//  for `watchSeconds`, logging every change of the banner's text, the Player's title and subtitle, the Starting
//  screen and the open section, and keeping a screenshot of each change. It presses nothing and makes no write
//  beyond the live sessions the links themselves open and close. The cold-start case (a link launching the app)
//  is read from the app's console instead: `devicectl … --console --terminate-existing --payload-url "<link>"`.
//
//  Run (the app first, then this, then the links from a third shell):
//    xcrun devicectl device process launch --device "Home Theater" --console --terminate-existing com.marlin1111.MarlinDVRTV &
//    xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" -derivedDataPath build/dd-device \
//      -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates test \
//      -only-testing:"Marlin DVR TVUITests/Pass139UITests/testWatchTheScreenWhileLinksArrive"
//

import XCTest

final class Pass139UITests: XCTestCase {
    private var app: XCUIApplication!
    private let watchSeconds: TimeInterval = 300

    private static let sections = ["Favorites", "On Now", "Guide", "On Later", "Recordings", "Cameras", "Weather", "Radio", "Search", "Manage DVR", "Settings"]

    override func setUp() {
        continueAfterFailure = true
        app = XCUIApplication()
        log("joining the running app — no launch()")
    }

    // MARK: reading the device

    private func stamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: Date())
    }

    private func log(_ line: String) { print("[pass139 \(stamp())] \(line)") }

    private func shot(_ name: String) {
        let a = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    /// The banner's text while it shows — `NotifyBannerView` identifies it; it lives in the app's second window.
    private func bannerText() -> String? {
        let banner = app.descendants(matching: .any).matching(identifier: "notifyBanner").firstMatch
        return banner.exists ? banner.label : nil
    }

    /// The live item's title, "ch2.1 WMAR-HD" (Pass 138's reading).
    private func playingTitle() -> String? {
        app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^ch[0-9].*")).allElementsBoundByIndex
            .map(\.label).first { !$0.contains(" · ") }
    }

    /// The item's subtitle — "<programme> · until 7:00 PM" live, "S1 E2 · <episode>" on a recording.
    private func playingSubtitle() -> String? {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", " · ")).allElementsBoundByIndex.first?.label
    }

    /// Only the Starting screen (6a) draws this.
    private var starting: Bool {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Press Menu to cancel'")).firstMatch.exists
    }

    /// The open section's title, when one of the eleven is on screen; Home draws none of them as a title.
    private func screenTitle() -> String? {
        Self.sections.first { app.staticTexts[$0].exists }
    }

    // MARK: the watch

    func testWatchTheScreenWhileLinksArrive() {
        let deadline = Date().addingTimeInterval(watchSeconds)
        var last = ""
        var n = 0
        shot("00 joined")
        log("watching for \(Int(watchSeconds)) s")
        while Date() < deadline {
            let state = "banner=\(bannerText() ?? "-") | title=\(playingTitle() ?? "-") | subtitle=\(playingSubtitle() ?? "-") | starting=\(starting) | section=\(screenTitle() ?? "-")"
            if state != last {
                n += 1
                log("CHANGE \(n): \(state)")
                shot(String(format: "%02d %@", n, state))
                last = state
            }
            usleep(400_000)
        }
        log("watch over after \(n) changes")
    }
}
