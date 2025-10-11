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

            // Automatic update check toggle
            Toggle("Automatically check for updates", isOn: $updaterViewModel.automaticallyChecksForUpdates)
                .font(.subheadline)

            // Automatic download toggle
            Toggle("Automatically download and install updates", isOn: $updaterViewModel.automaticallyDownloadsUpdates)
                .font(.subheadline)

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                if let lastCheck = updaterViewModel.lastUpdateCheckDate {
                    Text("Last checked: \(lastCheck.formatted())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Never checked for updates")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// ViewModel to bridge Sparkle with SwiftUI
class UpdaterViewModel: ObservableObject {
    private let updater: SPUUpdater
    @Published var canCheckForUpdates: Bool = true

    var automaticallyChecksForUpdates: Bool {
        get { updater.automaticallyChecksForUpdates }
        set { updater.automaticallyChecksForUpdates = newValue }
    }

    var automaticallyDownloadsUpdates: Bool {
        get { updater.automaticallyDownloadsUpdates }
        set { updater.automaticallyDownloadsUpdates = newValue }
    }

    var lastUpdateCheckDate: Date? {
        updater.lastUpdateCheckDate
    }

    init(updater: SPUUpdater) {
        self.updater = updater

        // Update canCheckForUpdates from Sparkle periodically
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.canCheckForUpdates = self.updater.canCheckForUpdates
            }
        }
    }

    func checkForUpdates() {
        updater.checkForUpdates()
    }
}
