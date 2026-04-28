# app.py - Flask Backend with Firebase Integration
from flask import Flask, render_template, request, jsonify, redirect
from flask_cors import CORS  # Added for cross-origin support
import firebase_admin
from firebase_admin import credentials, firestore
import os

# Initialize Flask app
app = Flask(
    __name__,
    template_folder="app/templates",
    static_folder="app/static"
)

# Enable CORS for all routes (important for Flutter/web clients)
CORS(app)

# Initialize Firebase Admin SDK only once
if not firebase_admin._apps:
    # Ensure 'serviceAccountKey.json' is in the same directory
    cred = credentials.Certificate('serviceAccountKey.json')
    firebase_admin.initialize_app(cred)
db = firestore.client()

# ======================
# Routes
# ======================

@app.route('/')
def home():
    return render_template('index.html')

@app.route('/api/delivery/request')
def delivery_request():
    """Handle delivery request from Flutter app"""
    try:
        donation_id = request.args.get('donation_id')
        ngo_id = request.args.get('ngo_id')
        pickup_lat = float(request.args.get('pickup_lat'))
        pickup_lng = float(request.args.get('pickup_lng'))
        dropoff_lat = float(request.args.get('dropoff_lat'))
        dropoff_lng = float(request.args.get('dropoff_lng'))
        ngo_name = request.args.get('ngo_name', '')
        ngo_phone = request.args.get('ngo_phone', '')
        donor_name = request.args.get('donor_name', '')
        donor_phone = request.args.get('donor_phone', '')
        serving_capacity = request.args.get('serving_capacity', '0')

        delivery_data = {
            'donation_id': donation_id,
            'ngo_id': ngo_id,
            'pickup_lat': pickup_lat,
            'pickup_lng': pickup_lng,
            'dropoff_lat': dropoff_lat,
            'dropoff_lng': dropoff_lng,
            'ngo_name': ngo_name,
            'ngo_phone': ngo_phone,
            'donor_name': donor_name,
            'donor_phone': donor_phone,
            'serving_capacity': serving_capacity,
            'status': 'pending',
            'created_at': firestore.SERVER_TIMESTAMP,
            'driver_name': None,
            'driver_phone': None,
            'driver_lat': None,
            'driver_lng': None,
            'vehicle_number': None,
            'driver_rating': None,
            'delivery_company': None,
            'assignment_type': None,
            'api_provider': None,
        }

        db.collection('deliveries').document(donation_id).set(delivery_data)

        # ✅ FIXED: Include 'delivery/' subfolder in template path
        return render_template('delivery/delivery_request.html',
                               donation_id=donation_id,
                               pickup_lat=pickup_lat,
                               pickup_lng=pickup_lng,
                               dropoff_lat=dropoff_lat,
                               dropoff_lng=dropoff_lng,
                               ngo_name=ngo_name,
                               ngo_phone=ngo_phone,
                               donor_name=donor_name,
                               donor_phone=donor_phone,
                               serving_capacity=serving_capacity)
    except Exception as e:
        return f"Error: {str(e)}", 400

