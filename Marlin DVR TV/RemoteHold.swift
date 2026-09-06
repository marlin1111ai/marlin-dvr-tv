//
//  RemoteHold.swift
//  Marlin DVR TV
//
//  Click-and-hold on the Siri Remote, second attempt.
//
//  Pass 8 built the hold on a SwiftUI `ButtonStyle`'s `configuration.isPressed`. That works
//  on the Simulator (a mouse press-and-hold on its Apple TV Remote opened the menu every
//  time) and does nothing on the owner's physical remote — reported after the Home Theater
//  test. So `isPressed` is not a dependable report of how long the Select button was held.
//
//  What *is* known to work on the physical remote is UIKit's press pipeline: the Pass 7C
//  live-pause fix reads `pressesBegan` for `.select` in a container controller and the owner
//  accepted it on Home Theater ("live pause from the first second", DECISIONS.md 2026-09-06).
//  This file therefore detects the hold with UIKit, and keeps the Pass 8 path as a second,
//  independent trigger so that whichever one the hardware honours, the hold happens:
//
//    A. `UILongPressGestureRecognizer` with `allowedPressTypes = [.select]`, installed on the
//       window. This is the pre-SwiftUI tvOS way to read a click-and-hold and it is the
//       primary path here.
//    B. The Pass 8 `isPressed` timer inside `HoldButton`.
//
//  Both report to the same `RemoteHold`, which drops a duplicate inside 400 ms, so a remote
//  that honours both fires the hold once. A hold is *not* delivered to the button that was
//  pressed: it is published to the screen, which acts on whatever its own `@FocusState` says
//  is focused. That keeps one code path for both triggers and lets a screen decide what a
//  hold means for a program cell, a channel cell or an episode row.
//
//  The click that ends the same press must not also fire. `armSwallow` is set the moment a
//  hold is acted on and is consumed by the next click; `pressEnded` shortens it to a 400 ms
//  tail so a later, deliberate click is never eaten.
//

import SwiftUI
import UIKit

@MainActor
@Observable
final class RemoteHold {
    /// Bumped once per recognised hold; screens watch this.
    private(set) var holds = 0
    /// True while the Player is on screen: the recognizer lives on the window and would
    /// otherwise open a sheet on the screen underneath while someone is scrubbing.
    var suspended = false
    /// The last hold's time, to drop the second trigger's duplicate.
    private var lastFire = Date.distantPast
    private var swallowUntil = Date.distantPast

    static let minimumDuration: TimeInterval = 0.5
    private static let duplicateWindow: TimeInterval = 0.4

    /// Called by either trigger. `source` is only for the console.
    func fire(source: String) {
        guard !suspended else { return }
        let now = Date()
        guard now.timeIntervalSince(lastFire) > Self.duplicateWindow else {
            print("[hold] \(source): duplicate inside \(Self.duplicateWindow) s, dropped")
            return
        }
        lastFire = now
        holds &+= 1
        print("[hold] \(source) → hold #\(holds)")
    }

    /// A screen acted on the hold: swallow the click that ends this press.
    func armSwallow() {
        swallowUntil = Date().addingTimeInterval(6)
    }

    /// The press was released; leave a short tail for the click that follows it.
    func pressEnded() {
        guard swallowUntil > Date() else { return }
        swallowUntil = Date().addingTimeInterval(0.4)
    }

    /// True when this click is the tail of a hold that already acted.
    func shouldSwallowClick() -> Bool {
        guard Date() < swallowUntil else { return false }
        swallowUntil = .distantPast
        print("[hold] click after a hold, swallowed")
        return true
    }
}

// MARK: Trigger A — the window's long-press recognizer

/// A zero-size view that installs one press recognizer on the window. Put it in a screen's
/// background once; it removes its recognizer when it leaves the window.
struct RemoteHoldDetector: UIViewRepresentable {
    let hold: RemoteHold

    func makeUIView(context: Context) -> UIView {
        HoldProbeView(hold: hold)
    }

    func updateUIView(_ view: UIView, context: Context) {}
}

final class HoldProbeView: UIView, UIGestureRecognizerDelegate {
    private let hold: RemoteHold
    private var recognizer: UILongPressGestureRecognizer?
    private weak var installedOn: UIWindow?

    init(hold: RemoteHold) {
        self.hold = hold
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if let installedOn, installedOn !== window, let recognizer {
            installedOn.removeGestureRecognizer(recognizer)
            self.recognizer = nil
            self.installedOn = nil
        }
        guard let window, recognizer == nil else { return }
        let press = UILongPressGestureRecognizer(target: self, action: #selector(pressed(_:)))
        press.minimumPressDuration = RemoteHold.minimumDuration
        press.allowedPressTypes = [NSNumber(value: UIPress.PressType.select.rawValue)]
        press.allowedTouchTypes = []          // the remote's Select button, not a touch
        press.delegate = self
        window.addGestureRecognizer(press)
        recognizer = press
        installedOn = window
        print("[hold] press recognizer installed on the window")
    }

    @objc private func pressed(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            hold.fire(source: "press recognizer")
        case .ended, .cancelled, .failed:
            hold.pressEnded()
        default:
            break
        }
    }

    /// The focused control keeps its own handling; this recognizer only observes.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRequireFailureOf other: UIGestureRecognizer) -> Bool { false }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldBeRequiredToFailBy other: UIGestureRecognizer) -> Bool { false }
}

// MARK: Trigger B — the Pass 8 press-state timer, and the click that must not follow

/// A focusable button that reports a click, and reports a hold to `RemoteHold` rather than
/// acting on it. The screen decides what the hold means for whatever it has focused.
struct HoldButton<Label: View>: View {
    let hold: RemoteHold
    let action: () -> Void
    @ViewBuilder var label: () -> Label

    @State private var holdTask: Task<Void, Never>?

    init(hold: RemoteHold, action: @escaping () -> Void, @ViewBuilder label: @escaping () -> Label) {
        self.hold = hold
        self.action = action
        self.label = label
    }

    var body: some View {
        Button {
            guard !hold.shouldSwallowClick() else { return }
            action()
        } label: {
            label()
        }
        .buttonStyle(HoldReportingButtonStyle(onPressChange: pressChanged))
    }

    private func pressChanged(_ pressed: Bool) {
        holdTask?.cancel()
        guard pressed else {
            hold.pressEnded()
            return
        }
        holdTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(RemoteHold.minimumDuration))
            guard !Task.isCancelled else { return }
            if ProcessInfo.processInfo.environment["MARLIN_DISABLE_PRESS_STATE_HOLD"] == nil {
                hold.fire(source: "press state")
            }
        }
    }
}

/// `BareButtonStyle` (no chrome) plus a report of the press state.
private struct HoldReportingButtonStyle: ButtonStyle {
    let onPressChange: (Bool) -> Void

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, pressed in
                onPressChange(pressed)
            }
    }
}
