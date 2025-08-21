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
    
    @Published var isPlaying = false
    @Published var currentPosition: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var volume: Float = 0.7
    @Published var playbackRate: Float = 1.0
    @Published var currentTrack: YTVideoInfo?
    @Published var isLoading = false
    @Published var error: Error?
    
    private let ytdlpManager = YTDLPManager.shared
    
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
        
        // Remove KVO observers safely
        if hasKVOObservers, let item = currentItem {
            item.removeObserver(self, forKeyPath: "status", context: nil)
            item.removeObserver(self, forKeyPath: "duration", context: nil)
            hasKVOObservers = false
        }
        
        // Remove notification observer
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: currentItem)
        
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
        } else {
            player.rate = playbackRate
            isPlaying = true
        }
    }
    
    @MainActor
    func pause() {
        player?.pause()
        isPlaying = false
    }
    
    @MainActor
    func stop() {
        player?.pause()
        player?.seek(to: .zero)
        isPlaying = false
        currentPosition = 0
    }
    
    @MainActor
    func seek(to position: TimeInterval) {
        let time = CMTime(seconds: position, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player?.seek(to: time)
        currentPosition = position
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
    
    @objc private func playerItemDidReachEnd() {
        Task { @MainActor in
            print("🏁 Track ended")
            isPlaying = false
            currentPosition = duration // Set to end position
            
            // Optionally: Auto-play next track, loop, etc.
            // For now, just stop at the end
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