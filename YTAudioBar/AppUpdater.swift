import Foundation
import SwiftUI

class AppUpdater: ObservableObject {
    static let shared = AppUpdater()
    
    @Published var isCheckingForUpdates = false
    @Published var updateAvailable = false
    @Published var latestVersion = ""
    @Published var downloadURL = ""
    @Published var errorMessage: String?
    
    private let currentVersion: String
    private let githubRepo = "ilyassan/YTAudioBar-macos"
    
    private init() {
        // Get current app version from bundle
        self.currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    @MainActor
    func checkForUpdates(silent: Bool = false) async {
        guard !isCheckingForUpdates else { return }
        
        print("🔄 [AppUpdater] Starting update check (silent: \(silent))")
        print("🔄 [AppUpdater] Current version: \(currentVersion)")
        
        isCheckingForUpdates = true
        errorMessage = nil
        updateAvailable = false
        
        do {
            let result = try await checkGitHubReleases()
            
            print("🔄 [AppUpdater] Check result - Latest: \(result.latestVersion), Has update: \(result.hasUpdate)")
            
            if result.hasUpdate {
                updateAvailable = true
                latestVersion = result.latestVersion
                downloadURL = result.downloadURL
                
                if !silent {
                    print("🔄 Update available: v\(currentVersion) → v\(result.latestVersion)")
                    showUpdateAlert()
                }
            } else {
                if !silent {
                    print("✅ App is up to date (v\(currentVersion))")
                }
            }
            
        } catch {
            errorMessage = error.localizedDescription
            if !silent {
                print("⚠️ Update check failed: \(error.localizedDescription)")
            }
        }
        
        isCheckingForUpdates = false
    }
    
    private func checkGitHubReleases() async throws -> UpdateResult {
        guard let url = URL(string: "https://api.github.com/repos/\(githubRepo)/releases/latest") else {
            throw UpdateError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw UpdateError.networkError("HTTP error: \(response)")
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tagName = json["tag_name"] as? String,
              let assets = json["assets"] as? [[String: Any]] else {
            throw UpdateError.invalidResponse
        }
        
        // Find the .dmg asset
        guard let dmgAsset = assets.first(where: { asset in
            if let name = asset["name"] as? String {
                return name.hasSuffix(".dmg")
            }
            return false
        }),
        let downloadURL = dmgAsset["browser_download_url"] as? String else {
            throw UpdateError.noDownloadURL
        }
        
        let latestVersion = tagName.replacingOccurrences(of: "v", with: "")
        let hasUpdate = compareVersions(current: currentVersion, latest: latestVersion)
        
        return UpdateResult(
            hasUpdate: hasUpdate,
            currentVersion: currentVersion,
            latestVersion: latestVersion,
            downloadURL: downloadURL
        )
    }
    
    private func compareVersions(current: String, latest: String) -> Bool {
        // Simple version comparison - can be improved for complex versions
        let currentComponents = current.split(separator: ".").compactMap { Int($0) }
        let latestComponents = latest.split(separator: ".").compactMap { Int($0) }
        
        for i in 0..<max(currentComponents.count, latestComponents.count) {
            let currentPart = i < currentComponents.count ? currentComponents[i] : 0
            let latestPart = i < latestComponents.count ? latestComponents[i] : 0
            
            if latestPart > currentPart {
                return true
            } else if latestPart < currentPart {
                return false
            }
        }
        
        return false // Versions are equal
    }
    
    private func showUpdateAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Update Available"
            alert.informativeText = "Version \(self.latestVersion) is available. Would you like to download it?"
            alert.addButton(withTitle: "Download")
            alert.addButton(withTitle: "Later")
            alert.alertStyle = .informational
            
            if alert.runModal() == .alertFirstButtonReturn {
                self.openDownloadURL()
            }
        }
    }
    
    private func openDownloadURL() {
        guard let url = URL(string: downloadURL) else { return }
        NSWorkspace.shared.open(url)
    }
    
    func manualUpdate() {
        Task {
            await checkForUpdates(silent: false)
        }
    }
    
    // Debug method for testing
    func testUpdateWithVersion(_ testVersion: String) {
        print("🧪 [AppUpdater] Testing with simulated current version: \(testVersion)")
        // Temporarily override current version for testing
        let originalVersion = currentVersion
        // Note: This would require making currentVersion mutable, but for now we'll test with project version
        Task {
            await checkForUpdates(silent: false)
        }
    }
}

struct UpdateResult {
    let hasUpdate: Bool
    let currentVersion: String
    let latestVersion: String
    let downloadURL: String
}

enum UpdateError: LocalizedError {
    case invalidURL
    case networkError(String)
    case invalidResponse
    case noDownloadURL
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid GitHub API URL"
        case .networkError(let message):
            return "Network error: \(message)"
        case .invalidResponse:
            return "Invalid response from GitHub API"
        case .noDownloadURL:
            return "No download URL found in release"
        }
    }
}