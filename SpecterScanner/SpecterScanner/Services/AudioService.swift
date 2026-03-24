import Foundation
import AVFoundation
import Combine

/// Programmatic audio service for the Specter Scanner experience.
/// Generates spooky ambient tones, detection spikes, static bursts,
/// and EVP whisper effects using AVAudioEngine.
@Observable
final class AudioService {

    // MARK: - Published State

    private(set) var isDronePlaying: Bool = false
    private(set) var isEngineRunning: Bool = false

    // MARK: - Audio Engine Graph

    private let audioEngine = AVAudioEngine()
    private let mainMixer: AVAudioMixerNode

    // Drone nodes
    private var droneNode: AVAudioSourceNode?
    private var dronePhase: Double = 0.0
    private var droneLFOPhase: Double = 0.0
    private let droneBaseFrequency: Double = 100.0   // Hz centre
    private let droneLFORate: Double = 0.15           // Hz – slow wobble
    private let droneFrequencyDeviation: Double = 20  // +/- Hz

    // One-shot player for bundled audio files
    private var filePlayerNode: AVAudioPlayerNode?

    // Format
    private let sampleRate: Double = 44100.0
    private lazy var audioFormat: AVAudioFormat = {
        AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
    }()

    // Volume cap – no jump scares
    private let masterVolume: Float = 0.45

    // MARK: - Init / Deinit

    init() {
        mainMixer = audioEngine.mainMixerNode
        mainMixer.outputVolume = masterVolume
        configureAudioSession()
    }

    deinit {
        stopAmbientDrone()
        stopEngine()
    }

    // MARK: - Engine Management

    /// Starts the AVAudioEngine. Call before playing any audio.
    func startEngine() {
        guard !isEngineRunning else { return }
        do {
            try audioEngine.start()
            isEngineRunning = true
        } catch {
            print("[AudioService] ⚠️ Failed to start audio engine: \(error.localizedDescription)")
        }
    }

    /// Stops the AVAudioEngine.
    func stopEngine() {
        audioEngine.stop()
        isEngineRunning = false
    }

    // MARK: - Ambient Drone

    /// Starts a low sine-wave oscillation (80-120 Hz) with a slow LFO.
    func startAmbientDrone() {
        guard !isDronePlaying else { return }

        // Try bundled file first
        if let url = Bundle.main.url(forResource: "ambient_drone", withExtension: "wav") ??
                      Bundle.main.url(forResource: "ambient_drone", withExtension: "m4a") {
            if playLoopingFile(url: url, volume: 0.35) {
                isDronePlaying = true
                return
            }
        }

        // Programmatic fallback
        startEngineIfNeeded()

        dronePhase = 0
        droneLFOPhase = 0

        let sr = sampleRate
        let baseFreq = droneBaseFrequency
        let lfoRate = droneLFORate
        let freqDev = droneFrequencyDeviation

        let node = AVAudioSourceNode(format: audioFormat) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }

            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let buffer = ablPointer.first?.mData?.assumingMemoryBound(to: Float.self) else {
                return noErr
            }

            for frame in 0..<Int(frameCount) {
                // LFO modulates frequency
                let lfoValue = sin(2.0 * .pi * self.droneLFOPhase)
                let freq = baseFreq + freqDev * lfoValue

                let sample = Float(sin(2.0 * .pi * self.dronePhase) * 0.3)
                buffer[frame] = sample

                self.dronePhase += freq / sr
                if self.dronePhase > 1.0 { self.dronePhase -= 1.0 }

                self.droneLFOPhase += lfoRate / sr
                if self.droneLFOPhase > 1.0 { self.droneLFOPhase -= 1.0 }
            }

