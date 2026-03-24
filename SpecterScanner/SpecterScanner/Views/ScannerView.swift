import SwiftUI
import AVFoundation

// MARK: - ScannerView

/// Main scanner interface: camera preview with HUD overlay.
struct ScannerView: View {

    @State var viewModel = ScannerViewModel()
    @Environment(DossierViewModel.self) private var dossierVM
    @State private var timestamp = Date()
    @State private var radarAngle: Double = 0
    @State private var recDotVisible = true
    @State private var showCaseFile = false
    @State private var showSettings = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let simTimer = Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()

    // Colors
    private let accentGreen = Color(red: 0, green: 1, blue: 0.53)   // #00FF88
    private let accentCyan  = Color(red: 0, green: 1, blue: 0.8)    // #00FFCC
    private let alertRed    = Color(red: 1, green: 0.2, blue: 0.2)  // #FF3333
    private let darkBG      = Color(red: 10/255, green: 10/255, blue: 10/255)

    private var timestampString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.string(from: timestamp)
    }

    var body: some View {
        ZStack {
            // Camera preview
            CameraPreviewView()
                .ignoresSafeArea()

            // Green tint overlay
            Color.green.opacity(0.08)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            // Corner bracket accents
            ViewfinderBrackets()
                .stroke(accentGreen.opacity(0.6), lineWidth: 1.5)
                .padding(20)
                .allowsHitTesting(false)

            // Radar sweep
            RadarSweepView(angle: radarAngle, color: accentGreen)
                .frame(width: 200, height: 200)
                .opacity(0.3)
                .allowsHitTesting(false)

            // HUD elements
            VStack {
                // Top bar
                HStack(alignment: .top) {
                    // Top-left: title + REC
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SPECTER SCANNER")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(accentGreen)
                            .fontWeight(.bold)

                        HStack(spacing: 6) {
                            Circle()
                                .fill(alertRed)
                                .frame(width: 8, height: 8)
                                .opacity(recDotVisible ? 1 : 0)
                            Text("REC")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(alertRed)
                        }
                    }

                    Spacer()

                    // Top-right: timestamp
                    Text(timestampString)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(accentCyan)
                }
                .padding(.horizontal, 28)
                .padding(.top, 12)

                Spacer()

                // Bottom bar
                HStack(alignment: .bottom) {
                    // Bottom-left: EMF bar graph
                    EMFBarGraph(level: viewModel.emfLevel, color: accentGreen)
                        .frame(width: 60, height: 80)

                    Spacer()

                    // Bottom-right: Waveform
                    WaveformView(samples: viewModel.waveformSamples, color: accentCyan)
                        .frame(width: 120, height: 50)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 8)

                // Navigation buttons
                HStack(spacing: 16) {
                    Button {
                        showCaseFile = true
                    } label: {
                        Label("Case Files", systemImage: "folder.fill")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(accentGreen)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(darkBG.opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(accentGreen.opacity(0.5), lineWidth: 1)
                            )
                    }

                    Spacer()

                    Button {
                        showSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape.fill")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(accentGreen)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(darkBG.opacity(0.7))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(accentGreen.opacity(0.5), lineWidth: 1)
                            )
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 16)
            }

            // CRT scanlines
            Canvas { context, size in
                var y: CGFloat = 0
                while y < size.height {
                    let rect = CGRect(x: 0, y: y, width: size.width, height: 1)
                    context.fill(Path(rect), with: .color(.black.opacity(0.15)))
                    y += 3
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
        .onReceive(timer) { now in
            timestamp = now
            recDotVisible.toggle()
        }
        .onReceive(simTimer) { _ in
            viewModel.tickSimulation()
        }
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                radarAngle = 360
            }
        }
        .fullScreenCover(isPresented: $showCaseFile) {
            NavigationStack {
                CaseFileView()
                    .environment(dossierVM)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Close") { showCaseFile = false }
                                .foregroundStyle(accentGreen)
                        }
                    }
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView()
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showSettings = false }
                                .foregroundStyle(accentGreen)
                        }
                    }
            }
        }
        .fullScreenCover(isPresented: $viewModel.showDetectionAlert) {
            if let doll = viewModel.detectedDoll {
                DetectionAlertView(
                    doll: doll,
                    previouslyDiscovered: false,
                    onViewCaseFile: {
                        viewModel.showDetectionAlert = false
                        showCaseFile = true
                    },
                    onDismiss: {
                        viewModel.showDetectionAlert = false
                    }
                )
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
    }
}

