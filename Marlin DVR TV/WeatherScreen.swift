//
//  WeatherScreen.swift
//  Marlin DVR TV
//
//  Pass 13 step 4: the Weather screen, frame 5f (dc:690-762). Every field is drawn where the
//  design puts it, at the size and colour it names, and every value comes from WeatherKit —
//  nothing on this screen is fabricated and nothing comes from the DVR (dc:693).
//
//  Top to bottom, with the design's line for each:
//    the title "Weather" (dc:706) and "Towson, Maryland · updated 2:38 PM" (dc:707)
//    "From this Apple TV's location, not the server", right-aligned (dc:709)
//    the condition glyph, 104 pt accent-200 (dc:714)
//    "81°" at 112 pt light (dc:716), "Partly cloudy · feels like 84°" (dc:717)
//    "H 83° · L 66° · humidity 62% · wind 8 mph SW" (dc:718)
//    the alert card (dc:721-727)
//    8 hourly columns between two dividers (dc:730-739)
//    5 daily rows with the high/low range bar (dc:741-753)
//    the Apple Weather attribution footer (dc:754-758)
//
//  The one thing frame 5f does not draw is a way into the radar, which the owner added to the
//  approved design in Pass 13; it is the single control in the header row, left of the
//  source note, built to the app's look (the same route as Manage DVR and Favorites).
//

import SwiftUI
import WeatherKit

struct WeatherScreen: View {
    let model: WeatherModel
    let onLeave: () -> Void
    @State private var showRadar = false
    @FocusState private var focused: WeatherFocus?

