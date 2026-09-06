//
//  PlayerScreen.swift
//  Marlin DVR TV
//
//  The Player, frames 6a–6h, in the Pass 5 theme: AVPlayerViewController underneath, the
//  app's overlays on top. 6a starting; 6b live (distance behind live); 6c recording
//  (prepared-to and the resume note); 6d paused live (pause point and lag — the design's
//  "no buffer" copy is gone, contract §4); 6e ended with the next episode and a countdown;
//  6f/6g/6h errors and the expired session. Menu dismisses (and stops the session);
//  going to the background stops it too.
//

import SwiftUI

struct PlayerScreen: View {
    let api: APIClient
    let clientName: String
    let onDismiss: () -> Void
    @State private var model: PlayerModel
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var focused: String?

    init(request: PlayRequest, api: APIClient, clientName: String, onDismiss: @escaping () -> Void) {
        self.api = api
        self.clientName = clientName
        self.onDismiss = onDismiss
        _model = State(initialValue: PlayerModel(request: request, api: api, clientName: clientName))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if model.phase == .playing {
                PlayerHost(player: model.player, linearOnly: model.isCamera) { dismiss() }
                    .ignoresSafeArea()
                hud
            }
            switch model.phase {
            case .starting: StartingOverlay(model: model)
            case .ended: EndedState(model: model, focused: $focused, onPlayNext: playNext, onBack: dismiss)
            case .failed: FailureState(model: model, focused: $focused, onRetry: { Task { await model.restart() } }, onBack: dismiss)
            case .expired: ExpiredState(model: model, focused: $focused, onRestart: { Task { await model.restart() } }, onBack: dismiss)
            case .playing: EmptyView()
            }
        }
        .ignoresSafeArea()
        .task { await model.start() }
        .onChange(of: model.phase) { _, phase in
            switch phase {
            case .ended: focusSoon { focused = model.nextEpisode != nil ? "next" : "back" }
            case .failed: focusSoon { focused = "back" }
            case .expired: focusSoon { focused = "restart" }
            default: break
            }
        }
        .onChange(of: model.countdown) { _, value in
            if value == 0 { playNext() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { dismiss() }
        }
        .onExitCommand { dismiss() }
        // The system may dismiss the cover on Menu before the app sees the press (observed
        // in Pass 6 testing); the session is stopped on any disappearance, never left running.
        .onDisappear { Task { await model.stop() } }
    }

    @ViewBuilder
    private var hud: some View {
        if model.isPaused && model.isLive {
            PausedLiveOverlay(model: model)
        } else if model.hudVisible || model.notice != nil {
            if model.isRecording {
                RecordingHUD(model: model)
            } else {
                LiveHUD(model: model)
            }
        }
    }

    private func dismiss() {
        Task {
            await model.stop()
            onDismiss()
        }
    }

    /// Frame 6e: the next-newer episode of the same show, from the top.
    private func playNext() {
        guard let next = model.nextEpisode else { return }
        model.cancelCountdown()
        let request = model.request.replacing(episode: next, start: 0)
        Task {
            await model.stop()
            model = PlayerModel(request: request, api: api, clientName: clientName)
            await model.start()
        }
    }
}

// MARK: 6a — Starting (dc:865-878)

struct StartingOverlay: View {
    let model: PlayerModel

    var body: some View {
        ZStack {
            Nocturne.bg
            RadialGradient(colors: [Nocturne.accent900, .clear], center: UnitPoint(x: 0.5, y: 0.4), startRadius: 0, endRadius: 700)
                .scaleEffect(x: 1.3, y: 1)
            VStack(spacing: 30) {
                artwork
                VStack(spacing: 12) {
                    Text(model.request.title)
                        .font(.nocturne(64, .medium))
                        .tracking(-0.015 * 64)
                        .foregroundStyle(Nocturne.text)
                    if !model.request.subtitle.isEmpty {
                        Text(model.request.subtitle)
                            .font(.nocturne(Nocturne.TextSize.cardTitle))
                            .foregroundStyle(Nocturne.neutral300)
                    }
                }
                PulseBar()
                    .padding(.top, 14)
                Text(model.startingLine)
                    .font(.nocturne(Nocturne.TextSize.secondary))
                    .foregroundStyle(Nocturne.neutral400)
                Text(model.isLive ? "Live channels usually take 2–6 seconds. Press Menu to cancel." : "Press Menu to cancel.")
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .foregroundStyle(Nocturne.neutral600)
            }
            .padding(.vertical, Nocturne.Layout.marginVertical)
            .padding(.horizontal, Nocturne.Layout.marginHorizontal)
        }
    }

