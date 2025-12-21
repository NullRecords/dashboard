#!/bin/bash
# Download Bloom County comics from the last 5 years
# Usage: ./scripts/download_bloomcounty.sh [years]

YEARS=${1:-5}
cd "$(dirname "$0")/.."

echo "🌼 Bloom County Archive Downloader"
echo "=================================="
echo "Downloading comics from the last $YEARS years..."
echo ""

# Activate virtual environment if exists
if [ -f ".venv/bin/activate" ]; then
    source .venv/bin/activate
fi

python3 -c "
import sys
sys.path.insert(0, 'src')
from collectors.bloomcounty_collector import BloomCountyCollector
import logging

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(message)s'
)

collector = BloomCountyCollector()
print(f'Starting download of $YEARS years of Bloom County...')
print('This will take a while. Be patient!')
print('')

result = collector.download_archive(years=$YEARS, save_images=True)

print('')
print('=' * 50)
print('Download Complete!')
print(f'  ✅ Downloaded: {result[\"downloaded\"]}')
print(f'  ❌ Failed: {result[\"failed\"]}')
print(f'  ⏭️  Skipped (cached): {result[\"skipped\"]}')
print(f'  📚 Total in archive: {result[\"total_cached\"]}')
"

echo ""
echo "Done! Comics saved to data/comics/bloomcounty/"
