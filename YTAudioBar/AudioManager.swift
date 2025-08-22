//
//  AudioManager.swift
//  YTAudioBar
//
//  Created by Ilyass Anida on 21/8/2025.
//

import Foundation
import AVFoundation
import Combine

class AudioManager: NSObject, ObservableObject {
    static let shared = AudioManager()
    
    private var player: AVPlayer?
    private var currentItem: AVPlayerItem?
    private var timeObserver: Any?
    private var timeObserverPlayer: AVPlayer? // Track which player the observer belongs to
    private var hasKVOObservers = false // Track if KVO observers are added
    private var endOfTrackTimer: Timer? // Timer to handle auto-advance based on yt-dlp duration
    
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
    
    override init() {
        super.init()
        // No audio session setup needed on macOS
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Setup
    
    private func setupTimeObserver() {
        // Remove existing time observer using the player it was added to
        removeTimeObserver()
        
        // Set up new time observer only if we have a player
        guard let currentPlayer = player else { return }
        
        let interval = CMTime(seconds: 0.1, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = currentPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                let seconds = time.seconds
                if seconds.isFinite && seconds >= 0 {
                    // Clamp position to not exceed duration
                    if let duration = self?.duration, duration > 0 {
                        self?.currentPosition = min(seconds, duration)
                    } else {
                        self?.currentPosition = seconds
                    }
                }
            }
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
            Task { @MainActor in
                self?.handleTrackEnd()
            }
        }
    }
    
    private func removeTimeObserver() {
        if let timeObserver = timeObserver, let observerPlayer = timeObserverPlayer {
            observerPlayer.removeTimeObserver(timeObserver)
            self.timeObserver = nil
            self.timeObserverPlayer = nil
        }
    }
    
    private func cleanup() {
        // Remove time observer properly
        removeTimeObserver()
        
        // Remove end of track timer
        endOfTrackTimer?.invalidate()
        endOfTrackTimer = nil
        
        // Remove KVO observers safely
        if hasKVOObservers, let item = currentItem {
            item.removeObserver(self, forKeyPath: "status", context: nil)
            item.removeObserver(self, forKeyPath: "duration", context: nil)
            hasKVOObservers = false
        }
        
        // Remove notification observer for the current item
        if let item = currentItem {
            NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: item)
        }
        
        player?.pause()
        player = nil
        currentItem = nil
    }
    
    // MARK: - Playback Control
    
    @MainActor
    func play(track: YTVideoInfo) async {
        isLoading = true
        error = nil
        
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
            
            // Start playback
            player?.play()
            isPlaying = true
            isLoading = false
            
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
            player.rate = playbackRate
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
        player?.seek(to: time)
        currentPosition = position
        
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
        
        // Auto-advance to next track in queue
        Task { @MainActor in
            if let nextTrack = queueManager.playNext() {
                print("🎵 Auto-advancing to next track: \(nextTrack.title) (new index: \(queueManager.currentIndex))")
                await play(track: nextTrack)
            } else {
                print("🏁 End of queue reached - no more tracks to play")
            }
        }
    }
    
    @objc private func playerItemDidReachEnd() {
        Task { @MainActor in
            print("🏁 AVPlayer track ended notification (may be delayed): \(currentTrack?.title ?? "Unknown")")
            // Don't handle auto-advance here anymore, let the timer handle it
            // This is just for fallback logging
        }
    }
    
    // MARK: - KVO Observer
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let playerItem = object as? AVPlayerItem else { return }
        
        Task { @MainActor in
            switch keyPath {
            case "status":
                switch playerItem.status {
                case .readyToPlay:
                    // Don't set duration here, let the duration observer handle it
                    break
                case .failed:
                    self.error = playerItem.error ?? AudioError.playbackFailed
                    self.isLoading = false
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
                        
                        // Only update duration if this is the current item AND we don't already have duration from yt-dlp
                        if playerItem === self.currentItem && self.duration == 0 {
                            self.duration = durationSeconds
                            print("✅ Duration set from AVPlayer: \(durationSeconds) seconds (\(Int(durationSeconds/60)):\(String(format: "%02d", Int(durationSeconds) % 60)))")
                        } else if playerItem === self.currentItem {
                            print("⚠️ Ignoring AVPlayer duration, using yt-dlp duration: \(self.duration)")
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