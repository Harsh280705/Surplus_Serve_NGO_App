# app/delivery/services.py
# Core Business Logic for Delivery Module

import googlemaps
import os
from typing import Dict, Tuple, Optional
from datetime import datetime, timedelta
from .models import (
    DeliveryPriceData, PriceEstimateResponse, LocationData,
    DeliveryOption, DELIVERY_OPTIONS_SCHEMA, DELIVERY_PRICING_CONFIG
)
import logging

logger = logging.getLogger(__name__)

# ============================================================================
# PRICE ESTIMATION SERVICE — ✅ FULLY UPDATED
# ============================================================================

class PriceEstimationService:
    """
    Calculates estimated delivery prices based on distance.
    Uses Google Distance Matrix API for actual distance calculation.
    """
    
    def __init__(self):
        """Initialize with Google Maps API key"""
        api_key = os.getenv("GOOGLE_MAPS_API_KEY")
        if api_key:
            self.gmaps = googlemaps.Client(key=api_key)
        else:
            self.gmaps = None
            logger.warning("GOOGLE_MAPS_API_KEY not found, using Haversine fallback")
        self.pricing_config = DELIVERY_PRICING_CONFIG
    
    def estimate_distance(self, 
                         pickup_lat: float, 
                         pickup_lng: float,
                         drop_lat: float,
                         drop_lng: float) -> Tuple[float, int]:
        """
        Calculate distance and duration between two points using Google Distance Matrix API.
        
        Args:
            pickup_lat, pickup_lng: Pickup location coordinates
            drop_lat, drop_lng: Drop location coordinates
            
        Returns:
            (distance_km: float, duration_minutes: int)
        """
        try:
            if self.gmaps is None:
                logger.info("Google Maps not configured, using Haversine")
                distance_km = self._haversine_distance(pickup_lat, pickup_lng, drop_lat, drop_lng)
                duration_minutes = int((distance_km / 20) * 60) + 10  # 20 kmph + 10 min buffer
                return distance_km, duration_minutes
            
            result = self.gmaps.distance_matrix(
                origins=f"{pickup_lat},{pickup_lng}",
                destinations=f"{drop_lat},{drop_lng}",
                mode="driving",
                units="metric"
            )
            
            if result['rows'][0]['elements'][0]['status'] == 'OK':
                distance_m = result['rows'][0]['elements'][0]['distance']['value']
                duration_s = result['rows'][0]['elements'][0]['duration']['value']
                
                distance_km = distance_m / 1000
                duration_minutes = int(duration_s / 60) + 10  # Add 10 min buffer
                
                logger.info(f"Distance calculated: {distance_km:.2f} km, Duration: {duration_minutes} minutes")
                return distance_km, duration_minutes
            else:
                logger.error(f"Distance Matrix API error: {result['rows'][0]['elements'][0]['status']}")
                distance_km = self._haversine_distance(pickup_lat, pickup_lng, drop_lat, drop_lng)
                duration_minutes = int((distance_km / 20) * 60) + 10
                return distance_km, duration_minutes
        
        except Exception as e:
            logger.error(f"Exception in estimate_distance: {str(e)}")
            distance_km = self._haversine_distance(pickup_lat, pickup_lng, drop_lat, drop_lng)
            duration_minutes = int((distance_km / 20) * 60) + 10
            return distance_km, duration_minutes
    
    @staticmethod
    def _haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        """
        Fallback: Calculate distance using Haversine formula (when API is unavailable).
        Returns distance in kilometers.
        """
        from math import radians, sin, cos, sqrt, atan2
        
        R = 6371  # Earth radius in km
        
        lat1, lon1, lat2, lon2 = map(radians, [lat1, lon1, lat2, lon2])
        dlat = lat2 - lat1
        dlon = lon2 - lon1
        
        a = sin(dlat/2)**2 + cos(lat1) * cos(lat2) * sin(dlon/2)**2
        c = 2 * atan2(sqrt(a), sqrt(1-a))
        distance = R * c
        
        return round(distance, 2)
    
    @staticmethod
    def calculate_food_multiplier(serving_capacity: int) -> float:
        """
        Calculate multiplier based on food quantity.
        
        Args:
            serving_capacity: Number of people the food serves
            
        Returns:
            Multiplier (1.0 to 1.6)
        """
        if serving_capacity <= 20:
            return 1.0
        elif serving_capacity <= 30:
            return 1.2
        elif serving_capacity <= 50:
            return 1.4
        else:
            return 1.6
    
    def calculate_estimated_price(self, 
                                  provider: str, 
                                  distance_km: float,
                                  serving_capacity: int = 0) -> float:
        """
        Calculate estimated price using provider's pricing formula.
        
        Formula: (base_fare + (distance_km * per_km_rate)) * food_multiplier
        
        Args:
            provider: "porter", "dunzo", "rapido", "swiggy_genie", "self_service"
            distance_km: Distance in kilometers
            serving_capacity: Number of people food serves
            
        Returns:
            Estimated price in rupees (₹)
        """
        config = self.pricing_config.get(provider)
        if not config:
            logger.warning(f"Provider {provider} not found in config")
            return 0
        
        base_fare = config.get("baseFare", 0)
        per_km_rate = config.get("perKmRate", 0)
        min_fare = config.get("minFare", base_fare)
        max_fare = config.get("maxFare", 10000)
        
        # Calculate base price
        calculated_price = base_fare + (distance_km * per_km_rate)
        
        # Apply food quantity multiplier
        if serving_capacity > 0:
            food_multiplier = self.calculate_food_multiplier(serving_capacity)
            calculated_price *= food_multiplier
        
        # Apply min/max boundaries
        final_price = max(min_fare, min(calculated_price, max_fare))
        
        logger.info(f"Price for {provider}: ₹{final_price:.2f} (distance: {distance_km:.2f}km, serves: {serving_capacity})")
        return round(final_price, 2)
    
    def estimate_all_providers(self, 
                              pickup_lat: float, 
                              pickup_lng: float,
                              drop_lat: float,
                              drop_lng: float,
                              serving_capacity: int = 0) -> PriceEstimateResponse:
        """
        Estimate prices for ALL delivery providers.
        
        Returns:
            PriceEstimateResponse with prices for all providers
        """
        # Get distance from Google API or Haversine
        distance_km, duration_minutes = self.estimate_distance(
            pickup_lat, pickup_lng, drop_lat, drop_lng
        )
        
        # Calculate price for each provider
        providers = {}
        for provider in self.pricing_config.keys():
            estimated_price = self.calculate_estimated_price(provider, distance_km, serving_capacity)
            
            config = self.pricing_config[provider]
            
            providers[provider] = DeliveryPriceData(
                provider=provider,
                base_fare=config.get("baseFare", 0),
                per_km_rate=config.get("perKmRate", 0),
                estimated_price=estimated_price,
                min_fare=config.get("minFare", 0),
                max_fare=config.get("maxFare", 10000),
                distance_km=distance_km,
                estimated_time_minutes=duration_minutes,
            )
        
        return PriceEstimateResponse(
            distance_km=distance_km,
            estimated_duration_minutes=duration_minutes,
            providers=providers
        )


