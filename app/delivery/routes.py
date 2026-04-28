# app/delivery/routes.py
# Flask Routes for Delivery API Endpoints (Firebase-Compatible)

from flask import Blueprint, request, jsonify, render_template
from flask_cors import cross_origin
from .services import DeliveryService
from .models import LocationData, DeliveryStatus
import firebase_admin
from firebase_admin import firestore
import logging
from datetime import datetime

logger = logging.getLogger(__name__)

# Create Blueprint
delivery_bp = Blueprint('delivery', __name__, url_prefix='/api/delivery')

# Initialize services
delivery_service = DeliveryService()
db = firestore.client()

# ============================================================================
# FRONTEND PAGES (✅ ADDED — NOTHING REMOVED)
# ============================================================================

@delivery_bp.route('/options-page', methods=['GET'])
def delivery_options_page():
    return render_template('delivery/delivery_options.html')

@delivery_bp.route('/status-page/<donation_id>', methods=['GET'])
def delivery_status_page(donation_id):
    return render_template('delivery/delivery_status.html')

# ============================================================================
# NEW: MAIN INDEX (for web)
# ============================================================================

@delivery_bp.route('/', methods=['GET'])
def index():
    return render_template('delivery/index.html')

# ============================================================================
# HEALTH CHECK
# ============================================================================

@delivery_bp.route('/health', methods=['GET'])
def health_check():
    return jsonify({
        "status": "healthy",
        "service": "delivery",
        "timestamp": datetime.now().isoformat()
    }), 200

# ============================================================================
# DELIVERY OPTIONS (API)
# ============================================================================

@delivery_bp.route('/options', methods=['GET'])
@cross_origin()
def get_delivery_options():
    try:
        options = delivery_service.get_delivery_options()
        return jsonify({"success": True, "data": options}), 200
    except Exception as e:
        logger.error(f"Error getting delivery options: {str(e)}")
        return jsonify({"success": False, "error": str(e)}), 500

# ============================================================================
# PRICE ESTIMATION (NEW STYLE: /quote) — ✅ WITH serving_capacity
# ============================================================================

@delivery_bp.route('/quote', methods=['POST'])
@cross_origin()
def quote():
    try:
        data = request.get_json()
        
        if not data:
            return jsonify({"success": False, "error": "No data provided"}), 400
        
        required = ['pickup_lat', 'pickup_lng', 'dropoff_lat', 'dropoff_lng']
        missing = [k for k in required if k not in data or data[k] is None]
        
        if missing:
            return jsonify({
                "success": False, 
                "error": f"Missing required fields: {', '.join(missing)}"
            }), 400

        # Validate and convert to float
        try:
            pickup_lat = float(data['pickup_lat'])
            pickup_lng = float(data['pickup_lng'])
            dropoff_lat = float(data['dropoff_lat'])
            dropoff_lng = float(data['dropoff_lng'])
            serving_capacity = int(data.get('serving_capacity', 0))
        except (ValueError, TypeError) as e:
            return jsonify({
                "success": False,
                "error": f"Invalid values: {str(e)}"
            }), 400

        # Validate coordinate ranges
        if not (-90 <= pickup_lat <= 90) or not (-90 <= dropoff_lat <= 90):
            return jsonify({
                "success": False,
                "error": "Latitude must be between -90 and 90"
            }), 400
        
        if not (-180 <= pickup_lng <= 180) or not (-180 <= dropoff_lng <= 180):
            return jsonify({
                "success": False,
                "error": "Longitude must be between -180 and 180"
            }), 400

        estimates = delivery_service.price_estimator.estimate_all_providers(
            pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, serving_capacity
        )

        return jsonify({
            "success": True,
            "data": estimates.to_dict()
        }), 200

    except Exception as e:
        logger.error(f"Error in /quote: {str(e)}", exc_info=True)
        return jsonify({"success": False, "error": str(e)}), 500

# ============================================================================
# CREATE DELIVERY ORDER (Firebase version of /order)
# ============================================================================

@delivery_bp.route('/order', methods=['POST'])
@cross_origin()
def order():
    try:
        data = request.get_json()
        donation_id = data.get('donation_id')
        if not donation_id:
            return jsonify({"success": False, "error": "donation_id required"}), 400

        # Save delivery order to Firestore
        order_ref = db.collection('delivery_orders').document()
        order_data = {
            'donation_id': donation_id,
            'pickup_lat': data.get('pickup_lat'),
            'pickup_lng': data.get('pickup_lng'),
            'dropoff_lat': data.get('dropoff_lat'),
            'dropoff_lng': data.get('dropoff_lng'),
            'ngo_id': data.get('ngo_id'),
            'ngo_name': data.get('ngo_name', ''),
            'ngo_phone': data.get('ngo_phone', ''),
            'donor_name': data.get('donor_name', ''),
            'donor_phone': data.get('donor_phone', ''),
            'status': 'pending',
            'created_at': firestore.SERVER_TIMESTAMP
        }
        order_ref.set(order_data)

        # Update donation with delivery info
        db.collection('donations').document(donation_id).update({
            "status": "in_delivery",
            "deliveryOrderId": order_ref.id,
            "deliveryStatus": "pending",
            "updatedAt": firestore.SERVER_TIMESTAMP
        })

        return jsonify({
            "success": True,
            "order_id": order_ref.id,
            "status": "pending"
        }), 200

    except Exception as e:
        logger.error(f"Error creating delivery order: {str(e)}")
        return jsonify({"success": False, "error": str(e)}), 500