// MARK: - Camera Preview (UIViewRepresentable)

/// Shows a live camera preview using AVCaptureSession, or a dark placeholder
/// if the camera is unavailable (e.g. in Simulator).
struct CameraPreviewView: UIViewRepresentable {

    func makeUIView(context: Context) -> UIView {
        let view = CameraHostView()
        view.backgroundColor = UIColor(red: 10/255, green: 10/255, blue: 10/255, alpha: 1)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    private class CameraHostView: UIView {
        private var session: AVCaptureSession?
        private var previewLayer: AVCaptureVideoPreviewLayer?

        override init(frame: CGRect) {
            super.init(frame: frame)
            setupCamera()
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            setupCamera()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer?.frame = bounds
        }

        private func setupCamera() {
            let session = AVCaptureSession()
            session.sessionPreset = .high

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                // Camera unavailable — stay dark
                return
            }

            if session.canAddInput(input) {
                session.addInput(input)
            }

            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = bounds
            layer.addSublayer(previewLayer)

            self.session = session
            self.previewLayer = previewLayer

            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
            }
        }
    }
}

// MARK: - EMF Bar Graph

/// Vertical bar graph with ~8 bars whose heights are driven by a 0-1 level.
private struct EMFBarGraph: View {
    let level: Double
    let color: Color
    private let barCount = 8

    var body: some View {
        VStack(spacing: 2) {
            Text("EMF")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(color)

            HStack(spacing: 3) {
                ForEach(0..<barCount, id: \.self) { index in
                    let threshold = Double(index + 1) / Double(barCount)
                    let active = level >= threshold
                    let barColor: Color = threshold > 0.75 ? .red : (threshold > 0.5 ? .orange : color)

                    RoundedRectangle(cornerRadius: 1)
                        .fill(active ? barColor : barColor.opacity(0.2))
                        .frame(width: 5)
                }
            }
        }
    }
}

// MARK: - Waveform View

/// Simple oscilloscope-style waveform drawn from sample amplitudes.
private struct WaveformView: View {
    let samples: [Double]
    let color: Color

    var body: some View {
        Canvas { context, size in
            guard samples.count > 1 else { return }
            let stepX = size.width / CGFloat(samples.count - 1)
            let midY = size.height / 2

            var path = Path()
            for (i, sample) in samples.enumerated() {
                let x = CGFloat(i) * stepX
                let y = midY - CGFloat(sample - 0.5) * size.height
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }

            context.stroke(path, with: .color(color), lineWidth: 1.5)
        }
    }
}

// MARK: - Radar Sweep

/// Thin green line rotating 360 degrees inside a circular frame.
private struct RadarSweepView: View {
    let angle: Double
    let color: Color

    var body: some View {
        ZStack {
            // Faint ring
            Circle()
                .stroke(color.opacity(0.15), lineWidth: 0.5)

            // Cross-hairs
            Path { path in
                path.move(to: CGPoint(x: 100, y: 0))
                path.addLine(to: CGPoint(x: 100, y: 200))
                path.move(to: CGPoint(x: 0, y: 100))
                path.addLine(to: CGPoint(x: 200, y: 100))
            }
            .stroke(color.opacity(0.1), lineWidth: 0.5)

            // Sweep line
            Path { path in
                path.move(to: CGPoint(x: 100, y: 100))
                path.addLine(to: CGPoint(x: 100, y: 0))
            }
            .stroke(
                AngularGradient(
                    colors: [color.opacity(0.6), color.opacity(0)],
                    center: .center,
                    startAngle: .degrees(-5),
                    endAngle: .degrees(0)
                ),
                lineWidth: 1.5
            )
            .rotationEffect(.degrees(angle))
        }
    }
}

// MARK: - Viewfinder Brackets

/// L-shaped bracket corners framing the camera viewfinder.
private struct ViewfinderBrackets: Shape {
    func path(in rect: CGRect) -> Path {
        let len: CGFloat = 30
        var p = Path()

        // Top-left
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + len))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + len, y: rect.minY))

        // Top-right
        p.move(to: CGPoint(x: rect.maxX - len, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + len))

        // Bottom-right
        p.move(to: CGPoint(x: rect.maxX, y: rect.maxY - len))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - len, y: rect.maxY))

        // Bottom-left
        p.move(to: CGPoint(x: rect.minX + len, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - len))

        return p
    }
}

// MARK: - Preview

#Preview {
    ScannerView()
}
