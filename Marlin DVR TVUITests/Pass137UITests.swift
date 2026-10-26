//
//  Pass137UITests.swift
//  Marlin DVR TVUITests
//
//  Pass 137's evidence harness, not a standing test: On Now on the grid container with the
//  sideways-scrolling filter bar (the shell no longer shifts left and the open sidebar is whole),
//  On Later on the same container, show detail's 2:3 poster, Favorites' tags, the schedule's rows
//  and Settings on the list-plus-detail container. It needs the physical Apple TV ("Home Theater")
//  and the owner's server.
//
//  The second method is the owner's two photo defects of 2026-10-26: a focused card in the first
//  column of On Now and On Later starts at or inside the content's left edge, a focused card in
//  the third column ends at or inside its right edge, and the top row's ring is below the top of
//  the grid's scroll area. **The edges are read from the focus ring's own pixels in the
//  screenshot**, not from the accessibility frame: a card whose art is a landscape picture filled
//  into the 2:3 poster box reports a frame as wide as the unclipped picture (On Later's first card
//  read 26 pt wider than it is drawn), so the frame is logged and the pixels are the evidence.
//
//  **It makes no server write.** Select is pressed on Home's tiles, sidebar entries, one Recordings
//  card and Manage DVR's "Scheduled Recordings" row — never on a card that plays, records or deletes.
//  **`launch()`, not `activate()`** (Pass 92). **Every press is a click** (no swipe, no hold).
//
//  Run:
//    xcodebuild -project "Marlin DVR TV.xcodeproj" -scheme "Marlin DVR TV" \
//      -destination 'platform=tvOS,name=Home Theater' -allowProvisioningUpdates test \
//      -only-testing:"Marlin DVR TVUITests/Pass137UITests"
//

import UIKit
import XCTest

final class Pass137UITests: XCTestCase {
    private var app: XCUIApplication!
    private let remote = XCUIRemote.shared

    private static let railLabels = ["Home", "Favorites", "On Now", "Guide", "On Later", "Recordings", "Cameras", "Weather", "Radio", "Search", "Manage DVR", "Settings"]
    private static let homeTiles = [["Guide", "On Now", "On Later"], ["Recordings", "Cameras", "Favorites"], ["Weather", "Radio", "Settings"]]
    /// The content's inner edge beside the collapsed rail: 180 + 56 = 236; a card scaled 5 % on
    /// focus starts about 13 pt before it. Pass 136 read the first On Now card at x 191 — the shift.
    private static let contentInnerEdge: CGFloat = 236
    /// The content's outer edge: the screen less the design's 80 pt margin.
    private static let contentOuterEdge: CGFloat = 1920 - 80

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

    private func log(_ line: String) { print("[pass137 \(stamp())] \(line)") }

    private func shot(_ name: String) { attach(XCUIScreen.main.screenshot(), name) }

    private func attach(_ screenshot: XCUIScreenshot, _ name: String) {
        let a = XCTAttachment(screenshot: screenshot)
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }

    // MARK: reading the screenshot's pixels

    /// The focus ring's colour — Nocturne.accent, #9184D9 — matched within 16 per channel, which
    /// leaves out everything else that can share its row or column: the tag ink (accent300,
    /// #D2CEFD), the tag and active-chip rings (accent700, #5D5294) and accent600 (#796CBF).
    private func isRing(_ r: UInt8, _ g: UInt8, _ b: UInt8) -> Bool {
        abs(Int(r) - 0x91) <= 16 && abs(Int(g) - 0x84) <= 16 && abs(Int(b) - 0xD9) <= 16
    }

