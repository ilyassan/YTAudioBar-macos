//
//  MultiDownloadManager.swift
//  YTAudioBar
//
//  Created by Ilyass Anida on 22/8/2025.
//

import Foundation
import Combine

// Simplified - using only yt-dlp which works reliably

class MultiDownloadManager: ObservableObject {
    static let shared = MultiDownloadManager()
    
    @Published var activeDownloads: [String: DownloadProgress] = [:]
    @Published var completedDownloads: Set<String> = []
    
    private let ytdlpManager = YTDLPManager.shared
    private var downloadTasks: [String: Process] = [:]
    private let downloadsDirectory: URL
    private let notificationManager = NotificationManager.shared
    
    // Caching for performance
    private var filePathCache: [String: URL?] = [:]
    private var metadataCache: [String: YTVideoInfo?] = [:]
    private var lastCacheUpdate: Date = Date.distantPast
    private let cacheValidityDuration: TimeInterval = 30.0 // Cache valid for 30 seconds
    
    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        downloadsDirectory = appSupport.appendingPathComponent("YTAudioBar/Downloads")
        
        try? FileManager.default.createDirectory(at: downloadsDirectory, withIntermediateDirectories: true)
        loadCompletedDownloads()
    }
    
    // MARK: - Main Download Function
    
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
        
        activeDownloads[track.id] = DownloadProgress(
            videoID: track.id,
            progress: 0.0,
            speed: "Starting...",
            eta: "Calculating...",
            fileSize: "Unknown",
            isCompleted: false,
            error: nil
        )
        
        // Use yt-dlp directly since it works reliably
        try await downloadWithYTDLP(track: track)
        print("✅ Download completed successfully")
    }
    
    // MARK: - YT-DLP Download Implementation
    
    private func downloadWithYTDLP(track: YTVideoInfo) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: ytdlpManager.ytdlpPath)
            
            let safeTitle = sanitizeFilename(track.title)
            let safeUploader = sanitizeFilename(track.uploader)
            let filename = "\(safeTitle) - \(safeUploader).%(ext)s"
            let outputTemplate = downloadsDirectory.appendingPathComponent(filename).path
            
            // Use system ffmpeg if available
            let systemFFmpegPaths = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin"]
            var ffmpegLocation: String?
            
            for path in systemFFmpegPaths {
                if FileManager.default.fileExists(atPath: "\(path)/ffmpeg") && 
                   FileManager.default.fileExists(atPath: "\(path)/ffprobe") {
                    ffmpegLocation = path
                    break
                }
            }
            
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
                print("🔧 YT-DLP using system ffmpeg at: \(ffmpegLoc)")
            } else {
                process.arguments = [
                    "--extract-audio",
                    "--audio-format", "m4a",
                    "--audio-quality", "best",
                    "--output", outputTemplate,
                    "--newline",
                    "https://www.youtube.com/watch?v=\(track.id)"
                ]
                print("⚠️ YT-DLP without ffmpeg location")
            }
            
            setupProcessMonitoring(process: process, track: track, continuation: continuation)
        }
    }
    
    // MARK: - Process Monitoring
    
    private func setupProcessMonitoring(process: Process, track: YTVideoInfo, continuation: CheckedContinuation<Void, Error>) {
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        downloadTasks[track.id] = process
        
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
                print("🔍 YT-DLP stderr: \(error)")
                self?.parseDownloadProgress(output: error, for: track.id)
            }
        }
        
        process.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                self?.downloadTasks.removeValue(forKey: track.id)
                
                outputHandle.readabilityHandler = nil
                errorHandle.readabilityHandler = nil
                
                if process.terminationStatus == 0 {
                    print("✅ YT-DLP download completed successfully for: \(track.title)")
                    self?.markDownloadCompleted(track.id)
                    self?.saveTrackMetadata(track) // Save metadata when download completes
                    self?.notificationManager.showDownloadCompleted(track)
                    continuation.resume()
                } else {
                    print("❌ YT-DLP download failed with status: \(process.terminationStatus)")
                    let errorMessage = "YT-DLP failed with status \(process.terminationStatus)"
                    continuation.resume(throwing: YTDLPError.downloadFailed(errorMessage))
                }
            }
        }
        
        do {
            try process.run()
            print("🚀 YT-DLP download process started for: \(track.title)")
        } catch {
            downloadTasks.removeValue(forKey: track.id)
            continuation.resume(throwing: error)
        }
    }
    
    // MARK: - Progress Parsing
    
    private func parseDownloadProgress(output: String, for videoID: String) {
        DispatchQueue.main.async { [weak self] in
            let lines = output.components(separatedBy: .newlines)
            
            for line in lines {
                if line.contains("[download]") && line.contains("%") {
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
    
    // MARK: - Utility Functions
    
    @MainActor
    private func markDownloadCompleted(_ videoID: String) {
        activeDownloads.removeValue(forKey: videoID)
        completedDownloads.insert(videoID)
        saveCompletedDownloads()
        
        // Invalidate cache when new download completes
        invalidateCache()
    }
    
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
        
        let safeTitle = sanitizeFilename(title)
        let safeUploader = sanitizeFilename(uploader)
        let filename = "\(safeTitle) - \(safeUploader).m4a"
        let filePath = downloadsDirectory.appendingPathComponent(filename)
        
        return FileManager.default.fileExists(atPath: filePath.path) ? filePath : nil
    }
    
    // New method to find downloaded file by video ID only with caching
    func findDownloadedFile(for videoID: String) -> URL? {
        // Check if cache is still valid
        let now = Date()
        let cacheAge = now.timeIntervalSince(lastCacheUpdate)
        let shouldRefreshCache = cacheAge > cacheValidityDuration
        
        // Use cached result if available and cache is valid
        if !shouldRefreshCache, let cachedResult = filePathCache[videoID] {
            // Only log cache hit occasionally to reduce log spam
            if Int.random(in: 1...100) == 1 {
                print("💨 Cache hit for videoID: \(videoID) (age: \(String(format: "%.1f", cacheAge))s)")
            }
            return cachedResult
        }
        
        // Refresh cache if needed
        if shouldRefreshCache {
            refreshFilePathCache()
        }
        
        // Return cached result after potential refresh
        return filePathCache[videoID] ?? nil
    }
    
    private func refreshFilePathCache() {
        print("🔄 Refreshing file path cache...")
        filePathCache.removeAll()
        
        for videoID in completedDownloads {
            let filePath = performActualFileSearch(for: videoID)
            filePathCache[videoID] = filePath
        }
        
        lastCacheUpdate = Date()
        print("✅ File path cache refreshed with \(filePathCache.count) entries")
    }
    
    private func performActualFileSearch(for videoID: String) -> URL? {
        guard completedDownloads.contains(videoID) else { 
            return nil 
        }
        
        // First, try to find using metadata file to get the exact filename
        if let track = getCachedTrackMetadata(for: videoID) {
            let safeTitle = sanitizeFilename(track.title)
            let safeUploader = sanitizeFilename(track.uploader)
            let possibleFilenames = [
                "\(safeTitle) - \(safeUploader).m4a",
                "\(safeTitle) - \(safeUploader).webm",
                "\(safeTitle) - \(safeUploader).mp3"
            ]
            
            for filename in possibleFilenames {
                let filePath = downloadsDirectory.appendingPathComponent(filename)
                if FileManager.default.fileExists(atPath: filePath.path) {
                    return filePath
                }
            }
        }
        
        // Fallback: Search through all files and pick the best match
        do {
            let files = try FileManager.default.contentsOfDirectory(at: downloadsDirectory, includingPropertiesForKeys: nil)
            
            // Look for audio files (prefer m4a, but accept others)
            let audioExtensions = ["m4a", "webm", "mp3", "aac", "ogg"]
            let preferredExtensions = ["m4a", "mp3"] // Prefer these
            
            var candidateFiles: [(URL, Bool)] = []
            
            for file in files {
                let fileExtension = file.pathExtension.lowercased()
                
                if audioExtensions.contains(fileExtension) && FileManager.default.fileExists(atPath: file.path) {
                    let isPreferred = preferredExtensions.contains(fileExtension)
                    candidateFiles.append((file, isPreferred))
                }
            }
            
            // For fallback, just return the first file found (this is not ideal but better than nothing)
            return candidateFiles.first?.0
            
        } catch {
            print("❌ Error searching for downloaded file: \(error)")
            return nil
        }
    }
    
    func deleteDownload(for videoID: String, title: String, uploader: String) {
        guard let filePath = getDownloadedFilePath(for: videoID, title: title, uploader: uploader) else { return }
        
        do {
            // Delete the audio file
            try FileManager.default.removeItem(at: filePath)
            
            // Delete the metadata file
            let metadataFile = getMetadataFilePath(for: videoID)
            if FileManager.default.fileExists(atPath: metadataFile.path) {
                try FileManager.default.removeItem(at: metadataFile)
            }
            
            completedDownloads.remove(videoID)
            saveCompletedDownloads()
            
            // Invalidate cache when download is deleted
            invalidateCache()
            
            print("🗑️ Deleted download and metadata: \(title)")
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
    
    // MARK: - Cache Management
    
    private func invalidateCache() {
        print("🗑️ Invalidating file path and metadata cache")
        filePathCache.removeAll()
        metadataCache.removeAll()
        lastCacheUpdate = Date.distantPast
    }
    
    func clearCache() {
        invalidateCache()
    }
    
    // MARK: - Persistence
    
    private func loadCompletedDownloads() {
        let userDefaults = UserDefaults.standard
        if let downloadedIDs = userDefaults.array(forKey: "CompletedDownloads") as? [String] {
            completedDownloads = Set(downloadedIDs)
        }
    }
    
    func saveCompletedDownloads() {
        let userDefaults = UserDefaults.standard
        userDefaults.set(Array(completedDownloads), forKey: "CompletedDownloads")
    }
    
    // MARK: - Track Metadata Storage
    
    private func getMetadataFilePath(for videoID: String) -> URL {
        return downloadsDirectory.appendingPathComponent("\(videoID)_metadata.json")
    }
    
    private func sanitizeFilename(_ title: String) -> String {
        return title.replacingOccurrences(of: "[^a-zA-Z0-9 .-]", with: "", options: .regularExpression)
    }
    
    private func saveTrackMetadata(_ track: YTVideoInfo) {
        let metadataFile = getMetadataFilePath(for: track.id)
        
        do {
            let metadata: [String: Any] = [
                "id": track.id,
                "title": track.title,
                "uploader": track.uploader,
                "duration": track.duration,
                "thumbnailURL": track.thumbnailURL ?? "",
                "description": track.description ?? "",
                "downloadDate": Date().timeIntervalSince1970
            ]
            
            let jsonData = try JSONSerialization.data(withJSONObject: metadata, options: .prettyPrinted)
            try jsonData.write(to: metadataFile)
            print("💾 Saved metadata for: \(track.title)")
        } catch {
            print("❌ Failed to save metadata: \(error)")
        }
    }
    
    private func getCachedTrackMetadata(for videoID: String) -> YTVideoInfo? {
        // Check metadata cache first
        if let cachedMetadata = metadataCache[videoID] {
            return cachedMetadata
        }
        
        // Load from disk and cache the result
        let metadata = loadTrackMetadata(for: videoID)
        metadataCache[videoID] = metadata
        return metadata
    }
    
    private func loadTrackMetadata(for videoID: String) -> YTVideoInfo? {
        let metadataFile = getMetadataFilePath(for: videoID)
        
        guard FileManager.default.fileExists(atPath: metadataFile.path) else {
            return nil
        }
        
        do {
            let jsonData = try Data(contentsOf: metadataFile)
            let metadata = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
            
            guard let id = metadata?["id"] as? String,
                  let title = metadata?["title"] as? String,
                  let uploader = metadata?["uploader"] as? String,
                  let duration = metadata?["duration"] as? Int else {
                return nil
            }
            
            let thumbnailURL = metadata?["thumbnailURL"] as? String
            let description = metadata?["description"] as? String
            
            return YTVideoInfo(
                id: id,
                title: title,
                uploader: uploader,
                duration: duration,
                thumbnailURL: thumbnailURL?.isEmpty == false ? thumbnailURL : nil,
                audioURL: nil,
                description: description?.isEmpty == false ? description : nil
            )
        } catch {
            print("❌ Failed to load metadata for \(videoID): \(error)")
            return nil
        }
    }
    
    func getDownloadedTracks() -> [YTVideoInfo] {
        var tracks: [YTVideoInfo] = []
        
        for videoID in completedDownloads {
            if let filePath = findDownloadedFile(for: videoID) {
                // Try to load metadata first (using cached version)
                if let track = getCachedTrackMetadata(for: videoID) {
                    tracks.append(track)
                } else {
                    // Fallback: Parse from filename (legacy support)
                    // For legacy files, we'll create minimal track info but won't be able to match specific files to video IDs accurately
                    let filename = filePath.lastPathComponent
                    let fileExtension = filePath.pathExtension
                    
                    let nameWithoutExtension = filename.replacingOccurrences(of: ".\(fileExtension)", with: "")
                    let components = nameWithoutExtension.components(separatedBy: " - ")
                    
                    let title = components.first ?? nameWithoutExtension
                    let uploader = components.count > 1 ? components[1] : "Unknown"
                    
                    // Use a placeholder ID for legacy files - this won't be perfectly accurate
                    let track = YTVideoInfo(
                        id: videoID,
                        title: title,
                        uploader: uploader,
                        duration: 0, // Unknown duration for legacy files
                        thumbnailURL: "https://i.ytimg.com/vi/\(videoID)/hqdefault.jpg",
                        audioURL: nil,
                        description: nil
                    )
                    
                    tracks.append(track)
                }
            }
        }
        
        // Sort by download date (newest first) if metadata available, otherwise by file modification date
        tracks.sort { first, second in
            // Try to get download dates from metadata
            let firstMetadata = getMetadataFilePath(for: first.id)
            let secondMetadata = getMetadataFilePath(for: second.id)
            
            if FileManager.default.fileExists(atPath: firstMetadata.path) &&
               FileManager.default.fileExists(atPath: secondMetadata.path) {
                do {
                    let firstData = try Data(contentsOf: firstMetadata)
                    let secondData = try Data(contentsOf: secondMetadata)
                    let firstMeta = try JSONSerialization.jsonObject(with: firstData) as? [String: Any]
                    let secondMeta = try JSONSerialization.jsonObject(with: secondData) as? [String: Any]
                    
                    if let firstDate = firstMeta?["downloadDate"] as? TimeInterval,
                       let secondDate = secondMeta?["downloadDate"] as? TimeInterval {
                        return firstDate > secondDate
                    }
                } catch {}
            }
            
            // Fallback to file modification date
            guard let firstPath = findDownloadedFile(for: first.id),
                  let secondPath = findDownloadedFile(for: second.id),
                  let firstDate = (try? firstPath.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate,
                  let secondDate = (try? secondPath.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate else {
                return false
            }
            return firstDate > secondDate
        }
        
        return tracks
    }
    
    func getFileSize(for videoID: String) -> Int64 {
        guard let filePath = findDownloadedFile(for: videoID) else { return 0 }
        return Int64((try? filePath.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0)
    }
    
    func getFileSizes(for videoIDs: [String]) -> Int64 {
        return videoIDs.reduce(0) { total, videoID in
            total + getFileSize(for: videoID)
        }
    }
    
    func deleteDownloads(for videoIDs: [String]) {
        for videoID in videoIDs {
            if let filePath = findDownloadedFile(for: videoID) {
                do {
                    // Delete the audio file
                    try FileManager.default.removeItem(at: filePath)
                    
                    // Delete the metadata file
                    let metadataFile = getMetadataFilePath(for: videoID)
                    if FileManager.default.fileExists(atPath: metadataFile.path) {
                        try FileManager.default.removeItem(at: metadataFile)
                    }
                    
                    completedDownloads.remove(videoID)
                    print("🗑️ Deleted download and metadata: \(filePath.lastPathComponent)")
                } catch {
                    print("❌ Failed to delete download: \(error)")
                }
            }
        }
        saveCompletedDownloads()
        
        // Invalidate cache after batch deletion
        invalidateCache()
    }
}