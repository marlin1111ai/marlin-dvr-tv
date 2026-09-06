//
//  WeatherLocation.swift
//  Marlin DVR TV
//
//  Pass 13 step 3: where the Weather screen gets its place from. The design's note is
//  "From this Apple TV's location, not the server" (dc:709), so the fix comes from Core
//  Location on the device and never from the DVR.
//
//  tvOS has no continuous location: `startUpdatingLocation` is API_UNAVAILABLE(tvos) and
//  `requestAlwaysAuthorization` is too (CLLocationManager.h:585, :515 — Pass 12 §4.4). What is
//  available is `requestWhenInUseAuthorization` + a single `requestLocation`, which is what the
//  owner chose: one shot, the system prompt, the answer cached so the prompt is not shown again.
//
//  Everything here has a spoken state. If the owner declines, or the fix fails or never
//  arrives, `state` says which — the screen prints that sentence rather than a blank panel,
//  and there is no fallback to a hard-coded place anywhere in this file.
//

import CoreLocation
import Foundation
import MapKit   // CLLocationCoordinate2D for the radar map

/// The cached one-shot fix. Written once, on the first successful request; read on every
/// launch after that so the system prompt appears exactly once.
struct LocationFix: Codable, Equatable {
    var latitude: Double
    var longitude: Double
    /// "Towson, Maryland" — filled in by reverse geocoding, which may fail; the fix is
    /// still usable without it.
    var place: String?
    var fixedAt: Date

    var clLocation: CLLocation { CLLocation(latitude: latitude, longitude: longitude) }
    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
}

@Observable
final class DeviceLocation: NSObject, CLLocationManagerDelegate {
    /// Every state the screen can be in. None of them is silent.
    enum State: Equatable {
        case idle
        /// The system prompt is up, or the one-shot request is in flight.
        case asking
        case ready(LocationFix)
        /// The owner said no, or tvOS has location off for this Apple TV.
        case declined
        case failed(String)

        var fix: LocationFix? {
            if case .ready(let fix) = self { return fix }
            return nil
        }
    }

    private(set) var state: State = .idle

    private let manager = CLLocationManager()
    private static let defaultsKey = "marlinWeatherFix"
    /// tvOS can leave `requestLocation` outstanding with no delegate callback at all; without
    /// this the screen would sit on "Finding this Apple TV's location…" for ever.
    private static let timeout: Duration = .seconds(25)
    private var timeoutTask: Task<Void, Never>?
    /// `requestLocation` is only sent once per launch, however many times the authorization
    /// callback fires.
    private var requested = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    // MARK: The cache

    static var cachedFix: LocationFix? {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(LocationFix.self, from: data)
    }

    private static func cache(_ fix: LocationFix) {
        if let data = try? JSONEncoder().encode(fix) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    // MARK: The one shot

    /// Called once when Weather first needs a location. A cached fix short-circuits the
    /// whole thing — no prompt, no request.
    func start() {
        if case .ready = state { return }
        if case .asking = state { return }

        if let fix = Self.cachedFix {
            state = .ready(fix)
            // The coordinates are cached but the name may not have resolved last time.
            if fix.place == nil { resolvePlace(for: fix) }
            return
        }

        state = .asking
        beginTimeout()

        switch manager.authorizationStatus {
        case .notDetermined:
            // The prompt. `locationManagerDidChangeAuthorization` carries the answer.
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            requestOnce()
        case .denied, .restricted:
            finish(.declined)
        @unknown default:
            finish(.failed("Location returned an authorization state this app does not know."))
        }
    }

    private func requestOnce() {
        guard !requested else { return }
        requested = true
        manager.requestLocation()
    }

    private func beginTimeout() {
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: Self.timeout)
            guard !Task.isCancelled, let self, case .asking = self.state else { return }
            self.state = .failed("This Apple TV did not answer with a location within 25 seconds.")
        }
    }

    private func finish(_ new: State) {
        timeoutTask?.cancel()
        timeoutTask = nil
        state = new
    }

    // MARK: CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if state.fix == nil { requestOnce() }
        case .denied, .restricted:
            finish(.declined)
        case .notDetermined:
            break   // the prompt is still up
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let fix = LocationFix(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            place: nil,
            fixedAt: Date()
        )
        Self.cache(fix)
        finish(.ready(fix))
        resolvePlace(for: fix)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // A denial arrives here as kCLErrorDenied on some tvOS builds rather than through
        // the authorization callback; say the honest thing either way.
        if let clError = error as? CLError, clError.code == .denied {
            finish(.declined)
        } else {
            finish(.failed("Core Location could not fix this Apple TV: \(error.localizedDescription)"))
        }
    }

    // MARK: The place name

    /// "Towson, Maryland" (dc:707). Best effort: the screen shows the coordinates when the
    /// name will not resolve, never a made-up town.
    private func resolvePlace(for fix: LocationFix) {
        Task { [weak self] in
            guard let name = await Self.placeName(for: fix.clLocation) else { return }
            guard let self, var current = self.state.fix, current.place == nil else { return }
            current.place = name
            Self.cache(current)
            self.state = .ready(current)
        }
    }

    /// The design's line is a town and a state — "Towson, Maryland" (dc:707).
    ///
    /// It deliberately does **not** use MapKit's `MKReverseGeocodingRequest`, the tvOS 26
    /// replacement for CLGeocoder. That API returns an `MKAddress` carrying only two opaque
    /// strings, `fullAddress` and `shortAddress`, with no town or state field of its own
    /// (MKAddress.h:20-21) — and on the owner's Apple TV `shortAddress` came back as the
    /// **street address of the house** (measured in Pass 13). A street address is not what the
    /// design asks for and not something to put on a television, so the place name is read
    /// from `CLPlacemark`'s structured `locality` and `administrativeArea` instead. Those are
    /// the only two fields used; nothing finer-grained than a town is ever displayed.
    private static func placeName(for location: CLLocation) async -> String? {
        await townAndState(for: location)
    }

    /// CLGeocoder is deprecated at tvOS 26.0, but its replacement cannot answer this question
    /// (above) and the app's deployment target is tvOS 18.0 in any case.
    @available(tvOS, deprecated: 26.0)
    private static func townAndState(for location: CLLocation) async -> String? {
        let marks: [CLPlacemark]
        do {
            marks = try await CLGeocoder().reverseGeocodeLocation(location)
        } catch {
            print("[weather] reverse geocoding failed: \(error)")
            return nil
        }
        guard let mark = marks.first else {
            print("[weather] reverse geocoding returned no placemark")
            return nil
        }
        let town = mark.locality ?? mark.subAdministrativeArea
        let state = mark.administrativeArea
        switch (town, state) {
        case let (town?, state?): return "\(town), \(state)"
        case let (town?, nil): return town
        case let (nil, state?): return state
        default:
            // No town and no state: the header shows the coordinates rather than a street.
            print("[weather] reverse geocoding: placemark had no locality and no administrative area")
            return nil
        }
    }
}
