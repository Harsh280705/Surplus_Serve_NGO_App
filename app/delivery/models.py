# app/delivery/models.py
# Firestore Models for Delivery Module

from dataclasses import dataclass
from typing import Optional, List
from datetime import datetime
from enum import Enum

# ============================================================================
# ENUMS
# ============================================================================

class DeliveryMethod(str, Enum):
    """Supported delivery methods"""
    PORTER = "porter"
    DUNZO = "dunzo"
    RAPIDO = "rapido"
    SWIGGY_GENIE = "swiggy_genie"
    SELF_SERVICE = "self_service"


class DeliveryStatus(str, Enum):
    """Delivery status lifecycle"""
    PENDING = "pending"              # User hasn't chosen delivery method yet
    BOOKED = "booked"                # User booked on external service
    IN_PROGRESS = "in_progress"      # Delivery in transit
    DELIVERED = "delivered"          # Delivery completed
    CANCELLED = "cancelled"          # Delivery cancelled


# ============================================================================
# DATA CLASSES (Pydantic Models for validation)
# ============================================================================

@dataclass
class LocationData:
    """Represents a geographic location"""
    latitude: float
    longitude: float
    address: str
    city: str = ""
    postal_code: str = ""
    
    def to_dict(self):
        return {
            "latitude": self.latitude,
            "longitude": self.longitude,
            "address": self.address,
            "city": self.city,
            "postal_code": self.postal_code,
        }


@dataclass
class DeliveryPriceData:
    """Price estimation for a delivery service"""
    provider: str                    # "porter", "dunzo", "rapido", "swiggy"
    base_fare: float                 # Base fare (₹)
    per_km_rate: float              # Per kilometer rate (₹)
    estimated_price: float           # Calculated estimated price (₹)
    min_fare: float = 0             # Minimum fare
    max_fare: float = 10000         # Maximum fare
    distance_km: float = 0          # Distance calculated
    estimated_time_minutes: int = 30 # ETA in minutes
    
    def to_dict(self):
        return {
            "provider": self.provider,
            "baseFare": self.base_fare,
            "perKmRate": self.per_km_rate,
            "estimatedPrice": round(self.estimated_price, 2),
            "minFare": self.min_fare,
            "maxFare": self.max_fare,
            "distanceKm": round(self.distance_km, 2),
            "estimatedTimeMinutes": self.estimated_time_minutes,
        }


@dataclass
class DeliveryOption:
    """Represents a delivery service option"""
    id: str                         # "porter", "dunzo", "rapido", "swiggy", "self"
    name: str                       # "Porter", "Dunzo", "Rapido", "Swiggy Genie", "Self-Service"
    icon_url: str                   # URL to service icon
    description: str                # Brief description
    website: str                    # URL to website
    is_available: bool = True       # Service availability status
    
    def to_dict(self):
        return {
            "id": self.id,
            "name": self.name,
            "iconUrl": self.icon_url,
            "description": self.description,
            "website": self.website,
            "isAvailable": self.is_available,
        }


@dataclass
class DeliveryRecord:
    """Complete delivery record for a donation"""
    donation_id: str                # Reference to donation
    method: DeliveryMethod          # Which service is used
    status: DeliveryStatus = DeliveryStatus.PENDING
    estimated_price: float = 0      # Estimated cost (₹)
    actual_price: Optional[float] = None  # Actual cost if known
    distance_km: float = 0          # Distance between pickup and drop
    pickup_location: Optional[LocationData] = None
    drop_location: Optional[LocationData] = None
    booked_at: Optional[datetime] = None  # When user confirmed booking
    delivered_at: Optional[datetime] = None  # When delivery completed
    external_booking_id: Optional[str] = None  # ID from external service
    notes: str = ""                 # Additional notes
    
    def to_dict(self):
        return {
            "donationId": self.donation_id,
            "method": self.method.value,
            "status": self.status.value,
            "estimatedPrice": round(self.estimated_price, 2),
            "actualPrice": round(self.actual_price, 2) if self.actual_price else None,
            "distanceKm": round(self.distance_km, 2),
            "pickupLocation": self.pickup_location.to_dict() if self.pickup_location else None,
            "dropLocation": self.drop_location.to_dict() if self.drop_location else None,
            "bookedAt": self.booked_at.isoformat() if self.booked_at else None,
            "deliveredAt": self.delivered_at.isoformat() if self.delivered_at else None,
            "externalBookingId": self.external_booking_id,
            "notes": self.notes,
        }