@app.route('/api/delivery/assign', methods=['POST'])
def assign_delivery():
    """Assign delivery partner and update Firebase"""
    try:
        data = request.json
        donation_id = data.get('donation_id')
        delivery_company = data.get('delivery_company', 'manual')
        assignment_type = data.get('assignment_type', 'manual')

        delivery_ref = db.collection('deliveries').document(donation_id)
        
        update_data = {
            'delivery_company': delivery_company,
            'assignment_type': assignment_type,
            'status': 'confirmed',
            'confirmed_at': firestore.SERVER_TIMESTAMP,
        }

        if assignment_type == 'manual':
            driver_name = data.get('driver_name')
            driver_phone = data.get('driver_phone')
            vehicle_number = data.get('vehicle_number')
            driver_rating = data.get('driver_rating', 4.5)

            update_data.update({
                'driver_name': driver_name,
                'driver_phone': driver_phone,
                'vehicle_number': vehicle_number,
                'driver_rating': driver_rating,
            })
        
        elif assignment_type == 'api':
            api_provider = data.get('api_provider')
            
            update_data.update({
                'api_provider': api_provider,
                'api_request_sent_at': firestore.SERVER_TIMESTAMP,
                'driver_name': None,
                'driver_phone': None,
                'vehicle_number': None,
                'driver_rating': None,
            })
            # TODO: Integrate actual delivery APIs here (Swiggy, Porter, etc.)

        delivery_ref.update(update_data)

        donation_ref = db.collection('donations').document(donation_id)
        donation_ref.update({
            'deliveryStatus': 'confirmed',
            'deliveryConfirmedAt': firestore.SERVER_TIMESTAMP,
            'deliveryCompany': delivery_company,
        })

        return jsonify({
            'success': True,
            'message': 'Delivery partner assigned successfully',
            'assignment_type': assignment_type
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 400

@app.route('/api/delivery/update-status', methods=['POST'])
def update_delivery_status():
    """Update delivery status (picked_up, in_transit, delivered)"""
    try:
        data = request.json
        donation_id = data.get('donation_id')
        status = data.get('status')
        driver_lat = data.get('driver_lat')
        driver_lng = data.get('driver_lng')

        delivery_ref = db.collection('deliveries').document(donation_id)
        update_data = {'status': status}

        if driver_lat and driver_lng:
            update_data['driver_lat'] = driver_lat
            update_data['driver_lng'] = driver_lng

        if status == 'picked_up':
            update_data['picked_up_at'] = firestore.SERVER_TIMESTAMP
        elif status == 'in_transit':
            update_data['in_transit_at'] = firestore.SERVER_TIMESTAMP
        elif status == 'delivered':
            update_data['delivered_at'] = firestore.SERVER_TIMESTAMP

        delivery_ref.update(update_data)

        db.collection('donations').document(donation_id).update({
            'deliveryStatus': status,
        })

        return jsonify({
            'success': True,
            'message': f'Status updated to {status}'
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 400

@app.route('/api/delivery/track/<donation_id>')
def track_delivery(donation_id):
    """Get delivery tracking information"""
    try:
        doc = db.collection('deliveries').document(donation_id).get()
        if not doc.exists:
            return jsonify({'success': False, 'error': 'Delivery not found'}), 404
        return jsonify({'success': True, 'data': doc.to_dict()})
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 400

# ✅ NEW: Webhook for delivery companies (Swiggy, Porter, etc.)
@app.route('/api/delivery/webhook/driver-assigned', methods=['POST'])
def webhook_driver_assigned():
    """
    Webhook endpoint for delivery companies to notify when driver is assigned.
    Expected JSON payload:
    {
        "donation_id": "don_123",
        "driver_name": "Rajesh",
        "driver_phone": "+919876543210",
        "vehicle_number": "KA01AB1234",
        "driver_rating": 4.7,
        "driver_lat": 12.9716,
        "driver_lng": 77.5946
    }
    """
    try:
        data = request.json
        
        required_fields = ['donation_id', 'driver_name', 'driver_phone', 'vehicle_number']
        for field in required_fields:
            if field not in data or not data[field]:
                return jsonify({
                    'success': False,
                    'error': f'Missing or empty required field: {field}'
                }), 400
        
        donation_id = data['donation_id']
        update_data = {
            'driver_name': data['driver_name'],
            'driver_phone': data['driver_phone'],
            'vehicle_number': data['vehicle_number'],
            'driver_rating': data.get('driver_rating', 4.5),
            'driver_assigned_at': firestore.SERVER_TIMESTAMP,
        }
        
        if data.get('driver_lat') and data.get('driver_lng'):
            update_data['driver_lat'] = data['driver_lat']
            update_data['driver_lng'] = data['driver_lng']
        
        # Update delivery record
        db.collection('deliveries').document(donation_id).update(update_data)

        # Update donation record
        db.collection('donations').document(donation_id).update({
            'deliveryStatus': 'confirmed',
            'driverAssigned': True,
        })

        return jsonify({
            'success': True,
            'message': 'Driver details updated successfully'
        })
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 400

# Optional: Health check endpoint
@app.route('/health')
def health():
    return jsonify({"status": "healthy", "service": "Food Donation Backend"}), 200

# ======================
# Run
# ======================

if __name__ == '__main__':
    print("🚀 Starting Food Donation Backend Server...")
    print("✅ Endpoints:")
    for rule in app.url_map.iter_rules():
        methods = ', '.join(sorted(rule.methods - {'HEAD', 'OPTIONS'}))
        print(f"   - {methods:6} {rule.rule}")
    print("\n📡 Server running on http://0.0.0.0:5000\n")
    app.run(host='0.0.0.0', port=5000, debug=True)