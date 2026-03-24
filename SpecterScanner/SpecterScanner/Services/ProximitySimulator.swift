import Foundation
import Combine

/// Generates simulated EMF / proximity readings for the Specter Scanner UI.
/// In ambient mode values fluctuate gently; in detection mode they spike dramatically.
@Observable
final class ProximitySimulator {

    // MARK: - Published Readings

    /// Simulated EMF level in 0.0 … 1.0.
    private(set) var emfLevel: Double = 0.15

    /// Simulated waveform amplitude in 0.0 … 1.0.
    private(set) var waveformAmplitude: Double = 0.05

    // MARK: - State

    private(set) var isDetectionMode: Bool = false
    private(set) var isRunning: Bool = false

    // MARK: - Private

    private var timer: Timer?
    private let updateRate: TimeInterval = 1.0 / 20.0 // ~20 Hz

    // Smoothing / noise state
    private var emfTarget: Double = 0.15
    private var waveTarget: Double = 0.05
    private var phase: Double = 0.0

    // MARK: - Init / Deinit

    init() {}

    deinit {
        stop()
    }

    // MARK: - Public API

    /// Begin generating simulated readings at ~20 Hz.
    func start() {
        guard !isRunning else { return }
        isRunning = true

        timer = Timer.scheduledTimer(withTimeInterval: updateRate, repeats: true) { [weak self] _ in
            self?.tick()
        }
        // Make sure it runs during scrolling / tracking
        if let timer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }

    /// Stop generating readings.
    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    /// Switch between ambient and detection modes.
    /// - Parameter active: `true` to enter detection mode, `false` to return to ambient.
    func setDetectionMode(_ active: Bool) {
        isDetectionMode = active

        if active {
            emfTarget = Double.random(in: 0.80...1.0)
            waveTarget = Double.random(in: 0.70...1.0)
        } else {
            emfTarget = Double.random(in: 0.10...0.30)
            waveTarget = Double.random(in: 0.03...0.12)
        }
    }

    // MARK: - Simulation Tick

    private func tick() {
        phase += updateRate

        if isDetectionMode {
            // Chaotic: frequently shift targets and add noise
            if Double.random(in: 0...1) < 0.25 {
                emfTarget = Double.random(in: 0.70...1.0)
            }
            if Double.random(in: 0...1) < 0.30 {
                waveTarget = Double.random(in: 0.50...1.0)
            }

            // Add high-frequency jitter
            let emfNoise = Double.random(in: -0.08...0.08)
            let waveNoise = Double.random(in: -0.12...0.12)

            emfLevel = lerp(emfLevel, emfTarget + emfNoise, t: 0.18)
            waveformAmplitude = lerp(waveformAmplitude, waveTarget + waveNoise, t: 0.22)

        } else {
            // Ambient: gentle drift
            if Double.random(in: 0...1) < 0.05 {
                emfTarget = Double.random(in: 0.10...0.30)
            }
            if Double.random(in: 0...1) < 0.04 {
                waveTarget = Double.random(in: 0.02...0.10)
            }

            // Slow sine wobble layered on top
            let wobble = sin(phase * 2.0 * .pi * 0.3) * 0.03
            emfLevel = lerp(emfLevel, emfTarget + wobble, t: 0.06)
            waveformAmplitude = lerp(waveformAmplitude, waveTarget, t: 0.05)
        }

        // Clamp to valid range
        emfLevel = emfLevel.clamped(to: 0.0...1.0)
        waveformAmplitude = waveformAmplitude.clamped(to: 0.0...1.0)
    }

    // MARK: - Math Helpers

    private func lerp(_ a: Double, _ b: Double, t: Double) -> Double {
        a + (b - a) * t
    }
}

// MARK: - Comparable Clamping

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