@dataclass
class PriceEstimateRequest:
    """Request for price estimation"""
    pickup_latitude: float
    pickup_longitude: float
    drop_latitude: float
    drop_longitude: float
    
    def to_dict(self):
        return {
            "pickupLatitude": self.pickup_latitude,
            "pickupLongitude": self.pickup_longitude,
            "dropLatitude": self.drop_latitude,
            "dropLongitude": self.drop_longitude,
        }


@dataclass
class PriceEstimateResponse:
    """Response with estimated prices"""
    distance_km: float
    estimated_duration_minutes: int
    providers: dict  # {provider_id: DeliveryPriceData}
    
    def to_dict(self):
        return {
            "distanceKm": round(self.distance_km, 2),
            "estimatedDurationMinutes": self.estimated_duration_minutes,
            "providers": {
                key: value.to_dict() if isinstance(value, DeliveryPriceData) else value
                for key, value in self.providers.items()
            },
        }


# ============================================================================
# FIRESTORE DOCUMENT SCHEMAS
# ============================================================================

DELIVERY_OPTIONS_SCHEMA = {
    "porter": {
        "id": "porter",
        "name": "Porter",
        "iconUrl": "/static/images/delivery_icons/porter.png",
        "description": "Fast food delivery service",
        "website": "https://www.porter.in/app",
        "isAvailable": True,
    },
    "dunzo": {
        "id": "dunzo",
        "name": "Dunzo",
        "iconUrl": "/static/images/delivery_icons/dunzo.png",
        "description": "Quick delivery in your city",
        "website": "https://dunzohub.com",
        "isAvailable": True,
    },
    "rapido": {
        "id": "rapido",
        "name": "Rapido",
        "iconUrl": "/static/images/delivery_icons/rapido.png",
        "description": "Bike delivery service",
        "website": "https://www.rapido.app",
        "isAvailable": True,
    },
    "swiggy_genie": {
        "id": "swiggy_genie",
        "name": "Swiggy Genie",
        "iconUrl": "/static/images/delivery_icons/swiggy_genie.png",
        "description": "Multi-category delivery",
        "website": "https://www.swiggy.com/genie",
        "isAvailable": True,
    },
    "self_service": {
        "id": "self_service",
        "name": "Self-Service Delivery",
        "iconUrl": "/static/images/delivery_icons/self_service.png",
        "description": "Donor or NGO handles delivery",
        "website": "",
        "isAvailable": True,
    },
}


# ============================================================================
# DELIVERY PRICING CONFIG — ✅ UPDATED WITH NEW RATES
# ============================================================================

DELIVERY_PRICING_CONFIG = {
    "porter": {
        "provider": "porter",
        "baseFare": 30,
        "perKmRate": 12,
        "minFare": 30,
        "maxFare": 500,
        "estimatedDeliveryTime": 45,
        "lastUpdated": datetime.now().isoformat(),
    },
    "dunzo": {
        "provider": "dunzo",
        "baseFare": 35,
        "perKmRate": 13,
        "minFare": 35,
        "maxFare": 600,
        "estimatedDeliveryTime": 60,
        "lastUpdated": datetime.now().isoformat(),
    },
    "rapido": {
        "provider": "rapido",
        "baseFare": 25,
        "perKmRate": 10,
        "minFare": 25,
        "maxFare": 400,
        "estimatedDeliveryTime": 40,
        "lastUpdated": datetime.now().isoformat(),
    },
    "swiggy_genie": {
        "provider": "swiggy_genie",
        "baseFare": 40,
        "perKmRate": 14,
        "minFare": 40,
        "maxFare": 700,
        "estimatedDeliveryTime": 50,
        "lastUpdated": datetime.now().isoformat(),
    },
    "self_service": {
        "provider": "self_service",
        "baseFare": 0,
        "perKmRate": 0,
        "minFare": 0,
        "maxFare": 0,
        "estimatedDeliveryTime": 0,
        "lastUpdated": datetime.now().isoformat(),
    },
}