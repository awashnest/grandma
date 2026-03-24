import Foundation

/// A complete dossier for a single detected specter / haunted doll.
struct DollProfile: Codable, Identifiable {

    // MARK: - Persisted Properties

    /// Unique identifier for this doll profile (e.g. "SPEC-0042").
    let id: String

    /// Short classification tag shown in scan results (e.g. "Class-IV Apparition").
    var classificationLabel: String

    /// The specter's known or assigned name.
    var name: String

    /// Behavioral haunting category.
    var hauntingType: HauntingType

    /// Numeric threat level on a 1–5 scale.
    var threatLevel: Int {
        didSet { threatLevel = min(max(threatLevel, 1), 5) }
    }

    /// Narrative background — where and how this specter was first encountered.
    var originStory: String

    /// Timestamped log entries of observed paranormal activity.
    var documentedActivity: [String]

    /// Current operational status (e.g. "Contained", "At Large", "Dormant").
    var status: String

    // MARK: - Runtime State (excluded from Codable when nil)

    /// JPEG/PNG data captured by the device camera during a scan session.
    var capturedImageData: Data?

    /// Timestamp of the very first detection event for this specter.
    var firstDetected: Date?

    // MARK: - Computed Properties

    /// Human-readable description of the current threat level.
    var threatLevelDescription: String {
        let band = ThreatLevel.from(level: threatLevel)
        switch band {
        case .dormant:
            return "Level \(threatLevel) — Dormant. Minimal risk; safe for observation."
        case .active:
            return "Level \(threatLevel) — Active. Exercise caution; maintain safe distance."
        case .volatile:
            return "Level \(threatLevel) — Volatile! Immediate containment recommended."
        case .unknown:
            return "Level \(threatLevel) — Unknown. Threat assessment inconclusive."
        }
    }

    /// The ``ThreatLevel`` band derived from the raw integer.
    var threatBand: ThreatLevel {
        ThreatLevel.from(level: threatLevel)
    }
}

// MARK: - Sample Data

extension DollProfile {
    /// A prefabricated profile useful for SwiftUI previews and testing.
    static let sample = DollProfile(
        id: "SPEC-0001",
        classificationLabel: "Class-II Poltergeist",
        name: "Marguerite",
        hauntingType: .mover,
        threatLevel: 3,
        originStory: "Recovered from a sealed attic trunk in Savannah, GA. Previous owner reported nightly furniture rearrangement.",
        documentedActivity: [
            "2025-10-31 23:14 — Rocking chair moved 12 inches.",
            "2025-11-02 03:30 — Kitchen cabinet doors found open.",
            "2025-11-05 01:15 — EMF spike registered at 4.7 mG."
        ],
        status: "Under Observation",
        capturedImageData: nil,
        firstDetected: Date(timeIntervalSince1970: 1_730_419_200)
    )
}