    private enum WeatherFocus: Hashable {
        case radar
        case day(Int)
        case message
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            content
        }
        .task {
            model.load()
            // Home shares this model, so by the time this screen opens the read has usually
            // already landed and `onChange` below never fires. Without this the content never
            // takes focus and the remote is left in the rail — seen on the Apple TV in Pass 22,
            // the first run with data on the screen. Frame 5f draws the ring on the first
            // daily row (dc:1402-1403), so that is where it goes.
            if model.phase == .ready { focusSoon { focused = .day(0) } }
        }
        .onChange(of: model.phase) { _, phase in
            if phase == .ready { focusSoon { focused = .day(0) } }
        }
        .onExitCommand { onLeave() }
        .fullScreenCover(isPresented: $showRadar) {
            RadarScreen(fix: model.location.state.fix, place: placeLabel) { showRadar = false }
                .interactiveDismissDisabled(true)
        }
    }

    // MARK: Header (dc:704-710)

    /// "Towson, Maryland" when the name resolved, the coordinates when it did not, and
    /// nothing at all before there is a fix.
    private var placeLabel: String? {
        if let place = model.place { return place }
        if let fix = model.location.state.fix { return WeatherFormat.coordinates(fix) }
        return nil
    }

    /// "Towson, Maryland · updated 2:38 PM" (dc:707)
    private var placeAndUpdated: String? {
        let updated = model.updatedAt.map { "updated \(WeatherFormat.updated($0))" }
        switch (placeLabel, updated) {
        case let (place?, updated?): return "\(place) · \(updated)"
        case let (place?, nil): return place
        case let (nil, updated?): return updated
        default: return nil
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 28) {
            Text("Weather")
                .font(.nocturne(Nocturne.TextSize.screenTitle, .medium))
                .tracking(-0.01 * Nocturne.TextSize.screenTitle)
                .foregroundStyle(Nocturne.text)
            if let placeAndUpdated {
                Text(placeAndUpdated)
                    .font(.nocturne(Nocturne.TextSize.secondary))
                    .foregroundStyle(Nocturne.neutral500)
            }
            Spacer(minLength: 20)
            Button {
                showRadar = true
            } label: {
                InertActionButton(title: "Radar", primary: false, focused: focused == .radar, size: Nocturne.TextSize.secondary)
            }
            .buttonStyle(BareButtonStyle())
            .focused($focused, equals: .radar)
            Text("From this Apple TV's location, not the server")
                .font(.nocturne(Nocturne.TextSize.floor))
                .foregroundStyle(Nocturne.neutral600)
                .fixedSize()
        }
        // Without this the remote cannot get from the content up to Radar: the button sits at
        // the right-hand end of the header and the content below it is left-aligned, so the
        // focus engine finds nothing overlapping above. The same fix the episode list needed
        // in Pass 8.
        .focusSection()
    }

    // MARK: Body

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .idle, .locating:
            message("Finding this Apple TV's location…", detail: "tvOS asks once, and the answer is kept so it is not asked again.")
        case .loading:
            message("Asking Apple Weather…", detail: nil)
        case .noLocation(let sentence):
            message("No location, so no weather.", detail: sentence, retry: true)
        case .failed(let detail):
            message("Apple Weather did not answer.", detail: detail, retry: true)
        case .ready:
            forecast
        }
    }

    /// Never a blank panel: each stopped state prints what happened and offers another go.
    private func message(_ title: String, detail: String?, retry: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.nocturne(Nocturne.TextSize.cardTitle, .medium))
                .foregroundStyle(Nocturne.text)
            if let detail {
                Text(detail)
                    .font(.nocturne(Nocturne.TextSize.secondary))
                    .foregroundStyle(Nocturne.neutral500)
                    .frame(maxWidth: 1200, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if retry {
                Button {
                    model.retry()
                } label: {
                    InertActionButton(title: "Try again", primary: false, focused: focused == .message)
                }
                .buttonStyle(BareButtonStyle())
                .focused($focused, equals: .message)
                .padding(.top, 8)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { if retry { focusSoon { focused = .message } } }
    }

    private var forecast: some View {
        VStack(alignment: .leading, spacing: 0) {
            currentAndAlert
                .padding(.bottom, 28)
            hourlyStrip
                .padding(.bottom, 20)
            dailyList
            Spacer(minLength: 0)
            attribution
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: Current conditions + alert (dc:712-728)

    private var currentAndAlert: some View {
        HStack(alignment: .top, spacing: 56) {
            if let current = model.weather?.currentWeather {
                HStack(spacing: 34) {
                    Image(systemName: current.symbolName)
                        .font(.nocturne(104))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Nocturne.accent200)
                        .frame(width: 130)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(WeatherFormat.degrees(current.temperature))
                            .font(.nocturne(112, .light))
                            .tracking(-0.03 * 112)
                            .foregroundStyle(Nocturne.text)
                        Text("\(WeatherFormat.condition(current.condition)) · feels like \(WeatherFormat.degrees(current.apparentTemperature))")
                            .font(.nocturne(Nocturne.TextSize.cardTitle))
                            .foregroundStyle(Nocturne.neutral300)
                        Text(detailLine(current))
                            .font(.nocturne(Nocturne.TextSize.secondary))
                            .foregroundStyle(Nocturne.neutral500)
                    }
                }
                // The alert card is the flexible half of this row (`flex:1; min-width:0`,
                // dc:721) and the current block is not, so it takes its natural width first.
                // Without this SwiftUI proposes half the row to each and the detail line is
                // cut — "wind 5 mph N…" on the Apple TV in Pass 22.
                .layoutPriority(1)
            }
            alertCard
        }
    }

    /// "H 83° · L 66° · humidity 62% · wind 8 mph SW" (dc:718). The high and low are today's
    /// from the daily forecast — `CurrentWeather` carries no range.
    private func detailLine(_ current: CurrentWeather) -> String {
        var parts: [String] = []
        if let today = model.today {
            parts.append("H \(WeatherFormat.degrees(today.highTemperature))")
            parts.append("L \(WeatherFormat.degrees(today.lowTemperature))")
        }
        parts.append("humidity \(WeatherFormat.percent(current.humidity))")
        parts.append("wind \(WeatherFormat.wind(current.wind))")
        return parts.joined(separator: " · ")
    }

    /// The single alert card of dc:721-727. WeatherKit's `WeatherAlert` has no long body —
    /// `summary`, `severity`, `source` and `region` are the whole of it — so the card's
    /// second line is those, and no sentence is written for it here.
    @ViewBuilder
    private var alertCard: some View {
        if let alert = model.alert {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.nocturne(Nocturne.TextSize.body))
                        .foregroundStyle(Color(hex: 0xD6A94E))
                    Text(alert.summary)
                        .font(.nocturne(Nocturne.TextSize.body))
                        .foregroundStyle(Nocturne.neutral100)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(alertDetail(alert))
                    .font(.nocturne(Nocturne.TextSize.secondary))
                    .foregroundStyle(Nocturne.neutral400)
                    .lineSpacing(Nocturne.TextSize.secondary * 0.4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 22)
            .padding(.horizontal, 26)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Nocturne.surface, in: RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous)
                    .strokeBorder(Nocturne.hairline, lineWidth: 1)
            }
        } else {
            // The card's slot is held so the current block stays where the design puts it.
            Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
        }
    }

    private func alertDetail(_ alert: WeatherAlert) -> String {
        var parts = [WeatherFormat.severity(alert.severity), alert.source]
        if let region = alert.region, !region.isEmpty { parts.append(region) }
        return parts.joined(separator: " · ")
    }

    // MARK: Hourly (dc:730-739)

    private var hourlyStrip: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Nocturne.divider).frame(height: 1)
            HStack(spacing: 16) {
                ForEach(model.hourly, id: \.date) { hour in
                    VStack(spacing: 10) {
                        Text(WeatherFormat.hourLabel(hour.date))
                            .font(.nocturne(Nocturne.TextSize.secondary))
                            .foregroundStyle(Nocturne.neutral400)
                        Image(systemName: hour.symbolName)
                            .font(.nocturne(44))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(Nocturne.neutral200)
                            .frame(height: 52)
                        Text(WeatherFormat.degrees(hour.temperature))
                            .font(.nocturne(Nocturne.TextSize.cardTitle))
                            .foregroundStyle(Nocturne.text)
                        // The design leaves this line blank when there is no chance of rain.
                        Text(WeatherFormat.chance(hour.precipitationChance) ?? " ")
                            .font(.nocturne(Nocturne.TextSize.floor))
                            .foregroundStyle(Nocturne.accent300)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 18)
            Rectangle().fill(Nocturne.divider).frame(height: 1)
        }
    }

    // MARK: Daily (dc:741-753)

    private var dailyList: some View {
        // The bar is positioned and sized against the whole list's min and max (dc:1396-1401).
        let lows = model.daily.map { $0.lowTemperature.converted(to: .fahrenheit).value }
        let highs = model.daily.map { $0.highTemperature.converted(to: .fahrenheit).value }
        let minimum = lows.min() ?? 0
        let maximum = highs.max() ?? 1
        let span = max(maximum - minimum, 1)

        return VStack(spacing: 0) {
            ForEach(Array(model.daily.enumerated()), id: \.element.date) { index, day in
                let low = day.lowTemperature.converted(to: .fahrenheit).value
                let high = day.highTemperature.converted(to: .fahrenheit).value
                DailyRow(
                    day: day,
                    barStart: (low - minimum) / span,
                    barWidth: (high - low) / span,
                    focused: focused == .day(index)
                )
                .focusable()
                .focused($focused, equals: .day(index))
            }
        }
        .focusSection()
    }

    // MARK: Attribution (dc:754-758)

    private var attribution: some View {
        HStack(spacing: 16) {
            Image(systemName: "apple.logo")
                .font(.nocturne(Nocturne.TextSize.secondary))
            Text(model.attribution?.serviceName ?? "Weather")
            Text("· data and attribution required by WeatherKit")
                .foregroundStyle(Nocturne.neutral600)
            if let legal = model.attribution?.legalPageURL {
                Text("· \(legal.host ?? legal.absoluteString)\(legal.path)")
                    .foregroundStyle(Nocturne.neutral600)
            }
        }
        .font(.nocturne(Nocturne.TextSize.floor))
        .foregroundStyle(Nocturne.neutral500)
        .padding(.top, 18)
    }
}

