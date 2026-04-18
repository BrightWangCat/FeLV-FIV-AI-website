import Foundation

extension String {
    /// Formats an ISO 8601 date string for display (e.g. "Mar 31, 2026, 2:30 PM").
    var formattedDate: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatter.date(from: self) {
            return date.formatted(date: .abbreviated, time: .shortened)
        }

        // Retry without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: self) {
            return date.formatted(date: .abbreviated, time: .shortened)
        }

        return self
    }
}
