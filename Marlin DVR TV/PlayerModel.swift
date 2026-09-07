//
//  PlayerModel.swift
//  Marlin DVR TV
//
//  The Player's state behind the overlays of frames 6a–6h: one AVPlayer, one HLS session
//  (contract §2–§7), the 10-second keep-alive (§6), the recording position = session
//  start + player time (Pass 3 2(b) item 6), seek-past-the-prepared-range by a new
//  session (§3), the live time-shift buffer as the seekable range (§4), the resume store,
//  and watched-on-end. Everything runs on the main actor; AVFoundation callbacks hop to it.
//

import AVFoundation
import AVKit
import Foundation
import SwiftUI

@Observable
final class PlayerModel {
    enum Phase: Equatable {
        case starting, playing, ended, expired, failed
    }

    struct Failure {
        let status: Int             // HTTP status, or 0 for a transport / player failure
        let message: String         // the server's text
        var log: String?            // the session log's last lines (502)
        var busyRecordings: [BusyRecording] = []   // frame 6g: the recordings holding the tuner
    }

    /// One recording in progress on the same source as the channel that failed: the job id
    /// POST /api/schedule/jobs/{id}/stop needs, and the line frame 6g shows.
    struct BusyRecording: Identifiable {
        let id: String              // Job.id
        let label: String           // "WJZ News at 4 on 13.1 until 4:30 PM"
    }

    let request: PlayRequest
    let clientName: String
    let player = AVPlayer()

    private let sessions: PlaybackSessionClient
    private let api: APIClient

    private(set) var phase: Phase = .starting
    private(set) var failure: Failure?
    private(set) var session: PlaySession?
    private(set) var startOffset: Double = 0        // recording: the session's `start`
    private(set) var duration: Double = 0           // recording: the whole recording (contract §2.2)
    private(set) var position: Double = 0           // recording: absolute seconds
    private(set) var preparedTo: Double = 0         // recording: absolute end of the segmented range
    private(set) var behindLive: Double = 0         // live: seconds behind the live edge
    private(set) var bufferSeconds: Double = 0      // live: the advertised window (contract §4)
    private(set) var isPaused = false
    /// Pass 28: the rate this recording runs at, for the frame-step distance. 30 until a track
    /// reports one, and only ever replaced by a value above 1.
    private(set) var frameRate: Double = PlayerModel.defaultFrameRate
    /// The last frame step's measured distance, for the console line only.
    private(set) var lastFrameStep: Double = 0
    private(set) var pausedAt: Date?
    private(set) var pausedPosition: Double = 0     // live: seconds behind live when paused
    private(set) var notice: String?
    private(set) var hudVisible = true
    private(set) var countdown = 10
    private(set) var markedWatched = false
    private(set) var startingLine = ""
    private(set) var stopped = false
    /// Sweep 4: what the last write from a failure state did, and whether it succeeded.
    private(set) var writeNotice: String?
    private(set) var writeDone = false
    private(set) var writing = false

    private var keepAliveTask: Task<Void, Never>?
    private var hudTask: Task<Void, Never>?
    private var countdownTask: Task<Void, Never>?
    private var timeObserver: Any?
    private var observations: [NSKeyValueObservation] = []
    private var notificationTokens: [NSObjectProtocol] = []
    private var attachedAt: Date?
    private var lastResumeSave = Date.distantPast
    private var restartingBeyond = false

    static let defaultFrameRate: Double = 30
    /// Frame durations are built at 90 kHz: 1/25, 1/30 and 1/29.97 all land within a microsecond.
    private static let frameTimescale: CMTimeScale = 90_000

    var isLive: Bool { if case .live = request { return true }; return false }
    var isRecording: Bool { if case .recording = request { return true }; return false }
    var isCamera: Bool { if case .camera = request { return true }; return false }
    var nextEpisode: Episode? { request.nextEpisode }
    var fullyPrepared: Bool { duration > 0 && preparedTo >= duration - 2 }

    init(request: PlayRequest, api: APIClient, clientName: String, sessions: PlaybackSessionClient = PlaybackSessionClient()) {
        self.request = request
        self.api = api
        self.clientName = clientName
        self.sessions = sessions
        self.startingLine = Self.startingLine(for: request)
    }

