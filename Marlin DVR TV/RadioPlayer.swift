//
//  RadioPlayer.swift
//  Marlin DVR TV
//
//  Pass 19 steps 3, 4 and 5: the audio behind the Radio screen. A bare AVPlayer, nothing else.
//
//  What this deliberately does NOT do, because the contract forbids it for radio
//  (HLS-CLIENT-API.md §9, :305-316) and the owner's decision repeats it:
//
//  * **No play session.** No POST /api/play/sessions, no returned playlist URL, no first-
//    playlist probe, no 10-second keep-alive, no idle watchdog — ":307-309" says that route
//    "is for TV/cameras and does not know about radio". None of PlaybackSession is touched.
//  * **No AVPlayerViewController.** The station's transport is the Radio screen's own
//    now-playing bar, drawn in SwiftUI; there is no full-screen player and no PlayerScreen.
//  * **No MIME option of any kind.** `AVPlayerItem(url:)` builds its AVURLAsset with no
//    options dictionary, so AVFoundation reads the type off the wire — the Content-Type the
//    station actually sends — exactly as ":313" requires ("Play whatever content type the
//    stream serves; do not trust `format`").
//
//    `AVURLAssetOverrideMIMETypeKey` is the trap here and it is not used. Its own header says
//    that with a value supplied "**only the specified MIME type is considered** … Any other
//    information that may be available, such as the URL path extension or a server-provided
//    MIME type, **is ignored**" (AVAsset.h:550-552). Feeding the owner's `format` label into
//    it would make a label that is *empty on both of this owner's stations* authoritative over
//    the truth from the server.
//  * **No AVAudioSession category and no background mode.** Radio has the same lifetime as
//    every other player in this app (owner, 2026-09-06): leaving the screen stops it, and it
//    does not play behind another screen or survive the screen dimming. `stop()` is called on
//    disappear and when the app leaves the foreground.
//
//  Never silence presented as playing (step 7): the phase only becomes `.playing` when
//  AVPlayer's own `timeControlStatus` says audio is running, a station that produces nothing
//  within `startTimeout` becomes `.failed` naming what was seen, and a stream that ends does
//  not stay on screen as though it were still going.
//

import AVFoundation
import Foundation
import UIKit

@Observable
final class RadioPlayer {
    enum Phase: Equatable {
        case idle
        /// Asked for, no audio yet.
        case connecting(RadioStation)
        /// AVPlayer says it is rendering.
        case playing(RadioStation)
        /// It will not play, and this says what failed.
        case failed(RadioStation, String)

        var station: RadioStation? {
            switch self {
            case .idle: return nil
            case .connecting(let station), .playing(let station), .failed(let station, _): return station
            }
        }
    }

    private(set) var phase: Phase = .idle

    /// How long a station gets to produce audio before the screen says it did not. Generous —
    /// a cold CDN connection over the house wireless is a few seconds — but finite, because a
    /// bar that says "Connecting" for ever is the same lie as one that says "Playing".
    private static let startTimeout: Duration = .seconds(20)

    private var player: AVPlayer?
    private var observations: [NSKeyValueObservation] = []
    private var tokens: [NSObjectProtocol] = []
    private var watchdog: Task<Void, Never>?

    /// Bumped by every `play` and every `stop`. An AVFoundation callback that arrives from a
    /// torn-down item carries an older number and is dropped, so a station that fails a moment
    /// after Stop cannot repaint the bar it no longer owns.
    private var generation = 0

    /// The last line AVFoundation wrote to the item's error log. It is what names the failure
    /// when the watchdog fires and the item itself reported no error.
    private var lastErrorLogLine: String?

    /// Stops when the app leaves the foreground — the Apple TV going to sleep, or the user
    /// leaving for the tvOS home screen. Radio does not play behind anything (step 5).
    private var backgroundToken: NSObjectProtocol?

