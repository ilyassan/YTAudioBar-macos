//
//  DownloadManager.swift
//  YTAudioBar
//
//  Created by Ilyass Anida on 22/8/2025.
//

import Foundation
import Combine

struct DownloadProgress {
    let videoID: String
    let progress: Double // 0.0 to 1.0
    let speed: String
    let eta: String
    let fileSize: String
    let isCompleted: Bool
    let error: String?
}

class DownloadManager: ObservableObject {
    static let shared = DownloadManager()
    
    @Published var activeDownloads: [String: DownloadProgress] = [:]
    @Published var completedDownloads: Set<String> = []
    
    private let ytdlpManager = YTDLPManager.shared
    private var downloadTasks: [String: Process] = [:]
    private let downloadsDirectory: URL
    private let notificationManager = NotificationManager.shared
    
    init() {
        // Create downloads directory in app support
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        downloadsDirectory = appSupport.appendingPathComponent("YTAudioBar/Downloads")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
        
        // Load completed downloads from disk
        loadCompletedDownloads()
    }
    
    // MARK: - Download Operations
    
    @MainActor
    func downloadTrack(_ track: YTVideoInfo) async throws {
        guard !activeDownloads.keys.contains(track.id) else {
            print("⚠️ Download already in progress for: \(track.title)")
            return
        }
        
        guard !completedDownloads.contains(track.id) else {
            print("⚠️ Track already downloaded: \(track.title)")
            return
        }
        
        print("📥 Starting download: \(track.title)")
        
        // Initialize progress
        activeDownloads[track.id] = DownloadProgress(
            videoID: track.id,
            progress: 0.0,
            speed: "Starting...",
            eta: "Calculating...",
            fileSize: "Unknown",
            isCompleted: false,
            error: nil
        )
        
        do {
            try await downloadWithProgress(track: track)
        } catch {
            // Remove from active downloads on error
            activeDownloads.removeValue(forKey: track.id)
            
            // Provide better error messaging for ffmpeg issues
            if let ytdlpError = error as? YTDLPError,
               case .downloadFailed(let message) = ytdlpError,
               message.contains("ffmpeg") || message.contains("ffprobe") {
                throw YTDLPError.downloadFailed("FFmpeg not available. Please ensure the app bundle includes ffmpeg binaries.")
            }
            
            throw error
        }
    }
    
