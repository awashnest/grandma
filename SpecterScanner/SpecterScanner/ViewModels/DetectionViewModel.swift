import Foundation
import Observation
import CoreVideo

/// Result of a single frame classification attempt.
struct DetectionResult {
    /// The matched classification label, or `nil` if nothing met the threshold.
    let label: String?
    /// Confidence value from the model (0.0–1.0).
    let confidence: Double
    /// Whether a detection was confirmed (label present + above threshold).
    var isDetection: Bool { label != nil && confidence > 0 }
}

/// Bridges between the ``ClassificationService`` ML pipeline and the UI layer.
///
/// Use this view model when you need fine-grained control over individual
/// frame results without the full scanner lifecycle that ``ScannerViewModel``
/// provides.
@Observable
final class DetectionViewModel {

    // MARK: - Published State

    /// The most recent classification label returned by the model.
    private(set) var classificationLabel: String?

    /// Confidence of the most recent classification (0.0–1.0).
    private(set) var confidence: Double = 0.0

    /// `true` while a frame is actively being processed by the ML pipeline.
    private(set) var isProcessing: Bool = false

    /// Running history of the last N results for smoothing / UI display.
    private(set) var recentResults: [DetectionResult] = []

    // MARK: - Configuration

    /// Maximum number of recent results to keep in memory.
    var recentResultsLimit: Int = 20

    // MARK: - Services

    private let classificationService: ClassificationService

    // MARK: - Init

    /// Creates a new detection view model.
    /// - Parameter classificationService: The shared classification service.
    ///   Defaults to a new instance if none is provided.
    init(classificationService: ClassificationService = ClassificationService()) {
        self.classificationService = classificationService
    }

    // MARK: - Frame Processing

    /// Processes a single camera frame through the ML classification pipeline.
    ///
    /// - Parameter pixelBuffer: The camera frame to classify.
    /// - Returns: A ``DetectionResult`` describing the outcome.
    @discardableResult
    func processFrame(_ pixelBuffer: CVPixelBuffer) async -> DetectionResult {
        guard !isProcessing else {
            return DetectionResult(label: nil, confidence: 0.0)
        }

        isProcessing = true

        let result = await withCheckedContinuation { (continuation: CheckedContinuation<DetectionResult, Never>) in
            classificationService.classifyFrame(pixelBuffer) { label, confidence in
                let result = DetectionResult(label: label, confidence: confidence)
                continuation.resume(returning: result)
            }
        }

        // Update published state on main actor (we are already @Observable so
        // mutations on the main thread will be picked up automatically).
        classificationLabel = result.label ?? classificationLabel
        confidence = result.confidence
        isProcessing = false

        // Append to recent results ring buffer
        recentResults.append(result)
        if recentResults.count > recentResultsLimit {
            recentResults.removeFirst(recentResults.count - recentResultsLimit)
        }

        return result
    }

    /// Synchronous convenience wrapper — fires and forgets.
    func processFrameSync(_ pixelBuffer: CVPixelBuffer) {
        Task { @MainActor in
            await processFrame(pixelBuffer)
        }
    }

    // MARK: - State Management

    /// Clears the current classification state and recent history.
    func reset() {
        classificationLabel = nil
        confidence = 0.0
        isProcessing = false
        recentResults.removeAll()
        classificationService.resetCooldown()
    }

    /// The average confidence across recent results that actually produced a label.
    var averageDetectionConfidence: Double {
        let detections = recentResults.filter { $0.isDetection }
        guard !detections.isEmpty else { return 0.0 }
        return detections.map(\.confidence).reduce(0, +) / Double(detections.count)
    }

    /// The most frequently detected label in recent history, if any.
    var dominantLabel: String? {
        let labels = recentResults.compactMap(\.label)
        guard !labels.isEmpty else { return nil }

        var counts: [String: Int] = [:]
        for label in labels {
            counts[label, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }
}
