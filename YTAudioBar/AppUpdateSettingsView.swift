import SwiftUI

struct AppUpdateSettingsView: View {
    @StateObject private var appUpdater = AppUpdater.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Version")
                        .font(.subheadline)
                    Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    appUpdater.manualUpdate()
                }) {
                    HStack(spacing: 4) {
                        if appUpdater.isCheckingForUpdates {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text("Check for Updates")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(appUpdater.isCheckingForUpdates)
            }
            
            if appUpdater.updateAvailable {
                Divider()
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Update Available!")
                            .font(.subheadline)
                            .foregroundColor(.green)
                        Text("Version \(appUpdater.latestVersion)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Download") {
                        if let url = URL(string: appUpdater.downloadURL) {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            
            if let errorMessage = appUpdater.errorMessage {
                Divider()
                
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text("Automatically checks for updates on app launch")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}