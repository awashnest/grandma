import SwiftUI

// MARK: - CaseFileView

/// Grid view displaying all known specters; discovered dolls show details,
/// undiscovered ones appear as dark silhouettes.
struct CaseFileView: View {

    @Environment(DossierViewModel.self) private var viewModel

    // Colors
    private let accentGreen = Color(red: 0, green: 1, blue: 0.53)
    private let darkBG      = Color(red: 10/255, green: 10/255, blue: 10/255)

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Counter
                Text("\(viewModel.discoveredCount) of \(viewModel.totalCount) Entities Documented")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(accentGreen)
                    .padding(.top, 8)

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.1))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(accentGreen)
                            .frame(width: geo.size.width * viewModel.completionFraction)
                    }
                }
                .frame(height: 4)
                .padding(.horizontal, 16)

                // Grid
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(viewModel.allProfiles) { doll in
                        let discovered = viewModel.isDiscovered(doll.id)

                        if discovered {
                            NavigationLink(destination: DollDossierView(doll: doll)) {
                                DiscoveredDollCell(doll: doll, accentColor: accentGreen)
                            }
                            .buttonStyle(.plain)
                        } else {
                            UndiscoveredDollCell(accentColor: accentGreen)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(darkBG.ignoresSafeArea())
        .navigationTitle("Case Files")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

// MARK: - Discovered Doll Cell

private struct DiscoveredDollCell: View {
    let doll: DollProfile
    let accentColor: Color

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.05))

                if let data = doll.capturedImageData, let img = UIImage(data: data) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 140, height: 140)
                        .clipped()
                } else {
                    Image(systemName: doll.hauntingType.icon)
                        .font(.system(size: 36))
                        .foregroundStyle(accentColor.opacity(0.5))
                }
            }
            .frame(height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(doll.name.uppercased())
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .lineLimit(1)

            HStack(spacing: 3) {
                ForEach(1...5, id: \.self) { level in
                    Circle()
                        .fill(level <= doll.threatLevel ? doll.threatBand.color : Color.white.opacity(0.15))
                        .frame(width: 8, height: 8)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(accentColor.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Undiscovered Doll Cell

private struct UndiscoveredDollCell: View {
    let accentColor: Color

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.6))

                Image(systemName: "person.fill.questionmark")
                    .font(.system(size: 36))
                    .foregroundStyle(.white.opacity(0.1))
            }
            .frame(height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            Text("???")
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.bold)
                .foregroundStyle(.white.opacity(0.3))

            Text("UNDETECTED")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(accentColor.opacity(0.3))
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.02))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }
}
