//
//  YTDLPManager.swift
//  YTAudioBar
//
//  Created by Ilyass Anida on 21/8/2025.
//

import Foundation
import Combine

struct YTVideoInfo {
    let id: String
    let title: String
    let uploader: String
    let duration: Int
    let thumbnailURL: String?
    let audioURL: String?
    let description: String?
}

class YTDLPManager: ObservableObject {
    static let shared = YTDLPManager()
    
    var ytdlpPath: String // Make public for DownloadManager access
    private var downloadTasks: [String: Process] = [:]
    
    init() {
        // Use DependencyManager for runtime dependencies
        let dependencyManager = DependencyManager.shared
        
        // Set paths from DependencyManager
        ytdlpPath = dependencyManager.ytdlpPath
        
        // Fallback to system paths if dependencies don't exist
        if !FileManager.default.fileExists(atPath: ytdlpPath) {
            let systemPaths = [
                "/usr/local/bin/yt-dlp",
                "/opt/homebrew/bin/yt-dlp",
                "/usr/bin/yt-dlp"
            ]
            
            for path in systemPaths {
                if FileManager.default.fileExists(atPath: path) {
                    ytdlpPath = path
                    break
                }
            }
        }
        
        
        print("YTDLPManager using yt-dlp at: \(ytdlpPath)")
    }
    
    // MARK: - Search Functionality
    
    func search(query: String, musicMode: Bool = false) async throws -> [YTVideoInfo] {
        return try await withCheckedThrowingContinuation { continuation in
            // First verify yt-dlp exists and is executable
            guard FileManager.default.fileExists(atPath: ytdlpPath) else {
                continuation.resume(throwing: YTDLPError.binaryNotFound)
                return
            }
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: ytdlpPath)
            
            // Different search strategies based on mode
            let searchQuery: String
            if musicMode {
                // For music mode, add music-related keywords to prioritize music content
                searchQuery = "ytsearch10:\(query) music song audio"
            } else {
                // General YouTube search
                searchQuery = "ytsearch10:\(query)"
            }
            
            process.arguments = [
                "--dump-json",
                "--flat-playlist", 
                "--playlist-end", "10", // Limit to 10 results
                searchQuery
            ]
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            print("Executing: \(ytdlpPath) \(process.arguments?.joined(separator: " ") ?? "")")
            
            do {
                try process.run()
                
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                
                let output = String(data: outputData, encoding: .utf8) ?? ""
                let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
                
                process.waitUntilExit()
                
                print("yt-dlp exit status: \(process.terminationStatus)")
                if !errorOutput.isEmpty {
                    print("yt-dlp stderr: \(errorOutput)")
                }
                if !output.isEmpty {
                    print("yt-dlp stdout (first 500 chars): \(String(output.prefix(500)))")
                    
                    // Debug thumbnail URLs
                    let results = parseSearchResults(output)
                    for result in results.prefix(2) {
                        print("🖼️ Thumbnail URL for '\(result.title)': \(result.thumbnailURL ?? "nil")")
                    }
                }
                
                if process.terminationStatus == 0 {
                    let results = parseSearchResults(output)
                    continuation.resume(returning: results)
                } else {
                    let errorMessage = errorOutput.isEmpty ? "Exit code \(process.terminationStatus)" : errorOutput
                    continuation.resume(throwing: YTDLPError.searchFailed("Search failed: \(errorMessage)"))
                }
            } catch {
                print("Failed to run yt-dlp: \(error)")
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func parseSearchResults(_ output: String) -> [YTVideoInfo] {
        let lines = output.components(separatedBy: .newlines)
        var results: [YTVideoInfo] = []
        
        for line in lines {
            guard !line.isEmpty,
                  let data = line.data(using: .utf8) else { continue }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let id = json["id"] as? String,
                   let title = json["title"] as? String,
                   let uploader = json["uploader"] as? String {
                    
                    let duration = json["duration"] as? Int ?? 0
                    
                    // Get the best thumbnail URL
                    let thumbnailURL = getBestThumbnailURL(from: json)
                    
                    let videoInfo = YTVideoInfo(
                        id: id,
                        title: title,
                        uploader: uploader,
                        duration: duration,
                        thumbnailURL: thumbnailURL,
                        audioURL: nil,
                        description: json["description"] as? String
                    )
                    
                    results.append(videoInfo)
                }
            } catch {
                print("Failed to parse JSON line: \(error)")
            }
        }
        
        return results
    }
    
    private func getBestThumbnailURL(from json: [String: Any]) -> String? {
        // First try to get thumbnails array for best quality
        if let thumbnails = json["thumbnails"] as? [[String: Any]] {
            // Look for medium quality thumbnail (good balance of quality/size)
            for thumbnail in thumbnails {
                if let url = thumbnail["url"] as? String,
                   let width = thumbnail["width"] as? Int,
                   width >= 320 && width <= 640 {
                    return url
                }
            }
            
            // Fallback to any thumbnail with URL
            for thumbnail in thumbnails {
                if let url = thumbnail["url"] as? String {
                    return url
                }
            }
        }
        
        // Fallback to simple thumbnail field
        if let thumbnailURL = json["thumbnail"] as? String {
            return thumbnailURL
        }
        
        // Last resort: construct YouTube thumbnail URL from ID
        if let id = json["id"] as? String {
            return "https://i.ytimg.com/vi/\(id)/hqdefault.jpg"
        }
        
        return nil
    }
    
    // MARK: - Audio URL Extraction
    
    func extractAudioURL(videoID: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: ytdlpPath)
            process.arguments = [
                "--get-url",
                "--format", "bestaudio[ext=m4a]/bestaudio",
                "https://www.youtube.com/watch?v=\(videoID)"
            ]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            
            do {
                try process.run()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                
                process.waitUntilExit()
                
                if process.terminationStatus == 0 && !output.isEmpty {
                    continuation.resume(returning: output)
                } else {
                    continuation.resume(throwing: YTDLPError.urlExtractionFailed("Failed to extract audio URL"))
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    // MARK: - Download Functionality
    
    func downloadAudio(videoID: String, outputPath: String, quality: String = "best") async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: ytdlpPath)
            
            var arguments = [
                "--extract-audio",
                "--audio-format", "m4a",
                "--output", outputPath,
                "https://www.youtube.com/watch?v=\(videoID)"
            ]
            
            if quality != "best" {
                arguments.append(contentsOf: ["--audio-quality", quality])
            }
            
            process.arguments = arguments
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            // Store the process for potential cancellation
            downloadTasks[videoID] = process
            
            do {
                try process.run()
                
                process.terminationHandler = { process in
                    DispatchQueue.main.async {
                        self.downloadTasks.removeValue(forKey: videoID)
                        
                        if process.terminationStatus == 0 {
                            continuation.resume()
                        } else {
                            continuation.resume(throwing: YTDLPError.downloadFailed("Download failed with status \(process.terminationStatus)"))
                        }
                    }
                }
            } catch {
                downloadTasks.removeValue(forKey: videoID)
                continuation.resume(throwing: error)
            }
        }
    }
    