    // MARK: Start

    func start() async {
        phase = .starting
        failure = nil
        notice = nil
        do {
            let created = try await sessions.create(request)
            session = created
            startOffset = created.start
            duration = created.duration
            print("[player] session \(created.id) \(created.kind) mode=\(created.mode) start=\(created.start) duration=\(created.duration)")
        } catch let error as APIError {
            await fail(status: error.httpStatus ?? 0, message: error.message, sessionID: nil)
            return
        } catch {
            await fail(status: 0, message: error.localizedDescription, sessionID: nil)
            return
        }
        guard let created = session, let url = ServerConfig.resolve(created.url) else {
            await fail(status: 0, message: "no playlist URL", sessionID: session?.id)
            return
        }
        let probe = await sessions.firstPlaylist(url)
        print("[player] first playlist → \(probe.status) \(probe.text)")
        guard !stopped else { return }
        guard probe.status == 200 else {
            await fail(status: probe.status, message: probe.text, sessionID: created.id)
            return
        }
        attach(url)
        startKeepAlive(url)
    }

    private static func startingLine(for request: PlayRequest) -> String {
        switch request {
        case .live: return "Tuning the antenna and starting the encoder"
        case .recording: return "Preparing the recording"
        case .camera: return "Connecting to the camera"
        }
    }

    private func attach(_ url: URL) {
        let item = AVPlayerItem(url: url)
        item.preferredForwardBufferDuration = 0
        item.externalMetadata = Self.metadata(for: request)
        observe(item)
        player.replaceCurrentItem(with: item)
        player.play()
        attachedAt = Date()
        phase = .playing
        showHUD(for: 6)
    }

    private static func metadata(for request: PlayRequest) -> [AVMetadataItem] {
        func item(_ identifier: AVMetadataIdentifier, _ value: String) -> AVMetadataItem {
            let m = AVMutableMetadataItem()
            m.identifier = identifier
            m.value = value as NSString
            m.extendedLanguageTag = "und"
            return m
        }
        var items = [item(.commonIdentifierTitle, request.title)]
        if !request.subtitle.isEmpty { items.append(item(.iTunesMetadataTrackSubTitle, request.subtitle)) }
        return items
    }

    // MARK: Observation

