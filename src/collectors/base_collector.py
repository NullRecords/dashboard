"""
Base collector class for personal dashboard collectors.
"""

import asyncio
import json
from typing import Dict, Any, Optional
from datetime import datetime
from dataclasses import dataclass
import httpx

@dataclass
class CollectionResult:
    """Result from a data collection operation."""
    success: bool
    data: Optional[Dict[str, Any]] = None
    error: Optional[str] = None
    timestamp: Optional[datetime] = None

class BaseCollector:
    """Base class for all data collectors."""
    
    def __init__(self, settings=None):
        self.settings = settings
        self.rate_limit_delay = 0.5  # seconds between requests
        self.last_request_time = 0
    
    async def collect_data(self) -> CollectionResult:
        """Override this method in subclasses."""
        raise NotImplementedError("Subclasses must implement collect_data()")
    
    def get_fallback_data(self) -> Dict[str, Any]:
        """Override this method to provide fallback data."""
        return {}
    
    async def _rate_limit(self):
        """Apply rate limiting between requests."""
        import time
        current_time = time.time()
        time_since_last = current_time - self.last_request_time
        if time_since_last < self.rate_limit_delay:
            await asyncio.sleep(self.rate_limit_delay - time_since_last)
        self.last_request_time = time.time()
    
    async def _fetch_json(self, url: str, headers: Optional[Dict] = None, timeout: float = 10.0) -> Dict[str, Any]:
        """Fetch JSON from a URL."""
        async with httpx.AsyncClient(timeout=timeout) as client:
            response = await client.get(url, headers=headers or {})
            response.raise_for_status()
            return response.json()
