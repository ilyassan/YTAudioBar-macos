//
//  MediaKeyManager.swift
//  YTAudioBar
//
//  Created by Ilyass Anida on 11/10/2025.
//

import Foundation
import MediaPlayer
import AppKit

class MediaKeyManager: NSObject {
    static let shared = MediaKeyManager()

    private let commandCenter = MPRemoteCommandCenter.shared()
    private let nowPlayingInfoCenter = MPNowPlayingInfoCenter.default()
    private var audioManager: AudioManager?
    private var currentArtwork: MPMediaItemArtwork?
    private var artworkCache: [String: NSImage] = [:]

    private override init() {
        super.init()
    }

    // MARK: - Setup

    func setup(with audioManager: AudioManager) {
        self.audioManager = audioManager
        setupRemoteCommands()
        setupObservers()
        print("🎹 MediaKeyManager: Setup complete")
    }

    private func setupRemoteCommands() {
        // Play Command
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] event in
            print("🎹 MediaKey: Play command received")
            self?.handlePlayCommand()
            return .success
        }

        // Pause Command
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] event in
            print("🎹 MediaKey: Pause command received")
            self?.handlePauseCommand()
            return .success
        }

        // Toggle Play/Pause Command
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] event in
            print("🎹 MediaKey: Toggle Play/Pause command received")
            self?.handleTogglePlayPause()
            return .success
        }

        // Next Track Command
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] event in
            print("🎹 MediaKey: Next track command received")
            self?.handleNextTrack()
            return .success
        }

        // Previous Track Command
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] event in
            print("🎹 MediaKey: Previous track command received")
            self?.handlePreviousTrack()
            return .success
        }

        // Skip Forward Command (15 seconds)
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [NSNumber(value: 15)]
        commandCenter.skipForwardCommand.addTarget { [weak self] event in
            print("🎹 MediaKey: Skip forward command received")
            self?.handleSeekForward(interval: 15)
            return .success
        }

        // Skip Backward Command (15 seconds)
        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.preferredIntervals = [NSNumber(value: 15)]
        commandCenter.skipBackwardCommand.addTarget { [weak self] event in
            print("🎹 MediaKey: Skip backward command received")
            self?.handleSeekBackward(interval: 15)
            return .success
        }

        // Change Playback Position Command (scrubbing)
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            print("🎹 MediaKey: Change playback position to \(event.positionTime)")
            self?.handleChangePlaybackPosition(to: event.positionTime)
            return .success
        }

        // Note: Volume commands are not available on macOS via MPRemoteCommandCenter
        // System volume is controlled separately by the OS
        commandCenter.changePlaybackRateCommand.isEnabled = false // We handle playback rate internally
    }

    private func setupObservers() {
        guard let audioManager = audioManager else { return }

        // Observe track changes
        audioManager.$currentTrack
            .receive(on: DispatchQueue.main)
            .sink { [weak self] track in
                // Clear current artwork when track changes
                self?.currentArtwork = nil
                self?.updateNowPlayingInfo()
            }
            .store(in: &observers)

        // Observe playback state changes
        audioManager.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateNowPlayingInfo()
            }
            .store(in: &observers)

        // Observe position changes (throttled)
        audioManager.$currentPosition
            .throttle(for: .seconds(1), scheduler: DispatchQueue.main, latest: true)
            .sink { [weak self] _ in
                self?.updateNowPlayingInfo()
            }
            .store(in: &observers)

        // Observe duration changes
        audioManager.$duration
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateNowPlayingInfo()
            }
            .store(in: &observers)

        // Observe playback rate changes
        audioManager.$playbackRate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateNowPlayingInfo()
            }
            .store(in: &observers)
    }

    private var observers = Set<AnyCancellable>()

    // MARK: - Command Handlers

    private func handlePlayCommand() {
        Task { @MainActor in
            guard let audioManager = audioManager else { return }
            if !audioManager.isPlaying {
                audioManager.togglePlayPause()
            }
        }
    }

    private func handlePauseCommand() {
        Task { @MainActor in
            guard let audioManager = audioManager else { return }
            if audioManager.isPlaying {
                audioManager.togglePlayPause()
            }
        }
    }

    private func handleTogglePlayPause() {
        Task { @MainActor in
            audioManager?.togglePlayPause()
        }
    }

    private func handleNextTrack() {
        Task { @MainActor in
            await audioManager?.playNext()
        }
    }

    private func handlePreviousTrack() {
        Task { @MainActor in
            await audioManager?.playPrevious()
        }
    }

    private func handleSeekForward(interval: TimeInterval) {
        Task { @MainActor in
            guard let audioManager = audioManager else { return }
            let newPosition = min(audioManager.currentPosition + interval, audioManager.duration)
            audioManager.seek(to: newPosition)
        }
    }

    private func handleSeekBackward(interval: TimeInterval) {
        Task { @MainActor in
            guard let audioManager = audioManager else { return }
            let newPosition = max(audioManager.currentPosition - interval, 0)
            audioManager.seek(to: newPosition)
        }
    }

    private func handleChangePlaybackPosition(to position: TimeInterval) {
        Task { @MainActor in
            audioManager?.seek(to: position)
        }
    }

    // MARK: - Now Playing Info

    func updateNowPlayingInfo() {
        guard let audioManager = audioManager,
              let track = audioManager.currentTrack else {
            // Clear now playing info if no track
            nowPlayingInfoCenter.nowPlayingInfo = nil
            currentArtwork = nil
            return
        }

        // Start with existing info to preserve artwork
        var nowPlayingInfo = nowPlayingInfoCenter.nowPlayingInfo ?? [String: Any]()

        // Basic track info
        nowPlayingInfo[MPMediaItemPropertyTitle] = track.title
        nowPlayingInfo[MPMediaItemPropertyArtist] = track.uploader
        nowPlayingInfo[MPMediaItemPropertyAlbumTitle] = "YouTube"

        // Playback info
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = audioManager.duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = audioManager.currentPosition
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = audioManager.isPlaying ? Double(audioManager.playbackRate) : 0.0

        // Media type
        nowPlayingInfo[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue

        // Preserve existing artwork if available, or load new one
        if let existingArtwork = currentArtwork {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = existingArtwork
        } else if let thumbnailURL = track.thumbnailURL {
            // Load artwork asynchronously
            loadAndCacheArtwork(from: thumbnailURL, trackID: track.id) { [weak self] artwork in
                guard let self = self else { return }
                if let artwork = artwork {
                    self.currentArtwork = artwork
                    var updatedInfo = self.nowPlayingInfoCenter.nowPlayingInfo ?? [:]
                    updatedInfo[MPMediaItemPropertyArtwork] = artwork
                    self.nowPlayingInfoCenter.nowPlayingInfo = updatedInfo
                    print("🎹 MediaKey: Artwork loaded for \(track.title)")
                }
            }
        }

        // Set the now playing info
        nowPlayingInfoCenter.nowPlayingInfo = nowPlayingInfo

        print("🎹 MediaKey: Updated Now Playing info - \(track.title) by \(track.uploader)")
    }

    // MARK: - Artwork Handling

    private func loadAndCacheArtwork(from urlString: String, trackID: String, completion: @escaping (MPMediaItemArtwork?) -> Void) {
        // Check cache first
        if let cachedImage = artworkCache[trackID] {
            let artwork = MPMediaItemArtwork(boundsSize: cachedImage.size) { _ in cachedImage }
            completion(artwork)
            return
        }

        // Download artwork
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let data = data,
                  let image = NSImage(data: data) else {
                completion(nil)
                return
            }

            // Cache the image
            self?.artworkCache[trackID] = image

            // Create artwork
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }

            DispatchQueue.main.async {
                completion(artwork)
            }
        }.resume()
    }

    // MARK: - Cleanup

    func cleanup() {
        // Remove all targets
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        commandCenter.nextTrackCommand.removeTarget(nil)
        commandCenter.previousTrackCommand.removeTarget(nil)
        commandCenter.skipForwardCommand.removeTarget(nil)
        commandCenter.skipBackwardCommand.removeTarget(nil)
        commandCenter.changePlaybackPositionCommand.removeTarget(nil)

        // Clear observers
        observers.removeAll()

        // Clear now playing info
        nowPlayingInfoCenter.nowPlayingInfo = nil

        print("🎹 MediaKeyManager: Cleanup complete")
    }

    deinit {
        cleanup()
    }
}

// MARK: - Combine Import

import Combine
