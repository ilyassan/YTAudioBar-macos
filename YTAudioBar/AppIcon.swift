//
//  AppIcon.swift
//  YTAudioBar
//
//  Created by Ilyass Anida on 22/8/2025.
//

import SwiftUI

// MARK: - App Icon Components

struct AppIconView: View {
    let size: CGFloat
    let isMenuBar: Bool = false
    
    var body: some View {
        ZStack {
            // Background gradient
            RoundedRectangle(cornerRadius: isMenuBar ? 4 : size * 0.2)
                .fill(
                    LinearGradient(
                        colors: [Color.red, Color.red.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // YouTube play button style
            VStack(spacing: size * 0.05) {
                // Main play triangle
                Image(systemName: "play.fill")
                    .font(.system(size: size * 0.35, weight: .semibold))
                    .foregroundColor(.white)
                
                // Audio wave lines
                HStack(spacing: size * 0.05) {
                    ForEach(0..<3) { index in
                        RoundedRectangle(cornerRadius: size * 0.01)
                            .fill(Color.white.opacity(0.8))
                            .frame(
                                width: size * 0.04,
                                height: size * (0.15 + Double(index) * 0.05)
                            )
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }
}

struct MenuBarIconView: View {
    let isActive: Bool
    
    var body: some View {
        ZStack {
            // Simple rounded rectangle background
            RoundedRectangle(cornerRadius: 3)
                .fill(isActive ? Color.accentColor : Color.primary)
                .frame(width: 18, height: 18)
            
            // Play symbol
            Image(systemName: "play.fill")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(isActive ? .white : .primary)
                .colorInvert()
        }
    }
}

// MARK: - Icon Generation Helpers

struct IconSizeSet {
    let size: Int
    let scale: Int
    
    var filename: String {
        if scale == 1 {
            return "icon_\(size)x\(size).png"
        } else {
            return "icon_\(size)x\(size)@\(scale)x.png"
        }
    }
    
    var actualSize: Int {
        return size * scale
    }
}

class AppIconGenerator {
    static let shared = AppIconGenerator()
    
    // Standard macOS app icon sizes
    let iconSizes: [IconSizeSet] = [
        IconSizeSet(size: 16, scale: 1),
        IconSizeSet(size: 16, scale: 2),
        IconSizeSet(size: 32, scale: 1),
        IconSizeSet(size: 32, scale: 2),
        IconSizeSet(size: 128, scale: 1),
        IconSizeSet(size: 128, scale: 2),
        IconSizeSet(size: 256, scale: 1),
        IconSizeSet(size: 256, scale: 2),
        IconSizeSet(size: 512, scale: 1),
        IconSizeSet(size: 512, scale: 2),
    ]
    
    private init() {}
    
    func generateIcons() {
        let outputDirectory = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Desktop")
            .appendingPathComponent("YTAudioBar_Icons")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        
        for iconSize in iconSizes {
            generateIcon(size: iconSize, outputDirectory: outputDirectory)
        }
        
        print("Icons generated at: \(outputDirectory.path)")
    }
    
    private func generateIcon(size: IconSizeSet, outputDirectory: URL) {
        let view = AppIconView(size: CGFloat(size.actualSize))
        let controller = NSHostingController(rootView: view)
        controller.view.frame = CGRect(x: 0, y: 0, width: size.actualSize, height: size.actualSize)
        
        guard let bitmapRep = controller.view.bitmapImageRepForCachingDisplay(in: controller.view.bounds) else {
            print("Failed to create bitmap for size \(size.actualSize)")
            return
        }
        
        controller.view.cacheDisplay(in: controller.view.bounds, to: bitmapRep)
        
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            print("Failed to create PNG data for size \(size.actualSize)")
            return
        }
        
        let fileURL = outputDirectory.appendingPathComponent(size.filename)
        
        do {
            try pngData.write(to: fileURL)
            print("Generated: \(size.filename)")
        } catch {
            print("Failed to write \(size.filename): \(error)")
        }
    }
}

// MARK: - SwiftUI Preview

struct AppIconView_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 20) {
            VStack(spacing: 10) {
                Text("App Icon")
                    .font(.caption)
                AppIconView(size: 64)
                
                Text("Menu Bar Icon")
                    .font(.caption)
                MenuBarIconView(isActive: false)
                
                Text("Menu Bar Icon (Active)")
                    .font(.caption)
                MenuBarIconView(isActive: true)
            }
        }
        .padding()
    }
}