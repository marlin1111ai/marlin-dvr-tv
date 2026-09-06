//
//  WeatherModel.swift
//  Marlin DVR TV
//
//  Pass 13 steps 2, 4 and 5: the one WeatherKit read behind both the Weather screen (frame
//  5f) and the Home glance card (frame 2a, dc:133-143). The design's caption is the rule —
//  "Weather — Apple WeatherKit on the device, no server involvement" (dc:693) — so nothing
//  here touches the DVR, and there is no second provider: if WeatherKit will not answer, the
//  screen says why.
//
//  One model, created once in `Marlin_DVR_TVApp` and shared, so Home and Weather show the
//  same numbers and the location prompt happens once.
//

import Foundation
import SwiftUI
import WeatherKit

@Observable
final class WeatherModel {
    enum Phase: Equatable {
        case idle
        /// Waiting on Core Location's one shot.
        case locating
        case loading
        case ready
        /// Location was declined or failed — the sentence to print comes from `DeviceLocation`.
        case noLocation(String)
        /// WeatherKit itself refused. `detail` is the framework's own error text.
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private(set) var weather: Weather?
    private(set) var attribution: WeatherAttribution?
    /// Read live from the one-shot fix rather than snapshotted: reverse geocoding finishes
    /// after the fix does, and often after the WeatherKit call has already settled, so a copy
    /// taken at load time would stay nil for the life of the screen.
    var place: String? { location.state.fix?.place }
    /// The moment WeatherKit says the data was produced (`CurrentWeather.metadata.date`),
    /// which is what "updated 2:38 PM" means — not the time this app asked.
    var updatedAt: Date? { weather?.currentWeather.metadata.date }

    let location = DeviceLocation()
    private var loadTask: Task<Void, Never>?

    /// Frame 5f draws 8 hourly columns (`wxHourly`, dc:1379-1386) and the owner fixed the
    /// daily list at 5 rows — the count the design ships (`wxDaily`, dc:1390-1394), not the
    /// render hint's 7 and not WeatherKit's 10 (DECISIONS.md 2026-09-06).
    static let hourlyCount = 8
    static let dailyCount = 5

    /// The next 8 hours from now. WeatherKit's hourly forecast starts at the top of the
    /// current hour, so hours already gone are dropped rather than drawn.
    var hourly: [HourWeather] {
        guard let weather else { return [] }
        let now = Date()
        return Array(weather.hourlyForecast.filter { $0.date >= now.addingTimeInterval(-1800) }.prefix(Self.hourlyCount))
    }

    var daily: [DayWeather] {
        guard let weather else { return [] }
        return Array(weather.dailyForecast.prefix(Self.dailyCount))
    }

    var today: DayWeather? { weather?.dailyForecast.first }

    /// Frame 5f draws one alert card (dc:721-727). WeatherKit may return several; the most
    /// severe comes first, and the rest are not drawn — the design has one slot.
    var alert: WeatherAlert? {
        weather?.weatherAlerts?.max { severityRank($0.severity) < severityRank($1.severity) }
    }

    private func severityRank(_ severity: WeatherSeverity) -> Int {
        switch severity {
        case .extreme: return 4
        case .severe: return 3
        case .moderate: return 2
        case .minor: return 1
        case .unknown: return 0
        @unknown default: return 0
        }
    }

    // MARK: Loading

    /// Idempotent: the first caller starts the location shot and the WeatherKit read, later
    /// callers join the one in flight. Home and the Weather screen both call this.
    func load() {
        guard loadTask == nil else { return }
        loadTask = Task { await run() }
    }

    /// Used by the Weather screen after a failure so the owner is not stuck with a dead panel.
    func retry() {
        loadTask?.cancel()
        loadTask = nil
        phase = .idle
        load()
    }

    private func run() async {
        phase = .locating
        location.start()

        // The one-shot fix arrives through the delegate; wait for it to settle.
        let fix = await waitForFix()
        guard let fix else {
            switch location.state {
            case .declined:
                phase = .noLocation("This Apple TV has not been allowed to use its location, so there is nothing to show the weather for. Settings → General → Privacy & Security → Location Services → Marlin DVR TV.")
            case .failed(let message):
                phase = .noLocation(message)
            default:
                phase = .noLocation("This Apple TV did not return a location.")
            }
            return
        }

        phase = .loading
        do {
            let service = WeatherService.shared
            async let forecast = service.weather(for: fix.clLocation)
            async let credit = service.attribution
            weather = try await forecast
            attribution = try? await credit
            phase = .ready
        } catch {
            // No substitute source (Pass 13 scope): say what WeatherKit said.
            phase = .failed("\(error)")
            print("[weather] WeatherKit: \(error)")
        }
    }

    /// Polls `DeviceLocation.state` — it is the delegate that moves it, and CLLocationManager
    /// has no async form. `DeviceLocation` carries its own 25 s timeout, so this ends.
    private func waitForFix() async -> LocationFix? {
        while true {
            switch location.state {
            case .ready(let fix): return fix
            case .declined, .failed: return nil
            case .idle, .asking:
                try? await Task.sleep(for: .milliseconds(150))
                if Task.isCancelled { return nil }
            }
        }
    }
}

// MARK: - The design's number and word formats

/// Frame 5f and the Home glance write temperatures as "81°", chances as "10%", wind as
/// "8 mph SW". WeatherKit hands back `Measurement`s, so the conversion happens here in one
/// place. Fahrenheit and miles per hour are what the design draws (dc:718, 740).
enum WeatherFormat {
    /// "81°"
    static func degrees(_ measurement: Measurement<UnitTemperature>) -> String {
        "\(Int(measurement.converted(to: .fahrenheit).value.rounded()))°"
    }

    /// "62%" from WeatherKit's 0…1
    static func percent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))%"
    }

    /// The hourly and daily strips show a chance only when there is one — the design leaves
    /// the slot empty at 0 (`pop:""`, dc:1379-1380, 1391).
    static func chance(_ fraction: Double) -> String? {
        fraction < 0.005 ? nil : percent(fraction)
    }

    /// "8 mph SW"
    static func wind(_ wind: Wind) -> String {
        let mph = Int(wind.speed.converted(to: .milesPerHour).value.rounded())
        return "\(mph) mph \(wind.compassDirection.abbreviation)"
    }

    /// "Partly Cloudy" — WeatherKit's own localized text, not a table of our own.
    static func condition(_ condition: WeatherCondition) -> String { condition.description }

    /// "3 PM" (dc:1379); the current hour reads "Now" so the strip has an anchor.
    static func hourLabel(_ date: Date, now: Date = Date()) -> String {
        if Calendar.current.isDate(date, equalTo: now, toGranularity: .hour) { return "Now" }
        return date.formatted(.dateTime.hour())
    }

    /// "Today", "Saturday" (dc:1390-1394)
    static func dayLabel(_ date: Date) -> String { TimeFormat.relativeDay(date) }

    /// "2:38 PM" (dc:707)
    static func updated(_ date: Date) -> String { TimeFormat.clock(date) }

    /// "39.40, -76.60" — shown in place of a town when reverse geocoding will not name it,
    /// so the header never invents a place.
    static func coordinates(_ fix: LocationFix) -> String {
        String(format: "%.2f, %.2f", fix.latitude, fix.longitude)
    }

    /// "Severe", "Moderate" — the alert card's severity word.
    static func severity(_ severity: WeatherSeverity) -> String {
        severity.description.capitalized
    }
}