# ============================================================================
# DELIVERY OPTION SERVICE
# ============================================================================

class DeliveryOptionService:
    """
    Manages delivery service options (Porter, Dunzo, etc.)
    """
    
    def __init__(self):
        self.options = DELIVERY_OPTIONS_SCHEMA
    
    def get_all_options(self) -> Dict[str, DeliveryOption]:
        """Get all available delivery options"""
        return {
            key: DeliveryOption(
                id=val["id"],
                name=val["name"],
                icon_url=val["iconUrl"],
                description=val["description"],
                website=val["website"],
                is_available=val.get("isAvailable", True)
            )
            for key, val in self.options.items()
        }
    
    def get_option(self, option_id: str) -> Optional[DeliveryOption]:
        """Get specific delivery option by ID"""
        if option_id not in self.options:
            return None
        
        opt = self.options[option_id]
        return DeliveryOption(
            id=opt["id"],
            name=opt["name"],
            icon_url=opt["iconUrl"],
            description=opt["description"],
            website=opt["website"],
            is_available=opt.get("isAvailable", True)
        )


# ============================================================================
# DELIVERY REDIRECT SERVICE
# ============================================================================

class DeliveryRedirectService:
    """
    Generates URLs and handles redirects to external delivery services.
    """
    
    REDIRECT_URLS = {
        "porter": {
            "web": "https://www.porter.in/app",
            "deep_link": "porter://",
            "description": "Open Porter app to book delivery"
        },
        "dunzo": {
            "web": "https://dunzohub.com",
            "deep_link": "dunzo://",
            "description": "Open Dunzo app to book delivery"
        },
        "rapido": {
            "web": "https://www.rapido.app",
            "deep_link": "rapido://",
            "description": "Open Rapido app to book delivery"
        },
        "swiggy_genie": {
            "web": "https://www.swiggy.com/genie",
            "deep_link": "swiggy://",
            "description": "Open Swiggy Genie to book delivery"
        },
        "self_service": {
            "web": None,
            "deep_link": None,
            "description": "Handle delivery yourself"
        }
    }
    
    @staticmethod
    def generate_redirect_url(provider: str, is_mobile: bool = False) -> Optional[str]:
        """
        Generate redirect URL for delivery provider.
        
        Args:
            provider: "porter", "dunzo", "rapido", "swiggy_genie", "self_service"
            is_mobile: Whether to use deep link (app) or web URL
            
        Returns:
            URL string or None for self-service
        """
        if provider not in DeliveryRedirectService.REDIRECT_URLS:
            logger.warning(f"Unknown provider: {provider}")
            return None
        
        config = DeliveryRedirectService.REDIRECT_URLS[provider]
        
        if provider == "self_service":
            return None  # No redirect for self-service
        
        # Use deep link for mobile, web URL for desktop
        if is_mobile and config.get("deep_link"):
            return config["deep_link"]
        
        return config.get("web")
    
    @staticmethod
    def format_delivery_address(address: str, city: str = "", postal_code: str = "") -> str:
        """
        Format address for external delivery service.
        Removes special characters and extra spaces.
        
        Args:
            address: Full address
            city: City name
            postal_code: Postal/ZIP code
            
        Returns:
            Formatted address string
        """
        parts = [address, city, postal_code]
        formatted = ", ".join([p for p in parts if p])
        # Remove extra spaces
        formatted = " ".join(formatted.split())
        return formatted