    // MARK: - Utility Functions
    
    func cancelDownload(videoID: String) {
        if let process = downloadTasks[videoID] {
            process.terminate()
            downloadTasks.removeValue(forKey: videoID)
        }
    }
    
    func getVersion() async -> String? {
        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: ytdlpPath)
            process.arguments = ["--version"]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            
            do {
                try process.run()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                
                process.waitUntilExit()
                
                continuation.resume(returning: process.terminationStatus == 0 ? output : nil)
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }
    
    func isAvailable() async -> Bool {
        let version = await getVersion()
        return version != nil
    }
    
    // MARK: - Update Management
    struct UpdateResult {
        let hasUpdate: Bool
        let currentVersion: String
        let latestVersion: String
    }
    
    func getCurrentVersion() async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: self.ytdlpPath)
        process.arguments = ["--version"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"
        
        return output
    }
    
    func checkForUpdates() async throws -> UpdateResult {
        // Get current version
        let currentVersion = try await getCurrentVersion()
        
        // Get latest version from GitHub API
        guard let url = URL(string: "https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest") else {
            throw NSError(domain: "UpdateError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid API URL"])
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tagName = json["tag_name"] as? String else {
            throw NSError(domain: "UpdateError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid API response"])
        }
        
        let latestVersion = tagName
        let hasUpdate = currentVersion != latestVersion
        
        return UpdateResult(hasUpdate: hasUpdate, currentVersion: currentVersion, latestVersion: latestVersion)
    }
    
    func updateYTDLP() async throws {
        // Use yt-dlp's self-update functionality
        let process = Process()
        process.executableURL = URL(fileURLWithPath: self.ytdlpPath)
        process.arguments = ["--update"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let error = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "UpdateError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Update failed: \(error)"])
        }
    }
}

// MARK: - Error Types

enum YTDLPError: LocalizedError {
    case searchFailed(String)
    case urlExtractionFailed(String)
    case downloadFailed(String)
    case binaryNotFound
    
    var errorDescription: String? {
        switch self {
        case .searchFailed(let message):
            return "Search failed: \(message)"
        case .urlExtractionFailed(let message):
            return "URL extraction failed: \(message)"
        case .downloadFailed(let message):
            return "Download failed: \(message)"
        case .binaryNotFound:
            return "yt-dlp binary not found"
        }
    }
}

// MARK: - Extensions

extension ProcessInfo {
    var machineHardwareName: String {
        var sysinfo = utsname()
        let result = uname(&sysinfo)
        guard result == EXIT_SUCCESS else { return "unknown" }
        
        let machine = withUnsafePointer(to: &sysinfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0)
            }
        }
        
        return machine ?? "unknown"
    }
}