    @ViewBuilder
    private var artwork: some View {
        if let channel = model.request.channel {
            InitialsTile(initials: channel.initials, logoBg: channel.logoBg, size: 104, fontSize: 34)
        } else if let episode = model.request.episode {
            ServerImage(path: AiringSelection.artPath(for: episode.show)) { ArtPlaceholder() }
                .frame(width: 104, height: 148)
                .clipShape(RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous))
        } else {
            Image(systemName: "video")
                .font(.nocturne(64))
                .foregroundStyle(Nocturne.neutral300)
                .frame(width: 104, height: 104)
        }
    }
}

/// The 520 × 6 pulsing bar of frame 6a (dc:873-875).
struct PulseBar: View {
    @State private var on = false

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule().fill(Nocturne.neutral800)
            Capsule().fill(Nocturne.accent).frame(width: 180).opacity(on ? 1 : 0.35)
        }
        .frame(width: 520, height: 6)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { on = true }
        }
    }
}

// MARK: 6b — Live HUD (dc:889-892, 910-912) and the buffer notice

struct LiveHUD: View {
    let model: PlayerModel

    private var atLiveEdge: Bool { model.behindLive < 6 }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 18) {
                Text(atLiveEdge ? "LIVE" : "LIVE · −\(PlayerTime.lag(model.behindLive))")
                    .font(.nocturne(Nocturne.TextSize.floor, .semibold))
                    .tracking(0.14 * Nocturne.TextSize.floor)
                    .foregroundStyle(atLiveEdge ? Nocturne.bg : Nocturne.accent200)
                    .padding(.vertical, 7)
                    .padding(.horizontal, 18)
                    .background(atLiveEdge ? Nocturne.accent : Nocturne.accent900, in: Capsule())
                    .overlay { Capsule().strokeBorder(atLiveEdge ? .clear : Nocturne.accent600, lineWidth: 1) }
                Text(model.request.title)
                    .font(.nocturne(Nocturne.TextSize.secondary))
                    .foregroundStyle(Nocturne.neutral300)
                if !model.request.subtitle.isEmpty {
                    Text(model.request.subtitle)
                        .font(.nocturne(Nocturne.TextSize.secondary))
                        .foregroundStyle(Nocturne.neutral500)
                        .lineLimit(1)
                }
            }
            if !atLiveEdge, model.isLive {
                Text("\(PlayerTime.lag(model.behindLive)) behind live · buffer \(PlayerTime.lag(model.bufferSeconds))")
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .foregroundStyle(Nocturne.neutral400)
            }
            if let notice = model.notice {
                Text(notice)
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .foregroundStyle(Nocturne.neutral200)
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 24)
        .background(Nocturne.surface.opacity(0.86), in: RoundedRectangle(cornerRadius: Nocturne.Radius.lg, style: .continuous))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, Nocturne.Layout.marginVertical)
        .padding(.leading, Nocturne.Layout.marginHorizontal)
        .transition(.opacity)
    }
}

// MARK: 6c — Recording HUD (dc:927-950)

struct RecordingHUD: View {
    let model: PlayerModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(model.request.title)
                .font(.nocturne(44, .medium))
                .tracking(-0.01 * 44)
                .foregroundStyle(Nocturne.text)
            if !model.request.subtitle.isEmpty {
                Text(model.request.subtitle)
                    .font(.nocturne(Nocturne.TextSize.body))
                    .foregroundStyle(Nocturne.neutral400)
            }
            HStack(spacing: 34) {
                if model.duration > 0 {
                    Text("\(PlayerTime.clock(model.position)) of \(PlayerTime.clock(model.duration))")
                        .foregroundStyle(Nocturne.neutral300)
                }
                if !model.fullyPrepared, model.preparedTo > 0 {
                    Text("Prepared to \(PlayerTime.clock(model.preparedTo)). Jumping past that point restarts playback there — a second or two of buffering, not an error.")
                        .foregroundStyle(Nocturne.neutral500)
                        .lineLimit(2)
                }
                Text("Resume kept by \(model.clientName)")
                    .foregroundStyle(Nocturne.neutral500)
            }
            .font(.nocturne(Nocturne.TextSize.floor))
            if let notice = model.notice {
                Text(notice)
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .foregroundStyle(Nocturne.neutral200)
            }
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 32)
        .frame(maxWidth: 1500, alignment: .leading)
        .background(Nocturne.surface.opacity(0.86), in: RoundedRectangle(cornerRadius: Nocturne.Radius.lg, style: .continuous))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, Nocturne.Layout.marginVertical)
        .padding(.leading, Nocturne.Layout.marginHorizontal)
        .transition(.opacity)
    }
}