# ============================================================================
# DELIVERY STATUS SERVICE
# ============================================================================

class DeliveryStatusService:
    """
    Manages delivery status tracking and updates.
    """
    
    @staticmethod
    def calculate_eta(estimated_delivery_minutes: int, booked_at: datetime = None) -> datetime:
        """
        Calculate estimated time of arrival.
        
        Args:
            estimated_delivery_minutes: ETA from delivery service
            booked_at: When the delivery was booked (default: now)
            
        Returns:
            Estimated delivery datetime
        """
        if booked_at is None:
            booked_at = datetime.now()
        
        eta = booked_at + timedelta(minutes=estimated_delivery_minutes)
        return eta
    
    @staticmethod
    def get_status_badge(status: str) -> Dict[str, str]:
        """
        Get badge styling for status display.
        
        Returns:
            {color, label, icon}
        """
        badges = {
            "pending": {"color": "gray", "label": "Pending", "icon": "⏱️"},
            "booked": {"color": "blue", "label": "Booked", "icon": "✓"},
            "in_progress": {"color": "orange", "label": "On the way", "icon": "🚚"},
            "delivered": {"color": "green", "label": "Delivered", "icon": "✓✓"},
            "cancelled": {"color": "red", "label": "Cancelled", "icon": "✗"},
        }
        return badges.get(status, badges["pending"])
    
    @staticmethod
    def get_status_timeline():
        """Get complete delivery status timeline for UI"""
        return [
            {"step": 1, "status": "pending", "label": "Pending"},
            {"step": 2, "status": "booked", "label": "Booked"},
            {"step": 3, "status": "in_progress", "label": "In Transit"},
            {"step": 4, "status": "delivered", "label": "Delivered"},
        ]


# ============================================================================
# CLIPBOARD SERVICE
# ============================================================================

class ClipboardService:
    """
    Handles copying addresses to clipboard for easy pasting in external apps.
    """
    
    @staticmethod
    def format_clipboard_text(pickup_address: str, drop_address: str) -> str:
        """
        Format addresses for clipboard copying.
        
        Returns:
            Formatted text for clipboard
        """
        return f"PICKUP: {pickup_address}\n\nDROP: {drop_address}"
    
    @staticmethod
    def create_copy_payload(pickup_location: LocationData, 
                           drop_location: LocationData) -> Dict[str, str]:
        """
        Create payload for JavaScript to copy to clipboard.
        
        Returns:
            {pickupAddress, dropAddress, fullText}
        """
        pickup_text = DeliveryRedirectService.format_delivery_address(
            pickup_location.address,
            pickup_location.city,
            pickup_location.postal_code
        )
        drop_text = DeliveryRedirectService.format_delivery_address(
            drop_location.address,
            drop_location.city,
            drop_location.postal_code
        )
        
        return {
            "pickupAddress": pickup_text,
            "dropAddress": drop_text,
            "fullText": ClipboardService.format_clipboard_text(pickup_text, drop_text),
        }


# ============================================================================
# MAIN DELIVERY SERVICE (Facade)
# ============================================================================

class DeliveryService:
    """
    Main service that orchestrates all delivery operations.
    Uses dependency injection for modularity.
    """
    
    def __init__(self):
        self.price_estimator = PriceEstimationService()
        self.options = DeliveryOptionService()
        self.redirect = DeliveryRedirectService()
        self.status = DeliveryStatusService()
        self.clipboard = ClipboardService()
    
    def get_delivery_options(self) -> Dict:
        """Get all delivery options with their details"""
        options = self.options.get_all_options()
        return {key: opt.to_dict() for key, opt in options.items()}
    
    def estimate_prices(self, 
                       pickup_lat: float,
                       pickup_lng: float,
                       drop_lat: float,
                       drop_lng: float) -> Dict:
        """Estimate prices for all delivery providers"""
        # Note: In real usage, you might want to pass serving_capacity from donation data
        # For now, we use 0 (no multiplier) to match existing API
        response = self.price_estimator.estimate_all_providers(
            pickup_lat, pickup_lng, drop_lat, drop_lng, serving_capacity=0
        )
        return response.to_dict()
    
    def prepare_booking(self,
                       provider: str,
                       pickup_location: LocationData,
                       drop_location: LocationData,
                       is_mobile: bool = False) -> Dict:
        """
        Prepare all data needed for delivery booking.
        
        Returns:
            {redirectUrl, addresses, description}
        """
        return {
            "redirectUrl": self.redirect.generate_redirect_url(provider, is_mobile),
            "addresses": self.clipboard.create_copy_payload(pickup_location, drop_location),
            "description": self.redirect.REDIRECT_URLS.get(provider, {}).get("description", ""),
        }