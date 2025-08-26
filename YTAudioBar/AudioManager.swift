//
//  AudioManager.swift
//  YTAudioBar
//
//  Created by Ilyass Anida on 21/8/2025.
//

import Foundation
import AVFoundation
import Combine
import AppKit

class AudioManager: NSObject, ObservableObject {
    static let shared = AudioManager()
    
    private var player: AVPlayer?
    private var currentItem: AVPlayerItem?
    private var timeObserver: Any?
    private var timeObserverPlayer: AVPlayer? // Track which player the observer belongs to
    private var hasKVOObservers = false // Track if KVO observers are added
    private var endOfTrackTimer: Timer? // Timer to handle auto-advance based on yt-dlp duration
    
    // Performance optimization properties
    private var lastPositionUpdate: TimeInterval = 0
    private let positionUpdateThrottle: TimeInterval = 0.5 // Only update position every 0.5 seconds
    private var positionUpdateWorkItem: DispatchWorkItem?
    private var internalCurrentPosition: TimeInterval = 0 // Internal position tracker
    private var isAppActive: Bool = true // Track app activity for power management
    
    @Published var isPlaying = false
    @Published var currentPosition: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var volume: Float = 0.7
    @Published var playbackRate: Float = 1.0
    @Published var currentTrack: YTVideoInfo?
    @Published var isLoading = false
    @Published var error: Error?
    
    private let ytdlpManager = YTDLPManager.shared
    private let queueManager = QueueManager.shared
    private let notificationManager = NotificationManager.shared
    
    override init() {
        super.init()
        // No audio session setup needed on macOS
        
        // Set up app state monitoring for power management
        setupAppStateMonitoring()
    }
    
