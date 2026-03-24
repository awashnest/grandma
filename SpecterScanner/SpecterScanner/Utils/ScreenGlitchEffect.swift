import SwiftUI

/// A view modifier that overlays randomised glitch artefacts — RGB channel
/// splits, horizontal scanlines, and static noise blocks — on top of its
/// content.  Designed for the Specter Scanner's "detection" UI state.
struct ScreenGlitchEffect: ViewModifier {
    /// Whether the effect is currently rendering.
    @Binding var isActive: Bool

    /// Overall intensity of the glitch, from `0` (invisible) to `1` (maximum).
    var intensity: Double

    // MARK: - Internal animation state

    @State private var tick: Int = 0
    @State private var rgbOffset: CGFloat = 0
    @State private var noiseBlocks: [NoiseBlock] = []
    @State private var scanlineOffset: CGFloat = 0

    private struct NoiseBlock: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var width: CGFloat
        var height: CGFloat
        var opacity: Double
    }

    func body(content: Content) -> some View {
        content
            .overlay {
                if isActive {
                    TimelineView(.animation(minimumInterval: 0.05)) { timeline in
                        let _ = updateState(date: timeline.date)
                        glitchOverlay
                    }
                    .allowsHitTesting(false)
                }
            }
    }

    // MARK: - Composite overlay

    @ViewBuilder
    private var glitchOverlay: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                // --- RGB channel offset ---
                rgbChannelLayer(size: size)

                // --- Scanlines ---
                scanlineLayer(size: size)

                // --- Static noise blocks ---
                noiseBlockLayer()
            }
        }
        .clipped()
    }

    // MARK: - Layers

    @ViewBuilder
    private func rgbChannelLayer(size: CGSize) -> some View {
        let offset = rgbOffset * intensity
        Canvas { ctx, canvasSize in
            let rect = CGRect(origin: .zero, size: canvasSize)
            // Red channel shift
            ctx.addFilter(.colorMultiply(.red))
            ctx.fill(Path(rect), with: .color(.red.opacity(0.08 * intensity)))
        }
        .blendMode(.screen)
        .offset(x: offset, y: -offset * 0.5)

        Canvas { ctx, canvasSize in
            let rect = CGRect(origin: .zero, size: canvasSize)
            ctx.addFilter(.colorMultiply(.cyan))
            ctx.fill(Path(rect), with: .color(.cyan.opacity(0.06 * intensity)))
        }
        .blendMode(.screen)
        .offset(x: -offset * 0.7, y: offset * 0.3)
    }

    @ViewBuilder
    private func scanlineLayer(size: CGSize) -> some View {
        Canvas { ctx, canvasSize in
            let lineSpacing: CGFloat = 3
            var y: CGFloat = scanlineOffset.truncatingRemainder(dividingBy: lineSpacing * 2)
            while y < canvasSize.height {
                let rect = CGRect(x: 0, y: y, width: canvasSize.width, height: 1)
                ctx.fill(Path(rect), with: .color(.black.opacity(0.15 * intensity)))
                y += lineSpacing
            }
        }
    }

    @ViewBuilder
    private func noiseBlockLayer() -> some View {
        ForEach(noiseBlocks) { block in
            Rectangle()
                .fill(Color.white.opacity(block.opacity * intensity))
                .frame(width: block.width, height: block.height)
                .position(x: block.x, y: block.y)
                .blendMode(.difference)
        }
    }

    // MARK: - State update (called every timeline tick)

    @discardableResult
    private func updateState(date: Date) -> Bool {
        // Use the date's timeIntervalSince1970 as a cheap seed.
        let seed = date.timeIntervalSince1970

        // RGB offset jitter
        rgbOffset = CGFloat.random(in: -6...6)

        // Scanline scroll
        scanlineOffset += CGFloat.random(in: 0.5...2.0)

        // Regenerate noise blocks occasionally
        if Int(seed * 20) % 3 == 0 {
            let count = Int.random(in: 0...Int(5 * intensity))
            noiseBlocks = (0..<count).map { _ in
                NoiseBlock(
                    x: CGFloat.random(in: 0...400),
                    y: CGFloat.random(in: 0...800),
                    width: CGFloat.random(in: 20...160),
                    height: CGFloat.random(in: 2...12),
                    opacity: Double.random(in: 0.1...0.5)
                )
            }
        }

        return true
    }
}

// MARK: - View Extension

extension View {
    /// Applies the Specter Scanner glitch effect as an overlay.
    ///
    /// - Parameters:
    ///   - isActive: Controls whether the effect is visible.
    ///   - intensity: Strength of the effect, `0` (off) to `1` (full).
    func glitchEffect(isActive: Binding<Bool>, intensity: Double = 0.5) -> some View {
        modifier(ScreenGlitchEffect(isActive: isActive, intensity: intensity))
    }
}

// MARK: - Preview

#Preview("Glitch Effect") {
    @Previewable @State var active = true
    VStack(spacing: 24) {
        Text("SPECTER DETECTED")
            .font(.system(.title, design: .monospaced, weight: .bold))
            .foregroundStyle(.green)
        Text("Threat Level: 4")
            .font(.system(.headline, design: .monospaced))
            .foregroundStyle(.red)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.black)
    .glitchEffect(isActive: $active, intensity: 0.7)
    .onTapGesture { active.toggle() }
}
