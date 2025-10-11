#!/usr/bin/env python3
"""
Generate Sparkle appcast.xml from GitHub releases.
This script fetches releases from GitHub and creates an appcast feed.
"""

import json
import sys
import os
import urllib.request
import urllib.error
import subprocess
import tempfile
from datetime import datetime
from xml.etree.ElementTree import Element, SubElement, tostring
from xml.dom import minidom

GITHUB_REPO = "ilyassan/YTAudioBar-macos"
GITHUB_API_URL = f"https://api.github.com/repos/{GITHUB_REPO}/releases"


def fetch_github_releases():
    """Fetch all releases from GitHub API."""
    try:
        # Use GitHub token if available (for authenticated requests with higher rate limit)
        github_token = os.environ.get('GITHUB_TOKEN')

        request = urllib.request.Request(GITHUB_API_URL)
        # Add User-Agent header (required by GitHub API)
        request.add_header('User-Agent', 'YTAudioBar-Appcast-Generator')

        if github_token:
            # Use 'token' format (both 'token' and 'Bearer' work, but 'token' is more widely supported)
            request.add_header('Authorization', f'token {github_token}')
            print(f"✓ Using authenticated GitHub API request", file=sys.stderr)
        else:
            print(f"⚠️  Warning: No GITHUB_TOKEN found, using unauthenticated request (rate limited)", file=sys.stderr)

        with urllib.request.urlopen(request) as response:
            return json.loads(response.read().decode())
    except urllib.error.URLError as e:
        print(f"Error fetching releases: {e}", file=sys.stderr)
        sys.exit(1)


def get_dmg_asset(assets):
    """Find the .dmg asset from release assets."""
    for asset in assets:
        if asset['name'].endswith('.dmg'):
            return asset
    return None


def parse_version(tag_name):
    """Parse version from tag name (e.g., 'v1.0.2' -> '1.0.2')."""
    return tag_name.lstrip('v')


def parse_build_number(tag_name):
    """Extract build number from tag name (e.g., 'v1.0.8' -> '8')."""
    version = parse_version(tag_name)
    # Take the last component as build number (e.g., '1.0.8' -> '8')
    parts = version.split('.')
    return parts[-1] if parts else version


def sign_dmg(dmg_url, private_key):
    """Download DMG and generate EdDSA signature using Sparkle's sign_update tool."""
    if not private_key:
        return None

    try:
        # Download DMG to temporary file
        with tempfile.NamedTemporaryFile(delete=False, suffix='.dmg') as tmp_file:
            print(f"  Downloading {dmg_url}...", file=sys.stderr)
            request = urllib.request.Request(dmg_url)
            request.add_header('User-Agent', 'YTAudioBar-Appcast-Generator')

            with urllib.request.urlopen(request) as response:
                tmp_file.write(response.read())
            tmp_path = tmp_file.name

        # Sign the DMG using sign_update tool
        print(f"  Signing DMG...", file=sys.stderr)
        result = subprocess.run(
            ['./sign_update', tmp_path],
            input=private_key.encode(),
            capture_output=True,
            text=True
        )

        # Clean up
        os.unlink(tmp_path)

        if result.returncode == 0:
            # Extract signature from output (format: "sparkle:edSignature="SIGNATURE")
            output = result.stdout.strip()
            if 'sparkle:edSignature=' in output:
                signature = output.split('sparkle:edSignature="')[1].split('"')[0]
                return signature
        else:
            print(f"  Warning: Failed to sign DMG: {result.stderr}", file=sys.stderr)

        return None
    except Exception as e:
        print(f"  Warning: Failed to sign DMG: {e}", file=sys.stderr)
        return None


def create_appcast_item(release, private_key=None):
    """Create a Sparkle <item> element from a GitHub release."""
    dmg_asset = get_dmg_asset(release['assets'])
    if not dmg_asset:
        return None

    item = Element('item')

    # Title
    title = SubElement(item, 'title')
    title.text = f"Version {parse_version(release['tag_name'])}"

    # Publication date (RFC 822 format)
    pub_date = SubElement(item, 'pubDate')
    release_date = datetime.strptime(release['published_at'], '%Y-%m-%dT%H:%M:%SZ')
    pub_date.text = release_date.strftime('%a, %d %b %Y %H:%M:%S +0000')

    # Release notes link
    link = SubElement(item, 'link')
    link.text = release['html_url']

    # Description (release notes)
    description = SubElement(item, 'description')
    description.text = f"<![CDATA[{release['body'] or 'No release notes provided.'}]]>"

    # Enclosure (download info)
    enclosure = SubElement(item, 'enclosure')
    enclosure.set('url', dmg_asset['browser_download_url'])
    enclosure.set('length', str(dmg_asset['size']))
    enclosure.set('type', 'application/octet-stream')
    enclosure.set('sparkle:version', parse_build_number(release['tag_name']))
    enclosure.set('sparkle:shortVersionString', parse_version(release['tag_name']))

    # Add EdDSA signature if private key is available
    if private_key:
        signature = sign_dmg(dmg_asset['browser_download_url'], private_key)
        if signature:
            enclosure.set('sparkle:edSignature', signature)
            print(f"  ✓ Signed {parse_version(release['tag_name'])}", file=sys.stderr)

    # Minimum system version
    min_sys_version = SubElement(item, 'sparkle:minimumSystemVersion')
    min_sys_version.text = '14.0'

    return item


def generate_appcast(private_key=None):
    """Generate complete appcast.xml content."""
    releases = fetch_github_releases()

    # Create RSS root
    rss = Element('rss')
    rss.set('version', '2.0')
    rss.set('xmlns:sparkle', 'http://www.andymatuschak.org/xml-namespaces/sparkle')
    rss.set('xmlns:dc', 'http://purl.org/dc/elements/1.1/')

    channel = SubElement(rss, 'channel')

    # Channel metadata
    title = SubElement(channel, 'title')
    title.text = 'YTAudioBar Updates'

    description = SubElement(channel, 'description')
    description.text = 'Updates for YTAudioBar - YouTube Audio Player for macOS'

    language = SubElement(channel, 'language')
    language.text = 'en'

    link = SubElement(channel, 'link')
    link.text = f'https://github.com/{GITHUB_REPO}'

    # Add items for each release
    for release in releases:
        if release['draft'] or release['prerelease']:
            continue

        item = create_appcast_item(release, private_key)
        if item is not None:
            channel.append(item)

    # Pretty print XML
    xml_string = tostring(rss, encoding='unicode')
    dom = minidom.parseString(xml_string)
    return dom.toprettyxml(indent='  ')


def main():
    """Main entry point."""
    # Get private key from environment if available
    private_key = os.environ.get('SPARKLE_PRIVATE_KEY')

    if private_key:
        print("✓ Using private key for EdDSA signing", file=sys.stderr)
    else:
        print("⚠️  Warning: No SPARKLE_PRIVATE_KEY found, appcast will not include signatures", file=sys.stderr)

    print("Generating appcast.xml from GitHub releases...", file=sys.stderr)
    appcast_xml = generate_appcast(private_key)

    # Write to file
    with open('appcast.xml', 'w', encoding='utf-8') as f:
        f.write(appcast_xml)

    print("✅ appcast.xml generated successfully!", file=sys.stderr)


if __name__ == '__main__':
    main()
