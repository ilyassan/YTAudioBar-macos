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
    
    struct DependencyInfo {
        let name: String
        let url: String
        let filename: String
        let isExecutable: Bool
    }
    
    private lazy var dependencies: [DependencyInfo] = {
        return [
            DependencyInfo(
                name: "yt-dlp",
                url: "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos",
                filename: "yt-dlp",
                isExecutable: true
            )
        ]
    }()
    
    private init() {
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.ilyass.YTAudioBar"
        let appSupportDirectory = appSupportURL.appendingPathComponent(bundleIdentifier)
        
        self.resourcesDirectory = appSupportDirectory.appendingPathComponent("Resources")
        self.ytdlpURL = resourcesDirectory.appendingPathComponent("yt-dlp")
        
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
        return FileManager.default.fileExists(atPath: ytdlpURL.path)
    }
    
    var ytdlpPath: String {
        return ytdlpURL.path
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
                
                try await downloadFile(from: dependency.url, to: destinationURL, dependencyIndex: index, totalDependencies: totalDependencies)
                
                
                if dependency.isExecutable {
                    try await makeExecutable(at: destinationURL)
                }
                
                // Progress is now updated in real-time by the download delegate
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
        if FileManager.default.fileExists(atPath: ytdlpURL.path) {
            try? FileManager.default.removeItem(at: ytdlpURL)
        }
    }
    
    private func downloadFile(from urlString: String, to destinationURL: URL, dependencyIndex: Int, totalDependencies: Int) async throws {
        guard let url = URL(string: urlString) else {
            throw DependencyError.invalidURL
        }
        
        // Remove existing file if it exists
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try? FileManager.default.removeItem(at: destinationURL)
        }
        
        // Create URLSession with timeout
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60.0
        config.timeoutIntervalForResource = 300.0
        let session = URLSession(configuration: config)
        
        // Get response first to get content length
        let (asyncBytes, response) = try await session.bytes(from: url)
        
        // Validate response
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            throw DependencyError.downloadFailed("HTTP error: \(response)")
        }
        
        // Get expected total bytes for progress calculation
        let expectedContentLength = httpResponse.expectedContentLength > 0 ? httpResponse.expectedContentLength : 0
        
        // Create temporary file for writing
        let tempURL = destinationURL.appendingPathExtension("tmp")
        
        // Ensure parent directory exists
        let parentDir = destinationURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        
        var totalBytesWritten: Int64 = 0
        var buffer = Data()
        let bufferSize = 8192 // 8KB buffer
        
        // Create file handle for writing
        FileManager.default.createFile(atPath: tempURL.path, contents: nil)
        let fileHandle = try FileHandle(forWritingTo: tempURL)
        defer { 
            try? fileHandle.close()
        }
        
        // Process bytes in chunks for better performance
        for try await byte in asyncBytes {
            buffer.append(byte)
            
            // Write in chunks when buffer is full
            if buffer.count >= bufferSize {
                fileHandle.write(buffer)
                totalBytesWritten += Int64(buffer.count)
                buffer.removeAll()
                
                // Update progress
                let individualProgress = expectedContentLength > 0 ? 
                    Double(totalBytesWritten) / Double(expectedContentLength) : 0.0
                
                // Calculate overall progress across all dependencies
                let baseProgress = Double(dependencyIndex) / Double(totalDependencies)
                let progressIncrement = individualProgress / Double(totalDependencies)
                let overallProgress = baseProgress + progressIncrement
                
                await MainActor.run {
                    self.downloadProgress = overallProgress
                }
            }
        }
        
        // Write remaining bytes in buffer
        if !buffer.isEmpty {
            fileHandle.write(buffer)
            totalBytesWritten += Int64(buffer.count)
        }
        
        // Ensure final progress update
        let finalProgress = Double(dependencyIndex + 1) / Double(totalDependencies)
        await MainActor.run {
            self.downloadProgress = finalProgress
        }
        
        // Move temp file to final destination
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.moveItem(at: tempURL, to: destinationURL)
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
        // Basic file existence and executability check for yt-dlp only
        let filesToVerify = [
            ("yt-dlp", ytdlpURL)
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
    case permissionFailed
    case verificationFailed(String)
    case downloadFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid download URL"
        case .permissionFailed:
            return "Failed to set executable permissions"
        case .verificationFailed(let dependency):
            return "Failed to verify \(dependency)"
        case .downloadFailed(let message):
            return "Download failed: \(message)"
        }
    }
}

