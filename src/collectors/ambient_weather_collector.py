"""
Ambient Weather data collector for local weather station data.

API Documentation: https://ambientweather.docs.apiary.io/
Requires both applicationKey and apiKey from your AmbientWeather.net account.

Data specs: https://github.com/ambient-weather/api-docs/wiki/Device-Data-Specs
"""

import asyncio
import logging
from datetime import datetime
from typing import Dict, Any, Optional, List
import aiohttp
import os

logger = logging.getLogger(__name__)


class AmbientWeatherCollector:
    """Collects weather data from local Ambient Weather station via their REST API."""
    
    BASE_URL = "https://rt.ambientweather.net/v1"
    
    def __init__(self, api_key: str = None, application_key: str = None, settings=None):
        """Initialize Ambient Weather collector.
        
        Args:
            api_key: User's API key from AmbientWeather.net account
            application_key: Developer application key from AmbientWeather.net
            settings: Optional settings object with ambient_weather config
        """
        self.api_key = api_key
        self.application_key = application_key
        
        # Try to get from settings if not provided directly
        if settings:
            if hasattr(settings, 'ambient_weather'):
                self.api_key = self.api_key or getattr(settings.ambient_weather, 'api_key', None)
                self.application_key = self.application_key or getattr(settings.ambient_weather, 'application_key', None)
        
        # Fall back to environment variables
        self.api_key = self.api_key or os.getenv('AMBIENT_WEATHER_API_KEY')
        self.application_key = self.application_key or os.getenv('AMBIENT_WEATHER_APPLICATION_KEY')
        
        self._cached_devices = None
        self._cache_time = None
        self._cache_duration = 60  # Cache for 60 seconds (API rate limited)
    
    def is_configured(self) -> bool:
        """Check if both required API keys are configured."""
        return bool(self.api_key and self.application_key)
    
    async def get_devices(self) -> List[Dict[str, Any]]:
        """Fetch list of weather station devices and their latest data.
        
        Returns list of devices with their most recent readings.
        """
        if not self.is_configured():
            logger.warning("Ambient Weather not configured - need both api_key and application_key")
            return []
        
        # Check cache
        if self._cached_devices and self._cache_time:
            elapsed = (datetime.now() - self._cache_time).total_seconds()
            if elapsed < self._cache_duration:
                return self._cached_devices
        
        try:
            async with aiohttp.ClientSession() as session:
                url = f"{self.BASE_URL}/devices"
                params = {
                    'apiKey': self.api_key,
                    'applicationKey': self.application_key
                }
                
                async with session.get(url, params=params, timeout=10) as response:
                    if response.status == 200:
                        devices = await response.json()
                        self._cached_devices = devices
                        self._cache_time = datetime.now()
                        logger.info(f"Fetched {len(devices)} Ambient Weather device(s)")
                        return devices
                    elif response.status == 429:
                        logger.warning("Ambient Weather API rate limited (1 req/sec)")
                        return self._cached_devices or []
                    elif response.status == 401:
                        logger.error("Ambient Weather API unauthorized - check your API keys")
                        return []
                    else:
                        text = await response.text()
                        logger.error(f"Ambient Weather API error {response.status}: {text}")
                        return []
                        
        except asyncio.TimeoutError:
            logger.error("Ambient Weather API timeout")
            return self._cached_devices or []
        except Exception as e:
            logger.error(f"Ambient Weather API error: {e}")
            return self._cached_devices or []
    
    async def get_current_weather(self) -> Optional[Dict[str, Any]]:
        """Get current weather from the first available device.
        
        Returns formatted weather data compatible with dashboard display.
        """
        devices = await self.get_devices()
        if not devices:
            return None
        
        # Use first device's latest data
        device = devices[0]
        last_data = device.get('lastData', {})
        info = device.get('info', {})
        
        # Parse the data
        return self._format_weather_data(last_data, info, device.get('macAddress', 'unknown'))
    
    async def get_all_stations(self) -> List[Dict[str, Any]]:
        """Get weather data from all configured stations.
        
        Returns list of formatted weather data for each station.
        """
        devices = await self.get_devices()
        stations = []
        
        for device in devices:
            last_data = device.get('lastData', {})
            info = device.get('info', {})
            weather = self._format_weather_data(last_data, info, device.get('macAddress', 'unknown'))
            if weather:
                stations.append(weather)
        
        return stations
    
    def _format_weather_data(self, data: Dict, info: Dict, mac: str) -> Dict[str, Any]:
        """Format raw Ambient Weather data for dashboard display.
        
        Args:
            data: lastData from device
            info: device info (name, location, etc.)
            mac: device MAC address
            
        Returns:
            Formatted weather dictionary
        """
        if not data:
            return None
        
        # Get station name
        station_name = info.get('name', f'Weather Station ({mac[-8:]})')
        location = info.get('location', '')
        
        # Parse timestamp
        timestamp = data.get('date', data.get('dateutc'))
        if isinstance(timestamp, (int, float)):
            timestamp = datetime.fromtimestamp(timestamp / 1000).isoformat()
        
        # Build comprehensive weather data
        weather = {
            # Station info
            'station_name': station_name,
            'station_location': location,
            'station_mac': mac,
            'source': 'ambient_weather',
            'is_local_station': True,
            
            # Timestamp
            'timestamp': timestamp,
            'dateutc': data.get('dateutc'),
            
            # Temperature (outdoor)
            'temperature': data.get('tempf'),
            'feels_like': data.get('feelsLike'),
            'dew_point': data.get('dewPoint'),
            
            # Temperature (indoor)
            'temperature_indoor': data.get('tempinf'),
            'feels_like_indoor': data.get('feelsLikein'),
            'dew_point_indoor': data.get('dewPointin'),
            
            # Humidity
            'humidity': data.get('humidity'),
            'humidity_indoor': data.get('humidityin'),
            
            # Pressure
            'pressure_relative': data.get('baromrelin'),  # inHg
            'pressure_absolute': data.get('baromabsin'),  # inHg
            
            # Wind
            'wind_speed': data.get('windspeedmph'),
            'wind_gust': data.get('windgustmph'),
            'wind_direction': data.get('winddir'),
            'wind_gust_direction': data.get('windgustdir'),
            'max_daily_gust': data.get('maxdailygust'),
            
            # Wind averages
            'wind_speed_2m_avg': data.get('windspdmph_avg2m'),
            'wind_direction_2m_avg': data.get('winddir_avg2m'),
            'wind_speed_10m_avg': data.get('windspdmph_avg10m'),
            'wind_direction_10m_avg': data.get('winddir_avg10m'),
            
            # Rain
            'rain_hourly': data.get('hourlyrainin'),
            'rain_daily': data.get('dailyrainin'),
            'rain_weekly': data.get('weeklyrainin'),
            'rain_monthly': data.get('monthlyrainin'),
            'rain_yearly': data.get('yearlyrainin'),
            'rain_event': data.get('eventrainin'),
            'rain_total': data.get('totalrainin'),
            'last_rain': data.get('lastRain'),
            
            # Solar/UV
            'uv_index': data.get('uv'),
            'solar_radiation': data.get('solarradiation'),  # W/m²
            
            # Air Quality (if sensor present)
            'pm25': data.get('pm25'),
            'pm25_24h': data.get('pm25_24h'),
            'pm25_indoor': data.get('pm25_in'),
            'pm25_indoor_24h': data.get('pm25_in_24h'),
            'aqi_pm25': data.get('aqi_pm25_aqin'),
            'co2': data.get('co2'),
            'co2_indoor': data.get('co2_in_aqin'),
            
            # Lightning (if sensor present)
            'lightning_strikes_day': data.get('lightning_day'),
            'lightning_strikes_hour': data.get('lightning_hour'),
            'lightning_distance': data.get('lightning_distance'),
            'lightning_time': data.get('lightning_time'),
            
            # Battery status
            'battery_outdoor': 'OK' if data.get('battout', 1) == 1 else 'Low',
            'battery_indoor': 'OK' if data.get('battin', 1) == 1 else 'Low',
            
            # Additional sensors (soil, leaf, etc.)
            'soil_temp_1': data.get('soiltemp1f'),
            'soil_moisture_1': data.get('soilhum1'),
        }
        
        # Remove None values for cleaner output
        weather = {k: v for k, v in weather.items() if v is not None}
        
        # Add formatted display strings
        if weather.get('temperature') is not None:
            weather['temperature_display'] = f"{weather['temperature']:.1f}°F"
        if weather.get('feels_like') is not None:
            weather['feels_like_display'] = f"{weather['feels_like']:.1f}°F"
        if weather.get('humidity') is not None:
            weather['humidity_display'] = f"{weather['humidity']}%"
        if weather.get('wind_speed') is not None:
            weather['wind_display'] = f"{weather['wind_speed']:.1f} mph"
            if weather.get('wind_gust') is not None:
                weather['wind_display'] += f" (gusts {weather['wind_gust']:.1f})"
        if weather.get('pressure_relative') is not None:
            weather['pressure_display'] = f"{weather['pressure_relative']:.2f} inHg"
        
        # Wind direction as cardinal
        if weather.get('wind_direction') is not None:
            weather['wind_direction_cardinal'] = self._degrees_to_cardinal(weather['wind_direction'])
        
        return weather
    
    def _degrees_to_cardinal(self, degrees: float) -> str:
        """Convert wind direction degrees to cardinal direction."""
        directions = ['N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE',
                      'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW']
        idx = round(degrees / 22.5) % 16
        return directions[idx]
    
    async def get_device_history(self, mac_address: str, limit: int = 288) -> List[Dict[str, Any]]:
        """Fetch historical data for a specific device.
        
        Args:
            mac_address: Device MAC address
            limit: Number of records (default 288 = 24 hours at 5-min intervals)
            
        Returns:
            List of historical data points
        """
        if not self.is_configured():
            return []
        
        try:
            async with aiohttp.ClientSession() as session:
                url = f"{self.BASE_URL}/devices/{mac_address}"
                params = {
                    'apiKey': self.api_key,
                    'applicationKey': self.application_key,
                    'limit': limit
                }
                
                async with session.get(url, params=params, timeout=15) as response:
                    if response.status == 200:
                        return await response.json()
                    else:
                        logger.error(f"History fetch failed: {response.status}")
                        return []
                        
        except Exception as e:
            logger.error(f"History fetch error: {e}")
            return []


# Quick test function
async def test_ambient_weather():
    """Test the Ambient Weather collector."""
    import os
    
    api_key = os.getenv('AMBIENT_WEATHER_API_KEY')
    app_key = os.getenv('AMBIENT_WEATHER_APPLICATION_KEY')
    
    if not api_key or not app_key:
        print("Set AMBIENT_WEATHER_API_KEY and AMBIENT_WEATHER_APPLICATION_KEY environment variables")
        return
    
    collector = AmbientWeatherCollector(api_key=api_key, application_key=app_key)
    
    print("Fetching devices...")
    devices = await collector.get_devices()
    print(f"Found {len(devices)} device(s)")
    
    if devices:
        print("\nCurrent weather:")
        weather = await collector.get_current_weather()
        for key, value in weather.items():
            print(f"  {key}: {value}")


if __name__ == "__main__":
    asyncio.run(test_ambient_weather())
