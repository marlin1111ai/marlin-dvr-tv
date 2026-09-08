//
//  Formatting.swift
//  Marlin DVR TV
//
//  Time and size labels the screens derive themselves from unix seconds and byte counts
//  (the server's own labels are in the container's time zone — Pass 2 §5 item 6). Formats
//  follow the design's examples: "2:41 PM", "2:30 – 4:30 PM", "Fri Sep 5", "Sat · 12:00 AM".
//

import Foundation

enum TimeFormat {
    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = format
        return f
    }

    private static let clockFormatter = formatter("h:mm a")
    private static let clockNoMeridiem = formatter("h:mm")
    private static let meridiem = formatter("a")
    private static let shortDayFormatter = formatter("EEE MMM d")
    private static let weekdayFormatter = formatter("EEE")
    private static let longWeekdayFormatter = formatter("EEEE")

    static func date(_ unix: Int) -> Date { Date(timeIntervalSince1970: TimeInterval(unix)) }

    /// "2:41 PM"
    static func clock(_ date: Date) -> String { clockFormatter.string(from: date) }
    static func clock(unix: Int) -> String { clock(date(unix)) }

    /// "2:30 – 4:30 PM" (one meridiem when both ends share it), else "11:30 PM – 1:30 AM"
    static func timeRange(_ start: Int, _ end: Int) -> String {
        let s = date(start), e = date(end)
        if meridiem.string(from: s) == meridiem.string(from: e) {
            return "\(clockNoMeridiem.string(from: s)) – \(clockFormatter.string(from: e))"
        }
        return "\(clockFormatter.string(from: s)) – \(clockFormatter.string(from: e))"
    }

    /// "Fri Sep 5"
    static func shortDay(_ date: Date) -> String { shortDayFormatter.string(from: date) }

    /// "Sat"
    static func weekday(_ date: Date) -> String { weekdayFormatter.string(from: date) }

    /// "Today", "Tomorrow", or the weekday name
    static func relativeDay(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInTomorrow(date) { return "Tomorrow" }
        return longWeekdayFormatter.string(from: date)
    }

    static func sameDay(_ a: Date, _ b: Date) -> Bool { Calendar.current.isDate(a, inSameDayAs: b) }

    /// True at local midnight — the first slot of a new day in the guide header (frame 3c).
    static func isMidnight(unix: Int) -> Bool {
        let c = Calendar.current.dateComponents([.hour, .minute], from: date(unix))
        return c.hour == 0 && c.minute == 0
    }

    /// The current half hour, as the server truncates it (guide.go:599-604).
    static var currentHalfHour: Int { Int(Date().timeIntervalSince1970 / 1800) * 1800 }
}

enum SizeFormat {
    private static let bytesFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useMB, .useGB, .useTB]
        f.countStyle = .file
        return f
    }()

    /// "579.4 MB", "1.2 GB"
    static func bytes(_ count: Int) -> String { bytesFormatter.string(fromByteCount: Int64(count)) }

    /// The server's own `humanBytes` (system.go:120-131), reproduced: 1024-based, "%.0f" for
    /// bytes and KB and "%.2f" above that. `ByteCountFormatter` above is 1000-based, so the two
    /// disagree by 7% on a gigabyte. Used where the app formats a byte count the server would
    /// otherwise have labelled itself — the trash rows, whose listing carries no `sizeLabel` —
    /// so the same recording reads "1.86 GB" here and in the web UI (Pass 33 step 2).
    static func serverStyle(_ count: Int) -> String {
        let units = ["B", "KB", "MB", "GB", "TB", "PB"]
        var value = Double(count)
        var index = 0
        while value >= 1024 && index < units.count - 1 {
            value /= 1024
            index += 1
        }
        return String(format: index <= 1 ? "%.0f %@" : "%.2f %@", value, units[index])
    }
}

/// The RFC 3339 stamps the library hands out (`aired`, `trashedAt`). They carry the server's
/// UTC offset, so unlike its `dateLabel` strings they can be shown in this Apple TV's own time.
enum ServerTime {
    private static let internetDate: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// "2026-09-06T21:00:00-04:00", and Go's nanosecond form
    /// "2026-09-07T11:12:13.882484831-04:00" — which `ISO8601DateFormatter` will not take at
    /// any option, since it allows at most three fractional digits. The fraction is dropped
    /// and the rest parsed; a second is finer than any label here needs.
    static func date(_ text: String) -> Date? {
        if let date = internetDate.date(from: text) { return date }
        guard let dot = text.firstIndex(of: "."),
              let zone = text[text.index(after: dot)...].firstIndex(where: { $0 == "Z" || $0 == "+" || $0 == "-" })
        else { return nil }
        return internetDate.date(from: String(text[..<dot]) + String(text[zone...]))
    }
}

extension String {
    /// The duration the server appends to `airedLabel` only when the recording's probe is
    /// already cached (library.go:518-523; "today at 12:00 PM, 16 min"), in `humanMinutes`
    /// form (passes.go:301-313: "N sec", "N min", "N hr", "N hr M min"). Nil when absent.
    var cachedDurationSuffix: String? {
        guard let comma = range(of: ", ", options: .backwards) else { return nil }
        let tail = String(self[comma.upperBound...])
        let pattern = #"^\d+ (sec|min|hr)( \d+ min)?$"#
        return tail.range(of: pattern, options: .regularExpression) != nil ? tail : nil
    }
}
