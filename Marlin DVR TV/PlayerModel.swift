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
        var busyRecordings: [String] = []   // frame 6g: the recordings holding the tuner
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
    private(set) var pausedAt: Date?
    private(set) var pausedPosition: Double = 0     // live: seconds behind live when paused
    private(set) var notice: String?
    private(set) var hudVisible = true
    private(set) var countdown = 10
    private(set) var markedWatched = false
    private(set) var startingLine = ""
    private(set) var stopped = false

    private var keepAliveTask: Task<Void, Never>?
    private var hudTask: Task<Void, Never>?
    private var countdownTask: Task<Void, Never>?
    private var timeObserver: Any?
    private var observations: [NSKeyValueObservation] = []
    private var notificationTokens: [NSObjectProtocol] = []
    private var attachedAt: Date?
    private var lastResumeSave = Date.distantPast
    private var restartingBeyond = false

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
        let t = player.currentItem?.currentTime().seconds ?? -1
        let range = seekableRange.map { "\(Int($0.start))-\(Int($0.end))" } ?? "none"
        print("[player] timeControl=\(player.timeControlStatus.rawValue) rate=\(player.rate) waiting=\(player.reasonForWaitingToPlay?.rawValue ?? "-") t=\(Int(t)) seekable=\(range) isPaused=\(isPaused)")
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
        print("[player] recover check: t=\(t) range=\(range.start)-\(range.end)")
        if t < range.start + 1 {
            let target = CMTime(seconds: range.start + 2, preferredTimescale: 10)
            player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .positiveInfinity)
            player.play()
            notice = "The pause point left the buffer — resumed at the oldest point still available."
            showHUD(for: 8)
            print("[player] pause point left the window: seeking to \(range.start + 2)")
        }
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
                        .map { "\($0.program.title) on \($0.number) until \(TimeFormat.clock(unix: $0.end))" }
                }
            }
        }
        detachPlayer()
        keepAliveTask?.cancel()
        if let sessionID { await sessions.stop(id: sessionID) }
        self.failure = failure
        phase = .failed
    }

    // MARK: Restart / stop

    /// Frame 6h and seek-beyond: stop this session and start again, for a recording at `at` seconds.
    func restart(at requested: Double? = nil) async {
        let target = requested ?? (isRecording ? position : 0)
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