# ============================================================================
# FLUTTER DELIVERY REQUEST PAGE — ✅ PASSES serving_capacity
# ============================================================================

@delivery_bp.route('/request')
def delivery_request():
    """
    Handles delivery requests from the Flutter app via query params.
    Renders a confirmation page.
    """
    donation_id = request.args.get('donation_id')
    ngo_id = request.args.get('ngo_id')
    pickup_lat = request.args.get('pickup_lat')
    pickup_lng = request.args.get('pickup_lng')
    dropoff_lat = request.args.get('dropoff_lat')
    dropoff_lng = request.args.get('dropoff_lng')
    ngo_name = request.args.get('ngo_name', '')
    ngo_phone = request.args.get('ngo_phone', '')
    donor_name = request.args.get('donor_name', '')
    donor_phone = request.args.get('donor_phone', '')
    serving_capacity = request.args.get('serving_capacity', '0')  # ✅ ADDED

    # Validate essential params
    if not all([donation_id, ngo_id, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng]):
        return jsonify({"error": "Missing required parameters"}), 400

    return render_template(
        'delivery/flutter_request.html',
        donation_id=donation_id,
        ngo_id=ngo_id,
        pickup_lat=pickup_lat,
        pickup_lng=pickup_lng,
        dropoff_lat=dropoff_lat,
        dropoff_lng=dropoff_lng,
        ngo_name=ngo_name,
        ngo_phone=ngo_phone,
        donor_name=donor_name,
        donor_phone=donor_phone,
        serving_capacity=serving_capacity  # ✅ ADDED
    )

# ============================================================================
# EXISTING DELIVERY LOGIC (KEEP YOUR ORIGINAL ROUTES)
# ============================================================================

@delivery_bp.route('/estimate-price', methods=['POST'])
@cross_origin()
def estimate_price():
    try:
        data = request.get_json()
        required_fields = ['pickupLat', 'pickupLng', 'dropLat', 'dropLng']
        if not all(field in data for field in required_fields):
            return jsonify({
                "success": False,
                "error": f"Missing required fields: {', '.join(required_fields)}"
            }), 400

        pickup_lat = float(data['pickupLat'])
        pickup_lng = float(data['pickupLng'])
        drop_lat = float(data['dropLat'])
        drop_lng = float(data['dropLng'])

        estimates = delivery_service.estimate_prices(
            pickup_lat, pickup_lng, drop_lat, drop_lng
        )

        return jsonify({
            "success": True,
            "data": estimates
        }), 200

    except Exception as e:
        logger.error(f"Error estimating price: {str(e)}")
        return jsonify({
            "success": False,
            "error": str(e)
        }), 500

@delivery_bp.route('/prepare-booking', methods=['POST'])
@cross_origin()
def prepare_booking():
    try:
        data = request.get_json()
        pickup_location = LocationData(
            latitude=data.get('pickupLat', 0),
            longitude=data.get('pickupLng', 0),
            address=data['pickupAddress'],
            city=data.get('pickupCity', ''),
            postal_code=data.get('pickupPostalCode', '')
        )
        drop_location = LocationData(
            latitude=data.get('dropLat', 0),
            longitude=data.get('dropLng', 0),
            address=data['dropAddress'],
            city=data.get('dropCity', ''),
            postal_code=data.get('dropPostalCode', '')
        )
        booking_data = delivery_service.prepare_booking(
            data['provider'],
            pickup_location,
            drop_location,
            data.get('isMobile', False)
        )
        return jsonify({"success": True, "data": booking_data}), 200
    except Exception as e:
        logger.error(f"Error preparing booking: {str(e)}")
        return jsonify({"success": False, "error": str(e)}), 500

@delivery_bp.route('/book', methods=['POST'])
@cross_origin()
def record_booking():
    try:
        data = request.get_json()
        donation_id = data['donationId']
        db.collection('donations').document(donation_id).update({
            "delivery": {
                "method": data['provider'],
                "status": "booked",
                "estimatedPrice": float(data['estimatedPrice']),
                "distanceKm": float(data.get('distance', 0)),
                "bookedAt": firestore.SERVER_TIMESTAMP
            },
            "status": "in_delivery",
            "updatedAt": firestore.SERVER_TIMESTAMP
        })
        return jsonify({
            "success": True,
            "data": {
                "donationId": donation_id,
                "status": "booked"
            }
        }), 200
    except Exception as e:
        logger.error(f"Error recording booking: {str(e)}")
        return jsonify({"success": False, "error": str(e)}), 500

@delivery_bp.route('/status/<donation_id>', methods=['GET'])
@cross_origin()
def get_delivery_status(donation_id):
    try:
        doc = db.collection('donations').document(donation_id).get()
        if not doc.exists:
            return jsonify({"success": False, "error": "Donation not found"}), 404
        donation_data = doc.to_dict()
        delivery_data = donation_data.get('delivery', {})
        status = delivery_data.get('status', 'pending')
        status_badge = delivery_service.status.get_status_badge(status)
        return jsonify({
            "success": True,
            "data": {
                "donationId": donation_id,
                "method": delivery_data.get('method'),
                "status": status,
                "estimatedPrice": delivery_data.get('estimatedPrice'),
                "distance": delivery_data.get('distanceKm'),
                "statusBadge": status_badge,
                "timeline": delivery_service.status.get_status_timeline(),
                "bookedAt": delivery_data.get('bookedAt'),
                "deliveredAt": delivery_data.get('deliveredAt')
            }
        }), 200
    except Exception as e:
        logger.error(f"Error getting delivery status: {str(e)}")
        return jsonify({"success": False, "error": str(e)}), 500