    /// One pixel row of the screenshot (at `y` points) as RGBA bytes, with the pixels per point.
    private func rowPixels(of screenshot: XCUIScreenshot, y: CGFloat) -> ([UInt8], CGFloat)? {
        guard let cg = screenshot.image.cgImage else { return nil }
        let w = cg.width, h = cg.height
        let scale = CGFloat(h) / 1080
        let py = min(max(Int(y * scale), 0), h - 1)
        var row = [UInt8](repeating: 0, count: w * 4)
        let drawn = row.withUnsafeMutableBytes { buffer -> Bool in
            guard let ctx = CGContext(data: buffer.baseAddress, width: w, height: 1, bitsPerComponent: 8, bytesPerRow: w * 4,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(cg, in: CGRect(x: 0, y: -CGFloat(h - 1 - py), width: CGFloat(w), height: CGFloat(h)))
            return true
        }
        return drawn ? (row, scale) : nil
    }

    /// One pixel column of the screenshot (at `x` points) as RGBA bytes, top row first.
    private func columnPixels(of screenshot: XCUIScreenshot, x: CGFloat) -> ([UInt8], CGFloat)? {
        guard let cg = screenshot.image.cgImage else { return nil }
        let w = cg.width, h = cg.height
        let scale = CGFloat(w) / 1920
        let px = min(max(Int(x * scale), 0), w - 1)
        var column = [UInt8](repeating: 0, count: h * 4)
        let drawn = column.withUnsafeMutableBytes { buffer -> Bool in
            guard let ctx = CGContext(data: buffer.baseAddress, width: 1, height: h, bitsPerComponent: 8, bytesPerRow: 4,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(cg, in: CGRect(x: -CGFloat(px), y: 0, width: CGFloat(w), height: CGFloat(h)))
            return true
        }
        return drawn ? (column, scale) : nil
    }

    /// The leftmost and rightmost ring-coloured pixels on the row through `y`, between `fromX` and
    /// `toX`, in points (the right value is the far edge of the last pixel).
    private func ringSpan(in screenshot: XCUIScreenshot, y: CGFloat, fromX: CGFloat, toX: CGFloat) -> (left: CGFloat, right: CGFloat)? {
        guard let (row, scale) = rowPixels(of: screenshot, y: y) else { return nil }
        let count = row.count / 4
        var left: Int?, right: Int?
        for x in max(0, Int(fromX * scale))..<min(count, Int(toX * scale)) where isRing(row[x * 4], row[x * 4 + 1], row[x * 4 + 2]) {
            if left == nil { left = x }
            right = x
        }
        guard let left, let right else { return nil }
        return (CGFloat(left) / scale, CGFloat(right + 1) / scale)
    }

    /// The topmost ring-coloured pixel on the column through `x`, between `fromY` and `toY`, in points.
    private func ringTop(in screenshot: XCUIScreenshot, x: CGFloat, fromY: CGFloat, toY: CGFloat) -> CGFloat? {
        guard let (column, scale) = columnPixels(of: screenshot, x: x) else { return nil }
        let count = column.count / 4
        for y in max(0, Int(fromY * scale))..<min(count, Int(toY * scale)) where isRing(column[y * 4], column[y * 4 + 1], column[y * 4 + 2]) {
            return CGFloat(y) / scale
        }
        return nil
    }

    private func focusedElements() -> [XCUIElement] {
        app.descendants(matching: .any).matching(NSPredicate(format: "hasFocus == YES")).allElementsBoundByIndex
    }

    private func focusLine() -> String {
        let focused = focusedElements()
        if focused.isEmpty { return "NOTHING FOCUSED" }
        return focused.map { f in
            "\(f.elementType.rawValue):\u{201C}\(f.label)\u{201D} \(rect(f.frame))"
        }.joined(separator: " | ")
    }

    private func focusedLabel() -> String? { focusedElements().first?.label }
    private func focusedFrame() -> CGRect? { focusedElements().first?.frame }
    private func rect(_ r: CGRect) -> String { "(\(Int(r.minX)),\(Int(r.minY)) \(Int(r.width))x\(Int(r.height)))" }

    private func sidebarOpen() -> Bool { app.buttons["Manage DVR"].exists }

    private func waitSidebar(open: Bool, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if sidebarOpen() == open { return true }
            usleep(200_000)
        }
        return sidebarOpen() == open
    }

    // MARK: driving

    private func homeTile(_ name: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(name), ")).firstMatch
    }

    private func tilePosition(of label: String?) -> (Int, Int)? {
        guard let label else { return nil }
        for (r, row) in Self.homeTiles.enumerated() {
            for (c, name) in row.enumerated() where label.hasPrefix("\(name), ") { return (r, c) }
        }
        return nil
    }

    private func focusTile(_ name: String) {
        for _ in 0..<12 {
            guard let here = tilePosition(of: focusedLabel()) else { remote.press(.up); usleep(800_000); continue }
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

    /// Menu opens the sidebar on the current entry (Pass 136); then Up or Down to the entry named.
    private func sidebar(to label: String) {
        if !sidebarOpen() {
            remote.press(.menu)
            XCTAssertTrue(waitSidebar(open: true, timeout: 5), "Menu did not open the sidebar; focus=\(focusLine())")
            sleep(1)
        }
        for _ in 0..<14 {
            guard let here = focusedLabel(), let from = Self.railLabels.firstIndex(of: here),
                  let to = Self.railLabels.firstIndex(of: label) else { break }
            if from == to { return }
            remote.press(from < to ? .down : .up)
            usleep(600_000)
        }
        XCTAssertEqual(focusedLabel(), label, "could not reach the \(label) entry; focus=\(focusLine())")
    }

    // MARK: the focus room in the grid (the owner's photos, 2026-10-26)

    func testFocusedCardsHaveRoomInTheGrid() {
        XCTAssertTrue(homeTile("Guide").waitForExistence(timeout: 40), "Home did not appear")
        sleep(3)

        focusTile("On Now")
        remote.press(.select)
        XCTAssertTrue(app.staticTexts["On Now"].waitForExistence(timeout: 30), "On Now did not open")
        XCTAssertTrue(waitSidebar(open: false, timeout: 20), "the sidebar did not collapse on On Now")
        sleep(3)
        checkColumns(screen: "ON NOW", shotPrefix: "10-on-now")

        sidebar(to: "On Later")
        remote.press(.select)
        XCTAssertTrue(app.buttons["On This Week"].waitForExistence(timeout: 30), "On Later did not open")
        sleep(4)
        checkColumns(screen: "ON LATER", shotPrefix: "12-on-later")
    }

    /// The focused card in the first column of the top row, then two Rights to the third column:
    /// the ring of each whole inside the content's edges, read from the screenshot's pixels, and
    /// the first one's ring below the top of the grid's scroll area.
    private func checkColumns(screen: String, shotPrefix: String) {
        guard let first = focusedFrame(), focusedLabel()?.contains("·") == true else {
            return XCTFail("\(screen): no card has focus; focus=\(focusLine())")
        }
        log("\(screen) first column focused \(rect(first)) focus=\(focusLine())")
        let scrolls = app.scrollViews.allElementsBoundByIndex.map(\.frame)
        for (i, frame) in scrolls.enumerated() { log("\(screen) scroll area \(i) \(rect(frame))") }
        // The grid's scroll area is the lowest one on the screen (the bar's is above it).
        let gridTop = scrolls.max(by: { $0.minY < $1.minY })?.minY

        let firstShot = XCUIScreen.main.screenshot()
        attach(firstShot, "\(shotPrefix)-first-column-focused")
        if let span = ringSpan(in: firstShot, y: first.midY, fromX: 180, toX: 1920) {
            log("\(screen) ring on the row through the first card: x \(Int(span.left))–\(Int(span.right))")
            XCTAssertGreaterThanOrEqual(span.left, Self.contentInnerEdge,
                                        "\(screen): the focused first-column card's ring starts left of the content's edge (x \(Int(span.left)))")
            XCTAssertLessThanOrEqual(span.left, Self.contentInnerEdge + 20,
                                     "\(screen): the first column is inset too far (ring at x \(Int(span.left)))")
        } else {
            XCTFail("\(screen): no focus ring found on the row through the first card")
        }
        if let top = ringTop(in: firstShot, x: first.midX, fromY: 220, toY: 1080) {
            log("\(screen) ring top on the column through the first card: y \(Int(top)) (scroll area top \(gridTop.map { Int($0) } ?? -1))")
            if let gridTop {
                XCTAssertGreaterThan(top, gridTop + 2,
                                     "\(screen): the top row's ring sits at the scroll area's top edge — clipped (y \(Int(top)) vs \(Int(gridTop)))")
            }
            XCTAssertLessThanOrEqual(top, first.minY + 24, "\(screen): the ring's top is far below the card's frame (y \(Int(top)) vs \(Int(first.minY)))")
        } else {
            XCTFail("\(screen): no focus ring found on the column through the first card")
        }

        remote.press(.right); usleep(700_000)
        remote.press(.right); usleep(700_000)
        guard let third = focusedFrame() else { return XCTFail("\(screen): nothing focused after two Rights") }
        log("\(screen) third column focused \(rect(third)) focus=\(focusLine())")
        XCTAssertLessThan(abs(third.midY - first.midY), 30, "\(screen): two Rights did not stay on the top row")
        XCTAssertGreaterThan(third.minX, first.maxX + 400, "\(screen): two Rights did not reach the third column")
        let thirdShot = XCUIScreen.main.screenshot()
        attach(thirdShot, "\(shotPrefix)-third-column-focused")
        if let span = ringSpan(in: thirdShot, y: third.midY, fromX: 180, toX: 1920) {
            log("\(screen) ring on the row through the third card: x \(Int(span.left))–\(Int(span.right))")
            XCTAssertLessThanOrEqual(span.right, Self.contentOuterEdge,
                                     "\(screen): the focused third-column card's ring runs past the content's right edge (right \(Int(span.right)))")
            XCTAssertGreaterThanOrEqual(span.right, Self.contentOuterEdge - 20,
                                        "\(screen): the third column stops too far from the right edge (ring right \(Int(span.right)))")
        } else {
            XCTFail("\(screen): no focus ring found on the row through the third card")
        }

        remote.press(.left); usleep(700_000)
        remote.press(.left); usleep(700_000)
    }

    // MARK: the run

    func testGridPagesContractBadgesAndListDetail() {
        XCTAssertTrue(homeTile("Guide").waitForExistence(timeout: 40), "Home did not appear")
        sleep(3)

        // On Now: the first card sits at the content's edge, not 32 pt left of it.
        focusTile("On Now")
        remote.press(.select)
        XCTAssertTrue(app.staticTexts["On Now"].waitForExistence(timeout: 30), "On Now did not open")
        XCTAssertTrue(waitSidebar(open: false, timeout: 20), "the sidebar did not collapse on On Now")
        sleep(3)
        guard let firstCard = focusedFrame() else { return XCTFail("nothing focused on On Now") }
        log("ON NOW first card \(rect(firstCard)) focus=\(focusLine())")
        XCTAssertGreaterThanOrEqual(firstCard.minX, Self.contentInnerEdge - 20, "On Now's first card is still shifted left (x \(Int(firstCard.minX)))")
        shot("01-on-now")

        // Up into the bar, then Right through every chip: each one is on screen as it takes focus.
        remote.press(.up)
        sleep(1)
        XCTAssertTrue(focusedLabel().map { ["Favorites", "HD"].contains($0) || $0.hasPrefix("All ") } == true, "Up did not land on a chip; focus=\(focusLine())")
        var chips: [String] = []
        for _ in 0..<24 {
            guard let label = focusedLabel(), let frame = focusedFrame() else { break }
            if chips.last == label { break }
            chips.append(label)
            log("chip \(label) \(rect(frame))")
            XCTAssertGreaterThanOrEqual(frame.minX, 0, "chip \(label) is off the left edge")
            XCTAssertLessThanOrEqual(frame.maxX, 1920, "chip \(label) is off the right edge — the bar did not scroll")
            remote.press(.right)
            usleep(700_000)
        }
        log("chips walked: \(chips.count) — \(chips.joined(separator: " | "))")
        XCTAssertGreaterThan(chips.count, 3, "fewer chips than Favorites · All · HD · a source")
        shot("02-on-now-bar-scrolled-to-the-end")
        // The grid did not move while the bar scrolled.
        remote.press(.down)
        sleep(1)
        if let card = focusedFrame() {
            log("card under the last chip \(rect(card)) focus=\(focusLine())")
            XCTAssertGreaterThanOrEqual(card.minX, Self.contentInnerEdge - 20, "the grid shifted while the bar scrolled")
        }

        // A Left out of the content: the sidebar opens whole — the On Now entry starts right of x 0.
        for _ in 0..<4 {
            if sidebarOpen() { break }
            remote.press(.left); sleep(1)
        }
        XCTAssertTrue(waitSidebar(open: true, timeout: 5), "Left did not open the sidebar")
        sleep(1)
        guard let entry = focusedFrame() else { return XCTFail("nothing focused in the sidebar") }
        log("SIDEBAR ON ON NOW \(focusLine())")
        XCTAssertEqual(focusedLabel(), "On Now", "the sidebar did not open on On Now")
        XCTAssertGreaterThan(entry.minX, 40, "the sidebar is still cut off at the left on On Now (x \(Int(entry.minX)))")
        let logo = app.images.firstMatch
        if logo.exists { log("logo \(rect(logo.frame))"); XCTAssertGreaterThanOrEqual(logo.frame.minX, 60, "the logo is cut off") }
        shot("03-sidebar-whole-on-on-now")

        // On Later on the same container.
        sidebar(to: "On Later")
        remote.press(.select)
        XCTAssertTrue(app.buttons["On This Week"].waitForExistence(timeout: 30), "On Later did not open")
        sleep(4)
        log("ON LATER focus=\(focusLine())")
        XCTAssertTrue(app.buttons["On Today"].exists && app.buttons["Premieres"].exists, "On Later's pills are missing")
        shot("04-on-later")

        // Favorites: the rows with the HD tag.
        sidebar(to: "Favorites")
        remote.press(.select)
        XCTAssertTrue(app.staticTexts["Favorites"].waitForExistence(timeout: 30), "Favorites did not open")
        sleep(3)
        log("FAVORITES focus=\(focusLine())")
        shot("05-favorites")

        // Recordings, then one show's detail: the 2:3 poster.
        sidebar(to: "Recordings")
        remote.press(.select)
        XCTAssertTrue(app.staticTexts["Recently Added"].waitForExistence(timeout: 30), "Recordings did not open")
        sleep(3)
        log("RECORDINGS focus=\(focusLine())")
        shot("06-recordings")
        guard let card = focusedLabel(), !card.isEmpty else { return XCTFail("no Recordings card has focus") }
        remote.press(.select)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Play newest")).firstMatch.waitForExistence(timeout: 30), "show detail did not open")
        sleep(3)
        log("SHOW DETAIL focus=\(focusLine())")
        shot("07-show-detail-poster-2x3")
        remote.press(.menu)
        XCTAssertTrue(app.staticTexts["Recently Added"].waitForExistence(timeout: 10), "Menu did not return to Recordings")
        sleep(1)

        // Manage DVR → Scheduled Recordings: the rows with the poster and the status chip.
        sidebar(to: "Manage DVR")
        remote.press(.select)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Scheduled Recordings")).firstMatch.waitForExistence(timeout: 30), "Manage DVR did not open")
        sleep(2)
        remote.press(.select)
        XCTAssertTrue(app.staticTexts["Scheduled Recordings"].waitForExistence(timeout: 30), "Scheduled Recordings did not open")
        sleep(3)
        log("SCHEDULE focus=\(focusLine())")
        shot("08-scheduled-recordings")
        remote.press(.menu)
        sleep(2)

        // Settings on the list-plus-detail container.
        sidebar(to: "Settings")
        remote.press(.select)
        XCTAssertTrue(app.buttons["Server"].waitForExistence(timeout: 20), "Settings did not open")
        sleep(2)
        log("SETTINGS focus=\(focusLine())")
        XCTAssertEqual(focusedLabel(), "This Apple TV", "Settings did not open on its first group")
        remote.press(.right)
        sleep(1)
        XCTAssertTrue(focusedLabel()?.hasPrefix("Name, ") == true, "Right did not land on the Name row; focus=\(focusLine())")
        remote.press(.menu)
        sleep(1)
        XCTAssertEqual(focusedLabel(), "This Apple TV", "Menu on a row did not go back to its group")
        shot("09-settings")
    }
}
