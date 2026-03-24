import Foundation
import CoreHaptics

/// Manages Core Haptics patterns for the Specter Scanner experience.
/// Provides reusable ghost-themed haptic patterns.
@Observable
final class HapticsService {

    // MARK: - State

    private(set) var isEngineRunning: Bool = false
    private(set) var supportsHaptics: Bool = false

    // MARK: - Private

    private var engine: CHHapticEngine?

    // MARK: - Init

    init() {
        supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        if !supportsHaptics {
            print("[HapticsService] ⚠️ Device does not support Core Haptics.")
        }
    }

    deinit {
        stopEngine()
    }

    // MARK: - Engine Management

    /// Creates and starts the haptic engine.
    func startEngine() {
        guard supportsHaptics else { return }
        guard engine == nil else { return }

        do {
            let eng = try CHHapticEngine()

            eng.stoppedHandler = { [weak self] reason in
                print("[HapticsService] Engine stopped: \(reason.rawValue)")
                DispatchQueue.main.async { self?.isEngineRunning = false }
            }

            eng.resetHandler = { [weak self] in
                print("[HapticsService] Engine reset – restarting.")
                do {
                    try self?.engine?.start()
                    DispatchQueue.main.async { self?.isEngineRunning = true }
                } catch {
                    print("[HapticsService] Failed to restart engine: \(error.localizedDescription)")
                }
            }

            try eng.start()
            self.engine = eng
            isEngineRunning = true
        } catch {
            print("[HapticsService] ⚠️ Could not create haptic engine: \(error.localizedDescription)")
        }
    }

    /// Stops and tears down the haptic engine.
    func stopEngine() {
        engine?.stop(completionHandler: { _ in })
        engine = nil
        isEngineRunning = false
    }

    // MARK: - Patterns

    /// Single soft tap – use for ambient background pulsing.
    func ambientPulse() {
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.25)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.15)
        let event = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [intensity, sharpness],
            relativeTime: 0
        )
        playPattern(events: [event])
    }

    /// Increasing-intensity taps that get faster – proximity escalation.
    func proximityEscalation() {
        var events: [CHHapticEvent] = []
        let tapCount = 8
        var time: TimeInterval = 0

        for i in 0..<tapCount {
            let progress = Float(i) / Float(tapCount - 1) // 0…1
            let intensityVal = 0.2 + 0.8 * progress
            let sharpnessVal = 0.1 + 0.6 * progress
            let gap = 0.35 - 0.25 * Double(progress) // gaps shrink from 0.35s to 0.10s

            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensityVal)
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpnessVal)
            let event = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [intensity, sharpness],
                relativeTime: time
            )
            events.append(event)
            time += gap
        }

        playPattern(events: events)
    }

    /// Sharp double-tap followed by a sustained 1-second buzz – detection confirmed.
    func detectionBurst() {
        var events: [CHHapticEvent] = []

        // First tap
        events.append(CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
            ],
            relativeTime: 0
        ))

        // Second tap
        events.append(CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
            ],
            relativeTime: 0.1
        ))

        // Sustained buzz – 1 second
        events.append(CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.7),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3)
            ],
            relativeTime: 0.25,
            duration: 1.0
        ))

        playPattern(events: events)
    }

    /// Very light flutter – spooky EVP whisper feel.
    func evpWhisper() {
        var events: [CHHapticEvent] = []
        let flickerCount = 12
        var time: TimeInterval = 0

        for _ in 0..<flickerCount {
            let intensityVal = Float.random(in: 0.05...0.20)
            let sharpnessVal = Float.random(in: 0.02...0.10)

            events.append(CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensityVal),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpnessVal)
                ],
                relativeTime: time
            ))

            time += Double.random(in: 0.03...0.10)
        }

        playPattern(events: events)
    }

    // MARK: - Playback Helper

    private func playPattern(events: [CHHapticEvent]) {
        guard supportsHaptics, let engine else { return }

        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            print("[HapticsService] Failed to play pattern: \(error.localizedDescription)")
        }
    }
}
