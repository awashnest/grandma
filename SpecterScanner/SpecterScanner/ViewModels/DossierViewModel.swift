import Foundation
import Observation

/// Manages the "dossier" — the full collection of known doll profiles and
/// which ones the player has personally discovered through scanning.
///
/// This is the canonical view model for dossier/case-file screens.
/// It loads profiles from ``DollProfiles.json`` and persists discovery
/// state to ``UserDefaults``.
@Observable
final class DossierViewModel {

    // MARK: - State

    /// Master catalog of all doll profiles loaded from the JSON database.
    private(set) var allProfiles: [DollProfile] = []

    /// IDs of dolls the player has discovered via scanning.
    private(set) var discoveredDollIds: Set<String> = []

    // MARK: - Aliases for existing view compatibility

    /// Alias used by CaseFileView and other existing views.
    var allDolls: [DollProfile] { allProfiles }

    /// Alias used by CaseFileView.
    var discoveredIDs: Set<String> {
        get { discoveredDollIds }
        set { discoveredDollIds = newValue }
    }

    /// Discovered doll objects.
    var discoveredDolls: [DollProfile] {
        allProfiles.filter { discoveredDollIds.contains($0.id) }
    }

    /// Undiscovered doll objects.
    var undiscoveredDolls: [DollProfile] {
        allProfiles.filter { !discoveredDollIds.contains($0.id) }
    }

    // MARK: - UserDefaults Keys

    private let discoveredIdsKey = "discoveredDollIds"
    private let discoveryTimestampsKey = "discoveryTimestamps"
    private let discoveryImagesKey = "discoveryImages"

    // MARK: - Init

    init() {
        loadProfiles()
        loadDiscoveries()
    }

    // MARK: - Computed Properties

    /// Number of dolls the player has discovered so far.
    var discoveredCount: Int {
        discoveredDollIds.count
    }

    /// Total number of known doll profiles in the database.
    var totalCount: Int {
        allProfiles.count
    }

    /// Fraction of the dossier that has been unlocked (0.0 - 1.0).
    var completionFraction: Double {
        guard !allProfiles.isEmpty else { return 0 }
        return Double(discoveredCount) / Double(totalCount)
    }

    // MARK: - Queries

    /// Returns `true` when the given doll has been scanned at least once.
    func isDiscovered(_ dollId: String) -> Bool {
        discoveredDollIds.contains(dollId)
    }

    /// Looks up a full profile by its identifier.
    func profileFor(_ dollId: String) -> DollProfile? {
        allProfiles.first { $0.id == dollId }
    }

    /// Returns the stored discovery timestamp for a doll, if any.
    func discoveryDate(for dollId: String) -> Date? {
        guard let dict = UserDefaults.standard.dictionary(forKey: discoveryTimestampsKey) as? [String: Double],
              let interval = dict[dollId] else {
            return nil
        }
        return Date(timeIntervalSince1970: interval)
    }

    /// Returns stored captured image data for a discovered doll, if any.
    func capturedImageData(for dollId: String) -> Data? {
        guard let dict = UserDefaults.standard.dictionary(forKey: discoveryImagesKey) as? [String: Data] else {
            return nil
        }
        return dict[dollId]
    }

    // MARK: - Mutations

    /// Marks a doll as discovered, optionally storing a captured image.
    func markDiscovered(dollId: String, imageData: Data? = nil) {
        discoveredDollIds.insert(dollId)
        saveDiscoveredIds()

        // Save timestamp (only the first discovery)
        var timestamps = (UserDefaults.standard.dictionary(forKey: discoveryTimestampsKey) as? [String: Double]) ?? [:]
        if timestamps[dollId] == nil {
            timestamps[dollId] = Date.now.timeIntervalSince1970
            UserDefaults.standard.set(timestamps, forKey: discoveryTimestampsKey)
        }

        // Save image data if provided
        if let imageData {
            var images = (UserDefaults.standard.dictionary(forKey: discoveryImagesKey) as? [String: Data]) ?? [:]
            images[dollId] = imageData
            UserDefaults.standard.set(images, forKey: discoveryImagesKey)
        }
    }

    /// Compatibility wrapper used by existing code: `markDiscovered(_ id:)`.
    func markDiscovered(_ id: String) {
        markDiscovered(dollId: id)
    }

    /// Removes all discovery progress for a fresh start.
    func resetAllDiscoveries() {
        discoveredDollIds.removeAll()
        UserDefaults.standard.removeObject(forKey: discoveredIdsKey)
        UserDefaults.standard.removeObject(forKey: discoveryTimestampsKey)
        UserDefaults.standard.removeObject(forKey: discoveryImagesKey)
        // Also clear the legacy key used by some views
        UserDefaults.standard.removeObject(forKey: "discoveredDollIDs")
    }

    /// Compatibility alias.
    func resetDiscoveries() {
        resetAllDiscoveries()
    }

    // MARK: - Persistence Helpers

    private func loadProfiles() {
        guard let url = Bundle.main.url(forResource: "DollProfiles", withExtension: "json") else {
            print("[DossierViewModel] DollProfiles.json not found in bundle.")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            allProfiles = try JSONDecoder().decode([DollProfile].self, from: data)
        } catch {
            print("[DossierViewModel] Failed to decode DollProfiles.json: \(error.localizedDescription)")
        }
    }

    private func loadDiscoveries() {
        // Check both keys for backward compatibility
        let ids1 = UserDefaults.standard.stringArray(forKey: discoveredIdsKey) ?? []
        let ids2 = UserDefaults.standard.stringArray(forKey: "discoveredDollIDs") ?? []
        discoveredDollIds = Set(ids1).union(Set(ids2))
    }

    private func saveDiscoveredIds() {
        let array = Array(discoveredDollIds)
        UserDefaults.standard.set(array, forKey: discoveredIdsKey)
        // Also save to the legacy key for compatibility
        UserDefaults.standard.set(array, forKey: "discoveredDollIDs")
    }
}
