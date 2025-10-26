#!/usr/bin/env python3
"""
Script to add macOS-style rounded corners to app icons.
macOS uses approximately 22.37% corner radius for app icons.
"""

from PIL import Image, ImageDraw
import os

def add_rounded_corners(image_path, output_path, radius_percent=0.2237):
    """
    Add rounded corners to an image with macOS standard radius.

    Args:
        image_path: Path to input image
        output_path: Path to save output image
        radius_percent: Corner radius as percentage of image size (default: 0.2237 for macOS)
    """
    # Open image
    img = Image.open(image_path).convert("RGBA")
    width, height = img.size

    # Calculate corner radius
    radius = int(min(width, height) * radius_percent)

    # Create a mask with rounded corners
    mask = Image.new('L', (width, height), 0)
    draw = ImageDraw.Draw(mask)

    # Draw rounded rectangle on mask
    draw.rounded_rectangle([(0, 0), (width, height)], radius=radius, fill=255)

    # Create output image with transparency
    output = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    output.paste(img, (0, 0))
    output.putalpha(mask)

    # Save
    output.save(output_path, 'PNG')
    print(f"✓ Processed: {os.path.basename(output_path)} (radius: {radius}px)")

def main():
    # Icon directory
    icon_dir = "/Users/ilyassanida/Desktop/YTAudioBar/YTAudioBar/Assets.xcassets/AppIcon.appiconset"

    # Create backup directory
    backup_dir = os.path.join(icon_dir, "backup_original")
    os.makedirs(backup_dir, exist_ok=True)

    # Icon files to process
    icon_files = [
        "icon_16x16.png",
        "icon_16x16@2x.png",
        "icon_32x32.png",
        "icon_32x32@2x.png",
        "icon_128x128.png",
        "icon_128x128@2x.png",
        "icon_256x256.png",
        "icon_256x256@2x.png",
        "icon_512x512.png",
        "icon_512x512@2x.png",
        "icon_1024x1024.png"
    ]

    print("🎨 Adding macOS-style rounded corners to app icons...")
    print(f"📁 Icon directory: {icon_dir}")
    print(f"💾 Backing up originals to: {backup_dir}\n")

    processed = 0
    for icon_file in icon_files:
        icon_path = os.path.join(icon_dir, icon_file)

        if os.path.exists(icon_path):
            # Backup original
            backup_path = os.path.join(backup_dir, icon_file)
            if not os.path.exists(backup_path):
                img = Image.open(icon_path)
                img.save(backup_path)

            # Process icon
            add_rounded_corners(icon_path, icon_path)
            processed += 1
        else:
            print(f"⚠️  Skipped: {icon_file} (not found)")

    print(f"\n✅ Done! Processed {processed} icon files.")
    print(f"📦 Original icons backed up to: {backup_dir}")
    print(f"\n🔨 Next steps:")
    print(f"   1. Clean build in Xcode (Cmd+Shift+K)")
    print(f"   2. Rebuild your app (Cmd+B)")
    print(f"   3. The new rounded icons will appear in the app")

if __name__ == "__main__":
    main()
