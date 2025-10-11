import SwiftUI
import Sparkle

struct AppUpdateSettingsView: View {
    @ObservedObject private var updaterViewModel: UpdaterViewModel

    init(updater: SPUUpdater) {
        self.updaterViewModel = UpdaterViewModel(updater: updater)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Version")
                        .font(.subheadline)
                    Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: {
                    updaterViewModel.checkForUpdates()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("Check for Updates")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(!updaterViewModel.canCheckForUpdates)
            }

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Last checked: \(updaterViewModel.lastUpdateCheckDate?.formatted() ?? "Never")")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Automatically checks for updates on launch and every 24 hours")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Updates download and install automatically in the background")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// ViewModel to bridge Sparkle with SwiftUI
class UpdaterViewModel: ObservableObject {
    private let updater: SPUUpdater
    @Published var canCheckForUpdates: Bool = true // Always allow manual checks

    var lastUpdateCheckDate: Date? {
        updater.lastUpdateCheckDate
    }

    init(updater: SPUUpdater) {
        self.updater = updater
        // Ensure automatic updates are enabled by default
        updater.automaticallyDownloadsUpdates = true

        // Update canCheckForUpdates from Sparkle periodically
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                // Keep it true always, but use Sparkle's status as reference
                self.canCheckForUpdates = true
            }
        }
    }

    func checkForUpdates() {
        updater.checkForUpdates()
    }
}