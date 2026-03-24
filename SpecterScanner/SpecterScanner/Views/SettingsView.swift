import SwiftUI

/// App settings: scare level, discovery reset, and about section.
struct SettingsView: View {

    // MARK: - Persisted Settings

    /// false = Junior Investigator, true = Senior Agent
    @AppStorage("scareLevelSenior") private var isSeniorAgent = false

    @AppStorage("hapticFeedbackEnabled") private var hapticEnabled = true

    // MARK: - State

    @State private var showResetConfirmation = false
    @State private var resetComplete = false

    // MARK: - Colors

    private let accentGreen = Color(red: 0, green: 1, blue: 0.53)
    private let accentCyan  = Color(red: 0, green: 1, blue: 0.8)
    private let alertRed    = Color(red: 1, green: 0.2, blue: 0.2)
    private let darkBG      = Color(red: 10/255, green: 10/255, blue: 10/255)

    // MARK: - Body

    var body: some View {
        List {
            // Scare Level
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("INVESTIGATION CLEARANCE")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(accentGreen.opacity(0.6))
                        .tracking(1)

                    Picker("Scare Level", selection: $isSeniorAgent) {
                        Text("Junior Investigator")
                            .tag(false)
                        Text("Senior Agent")
                            .tag(true)
                    }
                    .pickerStyle(.segmented)

                    Text(isSeniorAgent
                         ? "Full threat data, longer detection events, and spookier effects."
                         : "Friendly mode with reduced intensity. Recommended for new recruits.")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(Color.white.opacity(0.05))
            } header: {
                sectionHeader("Scare Level")
            }

            // Preferences
            Section {
                Toggle(isOn: $hapticEnabled) {
                    Label {
                        Text("Haptic Feedback")
                            .font(.system(.body, design: .monospaced))
                    } icon: {
                        Image(systemName: "iphone.radiowaves.left.and.right")
                            .foregroundStyle(accentGreen)
                    }
                }
                .tint(accentGreen)
                .listRowBackground(Color.white.opacity(0.05))
            } header: {
                sectionHeader("Preferences")
            }

            // Data
            Section {
                Button(role: .destructive) {
                    showResetConfirmation = true
                } label: {
                    Label {
                        Text("Reset All Discoveries")
                            .font(.system(.body, design: .monospaced))
                    } icon: {
                        Image(systemName: "trash.fill")
                    }
                    .foregroundStyle(alertRed)
                }
                .listRowBackground(Color.white.opacity(0.05))

                if resetComplete {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("All discoveries cleared.")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                    .transition(.opacity)
                }
            } header: {
                sectionHeader("Data")
            }

            // About
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "ghost.fill")
                            .font(.title2)
                            .foregroundStyle(accentCyan)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Specter Scanner")
                                .font(.system(.headline, design: .monospaced))
                                .foregroundStyle(.white)
                            Text("v1.0.0")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text("A ghost detection simulator for young paranormal investigators. Point your device at toys and dolls to discover their haunted backstories.")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)

                    Divider().background(Color.white.opacity(0.1))

                    VStack(alignment: .leading, spacing: 4) {
                        creditLine("Design & Development", value: "Specter Labs")
                        creditLine("Sound Design", value: "Phantom Audio Co.")
                        creditLine("Entity Database", value: "Paranormal Research Div.")
                    }
                }
                .listRowBackground(Color.white.opacity(0.05))
            } header: {
                sectionHeader("About")
            }
        }
        .scrollContentBackground(.hidden)
        .background(darkBG.ignoresSafeArea())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .alert("Reset Discoveries?", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                performReset()
            }
        } message: {
            Text("This will erase all documented entities. You will need to scan them again to rebuild your case files. This cannot be undone.")
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(.caption2, design: .monospaced))
            .foregroundStyle(accentGreen)
            .tracking(1.5)
    }

    private func creditLine(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private func performReset() {
        UserDefaults.standard.removeObject(forKey: "discoveredDollIDs")
        withAnimation {
            resetComplete = true
        }
        // Hide confirmation after a few seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation {
                resetComplete = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SettingsView()
    }
}
