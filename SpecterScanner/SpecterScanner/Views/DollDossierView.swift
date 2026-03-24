import SwiftUI

/// Detailed case file for a single specter, styled as a classified document
/// on aged paper with coffee stains and a CLASSIFIED watermark.
struct DollDossierView: View {

    // MARK: - Parameters

    let doll: DollProfile

    // MARK: - Colors

    private let agedPaper     = Color(red: 212/255, green: 197/255, blue: 169/255) // #D4C5A9
    private let paperDarker   = Color(red: 180/255, green: 165/255, blue: 137/255)
    private let inkColor      = Color(red: 40/255, green: 30/255, blue: 20/255)
    private let stampRed      = Color(red: 0.7, green: 0.1, blue: 0.1)
    private let coffeeStain   = Color(red: 140/255, green: 100/255, blue: 60/255)

    // MARK: - Body

    var body: some View {
        ScrollView {
            ZStack {
                // Aged paper background
                agedPaper.ignoresSafeArea()

                // CLASSIFIED watermark
                Text("CLASSIFIED")
                    .font(.system(size: 64, weight: .black, design: .monospaced))
                    .foregroundStyle(stampRed.opacity(0.08))
                    .rotationEffect(.degrees(-35))
                    .offset(y: 100)

                // Coffee stain
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                coffeeStain.opacity(0.15),
                                coffeeStain.opacity(0.08),
                                coffeeStain.opacity(0)
                            ],
                            center: .center,
                            startRadius: 5,
                            endRadius: 55
                        )
                    )
                    .frame(width: 110, height: 110)
                    .offset(x: 120, y: -260)

                // Content
                VStack(alignment: .leading, spacing: 20) {

                    // Header
                    headerSection

                    Divider().background(inkColor.opacity(0.3))

                    // Photo / silhouette
                    photoSection

                    // Classification
                    classificationSection

                    Divider().background(inkColor.opacity(0.3))

                    // Threat level
                    threatSection

                    Divider().background(inkColor.opacity(0.3))

                    // Origin story
                    originSection

                    Divider().background(inkColor.opacity(0.3))

                    // Documented activity
                    activitySection

                    Divider().background(inkColor.opacity(0.3))

                    // Footer metadata
                    footerSection

                    Spacer(minLength: 40)
                }
                .padding(24)
            }
        }
        .background(agedPaper)
        .navigationTitle("Case File")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("PARANORMAL INVESTIGATION UNIT")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(inkColor.opacity(0.5))
                Spacer()
                Text(doll.id)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(inkColor.opacity(0.5))
            }

            Text(doll.name.uppercased())
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundStyle(inkColor)

            // Status badge
            Text(doll.status.uppercased())
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(statusColor)
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
    }

    private var photoSection: some View {
        Group {
            if let imageData = doll.capturedImageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(inkColor.opacity(0.2), lineWidth: 1)
                    )
            } else {
                // Silhouette placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(paperDarker.opacity(0.5))
                    VStack(spacing: 8) {
                        Image(systemName: "person.fill.questionmark")
                            .font(.system(size: 48))
                            .foregroundStyle(inkColor.opacity(0.25))
                        Text("NO PHOTOGRAPH ON FILE")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(inkColor.opacity(0.35))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
            }
        }
    }

    private var classificationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("CLASSIFICATION")

            HStack(spacing: 10) {
                Image(systemName: doll.hauntingType.icon)
                    .font(.title3)
                    .foregroundStyle(inkColor.opacity(0.7))

                VStack(alignment: .leading, spacing: 2) {
                    Text(doll.classificationLabel)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(inkColor)
                    Text("Behavioral Pattern: \(doll.hauntingType.displayName)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(inkColor.opacity(0.6))
                }
            }
        }
    }

    private var threatSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("THREAT ASSESSMENT")

            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { level in
                    Circle()
                        .fill(level <= doll.threatLevel ? doll.threatBand.color : inkColor.opacity(0.15))
                        .frame(width: 18, height: 18)
                        .overlay(
                            Circle().stroke(inkColor.opacity(0.3), lineWidth: 0.5)
                        )
                }
                Spacer()
                Text(doll.threatBand.label)
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.bold)
                    .foregroundStyle(doll.threatBand.color)
            }

            Text(doll.threatLevelDescription)
                .font(.system(.caption, design: .serif))
                .foregroundStyle(inkColor.opacity(0.7))
                .italic()
        }
    }

    private var originSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("ORIGIN / BACKGROUND")

            Text(doll.originStory)
                .font(.system(.body, design: .serif))
                .foregroundStyle(inkColor.opacity(0.85))
                .lineSpacing(4)
        }
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("DOCUMENTED ACTIVITY")

            ForEach(Array(doll.documentedActivity.enumerated()), id: \.offset) { _, entry in
                HStack(alignment: .top, spacing: 8) {
                    Text("\u{2022}")
                        .foregroundStyle(inkColor.opacity(0.5))
                    Text(entry)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(inkColor.opacity(0.75))
                }
            }
        }
    }

    private var footerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let date = doll.firstDetected {
                HStack {
                    Text("FIRST DETECTED:")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(inkColor.opacity(0.4))
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(inkColor.opacity(0.6))
                }
            }

            HStack {
                Text("FILE STATUS:")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(inkColor.opacity(0.4))
                Text(doll.status.uppercased())
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(inkColor.opacity(0.6))
            }

            // Stamp
            Text("CLASSIFIED")
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundStyle(stampRed.opacity(0.6))
                .padding(.top, 8)
                .rotationEffect(.degrees(-5))
        }
    }

    // MARK: - Helpers

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption, design: .monospaced))
            .fontWeight(.semibold)
            .foregroundStyle(inkColor.opacity(0.45))
            .tracking(1.5)
    }

    private var statusColor: Color {
        switch doll.status.lowercased() {
        case "contained":        .green.opacity(0.8)
        case "at large":         .red.opacity(0.8)
        case "dormant":          .gray
        default:                 .orange.opacity(0.8)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        DollDossierView(doll: .sample)
    }
}
