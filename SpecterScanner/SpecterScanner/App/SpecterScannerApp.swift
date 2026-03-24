import SwiftUI

// MARK: - App Entry Point

@main
struct SpecterScannerApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @State private var dossierVM = DossierViewModel()
    @State private var hasCompletedLaunchRitual = false

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedLaunchRitual {
                    MainContentView()
                } else {
                    LaunchRitualView(onComplete: {
                        withAnimation(.easeInOut(duration: 0.6)) {
                            hasCompletedLaunchRitual = true
                        }
                    })
                }
            }
            .environment(dossierVM)
            .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Portrait Orientation Lock

final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        .portrait
    }
}

// MARK: - Main Content View

struct MainContentView: View {

    @Environment(DossierViewModel.self) private var dossierVM

    var body: some View {
        NavigationStack {
            ScannerView()
        }
    }
}
