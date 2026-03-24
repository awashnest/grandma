import Foundation
import Observation
import AVFoundation
import SwiftUI

// MARK: - ScannerViewModel

/// Drives the live scanner screen — camera, classification pipeline,
/// detection state, haptics, audio, and random micro-glitch effects.
@Observable
final class ScannerViewModel {

    // MARK: - Scanning State

    var isScanning: Bool = false
    var isDetectionActive: Bool = false
    var currentDetection: DollProfile?
    var showDetectionAlert: Bool = false
    var showCaseFile: Bool = false
    var isGlitching: Bool = false

    // MARK: - HUD Simulation Properties (consumed by ScannerView)

    /// Simulated EMF level 0.0 - 1.0, forwarded from ProximitySimulator.
    var emfLevel: Double = 0.3

    /// Simulated waveform sample buffer (0.0 - 1.0 amplitudes).
    var waveformSamples: [Double] = Array(repeating: 0.2, count: 40)

    /// Convenience alias used by ScannerView for the detected doll.
    var detectedDoll: DollProfile? {
        get { currentDetection }
        set { currentDetection = newValue }
    }

    // MARK: - Services

    let cameraService = AROverlayService()
    let classificationService = ClassificationService()
    let proximitySimulator = ProximitySimulator()
    let hapticsService = HapticsService()
    let audioService = AudioService()

    // MARK: - Private

    private var dollProfiles: [DollProfile] = []
    private var glitchTimer: Timer?
    private var frameObservationTask: Task<Void, Never>?

    private let discoveredKey = "discoveredDollIds"
    private let eventsKey = "detectionEvents"

    // MARK: - Init

    init() {
        loadProfiles()
        hapticsService.startEngine()
    }

    deinit {
        stopScanning()
    }

    // MARK: - Profile Loading

    private func loadProfiles() {
        guard let url = Bundle.main.url(forResource: "DollProfiles", withExtension: "json") else {
            print("[ScannerViewModel] DollProfiles.json not found in bundle.")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            dollProfiles = try JSONDecoder().decode([DollProfile].self, from: data)
            print("[ScannerViewModel] Loaded \(dollProfiles.count) doll profiles.")
        } catch {
            print("[ScannerViewModel] Failed to decode DollProfiles.json: \(error.localizedDescription)")
        }
    }

    // MARK: - Start / Stop

    func startScanning() {
        guard !isScanning else { return }
        isScanning = true

        cameraService.startSession()
        audioService.startAmbientDrone()
        proximitySimulator.start()

        startFrameProcessing()
        scheduleNextGlitch()
    }

    func stopScanning() {
        isScanning = false

        cameraService.stopSession()
        audioService.stopAmbientDrone()
        proximitySimulator.stop()
        hapticsService.stopEngine()

        frameObservationTask?.cancel()
        frameObservationTask = nil

        glitchTimer?.invalidate()
        glitchTimer = nil

        isGlitching = false
    }

    // MARK: - Simulation Tick (called by ScannerView timer)

    /// Updates the simulated EMF and waveform values for the HUD display.
    func tickSimulation() {
        if proximitySimulator.isRunning {
            emfLevel = proximitySimulator.emfLevel
            waveformSamples = waveformSamples.map { sample in
                let target = proximitySimulator.waveformAmplitude + Double.random(in: -0.08...0.08)
                return min(1.0, max(0.05, sample + (target - sample) * 0.3))
            }
        } else {
            emfLevel = min(1.0, max(0.0, emfLevel + Double.random(in: -0.08...0.08)))
            waveformSamples = waveformSamples.map { sample in
                min(1.0, max(0.05, sample + Double.random(in: -0.15...0.15)))
            }
        }
    }

    // MARK: - Frame Processing

    private func startFrameProcessing() {
        frameObservationTask?.cancel()
        frameObservationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            var lastProcessedFrame: CVPixelBuffer?

            while !Task.isCancelled && self.isScanning {
                try? await Task.sleep(for: .milliseconds(50))

                guard let frame = self.cameraService.currentFrame,
                      frame !== lastProcessedFrame else { continue }
                lastProcessedFrame = frame

                self.classificationService.classifyFrame(frame) { [weak self] label, confidence in
                    guard let self, let label, self.isScanning else { return }
                    self.handleClassification(label: label, confidence: confidence)
                }
            }
        }
    }

    // MARK: - Classification Handling

    private func handleClassification(label: String, confidence: Double) {
        guard !isDetectionActive else { return }

        guard let profile = dollProfiles.first(where: {
            $0.classificationLabel.lowercased() == label.lowercased()
        }) else {
            return
        }

        isDetectionActive = true
        currentDetection = profile
        showDetectionAlert = true

        hapticsService.detectionBurst()
        audioService.playDetectionSpike()
        proximitySimulator.setDetectionMode(true)

        saveDiscovery(profile: profile, confidence: confidence)
    }

    // MARK: - Discovery Persistence

    private func saveDiscovery(profile: DollProfile, confidence: Double) {
        var discovered = Set(UserDefaults.standard.stringArray(forKey: discoveredKey) ?? [])
        discovered.insert(profile.id)
        UserDefaults.standard.set(Array(discovered), forKey: discoveredKey)

        let event = DetectionEvent(dollId: profile.id, confidence: confidence)
        var events = loadEvents()
        events.append(event)
        if let encoded = try? JSONEncoder().encode(events) {
            UserDefaults.standard.set(encoded, forKey: eventsKey)
        }
    }

    private func loadEvents() -> [DetectionEvent] {
        guard let data = UserDefaults.standard.data(forKey: eventsKey) else { return [] }
        return (try? JSONDecoder().decode([DetectionEvent].self, from: data)) ?? []
    }

    // MARK: - Detection Dismissal

    func dismissDetection() {
        isDetectionActive = false
        currentDetection = nil
        showDetectionAlert = false
        showCaseFile = false
        proximitySimulator.setDetectionMode(false)
        classificationService.resetCooldown()
    }

    func openCaseFile() {
        showDetectionAlert = false
        showCaseFile = true
    }

    // MARK: - Micro-Glitch Effect

    private func scheduleNextGlitch() {
        let delay = Double.random(in: 15...45)
        glitchTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self, self.isScanning else { return }
            self.triggerGlitch()
        }
    }

    private func triggerGlitch() {
        isGlitching = true
        hapticsService.ambientPulse()

        let duration = Double.random(in: 0.2...0.6)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self else { return }
            self.isGlitching = false
            self.scheduleNextGlitch()
        }
    }
}
