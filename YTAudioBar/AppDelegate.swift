//
//  AppDelegate.swift
//  YTAudioBar
//
//  Created by Ilyass Anida on 21/8/2025.
//

import Cocoa
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBar: NSStatusBar!
    var statusBarItem: NSStatusItem!
    var popover: NSPopover!
    private var audioManager = AudioManager.shared
    private var cancellables: Set<AnyCancellable> = []
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon to make it a proper menu bar app
        NSApp.setActivationPolicy(.accessory)
        
        // Create the status bar item
        statusBar = NSStatusBar.system
        statusBarItem = statusBar.statusItem(withLength: NSStatusItem.squareLength)
        
        // Set the status bar button
        if let statusBarButton = statusBarItem.button {
            updateMenuBarIcon(isPlaying: false)
            statusBarButton.imagePosition = .imageOnly
            statusBarButton.action = #selector(togglePopover(_:))
            statusBarButton.target = self
            statusBarButton.toolTip = "YTAudioBar - Click to open"
        }
        
        // Listen to audio manager state changes
        setupAudioManagerObservers()
        
        // Perform automatic yt-dlp update check (silent)
        performAutomaticYTDLPUpdate()
        
        // Create the popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 420, height: 520)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: MenuBarContentView()
                .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
        )
    }
    
    @objc func togglePopover(_ sender: AnyObject?) {
        if statusBarItem.button != nil {
            if popover.isShown {
                closePopover()
            } else {
                showPopover()
            }
        }
    }
    
    func showPopover() {
        guard let button = statusBarItem.button else { return }
        
        // Activate the app when showing popover
        NSApp.activate(ignoringOtherApps: true)
        
        // Show popover
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
        
        // Visual feedback - highlight the status bar button
        button.highlight(true)
    }
    
    func closePopover() {
        popover.performClose(nil)
        
        // Remove highlight from status bar button
        if let button = statusBarItem.button {
            button.highlight(false)
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Clean up resources
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        return false
    }
    
    // MARK: - Menu Bar Icon Management
    
    private func setupAudioManagerObservers() {
        // Observe playback state changes
        audioManager.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPlaying in
                self?.updateMenuBarIcon(isPlaying: isPlaying)
            }
            .store(in: &cancellables)
        
        // Observe current track changes for tooltip
        audioManager.$currentTrack
            .receive(on: DispatchQueue.main)
            .sink { [weak self] track in
                self?.updateTooltip(track: track)
            }
            .store(in: &cancellables)
    }
    
    private func updateMenuBarIcon(isPlaying: Bool) {
        guard let statusBarButton = statusBarItem.button else { return }
        
        let iconName = isPlaying ? "play.fill" : "music.note"
        let image = NSImage(systemSymbolName: iconName, accessibilityDescription: "YTAudioBar")
        image?.size = NSSize(width: 18, height: 18)
        
        // Add visual feedback for playing state
        if isPlaying {
            image?.isTemplate = false
            statusBarButton.image = image
            // Add subtle animation or color change for playing state
            statusBarButton.appearsDisabled = false
        } else {
            image?.isTemplate = true
            statusBarButton.image = image
            statusBarButton.appearsDisabled = false
        }
    }
    
    private func updateTooltip(track: YTVideoInfo?) {
        guard let statusBarButton = statusBarItem.button else { return }
        
        if let track = track {
            statusBarButton.toolTip = "YTAudioBar - Now Playing: \(track.title)"
        } else {
            statusBarButton.toolTip = "YTAudioBar - Click to open"
        }
    }
    
    // MARK: - Automatic yt-dlp Updates
    
    private func performAutomaticYTDLPUpdate() {
        Task {
            do {
                // Check for updates silently
                let result = try await YTDLPManager.shared.checkForUpdates()
                
                // If update is available, perform it silently
                if result.hasUpdate {
                    print("🔄 Auto-updating yt-dlp from \(result.currentVersion) to \(result.latestVersion)")
                    try await YTDLPManager.shared.updateYTDLP()
                    print("✅ yt-dlp auto-update completed successfully")
                } else {
                    print("✅ yt-dlp is up to date (\(result.currentVersion))")
                }
            } catch {
                // Fail silently, don't show any error to user
                print("⚠️ Auto-update check failed: \(error.localizedDescription)")
            }
        }
    }
}