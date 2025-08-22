//
//  DownloadsView.swift
//  YTAudioBar
//
//  Created by Ilyass Anida on 22/8/2025.
//

import SwiftUI

struct DownloadsView: View {
    @Binding var currentTrack: Track?
    @ObservedObject var audioManager: AudioManager
    @StateObject private var downloadManager = MultiDownloadManager.shared
    @State private var selectedTracks: Set<String> = []
    @State private var isSelectionMode = false
    
    // PERFORMANCE OPTIMIZATION: Cache downloaded tracks and only refresh when needed
    @State private var cachedDownloadedTracks: [YTVideoInfo] = []
    @State private var lastCacheRefresh: Date = Date.distantPast
    
    var downloadedTracks: [YTVideoInfo] {
        // Return cached tracks - updates happen via onReceive/onChange
        return cachedDownloadedTracks
    }
    
    var selectedSize: Int64 {
        // Only calculate when in selection mode to avoid unnecessary computation
        guard isSelectionMode && !selectedTracks.isEmpty else { return 0 }
        return downloadManager.getFileSizes(for: Array(selectedTracks))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Downloads header
            DownloadsHeaderView(
                downloadManager: downloadManager,
                isSelectionMode: $isSelectionMode,
                selectedTracks: selectedTracks,
                selectedSize: selectedSize,
                onDeleteSelected: deleteSelectedTracks,
                onSelectAll: selectAllTracks,
                onClearSelection: clearSelection
            )
            
            if downloadManager.activeDownloads.isEmpty && downloadManager.completedDownloads.isEmpty {
                EmptyDownloadsView()
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        // Active downloads section
                        if !downloadManager.activeDownloads.isEmpty {
                            DownloadsSectionHeader(title: "Downloading", count: downloadManager.activeDownloads.count)
                            
                            ForEach(Array(downloadManager.activeDownloads.keys), id: \.self) { videoID in
                                if let progress = downloadManager.activeDownloads[videoID] {
                                    ActiveDownloadRow(
                                        progress: progress,
                                        downloadManager: downloadManager
                                    )
                                }
                            }
                        }
                        
                        // Completed downloads section
                        if !downloadedTracks.isEmpty {
                            DownloadsSectionHeader(title: "Downloaded", count: downloadedTracks.count)
                            
                            ForEach(downloadedTracks, id: \.id) { track in
                                UnifiedTrackRow(
                                    track: track,
                                    context: .download(
                                        isSelected: selectedTracks.contains(track.id),
                                        isSelectionMode: isSelectionMode,
                                        isCurrentTrack: audioManager.currentTrack?.id == track.id,
                                        onPlay: { playTrack(track) },
                                        onToggleSelection: { toggleSelection(for: track.id) }
                                    ),
                                    audioManager: audioManager
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
            }
        }
        .onAppear {
            // Refresh cache when view appears
            refreshDownloadedTracksCache()
        }
        .onChange(of: downloadManager.completedDownloads) { _ in
            // Refresh cache when downloads change
            Task { @MainActor in
                refreshDownloadedTracksCache()
            }
        }
        .onReceive(Timer.publish(every: 5.0, on: .main, in: .common).autoconnect()) { _ in
            // Periodic refresh every 5 seconds (only if cache is stale)
            let now = Date()
            if now.timeIntervalSince(lastCacheRefresh) > 4.0 {
                refreshDownloadedTracksCache()
            }
        }
    }
    
    private func refreshDownloadedTracksCache() {
        cachedDownloadedTracks = downloadManager.getDownloadedTracks()
        lastCacheRefresh = Date()
    }
    
    private func playTrack(_ track: YTVideoInfo) {
        Task { @MainActor in
            await audioManager.play(track: track)
        }
    }
    
    private func toggleSelection(for videoID: String) {
        if selectedTracks.contains(videoID) {
            selectedTracks.remove(videoID)
        } else {
            selectedTracks.insert(videoID)
        }
    }
    
    private func selectAllTracks() {
        selectedTracks = Set(downloadedTracks.map { $0.id })
    }
    
    private func clearSelection() {
        selectedTracks.removeAll()
        isSelectionMode = false
    }
    
    private func deleteSelectedTracks() {
        downloadManager.deleteDownloads(for: Array(selectedTracks))
        selectedTracks.removeAll()
        isSelectionMode = false
    }
}

struct DownloadsHeaderView: View {
    @ObservedObject var downloadManager: MultiDownloadManager
    @Binding var isSelectionMode: Bool
    let selectedTracks: Set<String>
    let selectedSize: Int64
    let onDeleteSelected: () -> Void
    let onSelectAll: () -> Void
    let onClearSelection: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                if isSelectionMode {
                    Text("Select Downloads")
                        .font(.headline)
                        .fontWeight(.semibold)
                } else {
                    Text("Downloads")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                if isSelectionMode {
                    // Selection mode buttons
                    HStack(spacing: 8) {
                        Button("Select All", action: onSelectAll)
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Button("Cancel", action: onClearSelection)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    // Normal mode buttons
                    HStack(spacing: 8) {
                        if !downloadManager.completedDownloads.isEmpty {
                            Button(action: { isSelectionMode = true }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle")
                                        .font(.system(size: 14))
                                    Text("Select")
                                        .font(.caption)
                                }
                                .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                            .help("Select downloads to delete")
                        }
                        
                        if !downloadManager.activeDownloads.isEmpty {
                            Button(action: {
                                // Cancel all downloads
                                for videoID in downloadManager.activeDownloads.keys {
                                    downloadManager.cancelDownload(for: videoID)
                                }
                            }) {
                                Image(systemName: "stop.circle")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                            .help("Cancel all downloads")
                        }
                    }
                }
            }
            
            // Selection info or storage info
            HStack {
                if isSelectionMode && !selectedTracks.isEmpty {
                    Text("\(selectedTracks.count) selected • \(ByteCountFormatter().string(fromByteCount: selectedSize))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button("Delete Selected", action: onDeleteSelected)
                        .font(.caption)
                        .foregroundColor(.red)
                        .disabled(selectedTracks.isEmpty)
                } else if !downloadManager.completedDownloads.isEmpty {
                    Text("Storage used: \(downloadManager.getDownloadsDirectorySize())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.controlBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.secondary.opacity(0.2)),
            alignment: .bottom
        )
    }
}

struct EmptyDownloadsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("No Downloads")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Downloaded tracks will appear here.\nUse the download button on any track to start downloading.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

struct DownloadsSectionHeader: View {
    let title: String
    let count: Int
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("(\(count))")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
}

struct ActiveDownloadRow: View {
    let progress: DownloadProgress
    @ObservedObject var downloadManager: MultiDownloadManager
    
    var body: some View {
        HStack(spacing: 12) {
            // Progress indicator
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: progress.progress)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                if progress.progress < 0.01 {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Text("\(Int(progress.progress * 100))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                }
            }
            .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Video ID: \(progress.videoID)")
                    .font(.headline)
                    .lineLimit(1)
                
                HStack {
                    if !progress.speed.isEmpty {
                        Text(progress.speed)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if !progress.fileSize.isEmpty {
                        Text("• \(progress.fileSize)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if !progress.eta.isEmpty {
                        Text("• ETA: \(progress.eta)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                if let error = progress.error {
                    Text("Error: \(error)")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            Spacer()
            
            // Cancel button
            Button(action: {
                downloadManager.cancelDownload(for: progress.videoID)
            }) {
                Image(systemName: "xmark.circle")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}

