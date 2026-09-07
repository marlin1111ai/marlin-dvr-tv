//
//  PlayerHost.swift
//  Marlin DVR TV
//
//  AVPlayerViewController hosted as a child of a container controller (standing call:
//  Apple's transport UI as-is). The container catches the Menu press that
//  AVPlayerViewController does not consume and hands it to SwiftUI as `onMenu`.
//
//  Pass 7C (owner decision 1a, DECISIONS.md 2026-09-06): AVPlayerViewController will not
//  pause a live HLS item whose seekable window is short — Pass 7B measured it refusing at a
//  30 s and 36 s window and accepting at 60 s — and a live channel's window starts at zero.
//  While the window is under that threshold the container handles a centre Select itself:
//  it lets the press reach Apple's handler first and, a third of a second later, if the
//  player is still in the state it was, pauses or resumes it. From the threshold on, the
//  press is Apple's alone. Edge clicks and swipes are never touched.
//
//  Pass 28: left and right **clicks** step one frame while paused on a recording, through the
//  same `pressesBegan`/`pressesEnded` pair that already claims Menu. `frameStep` answers false
//  in every other case — playing, live, camera — and the press falls straight through to
//  Apple's transport bar unchanged. Swipes are untouched: a swipe on the touch surface is not
//  a `UIPress`, so only the discrete click reaches this code at all.
//
//  Pass 29: claiming the press was not enough. Measured on the device — every arrow press
//  reached `pressesBegan` and none was forwarded to `super`, and Apple skipped 10 s anyway —
//  because **AVPlayerViewController handles the arrow with its own gesture recognizers**, not
//  through the responder chain. Two `AVNonDigitizerTapRecognizer`s inside its view claim
//  `[up/down/left/right]`, and a recognizer fires in parallel with the responder chain, so no
//  amount of not-calling-super can stop one. `armArrowOwnership` disables exactly those
//  recognizers — found by their public `allowedPressTypes`, never by class name — for as long
//  as the app owns the arrow, and re-enables the very same ones the moment it does not. The
//  transport bar itself is untouched: it still draws, and Select still belongs to Apple.
//

import AVKit
import SwiftUI
import UIKit

struct PlayerHost: UIViewControllerRepresentable {
    let player: AVPlayer
    let linearOnly: Bool               // cameras: a 6-entry window, no seeking (standing call)
    let shortWindowSelect: Bool        // live channels only (Pass 7C)
    /// Pass 29: true exactly while the app owns left/right — paused on a recording.
    let ownsArrows: Bool
    /// Pass 28: one frame back (-1) or forward (+1). Returns true when it acted, which is the
    /// signal to swallow the press rather than hand it to Apple's transport.
    let frameStep: (Int) -> Bool
    let onMenu: () -> Void

    func makeUIViewController(context: Context) -> PlayerContainerController {
        let controller = PlayerContainerController()
        controller.onMenu = onMenu
        controller.frameStep = frameStep
        controller.attach(player: player, linearOnly: linearOnly, shortWindowSelect: shortWindowSelect)
        controller.armArrowOwnership(ownsArrows)
        return controller
    }

    func updateUIViewController(_ controller: PlayerContainerController, context: Context) {
        controller.onMenu = onMenu
        controller.frameStep = frameStep
        controller.armArrowOwnership(ownsArrows)
    }
}

final class PlayerContainerController: UIViewController {
    /// The seekable window from which AVPlayerViewController pauses a live item on its own
    /// (Pass 7B: refused at 30 s and 36 s, accepted at 60 s).
    static let appleHandlesFromWindow: Double = 60
    /// How long Apple's handler gets before the container acts (a click's press-ended
    /// arrives within about 100 ms; Apple toggles on it).
    static let appleGrace: TimeInterval = 0.35

    var onMenu: () -> Void = {}
    var frameStep: (Int) -> Bool = { _ in false }
    /// Set when a left/right press was consumed as a frame step, so its release is swallowed too
    /// and Apple's transport never sees half a press.
    private var swallowArrowRelease = false
    private let playerController = AVPlayerViewController()
    private var shortWindowSelect = false
    private var pendingSelect: DispatchWorkItem?
    /// The player's own arrow recognizers that this controller switched off, so exactly those
    /// are switched back on again and nothing else is ever touched.
    private var suppressed: [UIGestureRecognizer] = []
    private var armed = false

