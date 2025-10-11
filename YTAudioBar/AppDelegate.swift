//
//  AppDelegate.swift
//  YTAudioBar
//
//  Created by Ilyass Anida on 21/8/2025.
//

import Cocoa
import SwiftUI
import Combine
import Sparkle

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var statusBar: NSStatusBar!
    var statusBarItem: NSStatusItem!
    var popover: NSPopover!
    private var audioManager = AudioManager.shared
    private var mediaKeyManager = MediaKeyManager.shared
    private var cancellables: Set<AnyCancellable> = []
    private let updaterController: SPUStandardUpdaterController

    override init() {
        // Initialize Sparkle updater with automatic start
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()
    }

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
            statusBarButton.action = #selector(statusBarButtonClicked(_:))
            statusBarButton.target = self
            statusBarButton.toolTip = "YTAudioBar - Left click to open, Right click for options"
            
            // Enable right-click detection
            statusBarButton.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        // Listen to audio manager state changes
        setupAudioManagerObservers()

        // Setup media key manager for keyboard shortcuts and Control Center
        setupMediaKeyManager()

        // Check dependencies and show setup UI if needed
        checkDependenciesAndSetup()

        // Sparkle will automatically check for updates based on Info.plist settings

        // Create the popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 420, height: 520)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(
            rootView: MenuBarContentView(updaterController: updaterController)
                .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
        )
    }
    
    @objc func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        
        if event.type == .rightMouseUp {
            // Right click - show context menu
            showContextMenu()
        } else {
            // Left click - toggle popover
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
        mediaKeyManager.cleanup()
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        return false
    }
    
    // MARK: - Menu Bar Icon Management

    private func setupMediaKeyManager() {
        // Initialize media key manager with audio manager
        mediaKeyManager.setup(with: audioManager)
        print("🎹 Media key manager setup complete")
    }

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
    
    // MARK: - Dependency Management
    
    private func checkDependenciesAndSetup() {
        let dependencyManager = DependencyManager.shared
        
        // If dependencies don't exist, show setup window
        if !dependencyManager.allDependenciesExist {
            showDependencySetupWindow()
        } else {
            // Dependencies exist, perform silent update check
            performAutomaticYTDLPUpdate()
        }
    }
    
    private func showDependencySetupWindow() {
        DispatchQueue.main.async {
            let setupView = DependencySetupView(isPresented: .constant(true))
            let hostingController = NSHostingController(rootView: setupView)
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            
            window.center()
            window.title = "YTAudioBar Setup"
            window.contentViewController = hostingController
            window.isReleasedWhenClosed = false
            window.level = .floating
            window.makeKeyAndOrderFront(nil)
            
            // Keep the window alive
            window.delegate = self
        }
    }
    
    private func performAutomaticYTDLPUpdate() {
        Task {
            do {
                // Only update if dependencies exist
                guard DependencyManager.shared.allDependenciesExist else { return }
                
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
    
    // MARK: - Context Menu Setup
    
    private func showContextMenu() {
        guard let button = statusBarItem.button else { return }

        let menu = NSMenu()

        // About menu item
        let aboutMenuItem = NSMenuItem(title: "About YTAudioBar", action: #selector(showAbout), keyEquivalent: "")
        aboutMenuItem.target = self
        menu.addItem(aboutMenuItem)

        // Separator
        menu.addItem(NSMenuItem.separator())

        // Quit menu item
        let quitMenuItem = NSMenuItem(title: "Quit YTAudioBar", action: #selector(quitApplication), keyEquivalent: "q")
        quitMenuItem.target = self
        menu.addItem(quitMenuItem)

        // Show the menu at the button location
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
    }
    
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "YTAudioBar"
        alert.informativeText = "A powerful YouTube audio player for macOS.\n\nVersion: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")\nBuild: \(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")\n\n© 2025 Ilyass Anida"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        
        // Show the alert
        alert.runModal()
    }
    
    @objc private func quitApplication() {
        print("👋 Quitting YTAudioBar")
        NSApplication.shared.terminate(nil)
    }
}