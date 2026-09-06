//
//  PlayerHost.swift
//  Marlin DVR TV
//
//  AVPlayerViewController hosted as a child of a container controller (standing call:
//  Apple's transport UI as-is). The container catches the Menu press that
//  AVPlayerViewController does not consume and hands it to SwiftUI as `onMenu`.
//

import AVKit
import SwiftUI
import UIKit

struct PlayerHost: UIViewControllerRepresentable {
    let player: AVPlayer
    let linearOnly: Bool          // cameras: a 6-entry window, no seeking (standing call)
    let onMenu: () -> Void

    func makeUIViewController(context: Context) -> PlayerContainerController {
        let controller = PlayerContainerController()
        controller.onMenu = onMenu
        controller.attach(player: player, linearOnly: linearOnly)
        return controller
    }

    func updateUIViewController(_ controller: PlayerContainerController, context: Context) {
        controller.onMenu = onMenu
    }
}

final class PlayerContainerController: UIViewController {
    var onMenu: () -> Void = {}
    private let playerController = AVPlayerViewController()

    func attach(player: AVPlayer, linearOnly: Bool) {
        playerController.player = player
        playerController.showsPlaybackControls = true
        playerController.requiresLinearPlayback = linearOnly
        playerController.allowsPictureInPicturePlayback = false
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

    /// Focus does not reach the player on its own when the host appears beside SwiftUI
    /// overlays (Select presses were lost for the first seconds in Pass 7 testing).
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setNeedsFocusUpdate()
        updateFocusIfNeeded()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.setNeedsFocusUpdate()
            self?.updateFocusIfNeeded()
        }
    }

    private func describePress(_ presses: Set<UIPress>, _ phase: String) {
        let types = presses.map { "\($0.type.rawValue)" }.joined(separator: ",")
        let focused = UIFocusSystem.focusSystem(for: self)?.focusedItem.map { String(describing: type(of: $0)) } ?? "nil"
        let p = playerController.player
        let status = p.map { "\($0.timeControlStatus.rawValue)" } ?? "-"
        let reason = p?.reasonForWaitingToPlay?.rawValue ?? "-"
        let ranges = p?.currentItem?.seekableTimeRanges.map(\.timeRangeValue) ?? []
        let window = ranges.isEmpty ? "none" : "\(Int(ranges.first!.start.seconds))-\(Int(ranges.last!.end.seconds)) (\(Int(ranges.last!.end.seconds - ranges.first!.start.seconds)) s)"
        let t = p?.currentItem?.currentTime().seconds ?? -1
        print("[press] \(phase) types=\(types) focused=\(focused) rate=\(p?.rate ?? -1) status=\(status) waiting=\(reason) t=\(Int(t)) seekable=\(window)")
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        describePress(presses, "began")
        if presses.contains(where: { $0.type == .menu }) {
            onMenu()
            return
        }
        super.pressesBegan(presses, with: event)
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        describePress(presses, "ended")
        if presses.contains(where: { $0.type == .menu }) { return }
        super.pressesEnded(presses, with: event)
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        let from = context.previouslyFocusedItem.map { String(describing: type(of: $0)) } ?? "nil"
        let to = context.nextFocusedItem.map { String(describing: type(of: $0)) } ?? "nil"
        print("[focus] \(from) → \(to)")
    }
}