    private func observe(_ item: AVPlayerItem) {
        let interval = CMTime(seconds: 1, preferredTimescale: 10)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick() }
        }
        observations.append(player.observe(\.timeControlStatus, options: [.new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in self?.timeControlChanged() }
        })
        observations.append(item.observe(\.status, options: [.new]) { [weak self] _, _ in
            Task { @MainActor [weak self] in self?.itemStatusChanged() }
        })
        let center = NotificationCenter.default
        notificationTokens.append(center.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.playedToEnd() }
        })
        notificationTokens.append(center.addObserver(forName: AVPlayerItem.timeJumpedNotification, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.timeJumped() }
        })
        notificationTokens.append(center.addObserver(forName: .AVPlayerItemNewErrorLogEntry, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.errorLogEntry() }
        })
        notificationTokens.append(center.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main) { [weak self] note in
            let error = note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
            Task { @MainActor [weak self] in self?.playbackFailed(error) }
        })
    }

    private var seekableRange: (start: Double, end: Double)? {
        guard let item = player.currentItem else { return nil }
        let ranges = item.seekableTimeRanges.map(\.timeRangeValue).filter { $0.duration.isNumeric && $0.duration.seconds > 0 }
        guard let first = ranges.first, let last = ranges.last else { return nil }
        return (first.start.seconds, last.end.seconds)
    }

    private func tick() {
        guard phase == .playing, let item = player.currentItem else { return }
        let t = item.currentTime().seconds
        guard t.isFinite else { return }
        if isRecording {
            position = startOffset + t
            refreshFrameRate()
            if let range = seekableRange { preparedTo = startOffset + range.end }
            if Date().timeIntervalSince(lastResumeSave) >= 10, !isPaused {
                saveResume()
            }
        } else if let range = seekableRange {
            behindLive = max(0, range.end - t)
            bufferSeconds = range.end - range.start
        }
    }

    private func timeControlChanged() {
        guard phase == .playing else { return }
        switch player.timeControlStatus {
        case .paused:
            if !isPaused {
                isPaused = true
                pausedAt = Date()
                pausedPosition = behindLive
                showHUD(for: nil)
                if isRecording { saveResume() }
                print("[player] paused (\(isLive ? "\(Int(behindLive)) s behind live" : PlayerTime.clock(position)))")
            }
        case .playing:
            if isPaused {
                isPaused = false
                pausedAt = nil
                showHUD(for: 6)
                if isLive { recoverIfPausePointLeftWindow() }
                print("[player] playing (\(isLive ? "\(Int(behindLive)) s behind live" : PlayerTime.clock(position)))")
            }
        case .waitingToPlayAtSpecifiedRate:
            if isLive, isPaused == false { recoverIfPausePointLeftWindow() }
        @unknown default:
            break
        }
    }

    /// Contract §4: a pause longer than the buffer loses the pause point; re-seek to the
    /// earliest seekable time and say so (standing call), never to the live edge.
    private func recoverIfPausePointLeftWindow() {
        guard let item = player.currentItem, let range = seekableRange else { return }
        let t = item.currentTime().seconds
        if t < range.start + 1 {
            let target = CMTime(seconds: range.start + 2, preferredTimescale: 10)
            player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .positiveInfinity)
            player.play()
            notice = "The pause point left the buffer — resumed at the oldest point still available."
            showHUD(for: 8)
            print("[player] pause point left the window: seeking to \(range.start + 2)")
        }
    }

    // MARK: Frame stepping (Pass 28) — recordings only, paused only

    /// The video track's `nominalFrameRate`, which is the value this asks for. HLS items very
    /// often expose no `assetTrack` (Pass 27 read 0 from it on both recordings), so the
    /// `AVPlayerItemTrack`'s `currentVideoFrameRate` — the rate actually being rendered, and the
    /// same number — is the fallback. Read every tick while playing, so by the time anyone
    /// pauses the real rate is already in hand. Never accepts a value of 1 or less.
    private func refreshFrameRate() {
        guard let item = player.currentItem else { return }
        for track in item.tracks {
            if let nominal = track.assetTrack?.nominalFrameRate, nominal > 1 {
                adopt(Double(nominal), from: "nominalFrameRate")
                return
            }
        }
        // HLS items expose no assetTrack, so fall back to the rate actually being rendered —
        // but only while it is a plausible broadcast rate. `currentVideoFrameRate` sags towards
        // zero during start-up and rebuffering, and one bad sample is enough to poison every
        // later step: a 2.17 fps reading was measured on the device making each frame step
        // 0.46 s long instead of 0.033 s.
        for track in item.tracks where track.currentVideoFrameRate > 10 && track.currentVideoFrameRate < 121 {
            adopt(Double(track.currentVideoFrameRate), from: "currentVideoFrameRate")
            return
        }
    }

    /// The broadcast and film rates a recording can actually be. `currentVideoFrameRate` is a
    /// rolling average and reads a little off (30.59 was measured for 29.97 material), so a
    /// reading within 5% of a real rate is taken as that rate. Being exact matters: an
    /// over-estimated rate makes a step land short of the next frame, and two clicks in a row
    /// then show the same picture.
    private static let standardFrameRates: [Double] = [23.976, 24, 25, 29.97, 30, 50, 59.94, 60]

    private func adopt(_ measured: Double, from source: String) {
        let rate = Self.standardFrameRates.first { abs($0 - measured) / $0 < 0.05 } ?? measured
        guard rate > 1, abs(rate - frameRate) > 0.001 else { return }
        frameRate = rate
        print(String(format: "[framestep] frame rate %.4f fps (%@ read %.4f) → one frame = %.6f s",
                     rate, source, measured, 1 / rate))
    }

    /// One frame forward (`+1`) or back (`-1`), while paused on a recording.
    ///
    /// The move is an **exact seek**: both tolerances `.zero`, which is what makes AVFoundation
    /// land on the adjacent frame rather than the nearest keyframe. Play/pause is not touched —
    /// AVPlayer renders the seek target while paused, so the frame simply appears. Each step is
    /// computed fresh from `currentTime()`, never from an accumulated frame index, so a step can
    /// neither drift nor compound a rounding error.
    ///
    /// Returns **true** when it acted, which is the caller's signal to swallow the press. It
    /// returns false while playing, on live, on a camera, and before the item exists — in every
    /// one of those cases the press falls straight through to Apple's transport bar, unchanged.
    @discardableResult
    func frameStep(_ frames: Int) -> Bool {
        guard isRecording, isPaused, phase == .playing, frames != 0, let item = player.currentItem else { return false }
        if frameRate <= 1 { refreshFrameRate() }
        let fps = frameRate > 1 ? frameRate : Self.defaultFrameRate
        let frameDuration = CMTime(value: CMTimeValue((Double(Self.frameTimescale) / fps).rounded()),
                                   timescale: Self.frameTimescale)
        // A coalescing or chase seek still in flight would overwrite this one with its own
        // tolerance, and the frame would land on a keyframe instead.
        item.cancelPendingSeeks()
        let from = item.currentTime()
        var target = frames > 0 ? CMTimeAdd(from, frameDuration) : CMTimeSubtract(from, frameDuration)
        if let range = seekableRange {
            let low = CMTime(seconds: range.start, preferredTimescale: Self.frameTimescale)
            let high = CMTime(seconds: max(range.start, range.end - 0.05), preferredTimescale: Self.frameTimescale)
            if CMTimeCompare(target, low) < 0 { target = low }
            if CMTimeCompare(target, high) > 0 { target = high }
        }
        item.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            Task { @MainActor [weak self] in self?.frameStepLanded(from: from) }
        }
        return true
    }

    /// Where the step actually landed. `position` is refreshed here because `tick()` does not run
    /// while paused, and the HUD's "x of y" would otherwise stand still as the picture moved.
    private func frameStepLanded(from: CMTime) {
        guard let item = player.currentItem else { return }
        let landed = item.currentTime()
        lastFrameStep = CMTimeGetSeconds(landed) - CMTimeGetSeconds(from)
        position = startOffset + CMTimeGetSeconds(landed)
        print(String(format: "[framestep] %+.6f s (one frame at %.4f fps = %.6f s) → t=%.6f",
                     lastFrameStep, frameRate, 1 / frameRate, CMTimeGetSeconds(landed)))
    }

    private func itemStatusChanged() {
        guard let item = player.currentItem else { return }
        if item.status == .failed {
            playbackFailed(item.error)
        }
    }

    private func errorLogEntry() {
        guard let item = player.currentItem, let event = item.errorLog()?.events.last else { return }
        print("[player] error log: status=\(event.errorStatusCode) \(event.errorComment ?? "") uri=\(event.uri ?? "")")
        if isLive, event.errorStatusCode == 404 {
            recoverIfPausePointLeftWindow()
        }
    }

    private func playbackFailed(_ error: Error?) {
        guard phase == .playing || phase == .starting else { return }
        let text = error?.localizedDescription ?? "playback failed"
        print("[player] playback failed: \(text)")
        Task { await fail(status: 0, message: text, sessionID: session?.id) }
    }

    /// A user seek (AVPlayerViewController's scrubber) to the end of the prepared range
    /// while the recording is not fully segmented → DELETE, new session at that position,
    /// player at 0 (contract §3; standing call).
    private func timeJumped() async {
        if isLive, phase == .playing, let attachedAt, Date().timeIntervalSince(attachedAt) > 3 {
            tick()
            showHUD(for: 6)   // a rewind or fast-forward: show how far behind live
        }
        guard isRecording, phase == .playing, !restartingBeyond, let attachedAt, Date().timeIntervalSince(attachedAt) > 3,
              let item = player.currentItem, let range = seekableRange else { return }
        let t = item.currentTime().seconds
        guard t.isFinite, range.end - t < 1.5, !fullyPrepared else { return }
        let target = startOffset + t
        print("[player] seek past the prepared range: \(target)s of \(duration)s")
        restartingBeyond = true
        await restart(at: target)
        restartingBeyond = false
    }

    // MARK: Keep-alive (contract §6)

    private func startKeepAlive(_ url: URL) {
        keepAliveTask?.cancel()
        print("[session] keep-alive loop started for \(url.lastPathComponent) every 10 s")
        keepAliveTask = Task { [weak self] in
            var n = 0
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: PlaybackSessionClient.keepAliveInterval)
                } catch {
                    return
                }
                guard let self, !self.stopped else { return }
                n += 1
                let status = await self.sessions.keepAlive(url)
                print("[session] keep-alive #\(n) → \(status.map(String.init) ?? "no response")")
                if status == 410 {
                    self.sessionExpired()
                    return
                }
            }
        }
    }

    private func sessionExpired() {
        guard phase == .playing || phase == .starting else { return }
        if isRecording { saveResume() }
        detachPlayer()
        keepAliveTask?.cancel()
        phase = .expired
    }

    // MARK: End of a recording

    private func playedToEnd() async {
        guard isRecording, phase == .playing, let episode = request.episode else { return }
        print("[player] played to end")
        detachPlayer()
        keepAliveTask?.cancel()
        if let id = session?.id { await sessions.stop(id: id) }
        do {
            try await sessions.markWatched(recordingID: episode.id)
            markedWatched = true
        } catch {
            print("[player] watched:true failed: \(error)")
            markedWatched = false
        }
        ResumeStore.clear(recordingID: episode.id)
        phase = .ended
        if nextEpisode != nil { startCountdown() }
    }

    private func startCountdown() {
        countdown = 10
        countdownTask?.cancel()
        countdownTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, let self else { return }
                self.countdown -= 1
                if self.countdown <= 0 { return }
            }
        }
    }

    func cancelCountdown() {
        countdownTask?.cancel()
        countdown = -1
    }

    // MARK: Failure (contract §7; frames 6f, 6g, 6h)

    private func fail(status: Int, message: String, sessionID: String?) async {
        guard !stopped else { return }
        var failure = Failure(status: status, message: message)
        if status == 502, let sessionID {
            if let log = await sessions.log(id: sessionID) {
                failure.log = log.split(separator: "\n").suffix(6).joined(separator: "\n")
            }
            if isLive, let channel = request.channel {
                if let schedule = try? await api.schedule() {
                    failure.busyRecordings = schedule.jobs
                        .filter { $0.status == "Recording" && $0.sourceId == channel.sourceId }
                        .map { BusyRecording(id: $0.id, label: "\($0.program.title) on \($0.number) until \(TimeFormat.clock(unix: $0.end))") }
                }
            }
        }
        detachPlayer()
        keepAliveTask?.cancel()
        if let sessionID { await sessions.stop(id: sessionID) }
        // The session is stopped and its folder is gone; forget it so a later restart
        // (frame 6g's "Stop the recording and watch") does not DELETE it a second time.
        session = nil
        self.failure = failure
        phase = .failed
    }

    // MARK: Sweep 4 — the writes the failure states offer

    /// Frame 6f: "Hide this channel" → PUT /api/sources/{id}/lineup/{guid} {hidden: true}.
    /// The override hides the channel for every client, not only this Apple TV
    /// (sources.go:960-1004; Pass 4 Open Question 8), and the app's lists drop it on their
    /// next load because /api/channels and /api/guide skip hidden channels (sources.go:359).
    func hideChannel() async {
        guard let channel = request.channel, !writing else { return }
        writing = true
        writeNotice = nil
        do {
            let override = try await api.setChannelHidden(sourceId: channel.sourceId, guid: channel.guid, hidden: true)
            writeDone = override.hidden
            writeNotice = override.hidden
                ? "\(channel.number) \(channel.name) is hidden. It leaves the guide, On Now and the channel lists the next time they load."
                : "The server did not set the hidden flag."
        } catch {
            writeDone = false
            writeNotice = WriteError.text(error)
            print("[player] hide channel failed: \(error)")
        }
        writing = false
    }

    /// Frame 6g: "Stop the recording and watch" → POST /api/schedule/jobs/{id}/stop for the
    /// recording named in the copy, then start the live session that the busy tuner refused.
    /// The stop call returns only once the recorder has closed the file (recorder.go:672-676),
    /// so the tuner is free before the new session is created.
    func stopBlockingRecordingAndWatch() async {
        guard let busy = failure?.busyRecordings.first, !writing else { return }
        writing = true
        writeNotice = nil
        do {
            let outcome = try await api.stopJob(id: busy.id)
            writeDone = true
            writeNotice = "Stopped \(outcome.title.isEmpty ? busy.label : outcome.title) (\(outcome.status)). Starting the channel…"
            writing = false
            await restart()
        } catch {
            writeDone = false
            writeNotice = WriteError.text(error)
            writing = false
            print("[player] stop recording failed: \(error)")
        }
    }

    // MARK: Restart / stop

    /// Frame 6h and seek-beyond: stop this session and start again, for a recording at `at` seconds.
    func restart(at requested: Double? = nil) async {
        let target = requested ?? (isRecording ? position : 0)
        writeDone = false
        detachPlayer()
        keepAliveTask?.cancel()
        if let id = session?.id { await sessions.stop(id: id) }
        session = nil
        if isRecording, let episode = request.episode {
            ResumeStore.save(recordingID: episode.id, position: target, duration: duration)
        }
        startOffset = target
        position = target
        await startAgain(at: target)
    }

    private func startAgain(at target: Double) async {
        phase = .starting
        failure = nil
        do {
            let created = try await sessions.create(request.withStart(target))
            session = created
            startOffset = created.start
            duration = created.duration
            print("[player] session \(created.id) restarted start=\(created.start)")
            guard let url = ServerConfig.resolve(created.url) else { return }
            let probe = await sessions.firstPlaylist(url)
            guard !stopped else { return }
            guard probe.status == 200 else {
                await fail(status: probe.status, message: probe.text, sessionID: created.id)
                return
            }
            attach(url)
            startKeepAlive(url)
        } catch let error as APIError {
            await fail(status: error.httpStatus ?? 0, message: error.message, sessionID: nil)
        } catch {
            await fail(status: 0, message: error.localizedDescription, sessionID: nil)
        }
    }

    /// Dismissal, background, or switching to another request: never leave a session running.
    func stop() async {
        guard !stopped else { return }
        stopped = true
        print("[player] stop: phase=\(phase) session=\(session?.id ?? "none")")
        if isRecording, phase == .playing { saveResume() }
        detachPlayer()
        keepAliveTask?.cancel()
        hudTask?.cancel()
        countdownTask?.cancel()
        if let id = session?.id { await sessions.stop(id: id) }
        session = nil
    }

    private func detachPlayer() {
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        timeObserver = nil
        observations.forEach { $0.invalidate() }
        observations.removeAll()
        notificationTokens.forEach { NotificationCenter.default.removeObserver($0) }
        notificationTokens.removeAll()
        player.pause()
        player.replaceCurrentItem(with: nil)
        attachedAt = nil
        isPaused = false
    }

    private func saveResume() {
        guard isRecording, let episode = request.episode else { return }
        lastResumeSave = Date()
        if duration > 0, position >= duration - 3 { return }
        ResumeStore.save(recordingID: episode.id, position: position, duration: duration)
    }

    // MARK: HUD

    /// Show the overlay for a while (nil = until the next call).
    func showHUD(for seconds: Double?) {
        hudVisible = true
        hudTask?.cancel()
        guard let seconds else { return }
        hudTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled, let self, !self.isPaused else { return }
            self.hudVisible = false
        }
    }
}

enum PlayerTime {
    /// "22:14" or "1:02:14"
    static func clock(_ seconds: Double) -> String {
        let s = max(0, Int(seconds.rounded()))
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec) : String(format: "%d:%02d", m, sec)
    }

    /// "1 min 20 s" / "45 s" / "1 hr 2 min"
    static func lag(_ seconds: Double) -> String {
        let s = max(0, Int(seconds.rounded()))
        if s < 60 { return "\(s) s" }
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        if h > 0 { return m > 0 ? "\(h) hr \(m) min" : "\(h) hr" }
        return sec > 0 ? "\(m) min \(sec) s" : "\(m) min"
    }
}