    private func downloadWithProgress(track: YTVideoInfo) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: ytdlpManager.ytdlpPath)
            
            // Create safe filename
            let safeTitle = track.title.replacingOccurrences(of: "[^a-zA-Z0-9 .-]", with: "", options: .regularExpression)
            let filename = "\(safeTitle) - \(track.uploader).%(ext)s"
            let outputTemplate = downloadsDirectory.appendingPathComponent(filename).path
            
            print("🔍 Debug: outputTemplate = '\(outputTemplate)'")
            
            // Try different ffmpeg strategies
            var ffmpegLocation: String?
            
            // Strategy 1: Try system ffmpeg first
            let systemFFmpegPaths = [
                "/opt/homebrew/bin",
                "/usr/local/bin", 
                "/usr/bin"
            ]
            
            for path in systemFFmpegPaths {
                let ffmpegPath = "\(path)/ffmpeg"
                let ffprobePath = "\(path)/ffprobe"
                
                if FileManager.default.fileExists(atPath: ffmpegPath) && FileManager.default.fileExists(atPath: ffprobePath) {
                    print("✅ Found system ffmpeg at: \(path)")
                    testBinary(at: ffmpegPath, name: "system ffmpeg")
                    testBinary(at: ffprobePath, name: "system ffprobe")
                    ffmpegLocation = path
                    break
                }
            }
            
            // Strategy 2: If system ffmpeg not available, try bundled (but they seem corrupted)
            if ffmpegLocation == nil {
                print("⚠️ No system ffmpeg found, trying bundled binaries...")
                print("🔍 Debug: ytdlpManager.ffmpegPath = '\(ytdlpManager.ffmpegPath)'")
                print("🔍 Debug: ytdlpManager.ffprobePath = '\(ytdlpManager.ffprobePath)'")
                
                let ffmpegExists = FileManager.default.fileExists(atPath: ytdlpManager.ffmpegPath)
                let ffprobeExists = FileManager.default.fileExists(atPath: ytdlpManager.ffprobePath)
                print("🔍 Debug: ffmpeg exists at source: \(ffmpegExists)")
                print("🔍 Debug: ffprobe exists at source: \(ffprobeExists)")
                
                if ffmpegExists && ffprobeExists {
                    print("🔍 Debug: Testing bundled binaries...")
                    testBinary(at: ytdlpManager.ffmpegPath, name: "bundled ffmpeg")
                    testBinary(at: ytdlpManager.ffprobePath, name: "bundled ffprobe")
                    
                    // Create temp directory for bundled binaries
                    let tempDirectory = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("ytaudiobar_ffmpeg")
                    
                    do {
                        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
                        
                        let tempFFmpegPath = tempDirectory.appendingPathComponent("ffmpeg").path
                        let tempFFprobePath = tempDirectory.appendingPathComponent("ffprobe").path
                        
                        // Remove existing symlinks if any
                        try? FileManager.default.removeItem(atPath: tempFFmpegPath)
                        try? FileManager.default.removeItem(atPath: tempFFprobePath)
                        
                        try FileManager.default.createSymbolicLink(atPath: tempFFmpegPath, withDestinationPath: ytdlpManager.ffmpegPath)
                        try FileManager.default.createSymbolicLink(atPath: tempFFprobePath, withDestinationPath: ytdlpManager.ffprobePath)
                        
                        ffmpegLocation = tempDirectory.path
                        print("✅ Using bundled ffmpeg with symlinks at: \(ffmpegLocation!)")
                    } catch {
                        print("❌ Failed to set up bundled ffmpeg: \(error)")
                    }
                }
            }
            
            // Configure yt-dlp arguments based on available ffmpeg
            if let ffmpegLoc = ffmpegLocation {
                process.arguments = [
                    "--extract-audio",
                    "--audio-format", "m4a",
                    "--audio-quality", "best",
                    "--output", outputTemplate,
                    "--newline",
                    "--ffmpeg-location", ffmpegLoc,
                    "https://www.youtube.com/watch?v=\(track.id)"
                ]
                print("🔧 Using ffmpeg location: \(ffmpegLoc)")
            } else {
                // Try without ffmpeg-location (yt-dlp might find system ffmpeg)
                process.arguments = [
                    "--extract-audio",
                    "--audio-format", "m4a", 
                    "--audio-quality", "best",
                    "--output", outputTemplate,
                    "--newline",
                    "https://www.youtube.com/watch?v=\(track.id)"
                ]
                print("⚠️ No ffmpeg location specified, letting yt-dlp find it")
            }
            
            print("🔧 Download command: \(ytdlpManager.ytdlpPath) \(process.arguments?.joined(separator: " ") ?? "")")
            
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            // Store process for cancellation
            downloadTasks[track.id] = process
            
            // Set up progress monitoring
            let outputHandle = outputPipe.fileHandleForReading
            let errorHandle = errorPipe.fileHandleForReading
            
            outputHandle.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                if !data.isEmpty {
                    let output = String(data: data, encoding: .utf8) ?? ""
                    self?.parseDownloadProgress(output: output, for: track.id)
                }
            }
            
            errorHandle.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                if !data.isEmpty {
                    let error = String(data: data, encoding: .utf8) ?? ""
                    print("🔍 Debug: yt-dlp stderr: \(error)")
                    self?.parseDownloadProgress(output: error, for: track.id)
                }
            }
            
            process.terminationHandler = { [weak self] process in
                print("🔍 Debug: Process terminated with status: \(process.terminationStatus)")
                
                DispatchQueue.main.async {
                    self?.downloadTasks.removeValue(forKey: track.id)
                    
                    // Clean up handlers
                    outputHandle.readabilityHandler = nil
                    errorHandle.readabilityHandler = nil
                    
                    if process.terminationStatus == 0 {
                        // Download completed successfully
                        print("✅ Download completed successfully for: \(track.title)")
                        self?.markDownloadCompleted(track.id)
                        self?.notificationManager.showDownloadCompleted(track)
                        continuation.resume()
                    } else {
                        // Download failed
                        print("❌ Download failed with termination status: \(process.terminationStatus)")
                        let errorMessage = "Download failed with status \(process.terminationStatus)"
                        self?.activeDownloads[track.id] = DownloadProgress(
                            videoID: track.id,
                            progress: 0.0,
                            speed: "",
                            eta: "",
                            fileSize: "",
                            isCompleted: false,
                            error: "Download failed"
                        )
                        
                        self?.notificationManager.showDownloadFailed(track, error: errorMessage)
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            self?.activeDownloads.removeValue(forKey: track.id)
                        }
                        
                        continuation.resume(throwing: YTDLPError.downloadFailed(errorMessage))
                    }
                }
            }
            
            do {
                print("🔍 Debug: About to start process with executable: \(process.executableURL?.path ?? "nil")")
                print("🔍 Debug: Process arguments: \(process.arguments ?? [])")
                try process.run()
                print("🚀 Download process started for: \(track.title)")
                print("🔍 Debug: Process PID: \(process.processIdentifier)")
            } catch {
                print("❌ Failed to start download process: \(error)")
                downloadTasks.removeValue(forKey: track.id)
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func parseDownloadProgress(output: String, for videoID: String) {
        DispatchQueue.main.async { [weak self] in
            let lines = output.components(separatedBy: .newlines)
            
            for line in lines {
                if line.contains("[download]") && line.contains("%") {
                    // Parse progress line: [download] 45.6% of 3.2MiB at 1.2MiB/s ETA 00:02
                    let components = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    
                    var progress: Double = 0.0
                    var speed = ""
                    var eta = ""
                    var fileSize = ""
                    
                    for (index, component) in components.enumerated() {
                        if component.hasSuffix("%") {
                            let percentString = component.replacingOccurrences(of: "%", with: "")
                            progress = Double(percentString) ?? 0.0
                            progress = progress / 100.0
                        } else if component == "of" && index + 1 < components.count {
                            fileSize = components[index + 1]
                        } else if component == "at" && index + 1 < components.count {
                            speed = components[index + 1]
                        } else if component == "ETA" && index + 1 < components.count {
                            eta = components[index + 1]
                        }
                    }
                    
                    self?.activeDownloads[videoID] = DownloadProgress(
                        videoID: videoID,
                        progress: progress,
                        speed: speed,
                        eta: eta,
                        fileSize: fileSize,
                        isCompleted: progress >= 1.0,
                        error: nil
                    )
                }
            }
        }
    }
    
    @MainActor
    private func markDownloadCompleted(_ videoID: String) {
        activeDownloads.removeValue(forKey: videoID)
        completedDownloads.insert(videoID)
        saveCompletedDownloads()
        print("✅ Download completed: \(videoID)")
    }
    
    // MARK: - Download Management
    
    func cancelDownload(for videoID: String) {
        guard let process = downloadTasks[videoID] else { return }
        
        process.terminate()
        downloadTasks.removeValue(forKey: videoID)
        
        DispatchQueue.main.async { [weak self] in
            self?.activeDownloads.removeValue(forKey: videoID)
        }
        
        print("❌ Download cancelled: \(videoID)")
    }
    
    func isDownloaded(_ videoID: String) -> Bool {
        return completedDownloads.contains(videoID)
    }
    
    func isDownloading(_ videoID: String) -> Bool {
        return activeDownloads.keys.contains(videoID)
    }
    
    func getDownloadedFilePath(for videoID: String, title: String, uploader: String) -> URL? {
        guard completedDownloads.contains(videoID) else { return nil }
        
        let safeTitle = title.replacingOccurrences(of: "[^a-zA-Z0-9 .-]", with: "", options: .regularExpression)
        let filename = "\(safeTitle) - \(uploader).m4a"
        let filePath = downloadsDirectory.appendingPathComponent(filename)
        
        return FileManager.default.fileExists(atPath: filePath.path) ? filePath : nil
    }
    
    // MARK: - Persistence
    
    private func loadCompletedDownloads() {
        let userDefaults = UserDefaults.standard
        if let downloadedIDs = userDefaults.array(forKey: "CompletedDownloads") as? [String] {
            completedDownloads = Set(downloadedIDs)
        }
    }
    
    private func saveCompletedDownloads() {
        let userDefaults = UserDefaults.standard
        userDefaults.set(Array(completedDownloads), forKey: "CompletedDownloads")
    }
    
    // MARK: - File Management
    
    func deleteDownload(for videoID: String, title: String, uploader: String) {
        guard let filePath = getDownloadedFilePath(for: videoID, title: title, uploader: uploader) else { return }
        
        do {
            try FileManager.default.removeItem(at: filePath)
            completedDownloads.remove(videoID)
            saveCompletedDownloads()
            print("🗑️ Deleted download: \(title)")
        } catch {
            print("❌ Failed to delete download: \(error)")
        }
    }
    
    func getDownloadsDirectorySize() -> String {
        guard let enumerator = FileManager.default.enumerator(at: downloadsDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return "Unknown"
        }
        
        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                  let fileSize = resourceValues.fileSize else { continue }
            totalSize += Int64(fileSize)
        }
        
        return ByteCountFormatter().string(fromByteCount: totalSize)
    }
    
    // MARK: - Debug Helper
    
    private func testBinary(at path: String, name: String) {
        print("🧪 Testing \(name) at: \(path)")
        
        guard FileManager.default.fileExists(atPath: path) else {
            print("❌ \(name) does not exist at path")
            return
        }
        
        // Check if executable
        guard FileManager.default.isExecutableFile(atPath: path) else {
            print("❌ \(name) is not executable")
            return
        }
        
        // Try to run with --version
        let testProcess = Process()
        testProcess.executableURL = URL(fileURLWithPath: path)
        testProcess.arguments = ["--version"]
        
        let pipe = Pipe()
        testProcess.standardOutput = pipe
        testProcess.standardError = pipe
        
        do {
            try testProcess.run()
            testProcess.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            if testProcess.terminationStatus == 0 {
                let firstLine = output.components(separatedBy: .newlines).first ?? ""
                print("✅ \(name) works: \(firstLine)")
            } else {
                print("⚠️ \(name) returned status \(testProcess.terminationStatus): \(output)")
            }
        } catch {
            print("❌ Failed to test \(name): \(error)")
        }
    }
}