// MARK: 6d — Paused live (dc:960-973), with the buffer facts of contract §4

struct PausedLiveOverlay: View {
    let model: PlayerModel

    var body: some View {
        ZStack {
            Color(hex: 0x0F1018).opacity(0.5)
            VStack(spacing: 26) {
                Text("❙❙")
                    .font(.nocturne(88))
                    .tracking(0.08 * 88)
                    .foregroundStyle(Nocturne.neutral200)
                Text("Paused")
                    .font(.nocturne(Nocturne.TextSize.screenTitle, .medium))
                    .foregroundStyle(Nocturne.text)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    VStack(spacing: 10) {
                        if let at = model.pausedAt {
                            let held = context.date.timeIntervalSince(at)
                            Text("Paused at \(TimeFormat.clock(at)) · now \(PlayerTime.lag(model.pausedPosition + held)) behind live")
                                .font(.nocturne(Nocturne.TextSize.body))
                                .foregroundStyle(Nocturne.neutral300)
                            Text("Held for \(PlayerTime.clock(held)) · the buffer holds \(PlayerTime.lag(model.bufferSeconds)) · the tuner stays in use while paused")
                                .font(.nocturne(Nocturne.TextSize.floor))
                                .foregroundStyle(Nocturne.neutral500)
                        }
                    }
                }
                Text("Press play to continue from here. Rewind and fast-forward stay inside the buffer.")
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .foregroundStyle(Nocturne.neutral500)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, Nocturne.Layout.marginHorizontal)
            HStack(spacing: 18) {
                Text("LIVE · HELD")
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .tracking(0.14 * Nocturne.TextSize.floor)
                    .foregroundStyle(Nocturne.accent200)
                    .padding(.vertical, 7)
                    .padding(.horizontal, 18)
                    .overlay { Capsule().strokeBorder(Nocturne.accent600, lineWidth: 1) }
                Text("\(model.request.title) · \(model.request.subtitle)")
                    .font(.nocturne(Nocturne.TextSize.secondary))
                    .foregroundStyle(Nocturne.neutral400)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.top, Nocturne.Layout.marginVertical)
            .padding(.leading, Nocturne.Layout.marginHorizontal)
        }
        .transition(.opacity)
    }
}

// MARK: 6e — Ended (dc:1244-1247)

struct EndedState: View {
    let model: PlayerModel
    var focused: FocusState<String?>.Binding
    let onPlayNext: () -> Void
    let onBack: () -> Void

    private var nextLabel: String? {
        guard let next = model.nextEpisode else { return nil }
        return next.season > 0 || next.episode > 0 ? "Play S\(next.season) E\(next.episode)" : "Play the next episode"
    }

    var body: some View {
        StateCard(
            code: model.markedWatched ? "Marked watched on the server" : "Played to the end · could not mark watched",
            title: model.request.title,
            sub: model.request.subtitle,
            text: model.nextEpisode != nil && model.countdown >= 0 ? "Next episode starts in \(model.countdown) seconds." : (model.nextEpisode != nil ? "Next episode is ready." : "That was the newest episode of this show.")
        ) {
            if let nextLabel {
                StateButton(title: nextLabel, id: "next", primary: true, focused: focused) { onPlayNext() }
            }
            StateButton(title: "Back to the show", id: "back", primary: model.nextEpisode == nil, focused: focused) { onBack() }
            StateButton(title: "Delete this recording", id: "delete", primary: false, focused: focused) { /* sweep 4 */ }
        }
    }
}

// MARK: 6f / 6g / other failures (dc:1248-1255) and 6h (dc:1256-1259)

struct FailureState: View {
    let model: PlayerModel
    var focused: FocusState<String?>.Binding
    let onRetry: () -> Void
    let onBack: () -> Void
    @State private var showLog = false

    private var failure: PlayerModel.Failure { model.failure ?? PlayerModel.Failure(status: 0, message: "unknown failure") }

    private var code: String {
        switch failure.status {
        case 403: return "403 · channel is DRM-protected"
        case 404: return "404 · not found"
        case 410: return "410 · session ended"
        case 502: return "502 · stream could not start"
        case 0: return "playback failed"
        default: return "\(failure.status) · error"
        }
    }

    private var title: String {
        switch failure.status {
        case 403: return "This channel can't be played"
        case 404: return "Not on the server"
        case 502: return model.isLive && !failure.busyRecordings.isEmpty ? "The tuner is busy" : "The stream could not start"
        default: return "Playback stopped"
        }
    }

