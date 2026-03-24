import SwiftUI

/// Categorizes a specter's threat level into operational bands.
enum ThreatLevel: Equatable {
    /// Threat level 1 — minimal paranormal activity detected.
    case dormant
    /// Threat levels 2–3 — consistent measurable activity.
    case active
    /// Threat levels 4–5 — dangerous / unpredictable manifestation.
    case volatile
    /// Threat level could not be determined.
    case unknown

    /// Maps a raw 1-5 integer threat level to a ``ThreatLevel`` band.
    static func from(level: Int) -> ThreatLevel {
        switch level {
        case 1:     .dormant
        case 2...3: .active
        case 4...5: .volatile
        default:    .unknown
        }
    }

    /// Display label used in the scanner UI.
    var label: String {
        switch self {
        case .dormant:  "DORMANT"
        case .active:   "ACTIVE"
        case .volatile: "VOLATILE"
        case .unknown:  "UNKNOWN"
        }
    }

    /// Semantic color for threat-level badges and indicators.
    var color: Color {
        switch self {
        case .dormant:  Color.green
        case .active:   Color.orange
        case .volatile: Color.red
        case .unknown:  Color.gray
        }
    }
}
