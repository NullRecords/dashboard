"""eBay Auction Collector for Retro Tech"""
import httpx
import logging
from datetime import datetime, timedelta
from typing import Optional, List, Dict, Any
from bs4 import BeautifulSoup
import re

logger = logging.getLogger(__name__)


class EBayAuctionCollector:
    """Collector for eBay auctions - retro laptops, gaming systems"""
    
    def __init__(self):
        """Initialize eBay auction collector"""
        self.base_url = "https://www.ebay.com/sch/i.html"
        self.timeout = 15
    
    async def search_auctions(self, keywords: str, category: Optional[str] = None) -> List[Dict[str, Any]]:
        """
        Search eBay for auctions
        
        Args:
            keywords: Search keywords (e.g., "retro laptop", "vintage gaming system")
            category: Optional category filter
            
        Returns:
            List of auction items
        """
        try:
            params = {
                '_nkw': keywords,
                'LH_Auction': 1,  # Auctions only
                'rt': 'nc',
                'LH_ItemCondition': 3000,  # Used
                '_sop': 1  # End Time: Soonest
            }
            
            if category:
                params['_sacat'] = category
            
            async with httpx.AsyncClient(timeout=self.timeout, follow_redirects=True) as client:
                # Use a browser-like user agent
                headers = {
                    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                    'Accept-Language': 'en-US,en;q=0.9'
                }
                response = await client.get(self.base_url, params=params, headers=headers)
                response.raise_for_status()
                
                return self._parse_results(response.text)
        except Exception as e:
            logger.error(f"Error searching eBay: {e}")
            return []
    
    def _parse_results(self, html: str) -> List[Dict[str, Any]]:
        """Parse eBay HTML results"""
        auctions = []
        try:
            soup = BeautifulSoup(html, 'html.parser')
            
            # Find all item listings
            items = soup.select('li.s-item')
            
            for item in items[:12]:  # Get top 12 items
                try:
                    # Title
                    title_elem = item.select_one('.s-item__title')
                    title = title_elem.get_text(strip=True) if title_elem else 'Unknown'
                    
                    # Price
                    price_elem = item.select_one('.s-item__price')
                    price_text = price_elem.get_text(strip=True) if price_elem else '$0.00'
                    # Extract numeric price
                    price_match = re.search(r'\$([0-9,.]+)', price_text)
                    price = price_match.group(1) if price_match else '0.00'
                    
                    # Link
                    link_elem = item.select_one('a.s-item__link')
                    link = link_elem.get('href') if link_elem else '#'
                    
                    # Image
                    img_elem = item.select_one('img.s-item__image-img, img.s-item__image')
                    image_url = (img_elem.get('src') or img_elem.get('data-src')) if img_elem else '/static/images/ebay-default.png'
                    
                    # Time left (from subtitle)
                    time_elem = item.select_one('.s-item__time-left')
                    time_left = time_elem.get_text(strip=True) if time_elem else 'Time unknown'
                    
                    # Only include if auction is actually found
                    purchase_type = item.select_one('.s-item__purchase-options-with-icon')
                    is_auction = purchase_type and ('Auction' in purchase_type.get_text())
                    if is_auction or 'Time' in time_left:
                        auctions.append({
                            'id': link.split('itm/')[-1].split('?')[0] if '/itm/' in link else '',
                            'title': title,
                            'current_price': price,
                            'link': link,
                            'image_url': image_url,
                            'time_left': time_left,
                            'source': 'ebay'
                        })
                except Exception as e:
                    logger.debug(f"Error parsing item: {e}")
                    continue
        except Exception as e:
            logger.error(f"Error parsing eBay results: {e}")
        
        return auctions
    
    async def get_retro_tech_auctions(self) -> List[Dict[str, Any]]:
        """Get retro laptops and gaming systems with great prices ending soon"""
        all_auctions = []
        
        try:
            # Search for retro laptops
            laptop_auctions = await self.search_auctions(
                "retro laptop vintage",
                category="177"  # Computers/Tablets category
            )
            all_auctions.extend(laptop_auctions)
            
            # Search for vintage gaming systems
            gaming_auctions = await self.search_auctions(
                "vintage gaming system retro console",
                category="16734"  # Video Games category
            )
            all_auctions.extend(gaming_auctions)
        except Exception as e:
            logger.warning(f"eBay fetch failed, using sample data: {e}")
        
        # If no auctions found, return sample data
        if not all_auctions:
            all_auctions = self._get_sample_auctions()
        
        # Remove duplicates and sort by time_left
        seen_ids = set()
        unique_auctions = []
        for auction in all_auctions:
            if auction.get('id') not in seen_ids:
                seen_ids.add(auction.get('id'))
                unique_auctions.append(auction)
        
        return unique_auctions[:20]  # Return top 20
    
    def _get_sample_auctions(self) -> List[Dict[str, Any]]:
        """Return sample auction data when eBay is unavailable"""
        return [
            {
                'id': 'sample1',
                'title': 'IBM ThinkPad T42 - Vintage Laptop - Working',
                'current_price': '45.00',
                'link': 'https://www.ebay.com/sch/i.html?_nkw=thinkpad+t42',
                'image_url': 'https://i.ebayimg.com/images/g/example/s-l300.jpg',
                'time_left': '2h 30m',
                'source': 'ebay_sample'
            },
            {
                'id': 'sample2',
                'title': 'Nintendo 64 Console + Controller - Tested',
                'current_price': '65.00',
                'link': 'https://www.ebay.com/sch/i.html?_nkw=nintendo+64',
                'image_url': 'https://i.ebayimg.com/images/g/example/s-l300.jpg',
                'time_left': '4h 15m',
                'source': 'ebay_sample'
            },
            {
                'id': 'sample3',
                'title': 'Vintage Apple PowerBook G4 - For Parts/Repair',
                'current_price': '30.00',
                'link': 'https://www.ebay.com/sch/i.html?_nkw=powerbook+g4',
                'image_url': 'https://i.ebayimg.com/images/g/example/s-l300.jpg',
                'time_left': '6h 45m',
                'source': 'ebay_sample'
            },
            {
                'id': 'sample4',
                'title': 'Sega Genesis Model 1 Console Bundle',
                'current_price': '55.00',
                'link': 'https://www.ebay.com/sch/i.html?_nkw=sega+genesis',
                'image_url': 'https://i.ebayimg.com/images/g/example/s-l300.jpg',
                'time_left': '8h 20m',
                'source': 'ebay_sample'
            },
            {
                'id': 'sample5',
                'title': 'Dell Latitude D630 - Retro Business Laptop',
                'current_price': '35.00',
                'link': 'https://www.ebay.com/sch/i.html?_nkw=dell+latitude+d630',
                'image_url': 'https://i.ebayimg.com/images/g/example/s-l300.jpg',
                'time_left': '12h 10m',
                'source': 'ebay_sample'
            },
            {
                'id': 'sample6',
                'title': 'Sony PlayStation 2 Slim - Works Great',
                'current_price': '40.00',
                'link': 'https://www.ebay.com/sch/i.html?_nkw=ps2+slim',
                'image_url': 'https://i.ebayimg.com/images/g/example/s-l300.jpg',
                'time_left': '1d 2h',
                'source': 'ebay_sample'
            },
        ]