    private var bodyText: String {
        var lines: [String] = []
        if !failure.message.isEmpty { lines.append(failure.message) }
        if failure.status == 403 {
            lines.append("DRM channels are hidden from every list; this appears only if a stale link reached one.")
        }
        if !failure.busyRecordings.isEmpty {
            lines.append("Likely holding the tuner: " + failure.busyRecordings.joined(separator: "; ") + ". Stop that recording to watch this, or pick a channel on another source.")
        }
        return lines.joined(separator: "\n")
    }

    var body: some View {
        StateCard(code: code, title: title, sub: "\(model.request.title) · \(model.request.subtitle)", text: bodyText, extra: showLog ? failure.log : nil) {
            if failure.status == 502, model.isLive, !failure.busyRecordings.isEmpty {
                StateButton(title: "Stop the recording and watch", id: "stop", primary: false, focused: focused) { /* sweep 4 */ }
            }
            if failure.status == 403 {
                StateButton(title: "Back to the guide", id: "back", primary: true, focused: focused) { onBack() }
                StateButton(title: "Hide this channel", id: "hide", primary: false, focused: focused) { /* sweep 4 */ }
            } else {
                StateButton(title: model.isLive ? "Pick another channel" : "Back", id: "back", primary: true, focused: focused) { onBack() }
                StateButton(title: "Try again", id: "retry", primary: false, focused: focused) { onRetry() }
            }
            if failure.log != nil {
                StateButton(title: showLog ? "Hide the server log" : "Show the server log", id: "log", primary: false, focused: focused) { showLog.toggle() }
            }
        }
    }
}

struct ExpiredState: View {
    let model: PlayerModel
    var focused: FocusState<String?>.Binding
    let onRestart: () -> Void
    let onBack: () -> Void

    var body: some View {
        StateCard(
            code: "410 · session ended",
            title: "The stream ended on the server",
            sub: "\(model.request.title) · \(model.request.subtitle)",
            text: model.isRecording ? "The session expired. Restart continues from \(PlayerTime.clock(model.position))." : "The session expired while nothing was being fetched. Restart rejoins the channel."
        ) {
            StateButton(title: "Restart", id: "restart", primary: true, focused: focused) { onRestart() }
            StateButton(title: "Back", id: "back", primary: false, focused: focused) { onBack() }
        }
    }
}

/// The 1180 pt message card of frames 6e–6h (dc:982-997).
struct StateCard<Buttons: View>: View {
    let code: String
    let title: String
    let sub: String
    let text: String
    var extra: String? = nil
    @ViewBuilder let buttons: () -> Buttons

    var body: some View {
        ZStack {
            LinearGradient(colors: [Nocturne.neutral900, Nocturne.bg], startPoint: .topLeading, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 22) {
                Text(code.uppercased())
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .tracking(0.14 * Nocturne.TextSize.floor)
                    .foregroundStyle(Nocturne.accent300)
                Text(title)
                    .font(.nocturne(60, .medium))
                    .tracking(-0.015 * 60)
                    .foregroundStyle(Nocturne.text)
                    .lineLimit(2)
                Text(sub)
                    .font(.nocturne(Nocturne.TextSize.body))
                    .foregroundStyle(Nocturne.neutral400)
                    .lineLimit(1)
                if !text.isEmpty {
                    Text(text)
                        .font(.nocturne(Nocturne.TextSize.body))
                        .foregroundStyle(Nocturne.neutral300)
                        .lineSpacing(6)
                        .frame(maxWidth: 940, alignment: .leading)
                }
                if let extra, !extra.isEmpty {
                    Text(extra)
                        .font(.system(size: 20, design: .monospaced))
                        .foregroundStyle(Nocturne.neutral400)
                        .lineLimit(6)
                        .frame(maxWidth: 1060, alignment: .leading)
                }
                HStack(spacing: 20) { buttons() }
                    .padding(.top, 10)
            }
            .padding(.vertical, 56)
            .padding(.horizontal, 60)
            .frame(width: 1180, alignment: .leading)
            .background(Nocturne.surface, in: RoundedRectangle(cornerRadius: Nocturne.Radius.lg, style: .continuous))
            .shadow(color: .black.opacity(0.65), radius: 40, y: 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(.leading, 140)
        }
        .focusSection()
    }
}

struct StateButton: View {
    let title: String
    let id: String
    let primary: Bool
    var focused: FocusState<String?>.Binding
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            InertActionButton(title: title, primary: primary, focused: focused.wrappedValue == id)
        }
        .buttonStyle(BareButtonStyle())
        .focused(focused, equals: id)
    }
}
