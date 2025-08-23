#!/usr/bin/env swift

import Foundation
import AppKit
import SwiftUI

// Simple icon generation script
@available(macOS 11.0, *)
func generateAppIcons() {
    let sizes = [16, 32, 64, 128, 256, 512, 1024]
    let outputDir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("AppIcons")
    
    // Create output directory
    try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
    
    for size in sizes {
        let image = createIcon(size: CGFloat(size))
        let data = image.tiffRepresentation!
        let bitmap = NSBitmapImageRep(data: data)!
        let pngData = bitmap.representation(using: .png, properties: [:])!
        
        let filename = "icon_\(size)x\(size).png"
        let fileURL = outputDir.appendingPathComponent(filename)
        
        try! pngData.write(to: fileURL)
        print("Generated: \(filename)")
    }
    
    print("Icons saved to: \(outputDir.path)")
}

@available(macOS 11.0, *)
func createIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    
    image.lockFocus()
    
    // Background gradient (YouTube red)
    let gradient = NSGradient(colors: [
        NSColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1.0), // YouTube red
        NSColor(red: 0.8, green: 0.1, blue: 0.1, alpha: 1.0)  // Darker red
    ])!
    
    let cornerRadius = size * 0.2
    let rect = NSRect(x: 0, y: 0, width: size, height: size)
    let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    gradient.draw(in: path, angle: 45)
    
    // Play triangle
    NSColor.white.setFill()
    let triangleSize = size * 0.4
    let triangleX = (size - triangleSize) / 2 + size * 0.05  // Slightly offset right
    let triangleY = (size - triangleSize) / 2
    
    let triangle = NSBezierPath()
    triangle.move(to: NSPoint(x: triangleX, y: triangleY))
    triangle.line(to: NSPoint(x: triangleX + triangleSize, y: triangleY + triangleSize/2))
    triangle.line(to: NSPoint(x: triangleX, y: triangleY + triangleSize))
    triangle.close()
    triangle.fill()
    
    // Audio wave lines
    NSColor.white.setFill()
    let waveY = size * 0.7
    let waveWidth = size * 0.04
    let waveSpacing = size * 0.06
    let waveStartX = size * 0.2
    
    for i in 0..<3 {
        let waveHeight = size * (0.1 + Double(i) * 0.04)
        let waveRect = NSRect(
            x: waveStartX + CGFloat(i) * waveSpacing,
            y: waveY - waveHeight/2,
            width: waveWidth,
            height: waveHeight
        )
        NSBezierPath(roundedRect: waveRect, xRadius: waveWidth/2, yRadius: waveWidth/2).fill()
    }
    
    image.unlockFocus()
    return image
}

// Run the generation
if #available(macOS 11.0, *) {
    generateAppIcons()
} else {
    print("This script requires macOS 11.0 or later")
}