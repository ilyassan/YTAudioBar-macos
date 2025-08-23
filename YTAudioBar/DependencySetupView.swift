import SwiftUI

struct DependencySetupView: View {
    @StateObject private var dependencyManager = DependencyManager.shared
    @Binding var isPresented: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            headerSection
            
            if dependencyManager.isComplete {
                successSection
            } else if dependencyManager.errorMessage != nil {
                errorSection
            } else {
                downloadSection
            }
            
            buttonSection
        }
        .padding(30)
        .frame(width: 500, height: 400)
        .background(Color(.windowBackgroundColor))
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)
            
            Text("Welcome to YTAudioBar")
                .font(.title)
                .fontWeight(.semibold)
            
            Text("We need to download some dependencies to get you started")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var downloadSection: some View {
        VStack(spacing: 16) {
            if dependencyManager.isDownloading {
                VStack(spacing: 8) {
                    ProgressView(value: dependencyManager.downloadProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(height: 8)
                    
                    Text(dependencyManager.currentOperation)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        Image(systemName: "play.circle")
                            .foregroundColor(.blue)
                        Text("yt-dlp")
                            .fontWeight(.medium)
                        Spacer()
                        Text("~35MB")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(8)
                    
                    HStack(spacing: 12) {
                        Image(systemName: "waveform")
                            .foregroundColor(.green)
                        Text("ffmpeg")
                            .fontWeight(.medium)
                        Spacer()
                        Text("~60MB")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    private var successSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.green)
            
            Text("Setup Complete!")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("All dependencies have been downloaded successfully")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var errorSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Download Failed")
                .font(.title2)
                .fontWeight(.semibold)
            
            if let error = dependencyManager.errorMessage {
                Text(error)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }
    
    private var buttonSection: some View {
        HStack(spacing: 12) {
            if dependencyManager.isComplete {
                Button("Get Started") {
                    closeWindow()
                }
                .buttonStyle(PrimaryButtonStyle())
            } else if dependencyManager.errorMessage != nil {
                Button("Try Again") {
                    Task {
                        await dependencyManager.downloadDependencies()
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                
                Button("Cancel") {
                    closeWindow()
                }
                .buttonStyle(SecondaryButtonStyle())
            } else if dependencyManager.isDownloading {
                Button("Downloading...") {
                }
                .disabled(true)
                .buttonStyle(PrimaryButtonStyle())
            } else {
                Button("Download Dependencies") {
                    Task {
                        await dependencyManager.downloadDependencies()
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                
                Button("Cancel") {
                    closeWindow()
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }
    
    private func closeWindow() {
        // Close the window via NSApplication
        if let window = NSApplication.shared.windows.first(where: { $0.title == "YTAudioBar Setup" }) {
            window.close()
        }
        isPresented = false
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(configuration.isPressed ? Color.accentColor.opacity(0.8) : Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(configuration.isPressed ? Color(.controlBackgroundColor).opacity(0.8) : Color(.controlBackgroundColor))
            .foregroundColor(.primary)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}