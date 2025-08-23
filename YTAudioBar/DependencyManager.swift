import Foundation
import SwiftUI

class DependencyManager: ObservableObject {
    static let shared = DependencyManager()
    
    @Published var isDownloading = false
    @Published var downloadProgress = 0.0
    @Published var currentOperation = ""
    @Published var errorMessage: String?
    @Published var isComplete = false
    
    private let resourcesDirectory: URL
    private let ytdlpURL: URL
    private let ffmpegURL: URL
    
    struct DependencyInfo {
        let name: String
        let url: String
        let filename: String
        let isExecutable: Bool
    }
    
    private let dependencies: [DependencyInfo] = [
        DependencyInfo(
            name: "yt-dlp",
            url: "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos",
            filename: "yt-dlp",
            isExecutable: true
        ),
        DependencyInfo(
            name: "ffmpeg", 
            url: "https://evermeet.cx/ffmpeg/getrelease/ffmpeg/zip",
            filename: "ffmpeg.zip",
            isExecutable: false
        )
    ]
    
    private init() {
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.ilyass.YTAudioBar"
        let appSupportDirectory = appSupportURL.appendingPathComponent(bundleIdentifier)
        
        self.resourcesDirectory = appSupportDirectory.appendingPathComponent("Resources")
        self.ytdlpURL = resourcesDirectory.appendingPathComponent("yt-dlp")
        self.ffmpegURL = resourcesDirectory.appendingPathComponent("ffmpeg")
        
        createResourcesDirectory()
    }
    
    private func createResourcesDirectory() {
        try? FileManager.default.createDirectory(
            at: resourcesDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
    
    var allDependenciesExist: Bool {
        return FileManager.default.fileExists(atPath: ytdlpURL.path) &&
               FileManager.default.fileExists(atPath: ffmpegURL.path)
    }
    
    var ytdlpPath: String {
        return ytdlpURL.path
    }
    
    var ffmpegPath: String {
        return ffmpegURL.path
    }
    
    @MainActor
    func downloadDependencies() async {
        guard !isDownloading else { return }
        
        isDownloading = true
        downloadProgress = 0.0
        errorMessage = nil
        isComplete = false
        
        do {
            // Clean up any existing files first
            currentOperation = "Preparing download..."
            try await cleanupExistingFiles()
            
            let totalDependencies = dependencies.count
            
            for (index, dependency) in dependencies.enumerated() {
                currentOperation = "Downloading \(dependency.name)..."
                
                let destinationURL = resourcesDirectory.appendingPathComponent(dependency.filename)
                
                try await downloadFile(from: dependency.url, to: destinationURL)
                
                if dependency.name == "ffmpeg" {
                    currentOperation = "Extracting \(dependency.name)..."
                    try await extractFFmpeg(from: destinationURL)
                    try FileManager.default.removeItem(at: destinationURL)
                }
                
                if dependency.isExecutable {
                    try await makeExecutable(at: destinationURL)
                }
                
                downloadProgress = Double(index + 1) / Double(totalDependencies)
            }
            
            currentOperation = "Verifying dependencies..."
            try await verifyDependencies()
            
            downloadProgress = 1.0
            currentOperation = "Setup complete!"
            isComplete = true
            
        } catch {
            errorMessage = "Download failed: \(error.localizedDescription)"
            print("❌ Dependency download failed: \(error)")
        }
        
        isDownloading = false
    }
    
    private func cleanupExistingFiles() async throws {
        // Remove any existing files to avoid conflicts
        let filesToCleanup = [ytdlpURL, ffmpegURL]
        
        for fileURL in filesToCleanup {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }
    
    private func downloadFile(from urlString: String, to destinationURL: URL) async throws {
        guard let url = URL(string: urlString) else {
            throw DependencyError.invalidURL
        }
        
        // Remove existing file if it exists
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try? FileManager.default.removeItem(at: destinationURL)
        }
        
        // Create URLSession with timeout
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60.0 // 60 seconds
        config.timeoutIntervalForResource = 300.0 // 5 minutes
        let session = URLSession(configuration: config)
        
        let (tempURL, response) = try await session.download(from: url)
        
        // Validate response
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw DependencyError.downloadFailed("HTTP error: \(response)")
        }
        
        try FileManager.default.moveItem(at: tempURL, to: destinationURL)
    }
    
    private func extractFFmpeg(from zipURL: URL) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", zipURL.path, "-d", resourcesDirectory.path]
        process.currentDirectoryURL = resourcesDirectory
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw DependencyError.extractionFailed
        }
    }
    
    private func makeExecutable(at url: URL) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/chmod")
        process.arguments = ["+x", url.path]
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw DependencyError.permissionFailed
        }
    }
    
    private func verifyDependencies() async throws {
        // Basic file existence and executability check
        let filesToVerify = [
            ("yt-dlp", ytdlpURL),
            ("ffmpeg", ffmpegURL)
        ]
        
        for (name, url) in filesToVerify {
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw DependencyError.verificationFailed("\(name) file not found")
            }
            
            guard FileManager.default.isExecutableFile(atPath: url.path) else {
                throw DependencyError.verificationFailed("\(name) not executable")
            }
            
            // Check file size to ensure it's not corrupted
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                if let fileSize = attributes[.size] as? NSNumber, fileSize.intValue < 1000 {
                    throw DependencyError.verificationFailed("\(name) file too small (corrupted)")
                }
            } catch {
                throw DependencyError.verificationFailed("\(name) attributes check failed")
            }
        }
        
        print("✅ Dependencies verified successfully")
    }
}

enum DependencyError: LocalizedError {
    case invalidURL
    case extractionFailed
    case permissionFailed
    case verificationFailed(String)
    case downloadFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid download URL"
        case .extractionFailed:
            return "Failed to extract archive"
        case .permissionFailed:
            return "Failed to set executable permissions"
        case .verificationFailed(let dependency):
            return "Failed to verify \(dependency)"
        case .downloadFailed(let message):
            return "Download failed: \(message)"
        }
    }
}