    init() {
        backgroundToken = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.phase.station != nil else { return }
                print("[radio] app left the foreground — stopping")
                self.stop()
            }
        }
    }

    // MARK: Play

    func play(_ station: RadioStation) {
        stop()
        guard let url = URL(string: station.url) else {
            phase = .failed(station, "The server's stream URL for this station is not a URL the app can open.")
            print("[radio] \(station.name): unusable stream URL")
            return
        }
        generation += 1
        let mine = generation
        lastErrorLogLine = nil
        phase = .connecting(station)

        // The whole of step 3: the server's URL, straight into AVFoundation, with no options
        // dictionary and no asset subclass. Nothing between this line and the station.
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        self.player = player
        observe(item: item, player: player, station: station, generation: mine)
        player.play()
        startWatchdog(station: station, generation: mine)
        print("[radio] \(station.name): play \(url.host ?? "?")\(url.path)")
    }

    // MARK: Stop (step 4's control, and step 5's lifetime)

    func stop() {
        generation += 1
        watchdog?.cancel()
        watchdog = nil
        for observation in observations { observation.invalidate() }
        observations.removeAll()
        for token in tokens { NotificationCenter.default.removeObserver(token) }
        tokens.removeAll()
        if let player {
            player.pause()
            player.replaceCurrentItem(with: nil)
        }
        if let station = phase.station { print("[radio] \(station.name): stopped") }
        player = nil
        lastErrorLogLine = nil
        phase = .idle
    }

    // MARK: Observation

    private func observe(item: AVPlayerItem, player: AVPlayer, station: RadioStation, generation mine: Int) {
        observations.append(item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in self?.statusChanged(item, station: station, generation: mine) }
        })
        observations.append(player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            Task { @MainActor [weak self] in self?.timeControlChanged(player, station: station, generation: mine) }
        })
        let center = NotificationCenter.default
        tokens.append(center.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main) { [weak self] note in
            let error = note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
            Task { @MainActor [weak self] in
                self?.fail(station: station, generation: mine, "It stopped playing. \(Self.describe(error))")
            }
        })
        // A continuous stream has no end. If one arrives the station has gone away, and saying
        // "playing" after it would be silence presented as playing (step 7).
        tokens.append(center.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.fail(station: station, generation: mine, "The stream ended.")
            }
        })
        tokens.append(center.addObserver(forName: .AVPlayerItemNewErrorLogEntry, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.errorLogEntry(item, station: station, generation: mine) }
        })
    }

    private func statusChanged(_ item: AVPlayerItem, station: RadioStation, generation mine: Int) {
        guard mine == generation else { return }
        switch item.status {
        case .failed:
            fail(station: station, generation: mine, "AVPlayer could not play it. \(Self.describe(item.error))")
        case .readyToPlay:
            print("[radio] \(station.name): item ready")
        default:
            break
        }
    }

    private func timeControlChanged(_ player: AVPlayer, station: RadioStation, generation mine: Int) {
        guard mine == generation else { return }
        switch player.timeControlStatus {
        case .playing:
            // AVPlayer only reports this once it is actually rendering, so this is the one
            // moment the screen is entitled to say the station is playing.
            if case .playing = phase { return }
            watchdog?.cancel()
            watchdog = nil
            phase = .playing(station)
            print("[radio] \(station.name): playing")
        case .waitingToPlayAtSpecifiedRate:
            print("[radio] \(station.name): waiting — \(player.reasonForWaitingToPlay?.rawValue ?? "no reason given")")
        case .paused:
            break
        @unknown default:
            break
        }
    }

    private func errorLogEntry(_ item: AVPlayerItem, station: RadioStation, generation mine: Int) {
        guard mine == generation, let event = item.errorLog()?.events.last else { return }
        let comment = event.errorComment ?? "no comment"
        lastErrorLogLine = "\(comment) (status \(event.errorStatusCode))"
        print("[radio] \(station.name): error log — \(lastErrorLogLine ?? "")")
    }

    private func startWatchdog(station: RadioStation, generation mine: Int) {
        watchdog = Task { [weak self] in
            try? await Task.sleep(for: Self.startTimeout)
            guard !Task.isCancelled else { return }
            guard let self, mine == self.generation else { return }
            if case .playing = self.phase { return }
            let seconds = Int(Self.startTimeout.components.seconds)
            let tail = self.lastErrorLogLine.map { " Last thing AVFoundation reported: \($0)." } ?? ""
            self.fail(station: station, generation: mine,
                      "No audio started within \(seconds) seconds.\(tail)")
        }
    }

    private func fail(station: RadioStation, generation mine: Int, _ message: String) {
        guard mine == generation else { return }
        print("[radio] \(station.name): FAILED — \(message)")
        // Tear the player down; `stop` bumps the generation, so put the failure up afterwards
        // and it survives on screen with nothing left running behind it.
        stop()
        phase = .failed(station, message)
    }

    /// An NSError said in full — domain, code and any underlying error — because when a station
    /// will not play, the code is the evidence.
    private static func describe(_ error: Error?) -> String {
        guard let error = error as NSError? else { return "AVFoundation reported no error." }
        var parts: [String] = [error.localizedDescription]
        if let reason = error.localizedFailureReason, !reason.isEmpty { parts.append(reason) }
        parts.append("(\(error.domain) \(error.code))")
        if let underlying = error.userInfo[NSUnderlyingErrorKey] as? NSError {
            parts.append("← \(underlying.domain) \(underlying.code)")
        }
        return parts.joined(separator: " ")
    }
}