/// One daily row (dc:743-752): day name in a 240 pt column, glyph, chance of rain, the low,
/// the high/low range bar, the high. Focused draws the design's ring, tint and shadow —
/// frame 5f draws exactly that on the first row (dc:1402-1403).
struct DailyRow: View {
    let day: DayWeather
    let barStart: Double
    let barWidth: Double
    let focused: Bool

    var body: some View {
        HStack(spacing: 28) {
            Text(WeatherFormat.dayLabel(day.date))
                .font(.nocturne(Nocturne.TextSize.body))
                .foregroundStyle(Nocturne.neutral200)
                .frame(width: 240, alignment: .leading)
            Image(systemName: day.symbolName)
                .font(.nocturne(34))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Nocturne.neutral300)
                .frame(width: 44)
            Text(WeatherFormat.chance(day.precipitationChance) ?? "")
                .font(.nocturne(Nocturne.TextSize.floor))
                .foregroundStyle(Nocturne.accent300)
                .frame(width: 80, alignment: .leading)
            Text(WeatherFormat.degrees(day.lowTemperature))
                .font(.nocturne(Nocturne.TextSize.body))
                .foregroundStyle(Nocturne.neutral500)
                .frame(width: 80, alignment: .trailing)
            rangeBar
            Text(WeatherFormat.degrees(day.highTemperature))
                .font(.nocturne(Nocturne.TextSize.body))
                .foregroundStyle(Nocturne.text)
                .frame(width: 80, alignment: .leading)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 20)
        .background(
            focused ? Nocturne.accent.opacity(0.10) : .clear,
            in: RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous)
        )
        .overlay(alignment: .bottom) {
            Rectangle().fill(Nocturne.divider).frame(height: 1)
        }
        .focusTreatment(focused)
    }

    /// The 8 pt track with an accent-600 → accent-300 fill spanning this day's low to high
    /// within the whole list's range (dc:748-750).
    private var rangeBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Nocturne.neutral900)
                Capsule()
                    .fill(LinearGradient(colors: [Nocturne.accent600, Nocturne.accent300], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(geo.size.width * barWidth, 8))
                    .offset(x: geo.size.width * barStart)
            }
        }
        .frame(height: 8)
        .frame(maxWidth: .infinity)
    }
}
