import Foundation
import CoreML
import Vision
import Combine

/// Service that uses CoreML + Vision to classify camera frames.
/// Model-agnostic: loads any .mlmodel found in the app bundle.
/// Designed for the Specter Scanner ghost-detection simulator.
@Observable
final class ClassificationService {

    // MARK: - Published State

    private(set) var lastClassification: String?
    private(set) var lastConfidence: Double = 0.0

    // MARK: - Configuration

    /// Minimum confidence to accept a classification result.
    var confidenceThreshold: Double

    /// Cooldown period (seconds) to avoid re-triggering the same classification.
    private let cooldownInterval: TimeInterval = 5.0

    /// Frame sampling range – only process every Nth frame where N is in this range.
    private let frameSamplingRange: ClosedRange<Int> = 10...15

    // MARK: - Private State

    private var vnModel: VNCoreMLModel?
    private var frameCounter: Int = 0
    private var frameSamplingTarget: Int
    private var lastTriggerDate: Date?
    private var lastTriggeredLabel: String?
    private let classificationQueue = DispatchQueue(
        label: "com.specterscanner.classification",
        qos: .userInitiated
    )

    // MARK: - Init

    init(confidenceThreshold: Double = 0.75) {
        self.confidenceThreshold = confidenceThreshold
        self.frameSamplingTarget = Int.random(in: 10...15)
        loadModel()
    }

    // MARK: - Model Loading

    /// Attempts to find and load the first .mlmodelc compiled model in the bundle.
    private func loadModel() {
        guard let modelURL = findCompiledModelURL() else {
            print("[ClassificationService] ⚠️ No .mlmodelc found in bundle. Classification disabled.")
            return
        }

        do {
            let mlModel = try MLModel(contentsOf: modelURL)
            vnModel = try VNCoreMLModel(for: mlModel)
            print("[ClassificationService] Loaded model from \(modelURL.lastPathComponent)")
        } catch {
            print("[ClassificationService] ⚠️ Failed to load model: \(error.localizedDescription)")
            vnModel = nil
        }
    }

    /// Searches the main bundle for any compiled Core ML model (.mlmodelc directory).
    private func findCompiledModelURL() -> URL? {
        // Try .mlmodelc (compiled) first
        if let url = Bundle.main.urls(forResourcesWithExtension: "mlmodelc", subdirectory: nil)?.first {
            return url
        }

        // Try to compile a .mlmodel at runtime (development convenience)
        if let sourceURL = Bundle.main.urls(forResourcesWithExtension: "mlmodel", subdirectory: nil)?.first {
            do {
                let compiled = try MLModel.compileModel(at: sourceURL)
                return compiled
            } catch {
                print("[ClassificationService] ⚠️ Failed to compile .mlmodel: \(error.localizedDescription)")
            }
        }

        return nil
    }

    // MARK: - Classification

    /// Classify a camera frame. Respects frame sampling and cooldown logic.
    /// - Parameters:
    ///   - pixelBuffer: The camera frame to classify.
    ///   - completion: Called on the main queue with (label, confidence). Label is nil when skipped or unavailable.
    func classifyFrame(_ pixelBuffer: CVPixelBuffer, completion: @escaping (String?, Double) -> Void) {
        // Frame sampling: skip frames until we hit the target
        frameCounter += 1
        guard frameCounter >= frameSamplingTarget else {
            completion(nil, 0.0)
            return
        }
        frameCounter = 0
        // Pick a new random target for the next cycle
        frameSamplingTarget = Int.random(in: frameSamplingRange)

        // Guard: model must be loaded
        guard let vnModel else {
            completion(nil, 0.0)
            return
        }

        classificationQueue.async { [weak self] in
            guard let self else { return }

            let request = VNCoreMLRequest(model: vnModel) { [weak self] request, error in
                guard let self else { return }

                if let error {
                    print("[ClassificationService] Classification error: \(error.localizedDescription)")
                    DispatchQueue.main.async { completion(nil, 0.0) }
                    return
                }

                guard let results = request.results as? [VNClassificationObservation],
                      let top = results.first else {
                    DispatchQueue.main.async { completion(nil, 0.0) }
                    return
                }

                let confidence = Double(top.confidence)
                let label = top.identifier

                // Check confidence threshold
                guard confidence >= self.confidenceThreshold else {
                    DispatchQueue.main.async { completion(nil, confidence) }
                    return
                }

                // Check cooldown: don't re-trigger the same label within the cooldown window
                if let lastLabel = self.lastTriggeredLabel,
                   let lastDate = self.lastTriggerDate,
                   lastLabel == label,
                   Date().timeIntervalSince(lastDate) < self.cooldownInterval {
                    DispatchQueue.main.async { completion(nil, confidence) }
                    return
                }

                // Accept classification
                DispatchQueue.main.async {
                    self.lastClassification = label
                    self.lastConfidence = confidence
                    self.lastTriggeredLabel = label
                    self.lastTriggerDate = Date()
                    completion(label, confidence)
                }
            }

            request.imageCropAndScaleOption = .centerCrop

            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("[ClassificationService] VNImageRequestHandler error: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(nil, 0.0) }
            }
        }
    }

    /// Resets cooldown state so the next classification is accepted regardless.
    func resetCooldown() {
        lastTriggerDate = nil
        lastTriggeredLabel = nil
    }
}
