import SwiftUI

/// Full-screen modal shown when a spectral entity is detected.
/// Provides glitch transition, threat info, and navigation to the case file.
struct DetectionAlertView: View {

    // MARK: - Parameters

    let doll: DollProfile
    let previouslyDiscovered: Bool
    var onViewCaseFile: () -> Void
    var onDismiss: () -> Void

    // MARK: - State

    @State private var appeared = false
    @State private var flashOpacity: Double = 1.0
    @State private var glitchOffset: CGFloat = 0
    @State private var threatFill: Double = 0
    @State private var textFlicker: Double = 1.0

    // MARK: - Colors

    private let alertRed   = Color(red: 1, green: 0.2, blue: 0.2)    // #FF3333
    private let darkBG     = Color(red: 10/255, green: 10/255, blue: 10/255)
    private let warmOrange = Color.orange

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background
            darkBG.ignoresSafeArea()

            // Red/orange ambient glow
            RadialGradient(
                colors: [alertRed.opacity(0.25), darkBG],
                center: .center,
                startRadius: 50,
                endRadius: 400
            )
            .ignoresSafeArea()

            // Content
            VStack(spacing: 24) {
                Spacer()

                // Warning header
                Text("\u{26A0} SPECTRAL ENTITY DETECTED \u{26A0}")
                    .font(.system(.title2, design: .monospaced))
                    .fontWeight(.black)
                    .foregroundStyle(alertRed)
                    .multilineTextAlignment(.center)
                    .opacity(textFlicker)
                    .offset(x: glitchOffset)

                if previouslyDiscovered {
                    Text("PREVIOUSLY DOCUMENTED")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.yellow)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(Color.yellow.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }

                // Entity info card
                VStack(spacing: 16) {
                    // Name
                    Text(doll.name.uppercased())
                        .font(.system(.title, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundStyle(.white)

                    // Classification
                    HStack(spacing: 8) {
                        Image(systemName: doll.hauntingType.icon)
                            .foregroundStyle(warmOrange)
                        Text(doll.classificationLabel)
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.85))
                    }

                    // Haunting type
                    Text("Type: \(doll.hauntingType.displayName)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))

                    // Threat level bar
                    VStack(spacing: 6) {
                        Text("THREAT LEVEL: \(doll.threatLevel)/5")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(doll.threatBand.color)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                // Background track
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.white.opacity(0.1))

                                // Animated fill
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(
                                        LinearGradient(
                                            colors: [.green, .yellow, .orange, alertRed],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geo.size.width * threatFill)
                            }
                        }
                        .frame(height: 8)
                    }
                    .padding(.horizontal, 40)
                }
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(alertRed.opacity(0.3), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 24)

                Spacer()

                // CTA button
                Button(action: onViewCaseFile) {
                    Text("TAP TO VIEW CASE FILE")
                        .font(.system(.headline, design: .monospaced))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(alertRed)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.horizontal, 40)

                // Dismiss
                Button(action: onDismiss) {
                    Text("DISMISS")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(.bottom, 32)
            }

            // Screen flash on appear
            Color.white
                .ignoresSafeArea()
                .opacity(flashOpacity)
                .allowsHitTesting(false)

            // Glitch line artifacts
            if !appeared {
                VStack(spacing: 0) {
                    ForEach(0..<8, id: \.self) { _ in
                        Rectangle()
                            .fill(alertRed.opacity(Double.random(in: 0.1...0.4)))
                            .frame(height: CGFloat.random(in: 2...6))
                            .offset(x: CGFloat.random(in: -20...20))
                    }
                }
                .opacity(flashOpacity)
                .allowsHitTesting(false)
            }
        }
        .onAppear {
            runEntryAnimation()
        }
    }

    // MARK: - Animations

    private func runEntryAnimation() {
        // Flash: bright white that fades out
        flashOpacity = 1.0
        withAnimation(.easeOut(duration: 0.4)) {
            flashOpacity = 0
        }

        // Glitch offset shake
        withAnimation(.easeInOut(duration: 0.05).repeatCount(6, autoreverses: true)) {
            glitchOffset = 8
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.easeOut(duration: 0.15)) {
                glitchOffset = 0
            }
            appeared = true
        }

        // Threat bar fill
        withAnimation(.easeOut(duration: 1.2).delay(0.4)) {
            threatFill = Double(doll.threatLevel) / 5.0
        }

        // Text flicker
        withAnimation(
            .easeInOut(duration: 0.07)
            .repeatCount(10, autoreverses: true)
            .delay(0.1)
        ) {
            textFlicker = 0.3
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            withAnimation(.easeIn(duration: 0.1)) {
                textFlicker = 1.0
            }
        }
    }
}

// MARK: - Preview

#Preview {
    DetectionAlertView(
        doll: .sample,
        previouslyDiscovered: false,
        onViewCaseFile: {},
        onDismiss: {}
    )
}