    private func setupAppStateMonitoring() {
        // Monitor app activation/deactivation for power optimization
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidResignActive),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )
    }
    
    @objc private func appDidBecomeActive() {
        isAppActive = true
        // Resume normal update frequency when app becomes active
        if isPlaying {
            setupTimeObserver()
        }
    }
    
    @objc private func appDidResignActive() {
        isAppActive = false
        // When app goes to background, remove time observer to save CPU
        // Audio will continue playing but UI updates will stop
        removeTimeObserver()
    }
    
    deinit {
        cleanup()
        // Remove app state observers
        NotificationCenter.default.removeObserver(self, name: NSApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSApplication.didResignActiveNotification, object: nil)
    }
    
    // MARK: - Setup
    
    private func setupTimeObserver() {
        // Remove existing time observer using the player it was added to
        removeTimeObserver()
        
        // Set up new time observer only if we have a player and app is active
        guard let currentPlayer = player, isAppActive else { return }
        
        // PERFORMANCE OPTIMIZATION: Reduce frequency from 0.1s to 1.0s to save CPU and battery
        // UI will still feel responsive with 1-second updates, but CPU usage will be 10x lower
        let interval = CMTime(seconds: 1.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        
        // Use main queue directly and simplify the update logic
        timeObserver = currentPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            
            let seconds = time.seconds
            
            // Only update if the time is valid and the change is significant
            guard seconds.isFinite && seconds >= 0 else { return }
            
            let now = Date().timeIntervalSince1970
            guard now - self.lastPositionUpdate >= self.positionUpdateThrottle else { return }
            
            self.lastPositionUpdate = now
            
            // Cancel any pending position update
            self.positionUpdateWorkItem?.cancel()
            
            // Simple, direct update to avoid nested dispatch calls
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                
                // Clamp position to not exceed duration
                if self.duration > 0 {
                    self.currentPosition = min(seconds, self.duration)
                } else {
                    self.currentPosition = seconds
                }
            }
            
            self.positionUpdateWorkItem = workItem
            // Execute immediately since we're already on main queue
            workItem.perform()
        }
        
        // Remember which player this observer belongs to
        timeObserverPlayer = currentPlayer
    }
    
    private func setupEndOfTrackTimer(duration: TimeInterval) {
        // Cancel any existing timer
        endOfTrackTimer?.invalidate()
        
        // Set up timer to fire slightly before the actual end (0.5 seconds early to account for any delays)
        let timerDuration = max(0.1, duration - 0.5)
        
        print("🕐 Setting up end-of-track timer for \(timerDuration) seconds (track duration: \(duration))")
        
        endOfTrackTimer = Timer.scheduledTimer(withTimeInterval: timerDuration, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.handleTrackEnd()
            }
        }
    }
    
    private func removeTimeObserver() {
        // Cancel any pending position updates
        positionUpdateWorkItem?.cancel()
        positionUpdateWorkItem = nil
        
        if let timeObserver = timeObserver, let observerPlayer = timeObserverPlayer {
            observerPlayer.removeTimeObserver(timeObserver)
            self.timeObserver = nil
            self.timeObserverPlayer = nil
        }
    }
    
    private func cleanup() {
        print("🧹 Starting cleanup process...")
        
        // Remove time observer properly
        removeTimeObserver()
        
        // Remove end of track timer
        if endOfTrackTimer != nil {
            print("🧹 Invalidating end-of-track timer...")
            endOfTrackTimer?.invalidate()
            endOfTrackTimer = nil
        }
        
        // Remove KVO observers safely
        if hasKVOObservers, let item = currentItem {
            print("🧹 Removing KVO observers...")
            item.removeObserver(self, forKeyPath: "status", context: nil)
            item.removeObserver(self, forKeyPath: "duration", context: nil)
            hasKVOObservers = false
        }
        
        // Remove notification observer for the current item
        if let item = currentItem {
            print("🧹 Removing notification observers...")
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: item)
        }
        
        // Clean up player and item
        if player != nil {
            print("🧹 Stopping and clearing player...")
            player?.pause()
            player?.replaceCurrentItem(with: nil) // Explicitly clear the current item
            player = nil
        }
        
        if currentItem != nil {
            print("🧹 Clearing current item...")
            currentItem = nil
        }
        
        print("✅ Cleanup complete")
    }
    
    // MARK: - Playback Control
    
    @MainActor
    func playLocalFile(track: YTVideoInfo, filePath: URL) async {
        isLoading = true
        error = nil
        
        print("🎵 Playing local file: \(filePath.path)")
        print("🔍 Debug: Track ID: \(track.id), Title: \(track.title)")
        
        // IMPORTANT: Clean up everything from previous track first
        cleanup()
        
        // Small delay to ensure cleanup is complete (reduced from 0.1s to 0.05s for better responsiveness)
        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        
        // Reset state
        currentPosition = 0
        duration = 0
        
        // Verify the file exists before creating player
        guard FileManager.default.fileExists(atPath: filePath.path) else {
            print("❌ Local file does not exist: \(filePath.path)")
            error = AudioError.invalidURL
            isLoading = false
            return
        }
        
        print("✅ Verified file exists: \(filePath.lastPathComponent)")
        
        // Create player item and player for local file
        currentItem = AVPlayerItem(url: filePath)
        player = AVPlayer(playerItem: currentItem)
        player?.volume = volume
        
        print("🔧 Created new AVPlayer for: \(filePath.lastPathComponent)")
        
        // Observe player item status - ONLY for the new item
        currentItem?.addObserver(self, forKeyPath: "status", options: [.new], context: nil)
        currentItem?.addObserver(self, forKeyPath: "duration", options: [.new], context: nil)
        hasKVOObservers = true
        
        // Listen for playback end notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidReachEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: currentItem
        )
        
        // Set current track
        currentTrack = track
        
        // For local files, we have reliable metadata from download time
        // Use the stored duration directly since it's more trustworthy than AVPlayer for our use case
        if track.duration > 0 {
            duration = Double(track.duration)
            print("🎯 Using stored metadata duration: \(track.duration) seconds (\(track.duration/60):\(String(format: "%02d", track.duration % 60)))")
            
            // Setup timer for auto-advance based on stored duration
            setupEndOfTrackTimer(duration: duration)
        }
        
        // Setup time observer for new player
        setupTimeObserver()
        
        // Start playback with current playback rate
        player?.play()
        player?.rate = playbackRate // Apply current playback rate
        isPlaying = true
        isLoading = false
        
        // Show notification
        notificationManager.showTrackStarted(track)
        
        print("Started playing local file: \(track.title)")
    }
    
    @MainActor
    func play(track: YTVideoInfo) async {
        isLoading = true
        error = nil
        
        // First, check if we have a local file for this track
        let downloadManager = MultiDownloadManager.shared
        if let localFilePath = downloadManager.findDownloadedFile(for: track.id) {
            print("🚀 Found local file for \(track.title) at: \(localFilePath.lastPathComponent)")
            print("🔍 Debug: Playing track ID: \(track.id), Title: \(track.title)")
            await playLocalFile(track: track, filePath: localFilePath)
            return
        }
        
        print("📡 No local file found, streaming from YouTube...")
        
        do {
            // IMPORTANT: Clean up everything from previous track first
            cleanup()
            
            // Reset state
            currentPosition = 0
            duration = 0
            
            // Extract audio URL using yt-dlp (this runs on background thread)
            let audioURL = try await ytdlpManager.extractAudioURL(videoID: track.id)
            
            // Create player item and player on main thread
            guard let url = URL(string: audioURL) else {
                error = AudioError.invalidURL
                isLoading = false
                return
            }
            
            print("🎵 Creating player for: \(audioURL)")
            currentItem = AVPlayerItem(url: url)
            player = AVPlayer(playerItem: currentItem)
            player?.volume = volume
            
            // Observe player item status - ONLY for the new item
            currentItem?.addObserver(self, forKeyPath: "status", options: [.new], context: nil)
            currentItem?.addObserver(self, forKeyPath: "duration", options: [.new], context: nil)
            hasKVOObservers = true
            
            // Listen for playback end notification
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(playerItemDidReachEnd),
                name: .AVPlayerItemDidPlayToEndTime,
                object: currentItem
            )
            
            // Set current track and use its duration as the authoritative source
            currentTrack = track
            
            // Use yt-dlp metadata duration instead of AVPlayer duration (which can be wrong)
            if track.duration > 0 {
                duration = Double(track.duration)
                print("🎯 Using yt-dlp duration: \(track.duration) seconds (\(track.duration/60):\(String(format: "%02d", track.duration % 60)))")
                
                // Setup timer for auto-advance based on accurate duration
                setupEndOfTrackTimer(duration: duration)
            }
            
            // Setup time observer for new player
            setupTimeObserver()
            
            // Start playback with current playback rate
            player?.play()
            player?.rate = playbackRate // Apply current playback rate
            isPlaying = true
            isLoading = false
            
            // Show notification
            notificationManager.showTrackStarted(track)
            
            print("Started playing: \(track.title)")
        } catch {
            self.error = error
            isLoading = false
            print("Failed to play track: \(error)")
        }
    }
    
    @MainActor
    func togglePlayPause() {
        guard let player = player else { return }
        
        if isPlaying {
            player.pause()
            isPlaying = false
            // Pause the timer when pausing playback
            endOfTrackTimer?.invalidate()
            endOfTrackTimer = nil
        } else {
            player.play()
            player.rate = playbackRate // Ensure rate is applied when resuming
            isPlaying = true
            // Resume timer when resuming playback
            if let track = currentTrack, track.duration > 0 {
                let remainingTime = duration - currentPosition
                if remainingTime > 0.5 {
                    setupEndOfTrackTimer(duration: remainingTime)
                }
            }
        }
    }
    
    @MainActor
    func pause() {
        player?.pause()
        isPlaying = false
        // Cancel timer when pausing
        endOfTrackTimer?.invalidate()
        endOfTrackTimer = nil
    }
    
    @MainActor
    func stop() {
        player?.pause()
        player?.seek(to: .zero)
        isPlaying = false
        currentPosition = 0
        // Cancel timer when stopping
        endOfTrackTimer?.invalidate()
        endOfTrackTimer = nil
    }
    
    @MainActor
    func seek(to position: TimeInterval) {
        let time = CMTime(seconds: position, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player?.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) // More precise seeking
        currentPosition = position
        lastPositionUpdate = Date().timeIntervalSince1970 // Reset throttle after manual seek
        
        // Recalculate timer for remaining time if playing
        if isPlaying, let track = currentTrack, track.duration > 0 {
            let remainingTime = duration - position
            if remainingTime > 0.5 {
                setupEndOfTrackTimer(duration: remainingTime)
            }
        }
    }
    
    @MainActor
    func setVolume(_ newVolume: Float) {
        volume = max(0, min(1, newVolume))
        player?.volume = volume
    }
    
    @MainActor
    func setPlaybackRate(_ rate: Float) {
        let clampedRate = max(0.25, min(2.0, rate))
        playbackRate = clampedRate
        player?.rate = isPlaying ? clampedRate : 0.0
    }
    
    // MARK: - Queue Navigation
    
    @MainActor
    func playNext() async {
        if let nextTrack = queueManager.playNext() {
            await play(track: nextTrack)
        }
    }
    
    @MainActor
    func playPrevious() async {
        if let previousTrack = queueManager.playPrevious() {
            await play(track: previousTrack)
        }
    }
    
    func canPlayNext() -> Bool {
        return queueManager.hasNext()
    }
    
    func canPlayPrevious() -> Bool {
        return queueManager.hasPrevious()
    }
    
    @MainActor
    private func handleTrackEnd() {
        print("🕐 Timer-based track end triggered: \(currentTrack?.title ?? "Unknown")")
        print("🏁 Queue has \(queueManager.queue.count) tracks, current index: \(queueManager.currentIndex)")
        
        // Cancel the timer as it's already fired
        endOfTrackTimer?.invalidate()
        endOfTrackTimer = nil
        
        isPlaying = false
        currentPosition = duration // Set to end position
        
        // Auto-advance to next track in queue - simplified since we're already on MainActor
        if let nextTrack = queueManager.playNext() {
            print("🎵 Auto-advancing to next track: \(nextTrack.title) (new index: \(queueManager.currentIndex))")
            // Show track ended notification
            if let current = currentTrack {
                notificationManager.showTrackEnded(current, hasNext: true)
            }
            Task {
                await play(track: nextTrack)
            }
        } else {
            print("🏁 End of queue reached - no more tracks to play")
            // Show track ended notification
            if let current = currentTrack {
                notificationManager.showTrackEnded(current, hasNext: false)
            }
            // Show queue empty notification
            notificationManager.showQueueEmpty()
        }
    }
    
    @objc private func playerItemDidReachEnd() {
        print("🏁 AVPlayer track ended notification (may be delayed): \(currentTrack?.title ?? "Unknown")")
        // Don't handle auto-advance here anymore, let the timer handle it
        // This is just for fallback logging
    }
    
    // MARK: - KVO Observer
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let playerItem = object as? AVPlayerItem else { return }
        
        // KVO callbacks for AVPlayerItem are already on main thread, no need to dispatch
        switch keyPath {
        case "status":
            switch playerItem.status {
            case .readyToPlay:
                // Don't set duration here, let the duration observer handle it
                break
            case .failed:
                DispatchQueue.main.async { [weak self] in
                    self?.error = playerItem.error ?? AudioError.playbackFailed
                    self?.isLoading = false
                }
            case .unknown:
                break
            @unknown default:
                break
            }
        case "duration":
            if playerItem.duration.isValid && !playerItem.duration.isIndefinite {
                let durationSeconds = playerItem.duration.seconds
                if durationSeconds.isFinite && durationSeconds > 0 {
                    print("📏 AVPlayer duration KVO fired - Duration: \(durationSeconds)")
                    
                    // Update duration if this is the current item
                    if playerItem === self.currentItem {
                        // For local files, prefer stored metadata duration (more reliable)
                        if let currentTrack = self.currentTrack,
                           let _ = MultiDownloadManager.shared.findDownloadedFile(for: currentTrack.id),
                           currentTrack.duration > 0 {
                            print("⚠️ AVPlayer duration ignored for local file - using stored metadata: \(self.duration) seconds")
                        } else if self.duration == 0 {
                            // For streaming or local files without metadata, use AVPlayer duration
                            DispatchQueue.main.async { [weak self] in
                                self?.duration = durationSeconds
                            }
                            print("✅ Duration from AVPlayer: \(durationSeconds) seconds (\(Int(durationSeconds/60)):\(String(format: "%02d", Int(durationSeconds) % 60)))")
                        } else {
                            print("⚠️ AVPlayer duration ignored - using stored duration: \(self.duration) seconds")
                        }
                    } else {
                        print("⚠️ Ignoring duration from old item")
                    }
                }
            }
        default:
            break
        }
    }
}

// MARK: - Error Types

enum AudioError: LocalizedError {
    case invalidURL
    case playbackFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid audio URL"
        case .playbackFailed:
            return "Audio playback failed"
        }
    }
}