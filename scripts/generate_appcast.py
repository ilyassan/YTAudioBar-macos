#!/usr/bin/env python3
"""
Generate Sparkle appcast.xml from GitHub releases.
This script fetches releases from GitHub and creates an appcast feed.
"""

import json
import sys
import urllib.request
import urllib.error
from datetime import datetime
from xml.etree.ElementTree import Element, SubElement, tostring
from xml.dom import minidom

GITHUB_REPO = "ilyassan/YTAudioBar-macos"
GITHUB_API_URL = f"https://api.github.com/repos/{GITHUB_REPO}/releases"


def fetch_github_releases():
    """Fetch all releases from GitHub API."""
    try:
        with urllib.request.urlopen(GITHUB_API_URL) as response:
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


def create_appcast_item(release):
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
    enclosure.set('sparkle:version', parse_version(release['tag_name']))
    enclosure.set('sparkle:shortVersionString', parse_version(release['tag_name']))

    # Minimum system version
    min_sys_version = SubElement(item, 'sparkle:minimumSystemVersion')
    min_sys_version.text = '14.0'

    return item


def generate_appcast():
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

        item = create_appcast_item(release)
        if item is not None:
            channel.append(item)

    # Pretty print XML
    xml_string = tostring(rss, encoding='unicode')
    dom = minidom.parseString(xml_string)
    return dom.toprettyxml(indent='  ')


def main():
    """Main entry point."""
    print("Generating appcast.xml from GitHub releases...")
    appcast_xml = generate_appcast()

    # Write to file
    with open('appcast.xml', 'w', encoding='utf-8') as f:
        f.write(appcast_xml)

    print("✅ appcast.xml generated successfully!")


if __name__ == '__main__':
    main()
