"""iCloud Family Calendar Collector"""
import httpx
import logging
from datetime import datetime, timedelta
from typing import Optional, List, Dict, Any
from icalendar import Calendar
from dateutil.parser import parse as parse_date

logger = logging.getLogger(__name__)


class ICloudCalendarCollector:
    """Collector for iCloud Family Calendar via webcal URL"""
    
    def __init__(self, webcal_url: str):
        """
        Initialize iCloud calendar collector
        
        Args:
            webcal_url: The webcal:// URL for the iCloud calendar
        """
        self.webcal_url = webcal_url.replace('webcal://', 'https://')
        self.timeout = 10
    
    async def fetch_calendar(self) -> Optional[Calendar]:
        """Fetch calendar data from iCloud"""
        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                response = await client.get(self.webcal_url)
                response.raise_for_status()
                cal = Calendar.from_ical(response.content)
                return cal
        except Exception as e:
            logger.error(f"Error fetching iCloud calendar: {e}")
            return None
    
    async def get_events(self, days_ahead: int = 30) -> List[Dict[str, Any]]:
        """
        Get upcoming events from family calendar
        
        Args:
            days_ahead: Number of days to look ahead
            
        Returns:
            List of event dictionaries
        """
        cal = await self.fetch_calendar()
        if not cal:
            return []
        
        events = []
        now = datetime.now()
        cutoff = now + timedelta(days=days_ahead)
        
        try:
            for component in cal.walk():
                if component.name == "VEVENT":
                    try:
                        event_dict = {
                            'title': str(component.get('summary', 'Untitled')),
                            'description': str(component.get('description', '')),
                            'location': str(component.get('location', '')),
                            'uid': str(component.get('uid', ''))
                        }
                        
                        # Parse dates
                        start = component.get('dtstart')
                        if start:
                            start_dt = start.dt if hasattr(start, 'dt') else start
                            if isinstance(start_dt, datetime):
                                if start_dt.tzinfo is None:
                                    start_dt = start_dt.replace(tzinfo=None)
                                else:
                                    start_dt = start_dt.replace(tzinfo=None)
                                
                                if now <= start_dt <= cutoff:
                                    event_dict['start_time'] = start_dt.isoformat()
                                    
                                    end = component.get('dtend')
                                    if end:
                                        end_dt = end.dt if hasattr(end, 'dt') else end
                                        if isinstance(end_dt, datetime):
                                            end_dt = end_dt.replace(tzinfo=None)
                                            event_dict['end_time'] = end_dt.isoformat()
                                    
                                    events.append(event_dict)
                    except Exception as e:
                        logger.debug(f"Error parsing event: {e}")
                        continue
        except Exception as e:
            logger.error(f"Error walking calendar: {e}")
        
        # Sort by start time
        events.sort(key=lambda x: x.get('start_time', ''))
        return events[:20]  # Return first 20 events
