import Foundation

/// Classifies the behavioral pattern of a detected specter.
enum HauntingType: String, Codable, CaseIterable, Identifiable {
    case whisperer
    case watcher
    case mover
    case weeper
    case mimic
    case trickster

    var id: String { rawValue }

    /// Human-readable label for UI display.
    var displayName: String {
        switch self {
        case .whisperer: "Whisperer"
        case .watcher:   "Watcher"
        case .mover:     "Mover"
        case .weeper:    "Weeper"
        case .mimic:     "Mimic"
        case .trickster: "Trickster"
        }
    }

    /// SF Symbol name representing this haunting type.
    var icon: String {
        switch self {
        case .whisperer: "waveform"
        case .watcher:   "eye.fill"
        case .mover:     "arrow.triangle.swap"
        case .weeper:    "drop.fill"
        case .mimic:     "person.2.fill"
        case .trickster: "theatermasks.fill"
        }
    }

    /// Brief field-guide description of the haunting behavior.
    var description: String {
        switch self {
        case .whisperer:
            "Communicates through faint sounds at the edge of hearing — static bursts, half-formed words, and frequency anomalies."
        case .watcher:
            "Remains motionless but radiates an overwhelming sense of being observed. EMF readings spike when your back is turned."
        case .mover:
            "Displaces small objects. Items found in wrong rooms, drawers left open, furniture shifted inches from its original position."
        case .weeper:
            "Manifests moisture anomalies — fogged glass, unexplained condensation, and cold spots accompanied by faint sobbing."
        case .mimic:
            "Copies voices, footsteps, and familiar sounds. Often heard calling names from empty rooms."
        case .trickster:
            "Causes electronics to malfunction, lights to flicker, and devices to activate on their own. Feeds on confusion."
        }
    }
}
