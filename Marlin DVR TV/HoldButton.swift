//
//  HoldButton.swift
//  Marlin DVR TV
//
//  Click versus click-and-hold on the Siri Remote.
//
//  The design asks for both on the same item: a guide cell plays what is on now and opens
//  the airing sheet on a hold (DECISIONS.md 2026-09-06), and an episode row plays and opens
//  the actions menu on a hold (frame 5d, dc:643). Sweep 3 wrote that with
//  `.onLongPressGesture` on the Button. **That never fires on tvOS**: a focused Button takes
//  the Select press itself and runs its action on release, however long the press was held.
//  Pass 8 established this against the running app with three different inputs — a held
//  Return through System Events, a sustained CGEvent key-down with auto-repeat (1.5 s and
//  2.5 s), and a real mouse press-and-hold on the Simulator's Apple TV Remote touch surface —
//  and every one of them ran the click action and none of them ran the long press.
//
//  What does work is the button style's `isPressed`, which tvOS sets while Select is held.
//  `HoldButton` starts a timer when the press begins; if the press outlives `minimumHold`
//  the hold action runs at once (the tvOS feel: the menu appears under your thumb, not on
//  release) and a flag makes the Button's own action a no-op when the press finally ends.
//

import SwiftUI

struct HoldButton<Label: View>: View {
    /// A plain click.
    let action: () -> Void
    /// Click and hold, fired as soon as `minimumHold` passes.
    let onHold: () -> Void
    @ViewBuilder var label: () -> Label

    var minimumHold: Duration = .milliseconds(500)

    @State private var held = false
    @State private var holdTask: Task<Void, Never>?

    init(action: @escaping () -> Void, onHold: @escaping () -> Void, minimumHold: Duration = .milliseconds(500), @ViewBuilder label: @escaping () -> Label) {
        self.action = action
        self.onHold = onHold
        self.minimumHold = minimumHold
        self.label = label
    }

    var body: some View {
        Button {
            // The press that already fired the hold must not also click.
            if held {
                held = false
                return
            }
            action()
        } label: {
            label()
        }
        .buttonStyle(HoldButtonStyle(onPressChange: pressChanged))
    }

    private func pressChanged(_ pressed: Bool) {
        holdTask?.cancel()
        guard pressed else { return }
        held = false
        holdTask = Task { @MainActor in
            try? await Task.sleep(for: minimumHold)
            guard !Task.isCancelled else { return }
            held = true
            onHold()
        }
    }
}

/// `BareButtonStyle` (the app's no-chrome style) plus a report of the press state.
private struct HoldButtonStyle: ButtonStyle {
    let onPressChange: (Bool) -> Void

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, pressed in
                onPressChange(pressed)
            }
    }
}