            return noErr
        }

        audioEngine.attach(node)
        audioEngine.connect(node, to: mainMixer, format: audioFormat)

        droneNode = node
        startEngineIfNeeded()
        isDronePlaying = true
    }

    /// Stops the ambient drone.
    func stopAmbientDrone() {
        if let node = droneNode {
            audioEngine.disconnectNodeOutput(node)
            audioEngine.detach(node)
            droneNode = nil
        }
        if let player = filePlayerNode, player.isPlaying {
            player.stop()
            audioEngine.disconnectNodeOutput(player)
            audioEngine.detach(player)
            filePlayerNode = nil
        }
        isDronePlaying = false
    }

    // MARK: - Detection Spike

    /// Quick frequency sweep from 200 Hz to 2 kHz over ~0.3 seconds.
    func playDetectionSpike() {
        if playSoundFileIfAvailable(name: "detection_spike") { return }

        startEngineIfNeeded()

        let sr = sampleRate
        let duration: Double = 0.3
        let totalSamples = Int(sr * duration)
        var phase: Double = 0

        let buffer = createBuffer(frameCount: AVAudioFrameCount(totalSamples))
        guard let channelData = buffer.floatChannelData?[0] else { return }

        for i in 0..<totalSamples {
            let t = Double(i) / Double(totalSamples) // 0…1
            let freq = 200.0 + 1800.0 * t            // 200 → 2000 Hz
            let envelope = Float(1.0 - t)             // fade out
            let sample = Float(sin(2.0 * .pi * phase)) * 0.35 * envelope

            channelData[i] = sample
            phase += freq / sr
            if phase > 1.0 { phase -= 1.0 }
        }

        buffer.frameLength = AVAudioFrameCount(totalSamples)
        playOneShotBuffer(buffer)
    }

    // MARK: - Static Burst

    /// White noise burst, 0.5 second duration.
    func playStaticBurst() {
        if playSoundFileIfAvailable(name: "static_burst") { return }

        startEngineIfNeeded()

        let sr = sampleRate
        let duration: Double = 0.5
        let totalSamples = Int(sr * duration)

        let buffer = createBuffer(frameCount: AVAudioFrameCount(totalSamples))
        guard let channelData = buffer.floatChannelData?[0] else { return }

        for i in 0..<totalSamples {
            let t = Double(i) / Double(totalSamples)
            // Envelope: quick attack, slow release
            let envelope: Float = t < 0.05 ? Float(t / 0.05) : Float(1.0 - (t - 0.05) / 0.95)
            let noise = Float.random(in: -1.0...1.0)
            channelData[i] = noise * 0.3 * envelope
        }

        buffer.frameLength = AVAudioFrameCount(totalSamples)
        playOneShotBuffer(buffer)
    }

    // MARK: - EVP Whisper

    /// Heavily reverbed, pitch-shifted quiet sine blips.
    func playEVPWhisper() {
        if playSoundFileIfAvailable(name: "evp_whisper") { return }

        startEngineIfNeeded()

        let sr = sampleRate
        let duration: Double = 1.5
        let totalSamples = Int(sr * duration)

        let buffer = createBuffer(frameCount: AVAudioFrameCount(totalSamples))
        guard let channelData = buffer.floatChannelData?[0] else { return }

        // Generate sparse, quiet sine blips at random pitches
        var phase: Double = 0
        var blipFreq: Double = Double.random(in: 300...900)
        var nextBlipSample = Int.random(in: 0...2000)
        var blipRemaining = 0

        for i in 0..<totalSamples {
            if i == nextBlipSample {
                blipFreq = Double.random(in: 300...900)
                blipRemaining = Int.random(in: 400...1800)
                phase = 0
                nextBlipSample = i + blipRemaining + Int.random(in: 1500...5000)
            }

            if blipRemaining > 0 {
                let blipEnvelope = Float(blipRemaining) / 1800.0 * 0.12
                channelData[i] = Float(sin(2.0 * .pi * phase)) * blipEnvelope
                phase += blipFreq / sr
                blipRemaining -= 1
            } else {
                channelData[i] = 0
            }
        }

        buffer.frameLength = AVAudioFrameCount(totalSamples)

        // Play through reverb
        let reverb = AVAudioUnitReverb()
        reverb.loadFactoryPreset(.largeChamber)
        reverb.wetDryMix = 80

        audioEngine.attach(reverb)

        let player = AVAudioPlayerNode()
        audioEngine.attach(player)
        audioEngine.connect(player, to: reverb, format: audioFormat)
        audioEngine.connect(reverb, to: mainMixer, format: audioFormat)

        startEngineIfNeeded()
        player.scheduleBuffer(buffer) {
            DispatchQueue.main.async { [weak self] in
                self?.audioEngine.disconnectNodeOutput(reverb)
                self?.audioEngine.detach(reverb)
                self?.audioEngine.disconnectNodeOutput(player)
                self?.audioEngine.detach(player)
            }
        }
        player.play()
    }

    // MARK: - Helpers

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("[AudioService] ⚠️ Audio session setup failed: \(error.localizedDescription)")
        }
    }

    private func startEngineIfNeeded() {
        if !audioEngine.isRunning {
            startEngine()
        }
    }

    private func createBuffer(frameCount: AVAudioFrameCount) -> AVAudioPCMBuffer {
        AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount)!
    }

    /// Plays a one-shot PCM buffer through a temporary player node.
    private func playOneShotBuffer(_ buffer: AVAudioPCMBuffer) {
        let player = AVAudioPlayerNode()
        audioEngine.attach(player)
        audioEngine.connect(player, to: mainMixer, format: audioFormat)

        startEngineIfNeeded()
        player.scheduleBuffer(buffer) {
            DispatchQueue.main.async { [weak self] in
                self?.audioEngine.disconnectNodeOutput(player)
                self?.audioEngine.detach(player)
            }
        }
        player.play()
    }

    /// Attempts to play a bundled audio file by name. Returns true if successful.
    private func playSoundFileIfAvailable(name: String) -> Bool {
        for ext in ["wav", "m4a", "caf", "aif"] {
            if let url = Bundle.main.url(forResource: name, withExtension: ext) {
                do {
                    startEngineIfNeeded()
                    let file = try AVAudioFile(forReading: url)
                    let player = AVAudioPlayerNode()
                    audioEngine.attach(player)
                    audioEngine.connect(player, to: mainMixer, format: file.processingFormat)
                    player.scheduleFile(file, at: nil) {
                        DispatchQueue.main.async { [weak self] in
                            self?.audioEngine.disconnectNodeOutput(player)
                            self?.audioEngine.detach(player)
                        }
                    }
                    player.play()
                    return true
                } catch {
                    print("[AudioService] Could not play \(name).\(ext): \(error.localizedDescription)")
                }
            }
        }
        return false
    }

    /// Plays a looping audio file. Returns true if successful.
    private func playLoopingFile(url: URL, volume: Float) -> Bool {
        do {
            startEngineIfNeeded()
            let file = try AVAudioFile(forReading: url)
            let player = AVAudioPlayerNode()
            player.volume = volume
            audioEngine.attach(player)
            audioEngine.connect(player, to: mainMixer, format: file.processingFormat)

            // Read entire file into a buffer for looping
            let buf = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                       frameCapacity: AVAudioFrameCount(file.length))!
            try file.read(into: buf)
            player.scheduleBuffer(buf, at: nil, options: .loops)
            player.play()

            filePlayerNode = player
            return true
        } catch {
            print("[AudioService] Could not loop file: \(error.localizedDescription)")
            return false
        }
    }
}
