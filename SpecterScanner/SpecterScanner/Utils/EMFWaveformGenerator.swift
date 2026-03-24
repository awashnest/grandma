import SwiftUI

/// An animated EMF-style waveform view that draws a noisy sine wave,
/// continuously scrolling when active.  Suitable for the Specter Scanner's
/// ambient detection display.
struct EMFWaveformGenerator: View {
    /// Normalised wave amplitude (`0` = flat line, `1` = full swing).
    var amplitude: Double

    /// Stroke color for the waveform line.
    var color: Color

    /// Whether the waveform is animating.
    var isActive: Bool

    /// Number of visible wave cycles across the view's width.
    var frequency: Double = 3.0

    /// Stroke line width.
    var lineWidth: CGFloat = 2.0

    // MARK: - Internal state

    /// Persistent noise offsets so the waveform feels organic rather than
    /// perfectly periodic.  Regenerated each time the view activates.
    @State private var noiseSeeds: [Double] = EMFWaveformGenerator.generateSeeds()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !isActive)) { timeline in
            let elapsed = isActive
                ? timeline.date.timeIntervalSinceReferenceDate
                : 0

            Canvas { ctx, size in
                drawWaveform(in: ctx, size: size, time: elapsed)
            }
        }
        .onChange(of: isActive) { _, active in
            if active {
                noiseSeeds = Self.generateSeeds()
            }
        }
    }

    // MARK: - Drawing

    private func drawWaveform(in ctx: GraphicsContext, size: CGSize, time: Double) {
        guard size.width > 0, size.height > 0 else { return }

        let midY = size.height / 2
        let maxAmplitude = size.height * 0.4
        let effectiveAmplitude = amplitude * maxAmplitude

        let stepCount = Int(size.width)
        guard stepCount > 1 else { return }

        var path = Path()

        for i in 0...stepCount {
            let x = CGFloat(i)
            let normalizedX = Double(i) / Double(stepCount)

            // Primary sine component — scrolls over time.
            let phase1 = normalizedX * frequency * 2 * .pi + time * 2.5
            let sine1 = sin(phase1)

            // Secondary harmonic for visual richness.
            let phase2 = normalizedX * frequency * 4.3 * .pi + time * 1.7
            let sine2 = sin(phase2) * 0.35

            // Pseudo-random noise sampled from the seed table.
            let noiseIndex = Int(normalizedX * Double(noiseSeeds.count - 1))
                .clamped(to: 0...(noiseSeeds.count - 1))
            let noiseFactor = noiseSeeds[noiseIndex]
                * sin(time * 5.3 + normalizedX * 13.0) * 0.3

            // Combine components.
            let combined = (sine1 + sine2 + noiseFactor)
            let y = midY + CGFloat(combined * effectiveAmplitude)

            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        // Glow layer (wider, translucent).
        ctx.stroke(
            path,
            with: .color(color.opacity(0.3)),
            lineWidth: lineWidth * 3
        )

        // Core line.
        ctx.stroke(
            path,
            with: .color(color),
            lineWidth: lineWidth
        )

        // Flat-line faded center reference.
        let baseline = Path { p in
            p.move(to: CGPoint(x: 0, y: midY))
            p.addLine(to: CGPoint(x: size.width, y: midY))
        }
        ctx.stroke(
            baseline,
            with: .color(color.opacity(0.12)),
            lineWidth: 0.5
        )
    }

    // MARK: - Helpers

    /// Generates a table of random offsets used to add organic noise to the
    /// waveform without calling `Double.random` every frame.
    private static func generateSeeds(count: Int = 128) -> [Double] {
        (0..<count).map { _ in Double.random(in: -1...1) }
    }
}

// MARK: - Comparable clamping helper

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Preview

#Preview("EMF Waveform") {
    VStack(spacing: 32) {
        EMFWaveformGenerator(amplitude: 0.3, color: .green, isActive: true)
            .frame(height: 100)
        EMFWaveformGenerator(amplitude: 0.8, color: .red, isActive: true, frequency: 5)
            .frame(height: 100)
        EMFWaveformGenerator(amplitude: 0.0, color: .gray, isActive: false)
            .frame(height: 60)
    }
    .padding()
    .background(.black)
}
