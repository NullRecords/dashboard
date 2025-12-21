#!/bin/bash
# Cron job to monitor eBay auctions and generate suggestions
# Add to crontab with: 0 9,17 * * * /path/to/scripts/ebay_auction_monitor.sh

cd "$(dirname "$0")/.."

source .venv/bin/activate

python3 -c "
import asyncio
import json
import logging
from datetime import datetime
from pathlib import Path
from src.collectors.ebay_auction_collector import EBayAuctionCollector

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

async def monitor_ebay():
    \"\"\"Monitor eBay auctions and save suggestions\"\"\"
    collector = EBayAuctionCollector()
    
    logger.info('Fetching retro tech auctions...')
    auctions = await collector.get_retro_tech_auctions()
    
    if auctions:
        # Save to data directory
        data_file = Path('data/ebay_auctions_suggestions.json')
        data = {
            'last_updated': datetime.now().isoformat(),
            'auctions': auctions
        }
        
        with open(data_file, 'w') as f:
            json.dump(data, f, indent=2)
        
        logger.info(f'Found {len(auctions)} auctions. Saved to {data_file}')
        
        # Log best deals
        for auction in auctions[:5]:
            logger.info(f\"  - {auction['title']}: {auction['current_price']} ({auction['time_left']})\")
    else:
        logger.warning('No auctions found')

if __name__ == '__main__':
    asyncio.run(monitor_ebay())
"
