import Foundation
import ARKit
import AVFoundation
import Combine

/// Provides camera frames for the Specter Scanner overlay.
/// Prefers ARKit for camera passthrough; falls back to AVCaptureSession
/// when ARKit is unavailable (e.g. Simulator).
@Observable
final class AROverlayService: NSObject {

    // MARK: - Published State

    private(set) var currentFrame: CVPixelBuffer?
    private(set) var isRunning: Bool = false
    private(set) var isUsingARKit: Bool = false

    // MARK: - Private – ARKit

    private var arSession: ARSession?

    // MARK: - Private – AVCapture fallback

    private var captureSession: AVCaptureSession?
    private var captureOutput: AVCaptureVideoDataOutput?
    private let captureQueue = DispatchQueue(label: "com.specterscanner.capture", qos: .userInitiated)

    // MARK: - Lifecycle

    override init() {
        super.init()
    }

    deinit {
        stopSession()
    }

    // MARK: - Public API

    /// Starts camera frame delivery. Uses ARKit when available, otherwise AVCaptureSession.
    func startSession() {
        guard !isRunning else { return }

        if ARWorldTrackingConfiguration.isSupported || AROrientationTrackingConfiguration.isSupported {
            startARSession()
        } else {
            print("[AROverlayService] ARKit not available – falling back to AVCaptureSession.")
            startCaptureSession()
        }
    }

    /// Stops whichever camera pipeline is active.
    func stopSession() {
        if let arSession {
            arSession.pause()
            arSession.delegate = nil
            self.arSession = nil
        }

        if let captureSession, captureSession.isRunning {
            captureSession.stopRunning()
        }
        captureSession = nil
        captureOutput = nil

        isRunning = false
        isUsingARKit = false
    }

    // MARK: - ARKit Path

    private func startARSession() {
        let session = ARSession()
        session.delegate = self
        self.arSession = session

        let configuration: ARConfiguration
        if ARWorldTrackingConfiguration.isSupported {
            let worldConfig = ARWorldTrackingConfiguration()
            worldConfig.planeDetection = []          // No plane detection needed
            worldConfig.isLightEstimationEnabled = false
            configuration = worldConfig
        } else {
            configuration = AROrientationTrackingConfiguration()
        }

        session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        isRunning = true
        isUsingARKit = true
        print("[AROverlayService] ARKit session started.")
    }

    // MARK: - AVCaptureSession Fallback

    private func startCaptureSession() {
        let session = AVCaptureSession()
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("[AROverlayService] ⚠️ No back camera available.")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }
        } catch {
            print("[AROverlayService] ⚠️ Could not create camera input: \(error.localizedDescription)")
            return
        }

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.setSampleBufferDelegate(self, queue: captureQueue)

        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        self.captureSession = session
        self.captureOutput = output

        captureQueue.async {
            session.startRunning()
        }

        isRunning = true
        isUsingARKit = false
        print("[AROverlayService] AVCaptureSession started (fallback).")
    }
}

// MARK: - ARSessionDelegate

extension AROverlayService: ARSessionDelegate {

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let pixelBuffer = frame.capturedImage
        DispatchQueue.main.async {
            self.currentFrame = pixelBuffer
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        print("[AROverlayService] AR session failed: \(error.localizedDescription)")
        // Attempt fallback
        stopSession()
        startCaptureSession()
    }

    func sessionWasInterrupted(_ session: ARSession) {
        print("[AROverlayService] AR session interrupted.")
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        print("[AROverlayService] AR session interruption ended.")
        if let config = session.configuration {
            session.run(config, options: [.resetTracking])
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension AROverlayService: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        DispatchQueue.main.async {
            self.currentFrame = pixelBuffer
        }
    }
}
