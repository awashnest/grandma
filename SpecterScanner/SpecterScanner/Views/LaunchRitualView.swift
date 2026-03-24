import SwiftUI

/// Boot-sequence animation shown at app launch.
/// Displays scrolling fake system logs with a CRT scanline overlay,
/// then calls `onComplete` once the sequence finishes.
struct LaunchRitualView: View {

    // MARK: - Callbacks

    var onComplete: () -> Void

    // MARK: - Constants

    private static let logLines: [String] = [
        "> Initializing EMF array...",
        "> Calibrating thermal sensors...",
        "> Scanning spectral frequencies...",
        "> Loading entity database...",
        "> Paranormal Detection System ONLINE"
    ]

    private static let lineDelay: UInt64 = 800_000_000   // 0.8 s per line
    private static let holdDelay: UInt64 = 1_000_000_000 // 1 s after last line

    // MARK: - State

    @State private var visibleLines: [String] = []
    @State private var flickerOpacity: Double = 1.0
    @State private var sequenceFinished = false

    // MARK: - Colors

    private let terminalGreen = Color(red: 0, green: 1, blue: 0.53)  // #00FF88
    private let terminalCyan  = Color(red: 0, green: 1, blue: 0.8)   // #00FFCC
    private let darkBG        = Color(red: 10/255, green: 10/255, blue: 10/255) // #0A0A0A

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background
            darkBG.ignoresSafeArea()

            // Log text
            VStack(alignment: .leading, spacing: 6) {
                Spacer()

                ForEach(Array(visibleLines.enumerated()), id: \.offset) { index, line in
                    let isLast = (index == visibleLines.count - 1)
                    let isOnline = line.contains("ONLINE")

                    Text(line)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(isOnline ? terminalCyan : terminalGreen)
                        .fontWeight(isOnline ? .bold : .regular)
                        .opacity(isLast ? flickerOpacity : 1.0)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.easeInOut(duration: 0.25), value: visibleLines.count)

            // CRT scanline overlay
            CRTScanlinesOverlay()
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
        .task {
            await runBootSequence()
        }
    }

    // MARK: - Sequence Logic

    private func runBootSequence() async {
        // Start the flicker loop
        startFlicker()

        for line in Self.logLines {
            try? await Task.sleep(nanoseconds: Self.lineDelay)
            withAnimation {
                visibleLines.append(line)
            }
        }

        // Hold briefly after the last line
        try? await Task.sleep(nanoseconds: Self.holdDelay)

        sequenceFinished = true
        onComplete()
    }

    private func startFlicker() {
        // Continuous flicker using a timer-driven animation
        withAnimation(
            .easeInOut(duration: 0.08)
            .repeatForever(autoreverses: true)
        ) {
            flickerOpacity = 0.4
        }
    }
}

// MARK: - CRT Scanlines Overlay

/// Semi-transparent horizontal lines that simulate a CRT monitor.
private struct CRTScanlinesOverlay: View {
    var body: some View {
        Canvas { context, size in
            let lineSpacing: CGFloat = 3
            var y: CGFloat = 0
            while y < size.height {
                let rect = CGRect(x: 0, y: y, width: size.width, height: 1)
                context.fill(Path(rect), with: .color(.black.opacity(0.25)))
                y += lineSpacing
            }
        }
    }
}

// MARK: - Preview

#Preview {
    LaunchRitualView {
        print("Boot complete")
    }
}