    func attach(player: AVPlayer, linearOnly: Bool, shortWindowSelect: Bool) {
        playerController.player = player
        playerController.showsPlaybackControls = true
        playerController.requiresLinearPlayback = linearOnly
        playerController.allowsPictureInPicturePlayback = false
        self.shortWindowSelect = shortWindowSelect
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        addChild(playerController)
        playerController.view.frame = view.bounds
        playerController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(playerController.view)
        playerController.didMove(toParent: self)
    }

    /// Pass 29. While the app owns the arrow, the player's own left/right recognizers are
    /// disabled; otherwise the exact ones that were disabled are restored. Recognizers are
    /// matched on `allowedPressTypes`, which is public API — no private class name is relied on.
    /// Nothing else about the transport is changed: it still draws, and Select is still Apple's.
    func armArrowOwnership(_ owns: Bool) {
        guard owns != armed else { return }
        armed = owns
        if owns {
            suppressed = Self.arrowRecognizers(in: playerController.view).filter(\.isEnabled)
            suppressed.forEach { $0.isEnabled = false }
            print("[framestep] app owns the arrow — \(suppressed.count) player recognizer(s) disabled")
        } else {
            suppressed.forEach { $0.isEnabled = true }
            print("[framestep] arrow returned to the player — \(suppressed.count) recognizer(s) restored")
            suppressed = []
        }
    }

    private static func arrowRecognizers(in view: UIView) -> [UIGestureRecognizer] {
        var found: [UIGestureRecognizer] = []
        let arrows: Set<Int> = [UIPress.PressType.leftArrow.rawValue, UIPress.PressType.rightArrow.rawValue]
        func walk(_ v: UIView) {
            for g in v.gestureRecognizers ?? [] where !g.allowedPressTypes.isEmpty {
                if g.allowedPressTypes.contains(where: { arrows.contains($0.intValue) }) { found.append(g) }
            }
            v.subviews.forEach(walk)
        }
        walk(view)
        return found
    }

    /// The player's recognizers must never be left switched off behind us.
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        armArrowOwnership(false)
    }

    override var preferredFocusEnvironments: [UIFocusEnvironment] { [playerController] }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setNeedsFocusUpdate()
        updateFocusIfNeeded()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.setNeedsFocusUpdate()
            self?.updateFocusIfNeeded()
        }
    }

    /// The live item's seekable window in seconds; 0 until AVPlayer reports one.
    private var seekableWindow: Double {
        guard let item = playerController.player?.currentItem else { return 0 }
        let ranges = item.seekableTimeRanges.map(\.timeRangeValue).filter { $0.duration.isNumeric && $0.duration.seconds > 0 }
        guard let first = ranges.first, let last = ranges.last else { return 0 }
        return last.end.seconds - first.start.seconds
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if presses.contains(where: { $0.type == .menu }) {
            onMenu()
            return
        }
        // Pass 28. `frameStep` decides: it acts only while paused on a recording and answers
        // false everywhere else, so nothing here changes playing, live or camera behaviour.
        if presses.contains(where: { $0.type == .leftArrow }) {
            if frameStep(-1) { swallowArrowRelease = true; return }
        }
        if presses.contains(where: { $0.type == .rightArrow }) {
            if frameStep(1) { swallowArrowRelease = true; return }
        }
        if shortWindowSelect, presses.contains(where: { $0.type == .select }) {
            handleShortWindowSelect()
        }
        super.pressesBegan(presses, with: event)
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if presses.contains(where: { $0.type == .menu }) { return }
        if swallowArrowRelease, presses.contains(where: { $0.type == .leftArrow || $0.type == .rightArrow }) {
            swallowArrowRelease = false
            return
        }
        super.pressesEnded(presses, with: event)
    }

    /// Pass 7C: pause or resume a live item ourselves while the window is short and Apple's
    /// handler leaves the player as it was; otherwise the press is Apple's.
    private func handleShortWindowSelect() {
        guard let player = playerController.player else { return }
        let window = seekableWindow
        guard window < Self.appleHandlesFromWindow else {
            print("[select] window \(Int(window)) s → Apple's handler")
            return
        }
        let wasPlaying = player.timeControlStatus != .paused
        pendingSelect?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, let player = self.playerController.player else { return }
            let stillSame = (player.timeControlStatus != .paused) == wasPlaying
            guard stillSame else {
                print("[select] window \(Int(window)) s → Apple's handler acted")
                return
            }
            if wasPlaying {
                player.pause()
                print("[select] window \(Int(window)) s < \(Int(Self.appleHandlesFromWindow)) → app paused")
            } else {
                player.play()
                print("[select] window \(Int(window)) s < \(Int(Self.appleHandlesFromWindow)) → app resumed from the pause point")
            }
        }
        pendingSelect = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.appleGrace, execute: work)
    }
}
