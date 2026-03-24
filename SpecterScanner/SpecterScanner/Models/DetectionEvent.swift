import Foundation

/// Records a single point-in-time detection of a specter by the scanner.
struct DetectionEvent: Codable, Identifiable {
    /// Unique event identifier.
    let id: UUID

    /// The ``DollProfile/id`` of the specter that triggered this event.
    let dollId: String

    /// When the detection occurred.
    let timestamp: Date

    /// Scanner confidence in the detection, expressed as 0.0 (none) to 1.0 (certain).
    let confidence: Double

    /// Convenience initializer that auto-generates an `id` and uses the current time.
    init(
        id: UUID = UUID(),
        dollId: String,
        timestamp: Date = .now,
        confidence: Double
    ) {
        self.id = id
        self.dollId = dollId
        self.timestamp = timestamp
        self.confidence = min(max(confidence, 0), 1)
    }
}

// MARK: - Sample Data

extension DetectionEvent {
    static let sample = DetectionEvent(
        dollId: "SPEC-0001",
        confidence: 0.87
    )
}
