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

import AVKit
import SwiftUI
import UIKit

struct PlayerHost: UIViewControllerRepresentable {
    let player: AVPlayer
    let linearOnly: Bool               // cameras: a 6-entry window, no seeking (standing call)
    let shortWindowSelect: Bool        // live channels only (Pass 7C)
    let onMenu: () -> Void

    func makeUIViewController(context: Context) -> PlayerContainerController {
        let controller = PlayerContainerController()
        controller.onMenu = onMenu
        controller.attach(player: player, linearOnly: linearOnly, shortWindowSelect: shortWindowSelect)
        return controller
    }

    func updateUIViewController(_ controller: PlayerContainerController, context: Context) {
        controller.onMenu = onMenu
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
    private let playerController = AVPlayerViewController()
    private var shortWindowSelect = false
    private var pendingSelect: DispatchWorkItem?

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
        if shortWindowSelect, presses.contains(where: { $0.type == .select }) {
            handleShortWindowSelect()
        }
        super.pressesBegan(presses, with: event)
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if presses.contains(where: { $0.type == .menu }) { return }
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
