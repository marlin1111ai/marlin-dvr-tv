//
//  HomeWeatherGlance.swift
//  Marlin DVR TV
//
//  Pass 13 step 5: the Home weather glance card, frame 2a (dc:133-143). DECISIONS.md
//  2026-09-05 (sweep 1) parked it — "The Home weather glance is omitted until Weather is
//  built" — and Pass 5 held its 520 pt slot open (HomeView, the `Color.clear` spacer) so the
//  clock would sit where the design puts it. Weather is built now, so the card fills that slot.
//
//  The design's four lines, and where each value comes from:
//    the condition glyph, 58 pt neutral-300           CurrentWeather.symbolName    dc:134
//    "72°"  52 pt medium · "Clear" 29 pt neutral-300  temperature, condition       dc:137-138
//    "H 78° · L 58° · 10% rain today"  23 pt          today's high/low, daily pop  dc:140
//    "Feels 72° · humidity 54% · Apple WeatherKit"    apparentTemperature,         dc:141
//                                                     humidity, attribution
//
//  Same `WeatherModel` as the Weather screen, so Home does not ask WeatherKit a second time
//  and the location prompt still happens once.
//

import SwiftUI
import WeatherKit

struct HomeWeatherGlance: View {
    let model: WeatherModel

    /// Frame 2a's card is exactly 520 pt wide (dc:133).
    static let width: CGFloat = 520

    var body: some View {
        Group {
            if let current = model.weather?.currentWeather {
                HStack(spacing: 26) {
                    Image(systemName: current.symbolName)
                        .font(.nocturne(58))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Nocturne.neutral300)
                        // The design's glyph is 58 pt and reserves no box (dc:134); the frame
                        // only keeps the text column from moving as the symbol changes. It was
                        // 72, and those 14 pt were 14 the fourth line did not have — see below.
                        .frame(width: 58)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 14) {
                            Text(WeatherFormat.degrees(current.temperature))
                                .font(.nocturne(Nocturne.TextSize.screenTitle, .medium))
                                .tracking(-0.02 * Nocturne.TextSize.screenTitle)
                                .foregroundStyle(Nocturne.text)
                            Text(WeatherFormat.condition(current.condition))
                                .font(.nocturne(Nocturne.TextSize.body))
                                .foregroundStyle(Nocturne.neutral300)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        Text(todayLine)
                            .font(.nocturne(Nocturne.TextSize.floor))
                            .foregroundStyle(Nocturne.neutral400)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text(detailLine(current))
                            .font(.nocturne(Nocturne.TextSize.floor))
                            .foregroundStyle(Nocturne.neutral600)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    // The text column takes its width first and the spacer keeps whatever is
                    // left, which is what the design's flex row does (the column is the last
                    // child, dc:135). Without this SwiftUI splits the row between the column
                    // and the spacer and the fourth line is cut — "Apple Weat…" on the Apple
                    // TV in Pass 22, the first run with data in this card.
                    .layoutPriority(1)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 24)
                .padding(.horizontal, 30)
                .background(Nocturne.surface, in: RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Nocturne.Radius.md, style: .continuous)
                        .strokeBorder(Nocturne.hairline, lineWidth: 1)
                }
            } else {
                // Before the fix and the read land — and if they never do — the slot keeps the
                // clock in place and says one short thing rather than showing a made-up number.
                Text(waitingLine)
                    .font(.nocturne(Nocturne.TextSize.floor))
                    .foregroundStyle(Nocturne.neutral600)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .frame(width: Self.width, alignment: .trailing)
        .task { model.load() }
    }

    /// "H 78° · L 58° · 10% rain today" (dc:140)
    private var todayLine: String {
        guard let today = model.today else { return "" }
        var parts = ["H \(WeatherFormat.degrees(today.highTemperature))", "L \(WeatherFormat.degrees(today.lowTemperature))"]
        if let chance = WeatherFormat.chance(today.precipitationChance) {
            parts.append("\(chance) rain today")
        }
        return parts.joined(separator: " · ")
    }

    /// "Feels 72° · humidity 54% · Apple WeatherKit" (dc:141)
    ///
    /// The service name is printed as WeatherKit gives it. It hands back "Apple Weather", and
    /// prefixing a word "Apple" of our own made the line read "Apple Apple Weather" — seen on
    /// the Apple TV in Pass 22, the first run with data in this card.
    private func detailLine(_ current: CurrentWeather) -> String {
        let service = model.attribution?.serviceName ?? "Apple Weather"
        return "Feels \(WeatherFormat.degrees(current.apparentTemperature)) · humidity \(WeatherFormat.percent(current.humidity)) · \(service)"
    }

    private var waitingLine: String {
        switch model.phase {
        case .idle, .locating: return "Finding this Apple TV's location…"
        case .loading: return "Asking Apple Weather…"
        case .noLocation: return "Weather needs this Apple TV's location — open Weather"
        case .failed: return "Apple Weather did not answer — open Weather"
        case .ready: return ""
        }
    }
}
