#!/usr/bin/env python3
"""
Download comic archives from GoComics for multiple series.
Usage: python3 scripts/download_comic_archives.py [count]
Default count is 30 comics per series.
"""

import sys
import os
import json
import time
import re
import requests
from datetime import datetime, timedelta
from pathlib import Path

# Add project root to path
project_root = Path(__file__).parent.parent
sys.path.insert(0, str(project_root / "src"))

# Comics to download with their GoComics slugs
COMICS = {
    "foxtrot": {
        "name": "FoxTrot",
        "slug": "foxtrot"
    },
    "calvin": {
        "name": "Calvin & Hobbes",
        "slug": "calvinandhobbes"
    },
    "peanuts": {
        "name": "Peanuts",
        "slug": "peanuts"
    }
}

def fetch_comic(slug: str, date: datetime) -> dict:
    """Fetch a comic from GoComics for a specific date."""
    date_str = date.strftime("%Y/%m/%d")
    url = f"https://www.gocomics.com/{slug}/{date_str}"
    
    headers = {
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
        "Accept": "text/html,application/xhtml+xml",
        "Accept-Language": "en-US,en;q=0.9",
    }
    
    try:
        resp = requests.get(url, headers=headers, timeout=15)
        if resp.status_code != 200:
            return None
        
        # Find the comic image URL
        pattern = r'https://assets\.amuniversal\.com/[a-f0-9]+'
        match = re.search(pattern, resp.text)
        
        if not match:
            # Try featureassets
            pattern2 = r'https://featureassets\.gocomics\.com/assets/[a-f0-9]+'
            match = re.search(pattern2, resp.text)
        
        if match:
            return {
                "image_url": match.group(0),
                "date": date.strftime("%Y-%m-%d"),
                "page_url": url
            }
    except Exception as e:
        print(f"  Error fetching {slug} for {date_str}: {e}")
    
    return None


def download_image(url: str, save_path: Path) -> bool:
    """Download an image and save it."""
    try:
        headers = {
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
        }
        resp = requests.get(url, headers=headers, timeout=30)
        if resp.status_code == 200:
            save_path.parent.mkdir(parents=True, exist_ok=True)
            with open(save_path, 'wb') as f:
                f.write(resp.content)
            return True
    except Exception as e:
        print(f"  Error downloading image: {e}")
    return False


def download_series(comic_id: str, comic_info: dict, count: int, data_dir: Path):
    """Download comics for a series."""
    slug = comic_info["slug"]
    name = comic_info["name"]
    
    print(f"\n{'='*50}")
    print(f"📚 Downloading {name} ({count} comics)")
    print(f"{'='*50}")
    
    # Load existing archive
    archive_file = data_dir / f"{comic_id}_archive.json"
    comics_dir = data_dir / "comics" / comic_id
    comics_dir.mkdir(parents=True, exist_ok=True)
    
    if archive_file.exists():
        with open(archive_file) as f:
            archive = json.load(f)
    else:
        archive = {"comics": [], "last_updated": None}
    
    existing_dates = {c["date"] for c in archive.get("comics", [])}
    
    downloaded = 0
    skipped = 0
    failed = 0
    
    # Start from today and go backwards
    current_date = datetime.now()
    attempts = 0
    max_attempts = count * 3  # Allow for some failures
    
    while downloaded < count and attempts < max_attempts:
        date_str = current_date.strftime("%Y-%m-%d")
        
        if date_str in existing_dates:
            print(f"  ⏭️  {date_str} - already cached")
            skipped += 1
            current_date -= timedelta(days=1)
            attempts += 1
            continue
        
        print(f"  📥 Fetching {date_str}...", end=" ", flush=True)
        comic = fetch_comic(slug, current_date)
        
        if comic:
            # Download the image
            image_ext = ".gif"  # GoComics typically uses gif
            image_path = comics_dir / f"{date_str}{image_ext}"
            
            if download_image(comic["image_url"], image_path):
                # Add to archive
                archive_entry = {
                    "date": date_str,
                    "image_url": f"/data/comics/{comic_id}/{date_str}{image_ext}",
                    "original_url": comic["image_url"],
                    "page_url": comic["page_url"]
                }
                archive["comics"].append(archive_entry)
                downloaded += 1
                print(f"✅ Downloaded ({downloaded}/{count})")
            else:
                failed += 1
                print(f"❌ Failed to save")
        else:
            failed += 1
            print(f"❌ Not found")
        
        current_date -= timedelta(days=1)
        attempts += 1
        
        # Be nice to the server
        time.sleep(0.5)
    
    # Sort archive by date (newest first)
    archive["comics"] = sorted(archive["comics"], key=lambda x: x["date"], reverse=True)
    archive["last_updated"] = datetime.now().isoformat()
    
    # Save archive
    with open(archive_file, 'w') as f:
        json.dump(archive, f, indent=2)
    
    print(f"\n{name} Summary:")
    print(f"  ✅ Downloaded: {downloaded}")
    print(f"  ⏭️  Skipped (cached): {skipped}")
    print(f"  ❌ Failed: {failed}")
    print(f"  📚 Total in archive: {len(archive['comics'])}")
    
    return downloaded, skipped, failed


def main():
    count = int(sys.argv[1]) if len(sys.argv) > 1 else 30
    
    print(f"🎨 Comic Archive Downloader")
    print(f"   Downloading {count} comics per series")
    print(f"   Series: {', '.join(c['name'] for c in COMICS.values())}")
    
    data_dir = project_root / "data"
    
    total_downloaded = 0
    total_skipped = 0
    total_failed = 0
    
    for comic_id, comic_info in COMICS.items():
        downloaded, skipped, failed = download_series(comic_id, comic_info, count, data_dir)
        total_downloaded += downloaded
        total_skipped += skipped
        total_failed += failed
    
    print(f"\n{'='*50}")
    print(f"🎉 All Downloads Complete!")
    print(f"{'='*50}")
    print(f"  ✅ Total Downloaded: {total_downloaded}")
    print(f"  ⏭️  Total Skipped: {total_skipped}")
    print(f"  ❌ Total Failed: {total_failed}")


if __name__ == "__main__":
    main()
